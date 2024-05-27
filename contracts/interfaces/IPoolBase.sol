// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import "./IMintBurnERC20.sol";

interface IPoolBase {
    function usdAsset() external view returns (IMintBurnERC20);

    function poolIssuedUSD() external view returns (uint256);

    function totalCollateralAmount() external view returns (uint256);

    function getAsset() external view returns (address);

    function getAssetPrice() external view returns (uint256);

    function collateralAmount(address account) external view returns (uint256);

    function borrowedAmount(address account) external view returns (uint256);

    function collateralRatio(address account) external view returns (uint256);
}
