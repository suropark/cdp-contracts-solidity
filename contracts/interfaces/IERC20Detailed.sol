// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IERC20Detailed {
    function symbol() external view returns (string memory);

    function allowance(address owner, address spender) external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function decimals() external view returns (uint8);
}
