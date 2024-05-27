// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import "../interfaces/IMultiIncentive.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title MultiIncentiveBase
/// @author Noah, Park
/// @notice A base contract for multiple incentives
/// @dev This contract is used to provide basic functionality for multiple incentives
/// @dev 인센티브 리워드를 위한 기본적인 기능을 제공하는 컨트랙트입니다.
abstract contract MultiIncentiveBase is IMultiIncentive {
    using SafeERC20 for IERC20;

    /* ========== STATE VARIABLES ========== */

    mapping(address => Reward) public rewardData;
    address[] public rewardTokens;

    // user -> reward token -> amount
    mapping(address => mapping(address => uint256)) public userRewardPerTokenPaid;
    mapping(address => mapping(address => uint256)) public rewards;

    bool internal _lock;
    address public gov;

    function _initialize(address _gov) internal virtual {
        gov = _gov;

        emit SetGov(_gov);
    }

    modifier onlyGov() {
        require(msg.sender == gov, "Only gov can call this function");
        _;
    }

    modifier lock() {
        require(!_lock, "reentry");
        _lock = true;
        _;
        _lock = false;
    }

    function setGov(address _gov) external onlyGov {
        require(_gov != address(0), "zero address");
        gov = _gov;

        emit SetGov(_gov);
    }

    function addReward(address _rewardsToken, address _rewardsDistributor, uint256 _rewardsDuration) public onlyGov {
        require(rewardData[_rewardsToken].rewardsDuration == 0);
        require(_rewardsDistributor != address(0), "zero address");
        require(_rewardsDuration > 0, "zero duration");
        rewardTokens.push(_rewardsToken);
        rewardData[_rewardsToken].rewardsDistributor = _rewardsDistributor;
        rewardData[_rewardsToken].rewardsDuration = _rewardsDuration;
    }

    function lastTimeRewardApplicable(address _rewardsToken) public view returns (uint256) {
        return Math.min(block.timestamp, rewardData[_rewardsToken].periodFinish);
    }

    function rewardPerToken(address _rewardsToken) public view returns (uint256) {
        if (getTotalAmount() == 0) {
            return rewardData[_rewardsToken].rewardPerTokenStored;
        }
        return rewardData[_rewardsToken].rewardPerTokenStored
            + (
                (
                    (lastTimeRewardApplicable(_rewardsToken) - (rewardData[_rewardsToken].lastUpdateTime))
                        * (rewardData[_rewardsToken].rewardRate) * (1e18)
                ) / (getTotalAmount())
            );
    }

    function earned(address account, address _rewardsToken) public view returns (uint256) {
        return (
            getUserAmount(account) * (rewardPerToken(_rewardsToken) - (userRewardPerTokenPaid[account][_rewardsToken]))
        ) / (1e18) + (rewards[account][_rewardsToken]);
    }

    function getRewardForDuration(address _rewardsToken) external view returns (uint256) {
        return rewardData[_rewardsToken].rewardRate * (rewardData[_rewardsToken].rewardsDuration);
    }

    function rewardLength() external view returns (uint256) {
        return rewardTokens.length;
    }

    function getRewardRate(address _rewardToken) external view returns (uint256) {
        return rewardData[_rewardToken].rewardRate;
    }

    function getTotalAmount() public view virtual returns (uint256);

    function getUserAmount(address _user) public view virtual returns (uint256);

    /* ========== MUTATIVE FUNCTIONS ========== */

    function setRewardsDistributor(address _rewardsToken, address _rewardsDistributor) external onlyGov {
        require(_rewardsDistributor != address(0), "zero address");

        rewardData[_rewardsToken].rewardsDistributor = _rewardsDistributor;

        emit SetRewardsDistributor(_rewardsToken, _rewardsDistributor);
    }

    function getReward() public lock updateReward(msg.sender) {
        for (uint256 i; i < rewardTokens.length; i++) {
            address _rewardsToken = rewardTokens[i];
            uint256 reward = rewards[msg.sender][_rewardsToken];
            if (reward > 0) {
                rewards[msg.sender][_rewardsToken] = 0;
                IERC20(_rewardsToken).safeTransfer(msg.sender, reward);
                emit RewardPaid(msg.sender, _rewardsToken, reward);
            }
        }
    }

    /* ========== RESTRICTED FUNCTIONS ========== */

    function notifyRewardAmount(address _rewardsToken, uint256 reward) external updateReward(address(0)) {
        require(rewardData[_rewardsToken].rewardsDistributor == msg.sender);
        // handle the transfer of reward tokens via `transferFrom` to reduce the number
        // of transactions required and ensure correctness of the reward amount
        IERC20(_rewardsToken).safeTransferFrom(msg.sender, address(this), reward);

        if (block.timestamp >= rewardData[_rewardsToken].periodFinish) {
            rewardData[_rewardsToken].rewardRate = reward / (rewardData[_rewardsToken].rewardsDuration);
        } else {
            uint256 remaining = rewardData[_rewardsToken].periodFinish - (block.timestamp);
            uint256 leftover = remaining * (rewardData[_rewardsToken].rewardRate);
            rewardData[_rewardsToken].rewardRate = (reward + leftover) / (rewardData[_rewardsToken].rewardsDuration);
        }

        rewardData[_rewardsToken].lastUpdateTime = block.timestamp;
        rewardData[_rewardsToken].periodFinish = block.timestamp + (rewardData[_rewardsToken].rewardsDuration);
        emit RewardAdded(reward);
    }

    function setRewardsDuration(address _rewardsToken, uint256 _rewardsDuration) external {
        require(block.timestamp > rewardData[_rewardsToken].periodFinish, "Reward period still active");
        require(rewardData[_rewardsToken].rewardsDistributor == msg.sender);
        require(_rewardsDuration > 0, "Reward duration must be non-zero");
        rewardData[_rewardsToken].rewardsDuration = _rewardsDuration;
        emit RewardsDurationUpdated(_rewardsToken, rewardData[_rewardsToken].rewardsDuration);
    }

    /* ========== Reward MODIFIERS ========== */

    modifier updateReward(address account) {
        for (uint256 i; i < rewardTokens.length; i++) {
            address token = rewardTokens[i];
            rewardData[token].rewardPerTokenStored = rewardPerToken(token);
            rewardData[token].lastUpdateTime = lastTimeRewardApplicable(token);
            if (account != address(0)) {
                rewards[account][token] = earned(account, token);
                userRewardPerTokenPaid[account][token] = rewardData[token].rewardPerTokenStored;
            }
        }
        _;
    }

    uint256[50] private __gap;
}
