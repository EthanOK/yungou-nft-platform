// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

abstract contract YGIOStakingDomain {
    enum StakeYGIOType {
        NULL,
        STAKING_HAS_DEADLINE,
        STAKING_NO_DEADLINE,
        UNSTAKECASH,
        UNSTAKEORDER,
        UNSTAKEONLYOWNER
    }

    struct StakingYGIOParas {
        uint256 amount;
        uint256 stakeDays;
        uint256 deadline;
    }

    struct StakeYGIOData {
        uint256 cash;
        uint256[] stakingOrderIds;
        uint256 totalStaking;
    }

    struct StakeYGIOOrderData {
        address owner;
        uint256 amount;
        uint128 startTime;
        uint128 endTime;
    }

    event StakeYGIO(
        address indexed account,
        uint256 amount,
        uint256 startTime,
        uint256 endTime,
        StakeYGIOType indexed stakeType,
        uint256 orderId,
        uint256 callCount,
        uint256 blockNumber
    );

    // total Staking YGIO
    uint256 totalStakingYGIO;

    // total Staking YGIO days(All user)
    uint256 totalStakingYGIODays;

    // account => total staking YGIO Days
    mapping(address => uint256) stakingYGIODays;

    // account => StakeYGIOrderData
    mapping(address => StakeYGIOData) stakeYGIODatas;

    // orderId => StakeYGIOOrderData
    mapping(uint256 => StakeYGIOOrderData) stakeYGIOOrderDatas;
}
