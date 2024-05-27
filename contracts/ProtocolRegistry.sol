// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "./interfaces/IPoolBase.sol";

contract ProtocolRegistry is Initializable {
    address public gov;

    struct Pool {
        address pool;
        bool isYieldPool;
    }

    Pool[] public pools;

    mapping(address => bool) public poolRegistered;

    function initialize() public initializer {
        gov = msg.sender;
    }

    function addPool(address _pool, bool _isYieldPool) external {
        require(msg.sender == gov, "Only gov");
        require(!poolRegistered[_pool], "Already registered");
        pools.push(Pool(_pool, _isYieldPool));
        poolRegistered[_pool] = true;
    }

    function removePool(uint256 _index) external {
        require(msg.sender == gov, "Only gov");
        poolRegistered[pools[_index].pool] = false;

        pools[_index] = pools[pools.length - 1];
        pools.pop();
    }

    function getAllPools() external view returns (Pool[] memory) {
        return pools;
    }

    function poolLength() external view returns (uint256) {
        return pools.length;
    }

    function getPoolsCollateral() external view returns (address[] memory) {
        address[] memory _collaterals = new address[](pools.length);
        for (uint256 i = 0; i < pools.length; i++) {
            _collaterals[i] = IPoolBase(pools[i].pool).getAsset();
        }
        return _collaterals;
    }
}
