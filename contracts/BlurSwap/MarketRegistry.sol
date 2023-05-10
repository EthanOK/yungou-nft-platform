// SPDX-License-Identifier: MIT
// 0x3a574baC669F3B1CB54b92cCBAefbAFd07054d96
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";

contract MarketRegistry is Ownable {
    struct TradeDetails {
        uint256 marketId;
        uint256 value;
        bytes tradeData;
    }

    struct Market {
        address proxy;
        bool isLib;
        bool isActive;
    }
    // 10: 0x09c5eabe execute(bytes)
    // address: proxy 0x98661956ed6e2F5fC99C93D909EC28FDC3d48108
    // bool: isLib true
    // bool: isActive true

    // opensea: 0x00000000000000ADc04C56Bf30aC9d3c0aAF14dC
    // fulfillAvailableAdvancedOrders(...,receiver)	 0x87201b41
    // NFT transfer: seller => receiver

    // 7: 0xf7fc708b
    // address: proxy 0x43D31A29bd80051BB1F6C922D7C699aA3DDe88EC
    // bool: isLib true
    // bool: isActive true
    // blur: 0x000000000000ad05ccc4f10045630fb830b95127
    // bulkExecute() 0xb3be57f8
    // NFT transfer: seller => blur2 => buyer
    // 0x23b872dd transferFrom(address,address,uint256)

    // 0xb1283e77 markets(uint256)
    Market[] public markets;

    constructor(address[] memory proxies, bool[] memory isLibs) {
        for (uint256 i = 0; i < proxies.length; i++) {
            markets.push(Market(proxies[i], isLibs[i], true));
        }
    }

    function addMarket(address proxy, bool isLib) external onlyOwner {
        markets.push(Market(proxy, isLib, true));
    }

    function setMarketStatus(
        uint256 marketId,
        bool newStatus
    ) external onlyOwner {
        Market storage market = markets[marketId];
        market.isActive = newStatus;
    }

    function setMarketProxy(
        uint256 marketId,
        address newProxy,
        bool isLib
    ) external onlyOwner {
        Market storage market = markets[marketId];
        market.proxy = newProxy;
        market.isLib = isLib;
    }
}
