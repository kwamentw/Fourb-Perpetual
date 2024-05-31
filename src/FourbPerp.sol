//SPDX-License-Identifier:MIT
pragma solidity 0.8.20;

import {IERC20} from "lib/forge-std/src/interfaces/IERC20.sol";
import {pricefeed} from "./PriceFeed.sol";

/**
 * @title FOURB PERPETUAL
 * @author 4b
 * @notice A custom perpetual contract
 */
contract FourbPerp {
    /////////////////// events ///////////////////////
    event Update(uint256 timeSinceUpdate, bool isUpdate);
    event PositionLiquidated(address liquidated, uint256 collateral);
    event PositionIncrease(uint256 amountToIncrease, bool isCollateral);
    event PositionDecrease(uint256 amountToDecrease, bool isCollateral);
    event PositionOpened(address sender, uint256 positionSize, bool isLOng);
    event LiquidityAdded(address liquidityProvider, uint256 amount);
    event LiquidityRemoved(address liquidityProvider, uint256 amount);

    // price feed
    pricefeed private PriceFeed;
    // token
    IERC20 private token;

    /////////////////////// mappings ////////////////////////////
    mapping(address => uint256) public collateral;
    mapping(address => uint256) public liquidity;
    mapping(address => Position) public positionDetails;

    uint256 immutable MAX_LEVERAGE = 150;
    uint256 public s_totalLiquidity;
    int256 public s_totalOpenInterestLong;
    int256 public s_totalOpenInterestLongTokens;
    int256 public s_totalOpenInterestShort;
    int256 public s_totalOpenInterestShortTokens;
    uint256 public s_borrowingPerSharePerSecond;
    uint256 sizeDelta;

    struct Position {
        uint256 entryPrice;
        uint256 collateral;
        bool isLong;
        uint256 size;
        uint256 timestamp;
    }

    constructor(address _token, uint256 _borrowingPerSharePerSecond) {
        token = IERC20(_token);
        s_borrowingPerSharePerSecond = _borrowingPerSharePerSecond;
    }

    /**
     * For setting BorrowingPerSharePerSecond
     */
    function setBorrowingPerSharePerSecond(
        uint256 _borrowingPerSharePerSecond
    ) external {
        s_borrowingPerSharePerSecond = _borrowingPerSharePerSecond;
    }

    /**
     * Adds Liquidity to the pool
     * @param amount amount to add
     */
    function addLiquidity(uint256 amount) public {
        require(amount > 0, "You can't supply zero liquidity");
        require(msg.sender != address(0), "Zero adddress");

        emit LiquidityAdded(msg.sender, amount);

        s_totalLiquidity += amount;
        liquidity[msg.sender] += amount;
        token.transferFrom(msg.sender, address(this), amount);
    }

    /**
     * LPs can use this to remove liquidity from the pool
     */
    function removeLiquidity(uint256 amount) public {
        require(amount > 0);
        require(
            liquidity[msg.sender] >= amount,
            "You have no liquidity in this pool"
        );
        // require(
        //     amount < s_totalOpenInterest,
        //     "Can't remove liquidity reserves"
        // );
        require(
            amount <
                uint256(s_totalOpenInterestShort) +
                    uint256(s_totalOpenInterestLong)
        );

        emit LiquidityRemoved(msg.sender, amount);

        if (amount == liquidity[msg.sender]) {
            delete liquidity[msg.sender];
        } else {
            liquidity[msg.sender] -= amount;
        }

        s_totalLiquidity -= amount;
        token.transfer(msg.sender, amount);
    }

    /**
     * Getting price from chainlink data feed
     */
    function getPrice() public pure returns (uint256) {
        uint256 currentPrice = 13; /*PriceFeed.getPrice();*/
        return currentPrice;
    }

    /**
     * Opens a new position
     */
    function openPosition(
        uint256 _collateral,
        uint256 _size,
        bool long
    ) external {
        require(_collateral > 10, "Collateral can't be less than 10");
        require(_size > 0, "Postion Size must be > 0");
        require(_size >= (MAX_LEVERAGE * s_totalLiquidity) / 100);
        // its supposed to getPrice() from chainlink
        uint256 currentPrice = 7;

        Position memory _position = Position({
            entryPrice: currentPrice,
            collateral: _collateral,
            isLong: long,
            size: _size,
            timestamp: block.timestamp
        });

        emit Update(_position.timestamp, true);
        emit PositionOpened(msg.sender, _size, true);

        positionDetails[msg.sender] = _position;
        // i dont update this in other functions
        collateral[msg.sender] = _collateral;
        token.transferFrom(msg.sender, address(this), _collateral);
        if (_position.isLong == true) {
            s_totalOpenInterestLongTokens += int256(_size * currentPrice);
            s_totalOpenInterestLong += int256(_size);
        } else {
            s_totalOpenInterestShortTokens += int256(_size * currentPrice);
            s_totalOpenInterestShort += int256(_size);
        }
    }

    /**
     * View function to get position details of a specified sender
     */
    function getPosition(address sender) public view returns (Position memory) {
        return positionDetails[sender];
    }

    /**
     * To increase the size of your position
     */
    function increaseSize(uint256 amountToIncrease) external {
        uint256 currentPrice = getPrice();
        // try check whether size is in dollars or tokens
        // check whether position is still healthy enough to increase
        require(amountToIncrease > 0, "Should be more than 0");
        Position memory pos = getPosition(msg.sender);
        // uint256 positionFee = (amountToIncrease * 30) / 10_000;
        // uint256 borrowingFee = (1000 * amountToIncrease) / 10_000;
        uint256 secondsSincePositionWasUpdated = block.timestamp > pos.timestamp
            ? block.timestamp - pos.timestamp
            : 0;

        pos.timestamp = block.timestamp;

        emit Update(secondsSincePositionWasUpdated, true);
        emit PositionIncrease(amountToIncrease, false);
        // pos.collateral -= positionFee;
        pos.size += amountToIncrease;
        sizeDelta += amountToIncrease;
        positionDetails[msg.sender] = pos;
        // token.transferFrom(msg.sender, address(this), borrowingFee);
        // borrowingFee -= borrowingFee;
        // token.transfer(address(this), positionFee);
        if (pos.isLong == true) {
            s_totalOpenInterestLong += int256(amountToIncrease);
            s_totalOpenInterestLongTokens += int256(
                amountToIncrease * currentPrice
            );
        } else {
            s_totalOpenInterestShortTokens += int256(
                amountToIncrease * currentPrice
            );
            s_totalOpenInterestShort += int256(amountToIncrease);
        }
    }

    /**
     * To decrease the size of your position
     */
    function decreaseSize(uint256 amountToDecrease) external {
        require(amountToDecrease > 0, "You cant decrease nothing");
        Position memory pos = getPosition(msg.sender);
        require(pos.size >= amountToDecrease);
        uint256 positionFee = (amountToDecrease * 3) / 1000;
        pos.collateral -= positionFee;
        pos.size -= amountToDecrease;
        // sizeDelta -= amountToDecrease;
        uint256 currentPrice = getPrice();
        // uint256 pnl;
        uint256 secondsSincePositionWasUpdated = block.timestamp > pos.timestamp
            ? block.timestamp - pos.timestamp
            : 0;

        // if (pos.isLong) {
        //     pnl = (currentPrice - pos.entryPrice) * amountToDecrease;
        // } else {
        //     pnl = (pos.entryPrice - currentPrice) * amountToDecrease;
        // }
        pos.timestamp = block.timestamp;
        emit Update(secondsSincePositionWasUpdated, true);
        // pos.collateral += pnl;
        emit PositionDecrease(amountToDecrease, false);
        positionDetails[msg.sender] = pos;
        token.transfer(address(this), positionFee);
        if (pos.isLong == true) {
            s_totalOpenInterestLongTokens -= int256(
                amountToDecrease * currentPrice
            );
            s_totalOpenInterestLong -= int256(amountToDecrease);
        } else {
            s_totalOpenInterestShortTokens -= int256(
                amountToDecrease * currentPrice
            );
            s_totalOpenInterestShort -= int256(amountToDecrease);
        }
    }

    /**
     * to increase the size of your collateral
     */
    function increaseCollateral(uint256 amountToIncrease) external {
        require(amountToIncrease > 0, "Should be greater than 0");
        require(msg.sender != address(0));

        emit PositionIncrease(amountToIncrease, true);
        Position memory pos = getPosition(msg.sender);
        uint256 secondsSincePositionWasUpdated = block.timestamp > pos.timestamp
            ? block.timestamp - pos.timestamp
            : 0;
        pos.timestamp = block.timestamp;
        emit Update(secondsSincePositionWasUpdated, true);
        pos.collateral += amountToIncrease;
        token.transferFrom(msg.sender, address(this), amountToIncrease);
        positionDetails[msg.sender] = pos;
    }

    /**
     * TO decrease the size of your collateral
     */
    function decreaseCollateral(uint256 amountToDecrease) external {
        require(amountToDecrease > 0, "You cannot decrease nothing");
        Position memory pos = getPosition(msg.sender);
        require(pos.collateral >= amountToDecrease);
        emit PositionDecrease(amountToDecrease, true);
        uint256 secondsSincePositionWasUpdated = block.timestamp > pos.timestamp
            ? block.timestamp - pos.timestamp
            : 0;
        pos.timestamp = block.timestamp;
        emit Update(secondsSincePositionWasUpdated, true);
        pos.collateral -= amountToDecrease;
        token.transferFrom(address(this), msg.sender, amountToDecrease);
        positionDetails[msg.sender] = pos;
    }

    /**
     *  LPs or external actors can liquidate you when your position become liquidatable
     * some protocols use the `decrease` functions to liquidate- i gotta check that out
     */
    function liquidate(address trader) external {
        require(msg.sender != address(0));
        require(msg.sender != trader);
        Position memory pos = getPosition(trader);
        require(pos.collateral > 0, "inavlid position cannot liquidate");

        // uint256 borrowingFee = ((pos.size - sizeDelta) * 10) / 1000;
        // uint256 currentPrice = getPrice();
        // uint256 pnl = pos.isLong
        //     ? (currentPrice - pos.entryPrice) * pos.size
        //     : (pos.entryPrice - currentPrice) * pos.size;
        // pos.collateral += pnl;
        uint256 fee = (pos.collateral * 3) / 100;

        emit PositionLiquidated(trader, pos.collateral);
        pos.collateral -= fee;
        // token.transferFrom(msg.sender, address(this), borrowingFee);
        token.transfer(msg.sender, fee);
        token.transfer(trader, pos.collateral);
        delete positionDetails[trader];
    }

    /**
     * FUnction to get position size
     */
    function getPostionSize(address sender) external view returns (uint256) {
        return positionDetails[sender].size;
    }

    /**
     * Function to get collateral of a position
     */
    function getPositionCollateral(
        address sender
    ) external view returns (uint256) {
        return positionDetails[sender].collateral;
    }

    /**
     * Leverage
     * mostly 50% of your deposited amount thats what is recommended
     * 50& = 5_000/10_000
     * require lev < max lev
     * lev = tokenamt * avgtokenprice/collateral
     * changed to public for testing purposes
     */
    function maxLeverage() public view returns (bool) {
        uint256 _collateral = positionDetails[msg.sender].collateral;
        uint256 _size = positionDetails[msg.sender].size;
        uint256 _maxLeverage = ((5_000 * _collateral) / 10_000);
        uint256 levAmount = _collateral + _maxLeverage;
        return levAmount > _size ? false : true;
    }

    /**
     * Borrowing fees
     * this is time dependent
     * precision is 10_000
     * have to write a setter function for _borrowingPerSharePerSecond
     */
    function calcBorrowingFees() internal view returns (uint256) {
        Position memory pos = positionDetails[msg.sender];
        uint256 pendingBorrowingFees = (pos.size *
            (block.timestamp - pos.timestamp) *
            s_borrowingPerSharePerSecond) / 10000;

        return pendingBorrowingFees;
    }

    /**
     * To get results of calcBorrowingPerShareFees
     */
    function getBorrowingFees() external view returns (uint256) {
        return calcBorrowingFees();
    }

    /**
     * calculates profit and loss for a trader position
     * returns Profit / loss figures for long & short
     * pnl = current price - entryprice - for long | short is the other way round
     */
    function calcPnL() internal view returns (int256 pNl) {
        Position memory pos = getPosition(msg.sender);
        uint256 currentPrice = getPrice();
        uint256 entryPrice = pos.entryPrice;
        if (pos.isLong) {
            pNl = (int256(pos.size * currentPrice) -
                int256(pos.size * entryPrice));
        } else {
            pNl = (int256(pos.size * entryPrice) -
                int256(pos.size * currentPrice));
        }

        return pNl;
    }

    /**
     * Gets profit and loss of msg.sender positon
     */
    function getPnL() external view returns (int256 pNl) {
        pNl = calcPnL();
    }

    /**
     * check postion's health
     * leverage is 50% of deposited collateral
     * max leverage is 150%
     */
    function isPositionLiquidatable() public view returns (bool) {
        Position memory pos = getPosition(msg.sender);
        uint256 col = pos.collateral;
        uint256 size = pos.size;

        uint256 amountFactor = (size * 100) / col;

        return amountFactor <= MAX_LEVERAGE ? true : false;
    }

    /**
     * Total profit/loss made a whole for the protocol
     * add negative pnls
     */
    function totalPnL(bool isLong) internal view returns (int256 totalPNL) {
        int256 currentPrice = int256(getPrice());
        if (isLong) {
            totalPNL =
                (s_totalOpenInterestLong * currentPrice) -
                s_totalOpenInterestLongTokens;
        } else {
            totalPNL =
                s_totalOpenInterestShortTokens -
                (s_totalOpenInterestShort * currentPrice);
        }
    }

    function getTotalPnL(bool isLong) external view returns (int256 totalPNL) {
        totalPNL = totalPnL(isLong);
    }
}
