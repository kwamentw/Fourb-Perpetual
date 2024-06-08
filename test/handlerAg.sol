// SPDX-License-Identifier:MIT
pragma solidity 0.8.20;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "./ERC20Mock.sol";
import {console2} from "forge-std/console2.sol";
import {FourbPerp} from "../src/FourbPerp.sol";

contract Handler is Test {
    FourbPerp perp;
    ERC20 token;

    constructor(FourbPerp _perp) {
        perp = _perp;
        token = new ERC20("FOURBTOKEN", "FBTKN", 18, 10000e18);

        token.mint(address(this), 1000e18);
    }

    function openPosition(
        uint256 _collateral,
        uint256 _size,
        bool long
    ) external {
        _collateral = bound(_collateral, 1e18, 1000e18);
        _size = bound(_size, 1e18, 999e18);

        vm.startPrank(address(this));
        token.mint(address(this), _collateral);
        perp.openPosition(_collateral, _size, long);

        console2.log(
            "------------- Position Size Opened: ",
            _size,
            "------------- Collateral of position: ",
            _collateral
        );
        vm.stopPrank();
    }
}
