// SPDX-License-Identifier:MIT
pragma solidity 0.8.20;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

/**
 * @title Chainlink price feed
 * @notice Optimal way of getting price feed
 * This is on sepolia not on mainnet
 */
contract pricefeed {
    function getPrice() public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(
            0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43
        );

        (, int answer, , , ) = priceFeed.latestRoundData();
        return uint256(answer);
    }
}
