// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {ERC20} from "./ERC20Mock.sol";
import {FourbPerp} from "../src/FourbPerp.sol";

contract PerpTest is Test {
    FourbPerp perp;
    ERC20 token;

    function setUp() public {
        token = new ERC20("CustomToken", "CSTM-TKN", 18, 1000e18);
        perp = new FourbPerp(address(token));
    }

    function addLiquidity() public {
        token.mint(msg.sender, 10e18);
        vm.startPrank(msg.sender);
        perp.addLiquidity(10e18);
        vm.stopPrank();

        token.mint(address(55), 15e18);
        vm.startPrank(address(55));
        perp.addLiquidity(15e18);
        vm.stopPrank();

        console2.log("Liquidity added to sender: ", perp.liquidity(msg.sender));
        console2.log(
            "Liquidity added to address 55 : ",
            perp.liquidity(address(55))
        );
    }

    //////////////////////////////////////////////////////////////////////////////
    ///////////////////          U N I T -- T E S TS            //////////////////
    //////////////////////////////////////////////////////////////////////////////

    function testAddLiquidity() public {
        addLiquidity();

        assertEq(perp.liquidity(msg.sender), 10e18);
        assertEq(perp.s_totalLiquidity(), 25e18);

        assertEq(perp.liquidity(address(55)), 15e18);
        assertEq(perp.s_totalLiquidity(), 25e18);
    }

    function testRemoveLiquidity() public {
        addLiquidity();

        vm.prank(address(55));
        perp.removeLiquidity(7e18);

        console2.log(
            "---------------------------------------------------------- "
        );
        console2.log(
            "after removal lp value of address 55: ",
            perp.liquidity(address(55))
        );

        assertEq(perp.liquidity(address(55)), 8e18);
        assertEq(perp.s_totalLiquidity(), 18e18);
    }

    //////////////////////////////////////////////////////////////////////////////
    ///////////////////          F U Z Z -- T E S TS            //////////////////
    //////////////////////////////////////////////////////////////////////////////

    function testFuzz_AddLiquidity(uint256 amount) public {
        // vm.assume(amount < 2000e18 && amount != 0);
        amount = bound(amount, 1, 200e18);
        token.mint(address(22), amount);
        vm.startPrank(address(22));
        perp.addLiquidity(amount);
        uint256 totLiquidity;
        totLiquidity += amount;
        vm.stopPrank();

        assertEq(perp.liquidity(address(22)), amount);
        assertEq(perp.s_totalLiquidity(), totLiquidity);
    }

    function testFuzz_removeLiquidity(uint256 amount) public {
        amount = bound(amount, 1e18, 200e18);
        token.mint(address(44), amount);
        vm.startPrank(address(44));
        perp.addLiquidity(amount);
        uint256 totLiquidity;
        totLiquidity += amount;

        console2.log(perp.s_totalLiquidity());
        perp.removeLiquidity(amount);
        totLiquidity -= amount;

        vm.stopPrank();

        assertEq(perp.s_totalLiquidity(), totLiquidity);
    }
}
