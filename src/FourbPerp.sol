//SPDX-License-Identifier:MIT
pragma solidity 0.8.20;

import {IERC20} from "lib/forge-std/src/interfaces/IERC20.sol";
import {pricefeed} from "./PriceFeed.sol";

contract FourbPerp {
    event Update(uint256 timeSinceUpdate, bool isUpdate);

    pricefeed private PriceFeed;
    IERC20 private token;

    mapping(address => uint256) collateral;
    mapping(address => uint256) public liquidity;
    mapping(address => Position) positionDetails;

    uint256 immutable MAX_UTILIZATION = 80;
    uint256 public s_totalLiquidity;
    uint256 public s_totalOpenInterest;
    uint256 private sizeDelta;

    struct Position {
        uint256 entryPrice;
        uint256 collateral;
        bool isLong;
        uint256 size;
        uint256 timestamp;
    }

    constructor(address _token) {
        token = IERC20(_token);
    }

    function addLiquidity(uint256 amount) public {
        require(amount > 0, "You can't supply zero liquidity");
        require(msg.sender != address(0), "Zero adddress");

        s_totalLiquidity += amount;
        liquidity[msg.sender] += amount;
        token.transferFrom(msg.sender, address(this), amount);
    }

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
        require(amount < s_totalLiquidity * MAX_UTILIZATION);
        if (amount == liquidity[msg.sender]) {
            delete liquidity[msg.sender];
        } else {
            liquidity[msg.sender] -= amount;
        }

        s_totalLiquidity -= amount;
        token.transfer(msg.sender, amount);
    }

    function getPrice() public view returns (uint256) {
        uint256 currentPrice = PriceFeed.getPrice();
        return currentPrice;
    }

    function openPosition(uint256 _collateral, uint256 _size) external {
        require(_collateral > 10, "Collateral can't be less than 10");
        require(_size > 0, "Postion Size must be > 0");
        require(_size >= (MAX_UTILIZATION * s_totalLiquidity) / 100);
        uint256 currentPrice = getPrice();

        Position memory _position = Position({
            entryPrice: currentPrice,
            collateral: _collateral,
            isLong: true,
            size: _size,
            timestamp: block.timestamp
        });

        emit Update(_position.timestamp, true);

        positionDetails[msg.sender] = _position;
        collateral[msg.sender] = _collateral;
        token.transferFrom(msg.sender, address(this), _collateral);
        s_totalOpenInterest = _size;
    }

    function getPosition(address sender) public view returns (Position memory) {
        return positionDetails[sender];
    }

    function increaseSize(uint256 amountToIncrease) external {
        // try check whether size is in dollars or tokens
        // check whether position is still healthy enough to increase
        require(amountToIncrease > 0, "Should be more than 0");
        Position memory pos = getPosition(msg.sender);
        uint256 positionFee = (amountToIncrease * 30) / 10_000;
        uint256 borrowingFee = (1000 * amountToIncrease) / 10_000;
        uint256 secondsSincePositionWasUpdated = block.timestamp > pos.timestamp
            ? block.timestamp - pos.timestamp
            : 0;

        emit Update(secondsSincePositionWasUpdated, true);
        pos.collateral -= positionFee;
        pos.size += amountToIncrease;
        sizeDelta += amountToIncrease;
        positionDetails[msg.sender] = pos;
        token.transferFrom(msg.sender, address(this), borrowingFee);
        borrowingFee -= borrowingFee;
        token.transfer(address(this), positionFee);
        s_totalOpenInterest += amountToIncrease;
    }

    function decreaseSize(uint256 amountToDecrease) external {
        require(amountToDecrease > 0, "You cant decrease nothing");
        Position memory pos = getPosition(msg.sender);
        require(pos.size >= amountToDecrease);
        uint256 positionFee = (amountToDecrease * 3) / 1000;
        pos.collateral -= positionFee;
        pos.size -= amountToDecrease;
        sizeDelta -= amountToDecrease;
        uint256 currentPrice = getPrice();
        uint256 pnl;
        uint256 secondsSincePositionWasUpdated = block.timestamp > pos.timestamp
            ? block.timestamp - pos.timestamp
            : 0;

        if (pos.isLong) {
            pnl = (currentPrice - pos.entryPrice) * amountToDecrease;
        } else {
            pnl = (pos.entryPrice - currentPrice) * amountToDecrease;
        }
        emit Update(secondsSincePositionWasUpdated, true);
        pos.collateral += pnl;
        positionDetails[msg.sender] = pos;
        token.transfer(address(this), positionFee);
        s_totalOpenInterest -= amountToDecrease;
    }

    function increaseCollateral(uint256 amountToIncrease) external {
        require(amountToIncrease > 0, "Should be greater than 0");
        require(msg.sender != address(0));
        Position memory pos = getPosition(msg.sender);
        uint256 secondsSincePositionWasUpdated = block.timestamp > pos.timestamp
            ? block.timestamp - pos.timestamp
            : 0;
        emit Update(secondsSincePositionWasUpdated, true);
        pos.collateral += amountToIncrease;
        token.transferFrom(msg.sender, address(this), amountToIncrease);
        positionDetails[msg.sender] = pos;
    }

    function decreaseCollateral(uint256 amountToDecrease) external {
        require(amountToDecrease > 0, "You cannot decrease nothing");
        Position memory pos = getPosition(msg.sender);
        require(pos.collateral >= amountToDecrease);
        uint256 secondsSincePositionWasUpdated = block.timestamp > pos.timestamp
            ? block.timestamp - pos.timestamp
            : 0;
        emit Update(secondsSincePositionWasUpdated, true);
        pos.collateral -= amountToDecrease;
        token.transferFrom(address(this), msg.sender, amountToDecrease);
        positionDetails[msg.sender] = pos;
    }

    function liquidate(address trader) external {
        require(msg.sender != address(0));
        require(msg.sender != trader);
        Position memory pos = getPosition(trader);
        require(pos.collateral > 0, "inavlid position cannot liquidate");
        uint256 secondsSincePositionWasUpdated = block.timestamp > pos.timestamp
            ? block.timestamp - pos.timestamp
            : 0;

        uint256 borrowingFee = ((pos.size - sizeDelta) * 10) / 100;
        uint256 currentPrice = getPrice();
        uint256 pnl = pos.isLong
            ? (currentPrice - pos.entryPrice) * pos.size
            : (pos.entryPrice - currentPrice) * pos.size;
        pos.collateral += pnl;
        uint256 fee = (pos.collateral * 3) / 100;
        emit Update(secondsSincePositionWasUpdated, true);
        pos.collateral -= fee;
        token.transferFrom(msg.sender, address(this), borrowingFee);
        token.transfer(msg.sender, fee);
        token.transfer(trader, pos.collateral);
        delete positionDetails[trader];
    }
}
