// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

interface IPriceCalculator {
    struct ReferenceData {
        uint256 lastData;
        uint256 lastUpdated;
    }

    // return 18 decimals of precision
    function priceOf(address asset) external view returns (uint256);
}
