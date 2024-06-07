// SPDX-License-Identifier:MIT
pragma solidity 0.8.20;

import {Test} from "forge-std/Test.sol";
import {Handler} from "./handler.sol";
import {ERC20} from "./ERC20Mock.sol";
import {FourbPerp} from "../src/FourbPerp.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";

contract InvarTest is Test {
    ERC20 token;
    Handler handler;
    FourbPerp perp;

    function setUp() public {
        token = new ERC20("FOURBTOKEN", "FBTKN", 18, 1000e18);
        perp = new FourbPerp(address(token), 1);
        handler = new Handler(perp);

        token.mint(address(handler), 1000e18);
        token.mint(address(perp), 1000e18);

        // bytes4[] memory selectorss = new bytes4[](1);
        // selectorss[0] = handler.openPosition.selector;
        // targetSelector(
        //     FuzzSelector({addr: address(handler), selectors: selectorss})
        // );

        targetContract(address(handler));
        token.mint(address(handler), 1000e18);
        token.mint(address(perp), 1000e18);
    }

    function invariant_openInterestIncreases() public view {
        assertGt(perp.s_totalOpenInterestLong(), 0);
        assertGt(perp.s_totalOpenInterestShort(), 0);
    }

    function invariant_CollateralAlwaysGtZeroWhenOpenAnewPosition()
        public
        view
    {
        assertGt(perp.getPositionCollateral(address(handler)), 0);
    }
}
