// SPDX-License-Identifier:MIT
pragma solidity 0.8.20;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "./ERC20Mock.sol";
import {console2} from "forge-std/console2.sol";
import {FourbPerp} from "../src/FourbPerp.sol";

/**
 * @title FourbPerpetual Handler
 * @author 4b
 * @notice this is a handler for invariant testing
 */
contract Handler is Test {
    // main contract
    FourbPerp perp;
    // underlying token
    ERC20 token;

    // tracks the total amount of liquidity
    uint256 public liquidity;
    // tracks total Open Interest for long positions
    uint256 public totalOILong;
    // tracks total open interest for short positions
    uint256 public totalOIShort;
    // tracks total collateral this contract added
    uint256 public collateral;

    constructor(FourbPerp _perp) {
        perp = _perp;
        token = new ERC20("FOURBTOKEN", "FBTKN", 18, 10000e18);
        // token.mint(address(perp), 1000e18);
    }

    function addLiquidity(uint256 amount) public {
        amount = bound(amount, 1e8, 50e18);
        token.mint(address(this), amount);
        vm.startPrank(address(this));
        perp.addLiquidity(amount);
        vm.stopPrank();

        liquidity += amount;
        console2.log("-------- Liquidity added: ", amount);
    }

    function removeLiquidity(uint256 amount) public {
        amount = bound(amount, 1e8, 50e18);
        console2.log("balance is: ", perp.liquidity(address(this)));
        vm.startPrank(address(this));
        perp.removeLiquidity(amount);
        vm.stopPrank();

        liquidity -= amount;

        console2.log("------------- Liquidity removed: ", amount);
    }

    function openPosition(
        uint256 _collateral,
        uint256 _size,
        bool long
    ) external {
        _collateral = bound(_collateral, 1e18, 100e18);
        _size = bound(_size, 1e18, 100e18);

        vm.startPrank(address(this));
        token.mint(address(this), _collateral);
        perp.openPosition(_collateral, _size, long);

        if (long) {
            totalOILong += _size;
        } else {
            totalOIShort += _size;
        }

        console2.log(
            "------------- Position Size Opened: ",
            _size,
            "------------- Collateral of position: ",
            _collateral
        );
        vm.stopPrank();

        collateral = perp.getPositionCollateral(address(this));
    }

    function increaseSize(uint256 _amount) public {
        _amount = bound(_amount, 1e18, 100e18);
        address trader = address(this);

        vm.startPrank(trader);
        perp.increaseSize(_amount, trader);

        if (perp.getPosition(trader).isLong) {
            totalOILong += _amount;
        } else {
            totalOIShort += _amount;
        }

        vm.stopPrank();

        console2.log("------------- Position Size increased by: ", _amount);
    }

    function decreaseSize(uint256 _amount) public {
        _amount = bound(_amount, 1e18, 100e18);

        vm.startPrank(address(this));
        perp.decreaseSize(_amount);
        vm.stopPrank();

        if (perp.getPosition(address(this)).isLong) {
            totalOILong -= _amount;
        } else {
            totalOIShort -= _amount;
        }

        console2.log("------------- Position Size decreased by: ", _amount);
    }

    function increaseCollateral(uint256 _amount) public {
        _amount = bound(_amount, 0, 100e18);
        if (_amount > token.balanceOf(address(this))) {
            uint256 amountDelta1 = _amount - token.balanceOf(address(this));
            token.mint(address(this), amountDelta1);
        }

        vm.startPrank(address(this));
        perp.increaseCollateral(_amount);
        console2.log(
            "------------- Postion Collateral increased by: ",
            _amount
        );
        vm.stopPrank();

        collateral += _amount;
    }

    function decreaseCollateral(uint256 _amount) public {
        _amount = bound(_amount, 0, 100e18);

        vm.startPrank(address(this));
        perp.decreaseCollateral(_amount);
        vm.stopPrank();

        console2.log(
            "------------- Position collateral decreased by: ",
            _amount
        );
        collateral -= _amount;
    }

    function liquidate(address liquidator) public {
        vm.startPrank(liquidator);
        perp.liquidate(address(this));
        vm.stopPrank();

        console2.log(
            "------------- Position Liquidated: END OF STORY: ",
            perp.getPositionCollateral(address(this))
        );
        collateral = 0;
    }
}
