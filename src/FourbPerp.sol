//SPDX-License-Identifier:MIT
pragma solidity 0.8.20;

// import {IERC20} from "lib/forge-std/src/interfaces/IERC20.sol";
import {ERC20} from "../test/ERC20Mock.sol";
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

    // Price feed
    pricefeed private PriceFeed;
    // Token
    ERC20 private token;

    /////////////////////// mappings ////////////////////////////
    mapping(address => uint256) public collateral;
    mapping(address => uint256) public liquidity;
    mapping(address => Position) public positionDetails;

    /////////////////// Storage variables ///////////////////////
    uint256 immutable MAX_LEVERAGE = 150;
    uint256 public s_totalLiquidity;
    uint256 public s_totalOpenInterestLong;
    uint256 public s_totalOpenInterestLongTokens;
    uint256 public s_totalOpenInterestShort;
    uint256 public s_totalOpenInterestShortTokens;
    uint256 public s_borrowingPerSharePerSecond;

    ///////////////////////// structs /////////////////////////////
    struct Position {
        uint256 entryPrice;
        uint256 collateral;
        bool isLong;
        uint256 size;
        uint256 timestamp;
    }

    //////////////////////////// constructor /////////////////////////////////
    constructor(address _token, uint256 _borrowingPerSharePerSecond) {
        token = ERC20(_token);
        s_borrowingPerSharePerSecond = _borrowingPerSharePerSecond;
    }

    //////////////////////////// Functions /////////////////////////////////////

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
        require(
            _size <= (MAX_LEVERAGE * _collateral) / 100,
            "Doesnt meet leverage criteria"
        );
        // its supposed to `getPrice()` from chainlink
        uint256 currentPrice = 12;

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
        token.transferFrom(msg.sender, address(this), _collateral);
        if (_position.isLong == true) {
            s_totalOpenInterestLongTokens += (_size) * (currentPrice);
            s_totalOpenInterestLong += (_size);
        } else {
            s_totalOpenInterestShortTokens += (_size) * (currentPrice);
            s_totalOpenInterestShort += (_size);
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
    function increaseSize(uint256 amountToIncrease, address trader) external {
        uint256 currentPrice = getPrice();
        // check whether position is still healthy enough to increase
        require(amountToIncrease > 0, "Should be more than 0");
        Position memory pos = getPosition(msg.sender);
        uint256 positionFee = (amountToIncrease * 30) / 10_000;
        uint256 borrowingFee = calcBorrowingFees(trader);
        uint256 secondsSincePositionWasUpdated = block.timestamp > pos.timestamp
            ? block.timestamp - pos.timestamp
            : 0;

        pos.timestamp = block.timestamp;

        emit Update(secondsSincePositionWasUpdated, true);
        emit PositionIncrease(amountToIncrease, false);
        pos.collateral -= positionFee;
        pos.size += amountToIncrease;
        positionDetails[msg.sender] = pos;
        token.transferFrom(msg.sender, address(this), borrowingFee);
        borrowingFee -= borrowingFee;
        isPositionLiquidatable(msg.sender);
        if (pos.isLong == true) {
            s_totalOpenInterestLong += (amountToIncrease);
            s_totalOpenInterestLongTokens += (amountToIncrease * currentPrice);
        } else {
            s_totalOpenInterestShortTokens += (amountToIncrease * currentPrice);
            s_totalOpenInterestShort += (amountToIncrease);
        }
        positionDetails[msg.sender] = pos;
    }

    /**
     * To decrease the size of your position
     */
    function decreaseSize(uint256 amountToDecrease) external {
        require(amountToDecrease > 0, "You cant decrease nothing");
        Position memory pos = getPosition(msg.sender);
        require(pos.size >= amountToDecrease, "this can lead to an underflow");
        uint256 positionFee = (amountToDecrease * 3) / 1000;
        uint256 currentPrice = getPrice();
        int256 pnl;
        uint256 secondsSincePositionWasUpdated = block.timestamp > pos.timestamp
            ? block.timestamp - pos.timestamp
            : 0;

        emit Update(secondsSincePositionWasUpdated, true);
        emit PositionDecrease(amountToDecrease, false);
        pnl = calcPnL(msg.sender);
        pos.collateral -= positionFee;
        pos.size -= amountToDecrease;
        isPositionLiquidatable(msg.sender);
        pos.timestamp = block.timestamp;
        if (pnl < 0) {
            pos.collateral -= uint256(pnl);
        } else {
            pos.collateral += uint256(pnl);
        }

        if (pos.isLong == true) {
            s_totalOpenInterestLongTokens -= (amountToDecrease * currentPrice);
            s_totalOpenInterestLong -= (amountToDecrease);
        } else {
            s_totalOpenInterestShortTokens -= (amountToDecrease * currentPrice);
            s_totalOpenInterestShort -= (amountToDecrease);
        }
        positionDetails[msg.sender] = pos;
    }

    /**
     * To increase the size of your collateral
     */
    function increaseCollateral(uint256 amountToIncrease) external {
        require(amountToIncrease > 0, "Should be greater than 0");
        require(msg.sender != address(0));

        emit PositionIncrease(amountToIncrease, true);
        Position memory pos = getPosition(msg.sender);
        require(pos.collateral > 0, "postion not opened");
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
        require(pos.collateral >= amountToDecrease, "You can't decrease zero");

        uint256 secondsSincePositionWasUpdated = block.timestamp > pos.timestamp
            ? block.timestamp - pos.timestamp
            : 0;
        emit Update(secondsSincePositionWasUpdated, true);
        emit PositionDecrease(amountToDecrease, true);
        pos.timestamp = block.timestamp;
        pos.collateral -= amountToDecrease;
        isPositionLiquidatable(msg.sender);
        token.transferFrom(address(this), msg.sender, amountToDecrease);
        positionDetails[msg.sender] = pos;
    }

    /**
     *  LPs or external actors can liquidate you when your position become liquidatable
     * some protocols use the `decrease` functions to liquidate- i gotta check that out
     */
    function liquidate(address trader) external {
        uint256 fee;
        require(msg.sender != address(0));
        require(msg.sender != trader);
        require(isPositionLiquidatable(trader), "Not liquidatable");
        Position memory pos = getPosition(trader);
        require(pos.collateral > 0, "inavlid position cannot liquidate");

        uint256 borrowingFee = calcBorrowingFees(trader);
        int256 pnl = calcPnL(trader);
        if (pnl < 0) {
            pos.collateral -= uint256(pnl);
            fee = (pos.collateral * 3) / 10000;
        } else if (pnl >= 0) {
            pos.collateral += uint256(pnl);
            fee = (pos.collateral * 3) / 10000;
        }

        emit PositionLiquidated(trader, pos.collateral);
        pos.collateral -= fee;
        token.transferFrom(trader, address(this), borrowingFee);
        token.transferFrom(address(this), trader, pos.collateral);
        token.transfer(msg.sender, fee);
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
     */
    function calcBorrowingFees(address trader) internal view returns (uint256) {
        Position memory pos = positionDetails[trader];
        uint256 pendingBorrowingFees = (pos.size *
            (block.timestamp - pos.timestamp) *
            s_borrowingPerSharePerSecond) / 10000;

        return pendingBorrowingFees;
    }

    /**
     * To get results of calcBorrowingPerShareFees
     */
    function getBorrowingFees(address trader) external view returns (uint256) {
        return calcBorrowingFees(trader);
    }

    /**
     * calculates profit and loss for a trader position
     * returns Profit / loss figures for long & short
     * pnl = current price - entryprice - for long | short is the other way round
     */
    function calcPnL(address trader) internal view returns (int256 pNl) {
        Position memory pos = getPosition(trader);
        uint256 currentPrice = getPrice();
        uint256 entryPrice = pos.entryPrice;
        if (pos.isLong) {
            pNl = (int256(pos.size) *
                int256(currentPrice) -
                int256(pos.size) *
                int256(entryPrice));
        } else {
            pNl = (int256(pos.size) *
                int256(entryPrice) -
                int256(pos.size) *
                int256(currentPrice));
        }

        return pNl;
    }

    /**
     * Gets profit and loss of msg.sender positon
     */
    function getPnL(address trader) external view returns (int256 pNl) {
        return calcPnL(trader);
    }

    /**
     * check postion's health
     * leverage is 50% of deposited collateral
     * max leverage is 150%
     */
    function isPositionLiquidatable(address sender) public view returns (bool) {
        Position memory pos = getPosition(sender);
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
        uint256 currentPrice = (getPrice());
        if (isLong) {
            totalPNL =
                int256(s_totalOpenInterestLong * currentPrice) -
                int256(s_totalOpenInterestLongTokens);
        } else {
            totalPNL =
                int256(s_totalOpenInterestShortTokens) -
                int256(s_totalOpenInterestShort * currentPrice);
        }
    }

    /**
     * Gets total PNL of the type of positions (i.e whether long or short)
     */
    function getTotalPnL(bool isLong) external view returns (int256 totalPNL) {
        totalPNL = totalPnL(isLong);
    }
}
