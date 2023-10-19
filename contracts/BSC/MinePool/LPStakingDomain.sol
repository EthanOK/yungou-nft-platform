// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

abstract contract LPStakingDomain {
    enum StakeLPType {
        NULL,
        STAKING_HAS_DEADLINE,
        STAKING_NO_DEADLINE,
        UNSTAKECASH,
        UNSTAKEORDER,
        UNSTAKEONLYOWNER
    }

    struct StakingLPParas {
        uint256 poolId;
        uint256 amount;
        uint256 stakeDays;
        address inviter;
        uint256 deadline;
    }

    struct StakeLPOrderData {
        address owner;
        uint256 poolId;
        uint256 amount;
        uint128 startTime;
        uint128 endTime;
    }

    struct StakeLPData {
        uint256 cash;
        uint256[] stakingOrderIds;
        uint256 totalStaking;
    }

    event StakeLP(
        uint256 indexed poolId,
        address indexed account,
        uint256 amount,
        uint256 startTime,
        uint256 endTime,
        StakeLPType indexed stakeType,
        uint256 stakingOrderId,
        uint256 callCount,
        uint256 blockNumber
    );

    event NewLPPool(
        uint256 poolId,
        address mineOwner,
        uint256 amount,
        uint256 blockNumber
    );

    event RemoveLPPool(
        uint256 poolId,
        address mineOwner,
        uint256 amount,
        uint256 blockNumber
    );

    event WithdrawReward(
        uint256 orderId,
        address indexed tokenAddress,
        address indexed account,
        uint256 amount,
        uint256 blockNumber
    );

    // total Staking LP Amount(All user exclude mineOwner)
    uint256 totalStakingLP;

    // total Staking LP days(All user)
    uint256 totalStakingLPDays;

    // account => total staking LP Days
    mapping(address => uint256) stakingLPDays;

    // account => StakeLPData
    mapping(address => StakeLPData) stakeLPDatas;

    // orderId => StakeLPOrderData
    mapping(uint256 => StakeLPOrderData) stakeLPOrderDatas;
}
