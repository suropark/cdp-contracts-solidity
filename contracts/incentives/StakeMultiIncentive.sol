// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../interfaces/IPoolBase.sol";
import "./MultiIncentiveBase.sol";

contract StakeMultiIncentive is MultiIncentiveBase, Initializable {
    using SafeERC20 for IERC20;

    /* ========== STATE VARIABLES ========== */
    IERC20 public stakingToken;
    uint256 private _totalSupply;
    mapping(address => uint256) private _balances;

    /* ========== INITIALIZER ========== */

    function initialize(IERC20 _stakingToken) public initializer {
        stakingToken = _stakingToken;

        _initialize(msg.sender);
    }

    /* ========== VIEWS ========== */

    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    function getTotalAmount() public view override returns (uint256) {
        return _totalSupply;
    }

    function getUserAmount(address account) public view override returns (uint256) {
        return _balances[account];
    }

    function stake(uint256 amount) external lock updateReward(msg.sender) {
        require(amount > 0, "Cannot stake 0");
        _totalSupply = _totalSupply + amount;
        _balances[msg.sender] = _balances[msg.sender] + amount;
        stakingToken.safeTransferFrom(msg.sender, address(this), amount);
        emit Staked(msg.sender, amount);
    }

    function withdraw(uint256 amount) public lock updateReward(msg.sender) {
        require(amount > 0, "Cannot withdraw 0");
        _totalSupply = _totalSupply - amount;
        _balances[msg.sender] = _balances[msg.sender] - amount;
        stakingToken.safeTransfer(msg.sender, amount);
        emit Withdrawn(msg.sender, amount);
    }

    function exit() external {
        withdraw(_balances[msg.sender]);
        getReward();
    }

    function refreshReward(address account) external updateReward(account) {}
}
