// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/access/Ownable.sol";

contract MarketRegistry is Ownable {
    struct TradeDetails {
        uint256 marketId;
        uint256 value;
        bytes tradeData;
    }

    struct Market {
        address marketAddress;
        bool isProxy;
        bool isActive;
    }

    Market[] public markets;

    constructor(address[] memory marketAddresses, bool[] memory isProxys) {
        for (uint256 i = 0; i < marketAddresses.length; i++) {
            markets.push(Market(marketAddresses[i], isProxys[i], true));
        }
    }

    function addMarket(address marketAddress, bool isProxy) external onlyOwner {
        markets.push(Market(marketAddress, isProxy, true));
    }

    function setMarketStatus(
        uint256 marketId,
        bool newStatus
    ) external onlyOwner {
        Market storage market = markets[marketId];
        market.isActive = newStatus;
    }

    function setMarket(
        uint256 marketId,
        address marketAddress,
        bool isProxy
    ) external onlyOwner {
        Market storage market = markets[marketId];
        market.marketAddress = marketAddress;
        market.isProxy = isProxy;
    }
}
