// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

abstract contract ExchangeDomainV1 {
    enum AssetType {
        ETH,
        ERC20,
        ERC1155,
        ERC721,
        ERC721Deprecated
    }

    struct Asset {
        address token;
        uint256 tokenId;
        AssetType assetType;
    }

    struct OrderKey {
        address owner;
        uint256 salt;
        Asset sellAsset;
        Asset buyAsset;
    }

    struct Order {
        OrderKey key;
        uint256 sellAmount;
        uint256 unitPrice;
        uint256 startTime;
        uint256 endTime;
    }

    struct Sig {
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    struct EIP712Domain {
        string name;
        string version;
        uint256 chainId;
        address verifyingContract;
    }

    struct Call {
        address target;
        bytes callData;
    }

    event Exchange(
        address indexed sellToken,
        uint256 indexed sellTokenId,
        uint256 sellAmount,
        uint256 unitPrice,
        address seller,
        address buyToken,
        uint256 buyTokenId,
        address buyer,
        uint256 amount,
        uint256 payPrice,
        uint256 royaltyFee
    );
}
