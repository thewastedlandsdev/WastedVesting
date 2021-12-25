//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IWastedStaking {
    event Pool(
        uint256 poolId,
        string name,
        uint256 lockedMonths,
        uint256 totalRewards,
        uint256 maxWarriorPerAddress
    );
    event Staked(
        uint256[] indexed warriorIds,
        uint256 indexed poolId,
        address staker
    );
    event Unstaked(
        uint256[] indexed warriorIds,
        uint256 indexed poolId,
        address staker
    );
    event Claimed(
        uint256[] indexed warriorIds,
        uint256 indexed poolId,
        address staker
    );

    struct WastedPool {
        string name;
        uint256 lockedMonths;
        uint256 totalRewards;
        uint256 staked;
        uint256 maxWarriorPerAddress;
    }

    /**
     * @notice Stake warrior earn nfts.
     */
    function stake(uint256[] memory warriorIds, uint256 poolId) external;

    /**
     * @notice Unstake warrior before finish.
     */
    function unstake(uint256 poolId) external;

    /**
     * @notice claim warrior and rewards.
     */
    function claim(uint256 poolId) external payable;
}
