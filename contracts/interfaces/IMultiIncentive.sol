// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

interface IMultiIncentive {
    struct Reward {
        address rewardsDistributor;
        uint256 rewardsDuration;
        uint256 periodFinish;
        uint256 rewardRate;
        uint256 lastUpdateTime;
        uint256 rewardPerTokenStored;
    }

    function refreshReward(address account) external;

    function notifyRewardAmount(address _rewardsToken, uint256 reward) external;

    function getRewardRate(address _rewardsToken) external view returns (uint256);

    function earned(address account, address _rewardsToken) external view returns (uint256);

    function rewardTokens(uint256 index) external view returns (address);

    function rewardLength() external view returns (uint256);

    /* ========== EVENTS ========== */

    event RewardAdded(uint256 reward);
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, address indexed rewardsToken, uint256 reward);
    event RewardsDurationUpdated(address token, uint256 newDuration);
    event Recovered(address token, uint256 amount);
    event SetGov(address indexed gov);
    event SetRewardsDistributor(address indexed rewardsToken, address indexed rewardsDistributor);
}
