// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface INftExchange {
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

    function exchangeMul(
        Order[] calldata orders,
        Sig[] calldata sigs,
        uint256[] calldata amounts,
        uint256 endTime,
        uint256[] calldata royaltyFees,
        Sig calldata royaltySig
    ) external returns (bool);
}
