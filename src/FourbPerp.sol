//SPDX-License-Identifier:MIT
pragma solidity 0.8.20;

import {IERC20} from "lib/forge-std/src/interfaces/IERC20.sol";
import {pricefeed} from "./PriceFeed.sol";

contract FourbPerp {
    pricefeed private PriceFeed;
    IERC20 private token;
    mapping(address => uint256) collateral;
    mapping(address => uint256) liquidity;
    mapping(address => Position) positionDetails;

    uint256 immutable MAX_UTILIZATION = 80;
    uint256 s_totalLiquidity;
    uint256 s_totalOpenInterest;

    struct Position {
        uint256 entryPrice;
        uint256 collateral;
        bool isLong;
        uint256 size;
    }

    function addLiquidity(uint256 amount) public {
        require(amount > 0, "You can's supply zero liquidity");
        require(msg.sender != address(0));

        s_totalLiquidity += amount;
        liquidity[msg.sender] = amount;
        token.transferFrom(msg.sender, address(this), amount);
    }

    function removeLiquidity(uint256 amount) public {
        require(amount > 0);
        require(
            liquidity[msg.sender] == amount,
            "You have no liquidity in this pool"
        );
        require(
            amount < s_totalOpenInterest,
            "Can't remove liquidity reserves"
        );
        require(amount < s_totalLiquidity * MAX_UTILIZATION);
        delete liquidity[msg.sender];
        s_totalLiquidity -= amount;
        token.transfer(msg.sender, amount);
    }

    function getPrice() public view returns (uint256) {
        uint256 currentPrice = PriceFeed.getPrice();
        return currentPrice;
    }

    function openPosition(uint256 _collateral, uint256 _size) external {
        require(_collateral > 10, "Collateral cant be less than 1");
        require(_size > 0, "Size must be > 0");
        require(_size >= (MAX_UTILIZATION * s_totalLiquidity) / 100);
        uint256 currentPrice = getPrice();

        Position memory _position = Position({
            entryPrice: currentPrice,
            collateral: _collateral,
            isLong: true,
            size: _size
        });

        positionDetails[msg.sender] = _position;
        collateral[msg.sender] = _collateral;
        token.transferFrom(msg.sender, address(this), _collateral);
        s_totalOpenInterest = _size;
    }

    function getPosition(address sender) public view returns (Position memory) {
        return positionDetails[sender];
    }

    function increaseSize(uint256 amountToIncrease) external {
        require(amountToIncrease > 0, "Should be more than 0");
        Position memory pos = getPosition(msg.sender);
        pos.size += amountToIncrease;
        positionDetails[msg.sender] = pos;
        s_totalOpenInterest += amountToIncrease;
    }

    function decreaseSize(uint256 amountToDecrease) external {
        require(amountToDecrease > 0, "You cant decrease nothing");
        Position memory pos = getPosition(msg.sender);
        require(pos.size >= amountToDecrease);
        pos.size -= amountToDecrease;
        uint256 currentPrice = getPrice();
        uint256 pnl;
        if (pos.isLong) {
            pnl = (currentPrice - pos.entryPrice) * amountToDecrease;
        } else {
            pnl = (pos.entryPrice - currentPrice) * amountToDecrease;
        }
        pos.collateral += pnl;
        positionDetails[msg.sender] = pos;
        s_totalOpenInterest -= amountToDecrease;
    }

    function increaseCollateral(uint256 amountToIncrease) external {
        require(amountToIncrease > 0, "Should be greater than 0");
        require(msg.sender != address(0));
        Position memory pos = getPosition(msg.sender);
        pos.size += amountToIncrease;
        positionDetails[msg.sender] = pos;
    }

    function decreaseCollateral(uint256 amountToDecrease) external {
        require(amountToDecrease > 0, "You cannot decrease nothing");
        Position memory pos = getPosition(msg.sender);
        require(pos.collateral >= amountToDecrease);
        pos.collateral -= amountToDecrease;
        positionDetails[msg.sender] = pos;
    }

    function liquidate(address trader) external {
        require(msg.sender != address(0));
        Position memory pos = getPosition(trader);
        require(pos.collateral > 0, "inavlid position cannot liquidate");
        uint256 currentPrice = getPrice();
        uint256 pnl = pos.isLong
            ? (currentPrice - pos.entryPrice) * pos.size
            : (pos.entryPrice - currentPrice) * pos.size;
        pos.collateral += pnl;
        uint256 fee = (pos.collateral * 3) / 100;
        pos.collateral -= fee;
        token.transfer(msg.sender, fee);
        token.transfer(trader, pos.collateral);
        delete positionDetails[trader];
    }
}
