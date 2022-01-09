//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IWastedStaking {
    enum RarityPool {
        NORMAL,
        MYSTIC
    }

    event Pool(
        uint256 poolId,
        string name,
        uint256 lockedMonths,
        uint256 totalRewards,
        uint256 maxWarriorPerAddress,
        uint256 endTime,
        RarityPool rarityPool
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
    event Claimed(address staker, uint256 poolId, uint256[] warriorIds);

    struct WastedPool {
        string name;
        uint256 lockedMonths;
        uint256 totalRewards;
        uint256 staked;
        uint256 maxWarriorPerAddress;
        uint256 endTime;
        RarityPool rarityPool;
    }

    struct Warrior {
        uint256[] warriorIds;
        uint8[] rarity;
    }

    /**
     * @notice Stake warrior earn nfts.
     */
    function stake(
        uint256 poolId,
        Warrior calldata warrior,
        bytes memory signature
    ) external;

    /**
     * @notice Unstake warrior before finish.
     */
    function unstake(uint256 poolId) external;

    /**
     * @notice claim warrior and rewards.
     */
    function claim(uint256 poolId) external payable;
}
