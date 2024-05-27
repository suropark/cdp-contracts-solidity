// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import "./PoolBase.sol";

abstract contract YieldPoolBase is PoolBase {
    bool public isYieldPool = true;

    uint256 public totalCollateralStored;

    function _initialize(IMintBurnERC20 _usdAsset, IERC20 _collateral) internal virtual override {
        super._initialize(_usdAsset, _collateral);
    }

    function totalCollateralAmount() public view override returns (uint256) {
        return totalCollateralStored;
    }

    function _depositToYieldPool(uint256 amount) internal virtual;

    function _withdrawFromYieldPool(uint256 amount) internal virtual;

    function claimYield() external virtual;

    function _safeTransferIn(address from, uint256 amount) internal override returns (bool) {
        super._safeTransferIn(from, amount);

        _depositToYieldPool(amount);

        totalCollateralStored = totalCollateralStored + amount;

        return true;
    }

    function _safeTransferOut(address to, uint256 amount) internal override returns (bool) {
        _withdrawFromYieldPool(amount);

        totalCollateralStored = totalCollateralStored - amount;

        return super._safeTransferOut(to, amount);
    }

    uint256[50] private __gap;
}
