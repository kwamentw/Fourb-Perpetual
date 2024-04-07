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

    uint256 constant MAX_UTILIZATION = 80;
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
        require(_collateral > 0, "Collateral cant be less than 1");
        require(_size > 0, "Size must be > 0");
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

    function getPosition() public view returns (Position memory) {
        return positionDetails[msg.sender];
    }

    function increaseSize(uint256 amountToIncrease) external {
        require(amountToIncrease > 0, "Should be more than 0");
        Position memory pos = getPosition();
        pos.size += amountToIncrease;
        positionDetails[msg.sender] = pos;
        s_totalOpenInterest += amountToIncrease;
    }

    function increaseCollateral(uint256 amountToIncrease) external {
        require(amountToIncrease > 0, "Should be greater than 0");
        Position memory pos = getPosition();
        pos.size += amountToIncrease;
        positionDetails[msg.sender] = pos;
    }
}
