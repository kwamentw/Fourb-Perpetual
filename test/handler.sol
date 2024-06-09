// SPDX-License-Identifier:MIT
pragma solidity 0.8.20;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "./ERC20Mock.sol";
import {console2} from "forge-std/console2.sol";
import {FourbPerp} from "../src/FourbPerp.sol";

contract Handler is Test {
    FourbPerp perp;
    ERC20 token;

    uint256 public liquidity;

    constructor(FourbPerp _perp) {
        perp = _perp;
        token = new ERC20("FOURBTOKEN", "FBTKN", 18, 10000e18);
        token.mint(address(perp), 1000e18);
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

    // function openPosition(
    //     uint256 _collateral,
    //     uint256 _size,
    //     bool long
    // ) external {
    //     _collateral = bound(_collateral, 1e18, 1000e18);
    //     _size = bound(_size, 1e18, 999e18);

    //     vm.startPrank(address(44));
    //     token.mint(address(44), _collateral);
    //     perp.openPosition(_collateral, _size, long);

    //     console2.log(
    //         "------------- Position Size Opened: ",
    //         _size,
    //         "------------- Collateral of position: ",
    //         _collateral
    //     );
    //     vm.stopPrank();
    // }

    // function increaseSize(uint256 _amount) public {
    //     _amount = bound(_amount, 1e18, type(uint256).max);
    //     address trader = address(this);

    //     vm.prank(trader);
    //     perp.increaseSize(_amount, trader);

    //     console2.log("------------- Position Size increased by: ", _amount);
    // }

    // function decreaseSize(uint256 _amount) public {
    //     _amount = bound(_amount, 1e18, type(uint256).max);

    //     vm.prank(address(this));
    //     perp.decreaseSize(_amount);

    //     console2.log("------------- Position Size decreased by: ", _amount);
    // }

    // function increaseCollateral(uint256 _amount) public {
    //     _amount = bound(_amount, 1e18, type(uint256).max);
    //     if (_amount > token.balanceOf(address(this))) {
    //         uint256 amountDelta = _amount - token.balanceOf(address(this));
    //         token.mint(address(this), amountDelta);
    //     }
    //     vm.prank(address(this));
    //     perp.increaseCollateral(_amount);

    //     console2.log(
    //         "------------- Postion Collateral increased by: ",
    //         _amount
    //     );
    // }

    // function decreaseCollateral(uint256 _amount) public {
    //     _amount = bound(_amount, 1e18, type(uint256).max);

    //     vm.prank(address(this));
    //     perp.decreaseCollateral(_amount);

    //     console2.log(
    //         "------------- Position collateral decreased by: ",
    //         _amount
    //     );
    // }

    // function liquidate(address liquidator) public {
    //     vm.prank(liquidator);
    //     perp.liquidate(address(this));

    //     console2.log(
    //         "------------- Position Liquidated: ",
    //         perp.getPositionCollateral(address(this))
    //     );
    // }

    // function getUserCollateral() external view returns (uint256) {
    //     return perp.getPositionCollateral(address(this));
    // }
}
