// SPDX-License-Identifier:MIT
pragma solidity 0.8.20;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "./ERC20Mock.sol";
import {console2} from "forge-std/console2.sol";
import {FourbPerp} from "../src/FourbPerp.sol";

contract handler is Test {
    FourbPerp perp;
    ERC20 token;

    address user = makeAddr("USER");

    constructor(FourbPerp _perp) {
        perp = _perp;
        token = new ERC20("FOURBTOKEN", "FBTKN", 18, 100e18);
    }

    function addLiquidity(uint256 amount) public {
        amount = bound(amount, 1e18, type(uint256).max);
        token.mint(user, amount);
        vm.prank(user);
        perp.addLiquidity(amount);

        console2.log("-------- Liquidity added: ", amount);
    }

    function removeLiquidity(uint256 amount) public {
        amount = bound(amount, 1e18, type(uint256).max);
        vm.prank(user);
        perp.removeLiquidity(amount);

        console2.log("------------- Liquidity removed: ", amount);
    }

    function openPosition(
        uint256 _collateral,
        uint256 _size,
        bool long
    ) public {
        _collateral = bound(_collateral, 1e18, type(uint256).max);
        _size = bound(_size, 1e18, type(uint256).max);
        token.mint(user, _collateral);
        vm.prank(user);
        perp.openPosition(_collateral, _size, long);

        console2.log(
            "------------- Position Size Opened: ",
            _size,
            "------------- Collateral of position: ",
            _collateral
        );
    }

    function increaseSize(uint256 _amount) public {
        _amount = bound(_amount, 1e18, type(uint256).max);
        address trader = user;

        vm.prank(trader);
        perp.increaseSize(_amount, trader);

        console2.log("------------- Position Size increased by: ", _amount);
    }

    function decreaseSize(uint256 _amount) public {
        _amount = bound(_amount, 1e18, type(uint256).max);

        vm.prank(user);
        perp.decreaseSize(_amount);

        console2.log("------------- Position Size decreased by: ", _amount);
    }

    function increaseCollateral(uint256 _amount) public {
        _amount = bound(_amount, 1e18, type(uint256).max);
        if (_amount > token.balanceOf(user)) {
            uint256 amountDelta = _amount - token.balanceOf(user);
            token.mint(user, amountDelta);
        }
        vm.prank(user);
        perp.increaseCollateral(_amount);

        console2.log(
            "------------- Postion Collateral increased by: ",
            _amount
        );
    }

    function decreaseCollateral(uint256 _amount) public {
        _amount = bound(_amount, 1e18, type(uint256).max);

        vm.prank(user);
        perp.decreaseCollateral(_amount);

        console2.log(
            "------------- Position collateral decreased by: ",
            _amount
        );
    }

    function liquidate(address liquidator) public {
        vm.prank(liquidator);
        perp.liquidate(user);

        console2.log(
            "------------- Position Liquidated: ",
            perp.getPositionCollateral(user)
        );
    }
}
