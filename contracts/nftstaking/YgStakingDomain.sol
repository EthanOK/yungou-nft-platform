// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

abstract contract YgStakingDomain {
    struct StakingData {
        address owner;
        bool stakedState;
        uint128 startTime;
        uint128 endTime;
    }

    /* An ECDSA signature. */
    struct Sig {
        /* v parameter */
        uint8 v;
        /* r parameter */
        bytes32 r;
        /* s parameter */
        bytes32 s;
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

    event WithdrawERC20(
        uint256 orderId,
        address erc20,
        address account,
        uint256 amount,
        string random
    );
}
