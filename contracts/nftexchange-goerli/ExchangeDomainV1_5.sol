// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

abstract contract ExchangeDomainV1_5 {
    enum OrderType {
        ETH_TO_ERC721,
        ETH_TO_ERC1155,
        ERC20_TO_ERC721,
        ERC20_TO_ERC1155,
        ERC721_TO_ERC20,
        ERC1155_TO_ERC20
    }

    // buy it now
    struct BasicOrderParameters {
        OrderType orderType;
        address payable offerer;
        address offerToken;
        uint256 offerTokenId;
        uint256 unitPrice;
        uint256 sellAmount;
        uint256 startTime;
        uint256 endTime;
        address paymentToken;
        uint256 paymentTokenId;
        uint256 royaltyFee;
        uint256 platformFee;
        uint256 afterTaxPrice;
    }

    struct BasicOrder {
        BasicOrderParameters parameters;
        bytes orderSignature;
        uint256 buyAmount;
        uint256 totalRoyaltyFee;
        uint256 totalPlatformFee;
        uint256 totalAfterTaxIncome;
        uint256 totalPayment;
        uint256 expiryDate;
        bytes systemSignature;
    }

    struct EIP712Domain {
        string name;
        uint256 chainId;
        address verifyingContract;
    }

    event Exchange(
        address indexed offerer,
        address indexed offerToken,
        uint256 indexed offerTokenId,
        BasicOrderParameters parameters,
        address buyer,
        uint256 buyAmount,
        uint256 totalPayment,
        uint256 totalRoyaltyFee,
        uint256 totalPlatformFee
    );
}
