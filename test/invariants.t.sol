// SPDX-License-Identifier:MIT
pragma solidity 0.8.20;

import {Test} from "forge-std/Test.sol";
import {Handler} from "./handler.sol";
import {ERC20} from "./ERC20Mock.sol";
import {FourbPerp} from "../src/FourbPerp.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";

contract InvarTest is Test {
    Handler handler;
    FourbPerp perp;
    ERC20 token;

    function setUp() public {
        token = new ERC20("FOURBTOKEN", "FBTKN", 18, 1000e18);
        perp = new FourbPerp(address(token), 0);
        handler = new Handler(perp);

        token.mint(address(handler), 1000e18);
        token.mint(address(perp), 1000e18);

        bytes4[] memory selectorss = new bytes4[](1);
        selectorss[0] = handler.openPosition.selector;
        targetSelector(
            FuzzSelector({addr: address(handler), selectors: selectorss})
        );

        targetContract(address(handler));
    }

    function invariant_openInterestIncreases() public view {
        assertGt(perp.s_totalOpenInterestLong(), 0);
        assertGt(perp.s_totalOpenInterestShort(), 0);
    }
}
