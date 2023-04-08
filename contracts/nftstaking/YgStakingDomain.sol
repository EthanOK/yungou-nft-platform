// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

abstract contract YgStakingDomain {
    struct StakingData {
        address owner;
        bool stakedState;
        uint128 startTime;
        uint128 endTime;
    }

    // Multi Call
    struct Call {
        address target;
        bytes callData;
    }

    event Staking(
        address indexed account,
        uint256 indexed tokenId,
        address indexed nftContract,
        uint256 startTime,
        uint256 endTime
    );

    event UnStake(
        address indexed account,
        uint256 indexed tokenId,
        address indexed nftContract,
        uint256 startTime,
        uint256 real_endTime
    );

    event WithdrawERC20(uint256 orderId, address account, uint256 amount);
}
