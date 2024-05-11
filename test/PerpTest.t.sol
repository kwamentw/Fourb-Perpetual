// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test} from "forge-std/Test.sol";
import (ERC20) from "./ERC20Mock.sol";
import {FourbPerp} from "../src/FourbPerp.sol";

contract PerpTest is Test{
    FourbPerp perp;

    function setUp() public {
        perp = new FourbPerp();
    }

    function testAddLiquidity() public {
        perp.addLiquidity();
    }
}