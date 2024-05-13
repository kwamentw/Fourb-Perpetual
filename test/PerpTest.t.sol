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

    function test_getPrice() public view {
        uint256 price = perp.getPrice();
        assertGt(price, 0);
    }

    function test_OpenPositon() public {
        vm.startPrank(address(39));
        token.mint(address(39), 11e18);
        perp.openPosition(10e18, 100e18);

        assertEq(perp.collateral(address(39)), 10e18);

        vm.stopPrank();
    }

    function test_increaseSize() public {
        vm.startPrank(address(39));
        token.mint(address(39), 25e18);
        perp.openPosition(10e18, 100e18);

        assertEq(perp.collateral(address(39)), 10e18);

        perp.increaseSize(20e18);

        vm.stopPrank();

        assertEq(perp.getPostionSize(address(39)), 120e18);
    }

    function test_decreaseSize() public {
        vm.startPrank(address(39));
        token.mint(address(39), 25e18);
        perp.openPosition(10e18, 100e18);

        assertEq(perp.collateral(address(39)), 10e18);

        perp.increaseSize(20e18);
        assertEq(perp.getPostionSize(address(39)), 120e18);
        console2.log(
            "remaining collateral: ",
            perp.getPostionSize(address(39))
        );

        perp.decreaseSize(40e18);
        assertEq(perp.getPostionSize(address(39)), 80e18);

        vm.stopPrank();

        console2.log("remaining collateral: ", perp.collateral(address(39)));
    }

    function test_increaseCollateral() public {
        vm.startPrank(address(39));
        token.mint(address(39), 25e18);
        perp.openPosition(10e18, 100e18);

        assertEq(perp.collateral(address(39)), 10e18);

        perp.increaseSize(20e18);
        assertEq(perp.getPostionSize(address(39)), 120e18);

        perp.decreaseSize(40e18);
        assertEq(perp.getPostionSize(address(39)), 80e18);

        uint256 currentCollateral = perp.getPositionCollateral(address(39));

        vm.stopPrank();

        vm.prank(address(39));
        perp.increaseCollateral(10e18);

        console2.log(
            "remaining collateral: ",
            perp.getPositionCollateral(address(39))
        );

        assertEq(
            perp.getPositionCollateral(address(39)),
            currentCollateral + 10e18
        );
    }

    function test_decreaseCollateral() public {
        vm.startPrank(address(39));
        token.mint(address(39), 25e18);
        perp.openPosition(15e18, 100e18);

        assertEq(perp.collateral(address(39)), 15e18);

        uint256 currentCollateral = perp.getPositionCollateral(address(39));

        vm.stopPrank();

        vm.prank(address(39));
        perp.decreaseCollateral(7e18);

        assertEq(
            perp.getPositionCollateral(address(39)),
            currentCollateral - 7e18
        );

        console2.log(
            "Decreased collateral is: ",
            perp.getPositionCollateral(address(39))
        );
    }

    function test_liquidate() public {
        vm.startPrank(address(39));
        token.mint(address(39), 25e18);
        perp.openPosition(15e18, 100e18);

        assertEq(perp.collateral(address(39)), 15e18);

        vm.stopPrank();

        vm.startPrank(address(45));
        perp.liquidate(address(39));

        assertEq(perp.getPositionCollateral(address(39)), 0);
        vm.stopPrank();
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

    function testFuzz_openPosition(uint256 collateral, uint256 size) public {
        collateral = bound(collateral, 11, (type(uint256).max / 1000000));
        vm.assume(size > 0);

        vm.startPrank(address(25));
        token.mint(address(25), collateral);

        perp.openPosition(collateral, size);

        assertEq(perp.getPositionCollateral(address(25)), collateral);
        assertEq(perp.getPostionSize(address(25)), size);

        vm.stopPrank();
    }

    function testFuzz_increaseSize(uint256 sizeIncrease) public {
        sizeIncrease = bound(sizeIncrease, 1e18, (type(uint256).max) / 1e18);

        vm.startPrank(address(95));
        token.mint(address(95), 50e18);
        perp.openPosition(50e18, 85e18);

        perp.increaseSize(sizeIncrease);
        uint256 currSize = 85e18 + sizeIncrease;

        vm.stopPrank();

        assertEq(perp.getPostionSize(address(95)), currSize);
    }

    function testFuzz_decreaseSize(uint256 sizeDecrease) public {
        sizeDecrease = bound(sizeDecrease, 1, 80_000e18);
        vm.startPrank(address(115));
        token.mint(address(115), 500e18);
        perp.openPosition(500e18, 90000e18);
        vm.stopPrank();

        vm.prank(address(115));
        perp.decreaseSize(sizeDecrease);
        uint256 currSize = 90000e18 - sizeDecrease;

        assertEq(perp.getPostionSize(address(115)), currSize);
    }
}
