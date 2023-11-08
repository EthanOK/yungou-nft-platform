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

    enum MinerRole {
        NULL,
        // FIRST LEVEL MINER OWNER
        FIRSTLEVEL,
        // SECOND LEVEL  MINER OWNER
        SECONDLEVEL,
        // MINER
        MINER
    }

    struct StakingLPParas {
        uint256 amount;
        uint256 stakeDays;
        address inviter;
    }

    struct StakeLPOrderData {
        address owner;
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
        uint256 indexed orderId,
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
        uint256 orderId,
        address mineOwner,
        uint256 amount,
        MinerRole beforeRole,
        MinerRole afterRole,
        uint256 blockNumber
    );

    event RemoveLPPool(
        uint256 orderId,
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

    // account => StakeLPData
    mapping(address => StakeLPData) stakeLPDatas;

    // orderId => StakeLPOrderData
    mapping(uint256 => StakeLPOrderData) stakeLPOrderDatas;
}
