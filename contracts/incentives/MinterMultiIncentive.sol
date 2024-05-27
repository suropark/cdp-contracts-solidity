// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "../interfaces/IPoolBase.sol";
import "./MultiIncentiveBase.sol";

contract MinterMultiIncentive is MultiIncentiveBase, Initializable {
    /* ========== STATE VARIABLES ========== */
    IPoolBase public issuedPool;

    /* ========== INITIALIZER ========== */

    function initialize(IPoolBase _issuedPool) public initializer {
        issuedPool = _issuedPool;

        _initialize(msg.sender);
    }

    function getUserAmount(address account) public view override returns (uint256) {
        return issuedPool.borrowedAmount(account);
    }

    function getTotalAmount() public view override returns (uint256) {
        return issuedPool.poolIssuedUSD();
    }

    function refreshReward(address account) external updateReward(account) {}
}
