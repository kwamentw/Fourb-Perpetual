// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {ERC20} from "./ERC20Mock.sol";
import {FourbPerp} from "../src/FourbPerp.sol";
import {Handler} from "./handler.sol";

contract PerpTest is Test {
    // initializing contracts needed

    // protocol being tested
    FourbPerp perp;
    // underlying token
    ERC20 token;
    // handler contract for testing
    Handler handler;

    function setUp() public {
        token = new ERC20("CustomToken", "CSTM-TKN", 18, 1000e18);
        perp = new FourbPerp(address(token), 0);
        handler = new Handler(perp);

        targetContract(address(handler));

        token.mint(address(handler), 1000e18);
        // if protocol amasses earnings there must be extra tokens to pay i.e totalSupply of tokens > totalOpenInterest
        token.mint(address(perp), 1000e18);

        // Uncomment when running testRemoveLIquidity
        // token.mint(address(39), 11e18);
        // vm.prank(address(39));
        // perp.openPosition(10e18, 100e18, true);
    }

    /**
     * Function that adds liquidity to the protocol
     * It makes testing modular and easier
     */
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

    /**
     * Testing add liquidity
     */
    function testAddLiquidity() public {
        addLiquidity();

        assertEq(perp.liquidity(msg.sender), 10e18);
        assertEq(perp.s_totalLiquidity(), 25e18);

        assertEq(perp.liquidity(address(55)), 15e18);
        assertEq(perp.s_totalLiquidity(), 25e18);
    }

    /**
     * Testing remove liquidity
     */
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

    /**
     * Testing to see whether chainlink price feed working
     */
    function test_getPrice() public view {
        uint256 price = perp.getPrice();
        assertGt(price, 0);
    }

    /**
     * testing to see whether a user can open a position succesfully
     */
    function test_OpenPositon() public {
        vm.startPrank(address(39));
        token.mint(address(39), 11e18);
        perp.openPosition(10e18, 100e18, true);

        assertEq(perp.getPosition(address(39)).collateral, 10e18);

        vm.stopPrank();
    }

    /**
     * Unit testing the increaseSize function
     */
    function test_increaseSize() public {
        vm.startPrank(address(39));
        token.mint(address(39), 25e18);
        perp.openPosition(10e18, 100e18, true);

        assertEq(perp.getPosition(address(39)).collateral, 10e18);

        perp.increaseSize(20e18, msg.sender);

        vm.stopPrank();

        assertEq(perp.getPostionSize(address(39)), 120e18);
    }

    /**
     * Unit testing the decreaseSize function
     */
    function test_decreaseSize() public {
        vm.startPrank(address(39));
        token.mint(address(39), 25e18);
        perp.openPosition(10e18, 100e18, true);

        assertEq(perp.getPosition(address(39)).collateral, 10e18);

        perp.increaseSize(20e18, msg.sender);
        assertEq(perp.getPostionSize(address(39)), 120e18);
        console2.log(
            "remaining collateral: ",
            perp.getPostionSize(address(39))
        );

        perp.decreaseSize(40e18);
        assertEq(perp.getPostionSize(address(39)), 80e18);

        vm.stopPrank();

        console2.log(
            "remaining collateral: ",
            perp.getPositionCollateral(address(39))
        );
    }

    /**
     * Unit testing increase collateral to see whether it works
     */
    function test_increaseCollateral() public {
        vm.startPrank(address(39));
        token.mint(address(39), 25e18);
        perp.openPosition(10e18, 100e18, true);

        assertEq(perp.getPosition(address(39)).collateral, 10e18);

        perp.increaseSize(20e18, msg.sender);
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

    /**
     * Unit testing decreaseCollateral to see whether it works
     */
    function test_decreaseCollateral() public {
        vm.startPrank(address(39));
        token.mint(address(39), 25e18);
        perp.openPosition(15e18, 100e18, true);

        assertEq(perp.getPosition(address(39)).collateral, 15e18);

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

    /**
     * Unit test for liquidate
     */
    function test_liquidate() public {
        // we have to add extra tokens incase the position gathers profit
        token.mint(address(perp), 100e18);

        vm.startPrank(address(39));
        token.mint(address(39), 55e18);
        perp.openPosition(50e18, 70e18, true);

        console2.log(
            "Balance of address(this) ",
            token.balanceOf(address(perp))
        );
        assertEq(perp.getPosition(address(39)).collateral, 50e18);

        vm.stopPrank();

        vm.startPrank(address(45));
        console2.log(
            "Balance of address(this) ",
            token.balanceOf(address(perp))
        );
        perp.liquidate(address(39));

        assertEq(perp.getPositionCollateral(address(39)), 0);
        vm.stopPrank();
    }

    /**
     * Test to ensure 50% leverage works as planned
     */
    function testUtilisationMaxxedOut() public {
        token.mint(address(5), 50e18);
        vm.prank(address(5));
        perp.openPosition(50e18, 1220e18, true);

        vm.prank(address(5));
        assertTrue(perp.maxLeverage());
    }

    /**
     * Test to see whether LongPosition makes profit
     */
    function testforProfitLong() public {
        token.mint(address(3), 20e18);
        vm.startPrank(address(3));
        perp.openPosition(20e18, 30e18, true);

        int256 result = perp.getPnL(address(3));
        assertGt(result, 0);
        vm.stopPrank();
    }

    /**
     * Test to see whether Profit working for short postions
     */
    function testforProfitShort() public {
        token.mint(address(3), 30e18);
        vm.startPrank(address(3));
        perp.openPosition(30e18, 60e18, false);

        int256 result = perp.getPnL(address(3));
        assertGt(result, 0);
        vm.stopPrank();
    }

    /**
     * Test to see whether losses are computed in short positions
     */
    function testforLossShort() public {
        token.mint(address(3), 22e18);
        vm.startPrank(address(3));
        perp.openPosition(22e18, 44e18, false);

        int256 result = perp.getPnL(address(3));
        assertLt(result, 0);
        vm.stopPrank();
    }

    /**
     * Test to see whether LongPostion can lose profit
     */
    function testforLossLong() public {
        token.mint(address(3), 25e18);
        vm.startPrank(address(3));
        perp.openPosition(25e18, 50e18, true);

        int256 pnl = perp.getPnL(address(3));
        assertLt(pnl, 0);
        vm.stopPrank();
    }

    /**
     * Testing total pnl
     */
    function testTotalPNL() public {
        token.mint(address(5), 15e18);
        token.mint(address(6), 25e18);
        token.mint(address(7), 35e18);
        token.mint(address(8), 36e18);

        vm.prank(address(5));
        perp.openPosition(15e18, 30e18, true);
        vm.prank(address(6));
        perp.openPosition(25e18, 50e18, false);
        vm.prank(address(7));
        perp.openPosition(35e18, 70e18, false);
        vm.prank(address(8));
        perp.openPosition(36e18, 72e18, true);

        int256 totalPNL = perp.getTotalPnL(true);

        assertGt(totalPNL, 0, "Check your params");
    }

    /**
     * Test to see if position is liquidatable
     */
    function testIsPositionLiquidatable() public {
        token.mint(address(3), 50e18);
        vm.startPrank(address(3));
        perp.openPosition(50e18, 75e18, true);

        assertTrue(perp.isPositionLiquidatable(address(3)));

        vm.stopPrank();
    }

    /**
     * Testing position is not liquidatable
     */
    function testIsNotLiquidatable() public {
        token.mint(address(3), 25e18);
        vm.startPrank(address(3));
        perp.openPosition(25e18, 70e18, true);

        assertFalse(perp.isPositionLiquidatable(address(3)));

        vm.stopPrank();
    }

    /**
     * Testing computation of borrowing fees
     */
    function testBorrowingFees() public {
        token.mint(address(9), 233e18);
        vm.startPrank(address(9));
        vm.warp(1641070800);
        perp.openPosition(233e18, 400e18, true);

        // you can set the shares if you tryna test out something different
        perp.setBorrowingPerSharePerSecond(1);
        vm.warp(1841070800);
        uint256 fees = perp.getBorrowingFees(msg.sender);

        vm.stopPrank();

        // it is zero because the borrowingFeesPerShare value is set to 0 when deploying.
        assertGe(fees, 0);
    }

    //////////////////////////////////////////////////////////////////////////////
    ///////////////////          F U Z Z -- T E S TS            //////////////////
    //////////////////////////////////////////////////////////////////////////////

    /**
     * Fuzzing AddLiquidity
     * @param amount amount to fuzz
     */
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

    /**
     * Fuzzing remove liquidity
     */
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

    /**
     * Fuzzing openPosition function
     * @param collateral param 1 to fuzz
     * @param size param 2 to fuzz
     */
    function testFuzz_openPosition(uint256 collateral, uint256 size) public {
        collateral = bound(collateral, 11, (type(uint256).max / 1000000));
        vm.assume(size > 0);

        vm.startPrank(address(25));
        token.mint(address(25), collateral);

        perp.openPosition(collateral, size, true);

        assertEq(perp.getPositionCollateral(address(25)), collateral);
        assertEq(perp.getPostionSize(address(25)), size);

        vm.stopPrank();
    }

    /**
     * Fuzzing increaseSize
     */
    function testFuzz_increaseSize(uint256 sizeIncrease) public {
        sizeIncrease = bound(sizeIncrease, 1e18, (type(uint256).max) / 1e18);

        vm.startPrank(address(95));
        token.mint(address(95), 50e18);
        perp.openPosition(50e18, 85e18, true);

        perp.increaseSize(sizeIncrease, msg.sender);
        uint256 currSize = 85e18 + sizeIncrease;

        vm.stopPrank();

        assertEq(perp.getPostionSize(address(95)), currSize);
    }

    /**
     * Fuzzing decreaseSize
     * @param sizeDecrease param to fuzz
     */
    function testFuzz_decreaseSize(uint256 sizeDecrease) public {
        sizeDecrease = bound(sizeDecrease, 1, 80_000e18);
        vm.startPrank(address(115));
        token.mint(address(115), 500e18);
        perp.openPosition(500e18, 90000e18, true);
        vm.stopPrank();

        vm.prank(address(115));
        perp.decreaseSize(sizeDecrease);
        uint256 currSize = 90000e18 - sizeDecrease;

        assertEq(perp.getPostionSize(address(115)), currSize);
    }

    /**
     * Fuzzing increaseCollateral
     * @param amountToIncrease param to fuzz
     */
    function testFuzz_increaseCollateral(uint256 amountToIncrease) public {
        amountToIncrease = bound(amountToIncrease, 1, type(uint128).max);
        vm.startPrank(address(47));
        token.mint(address(47), 30e18);
        perp.openPosition(30e18, 100e18, true);

        assertEq(perp.getPostionSize(address(47)), 100e18);
        assertEq(perp.getPositionCollateral(address(47)), 30e18);

        uint256 oldCollateral = perp.getPositionCollateral(address(47));
        token.mint(address(47), amountToIncrease);
        perp.increaseCollateral(amountToIncrease);
        uint256 newCollateral = oldCollateral + amountToIncrease;

        vm.stopPrank();

        assertEq(perp.getPositionCollateral(address(47)), newCollateral);
    }

    /**
     * Fuzzing amountCOllateral to decrese
     */
    function testFuzz_decreaseCollateral(uint256 amountToDecrease) public {
        amountToDecrease = bound(amountToDecrease, 1, 100e18);
        vm.startPrank(address(1));
        token.mint(address(1), 100e18);
        perp.openPosition(100e18, 1000e18, true);

        assertEq(perp.getPositionCollateral(address(1)), 100e18);

        uint256 oldCollateral = perp.getPositionCollateral(address(1));
        perp.decreaseCollateral(amountToDecrease);
        uint256 newCollateral = oldCollateral - amountToDecrease;

        assertEq(perp.getPositionCollateral(address(1)), newCollateral);

        vm.stopPrank();
    }

    /**
     * Fuzzing Liquidate function
     */
    function testFuzz_Liquidate(uint256 fuzzIndex) public {
        // opening 4 positions with 4 different addresses so i can fuzz liquidate
        vm.startPrank(address(1));
        token.mint(address(1), 200e18);
        perp.openPosition(200e18, 2000e18, true);
        vm.stopPrank();

        vm.startPrank(address(2));
        token.mint(address(2), 300e18);
        perp.openPosition(300e18, 3000e18, true);
        vm.stopPrank();

        vm.startPrank(address(3));
        token.mint(address(3), 400e18);
        perp.openPosition(400e18, 4000e18, true);
        vm.stopPrank();

        vm.startPrank(address(4));
        token.mint(address(4), 500e18);
        perp.openPosition(500e18, 5000e18, true);
        vm.stopPrank();

        // trying to bound fuzzer to the open positions
        address[4] memory addresses = [
            address(1),
            address(2),
            address(3),
            address(4)
        ];
        address currentAddress;
        currentAddress = addresses[bound(fuzzIndex, 0, addresses.length - 1)];

        // Liquidator calling liquidate
        vm.startPrank(address(44));
        perp.liquidate(currentAddress);
        vm.stopPrank();

        // checking whether shit gets liquidated
        assertEq(perp.getPositionCollateral(currentAddress), 0);
        assertGt(token.balanceOf(currentAddress), 0);
    }

    //    testing to see if all handler functions were working
    function test_handlerFuncs() public {
        // handler.addLiquidity(112e18);
        // handler.openPosition(50e18, 75e18, true);
        // assertGt(perp.getPositionCollateral(address(handler)), 0);
        // handler.increaseSize();
        // handler.decreaseSize();
        // handler.increaseCollateral();
        // handler.decreaseCollateral();
        // handler.liquidate(address(33));
    }
}
