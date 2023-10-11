// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";

abstract contract YGMEStakingDomain is ERC721Holder {
    enum StakeYGMEType {
        NULL,
        STAKING,
        UNSTAKE,
        UNSTAKEONLYOWNER
    }

    struct StakingYGMEParas {
        uint256[] tokenIds;
        uint256 stakeDays;
        uint256 deadline;
    }

    struct StakingYGMEData {
        address owner;
        bool stakedState;
        uint128 startTime;
        uint128 endTime;
    }

    event StakingYGME(
        address indexed account,
        uint256 tokenId,
        uint256 startTime,
        uint256 endTime,
        StakeYGMEType indexed stakeType,
        uint256 callCount,
        uint256 blockNumber
    );

    // total Staking YGME
    uint256 totalStakingYGME;

    // total Staking YGME days(All user)
    uint256 totalStakingYGMEDays;

    // account => total staking YGME Days
    mapping(address => uint256) stakingYGMEDays;

    // tokenId => StakingYGMEData
    mapping(uint256 => StakingYGMEData) stakingYGMEDatas;

    // account => staking tokenIds
    mapping(address => uint256[]) stakingTokenIds;

    // account => token amount
    mapping(address => uint256) stakingYGMEAmounts;
}
