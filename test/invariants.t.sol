// SPDX-License-Identifier:MIT
pragma solidity 0.8.20;

import {Test} from "forge-std/Test.sol";
import {Handler} from "./handler.sol";
// import {Handler} from "./handlerAg.sol";
import {ERC20} from "./ERC20Mock.sol";
import {FourbPerp} from "../src/FourbPerp.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";

/**
 * @title Invariant Test suite
 * @author kwame 4b
 */
contract InvarTest is StdInvariant, Test {
    // underlying token
    ERC20 token;
    // Test handler: when all calls will be made to
    Handler handler;
    // main contract
    FourbPerp perp;

    function setUp() public {
        token = new ERC20("FOURBTOKEN", "FBTKN", 18, 10000e18);
        perp = new FourbPerp(address(token), 1);
        handler = new Handler(perp);

        // bytes4[] memory selectorss = new bytes4[](1);
        // selectorss[0] = handler.openPosition.selector;
        // targetSelector(
        //     FuzzSelector({addr: address(handler), selectors: selectorss})
        // );

        // Note: it is always necessary to fund the handler to get your tests to work.
        token.mint(address(handler), 1000e18);
        // if protocol amasses earnings there must be extra tokens to pay i.e totalSupply of tokens > totalOpenInterest
        token.mint(address(perp), 1000e18);

        // target contract to fuzz == handler
        targetContract(address(handler));
    }

    /**
     * Invariant test to check whether total open interest increases and decreases
     * with opening positions and liquidating positons respectively
     */
    function invariant_openInterestIncreases() public view {
        assertEq(perp.s_totalOpenInterestLong(), handler.totalOILong());
        assertEq(perp.s_totalOpenInterestShort(), handler.totalOIShort());
    }

    /**
     * Invariant to test whether AddLiquidity and removeLiquidity works
     * In the sense that total liquidity form the test always equals what the protocol has
     */
    function invariant_totalLiquidity() public view {
        assertEq(perp.s_totalLiquidity(), handler.liquidity());
    }

    /**
     * Invariant test to verify that collateral can never be negative
     */
    function invariant_CollateralShdNeverBeNeg() public view {
        assertGe(handler.collateral(), 0);
    }

    /**
     * Invariant test to verify thta collateral added and removed is always equal to the balance of the protocol
     */
    function invariant_CollateralEqbalanceOfProtocol() public view {
        assertEq(perp.getBalof(), handler.collateral() + handler.liquidity());
    }
}
