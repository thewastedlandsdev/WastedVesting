//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IWastedStakingToken {
    struct WastedPool {
        string name;
        uint256 warriorRequirement;
        uint256 tokenRequirement;
        uint256 totalReward;
        uint256 endTime;
        uint256 startTime;
    }

    event Pool(
        string name,
        uint256 warriorRequirement,
        uint256 tokenRequirement,
        uint256 totalReward,
        uint256 endTime,
        uint256 startTime
    );
}
