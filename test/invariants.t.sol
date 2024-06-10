// SPDX-License-Identifier:MIT
pragma solidity 0.8.20;

import {Test} from "forge-std/Test.sol";
import {Handler} from "./handler.sol";
// import {Handler} from "./handlerAg.sol";
import {ERC20} from "./ERC20Mock.sol";
import {FourbPerp} from "../src/FourbPerp.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";

contract InvarTest is StdInvariant, Test {
    ERC20 token;
    Handler handler;
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
        token.mint(address(handler), 1000e18);
        // if protocol amasses earnings there must be extra tokens to pay i.e totalSupply of tokens > totalOpenInterest
        token.mint(address(perp), 1000e18);

        targetContract(address(handler));
    }

    function invariant_openInterestIncreases() public view {
        assertEq(perp.s_totalOpenInterestLong(), handler.totalOILong());
        assertEq(perp.s_totalOpenInterestShort(), handler.totalOIShort());
    }

    function invariant_totalLiquidity() public view {
        assertEq(perp.s_totalLiquidity(), handler.liquidity());
    }
}
