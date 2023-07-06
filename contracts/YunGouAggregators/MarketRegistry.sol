// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/access/Ownable.sol";

contract MarketRegistry is Ownable {
    address constant YunGou = 0x0000006C517Ed32ff128B33f137BB4ac31B0C6Dd;
    address constant OpenSea = 0x00000000000000ADc04C56Bf30aC9d3c0aAF14dC;

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

    constructor() {
        markets.push(Market(address(0), false, false));
        markets.push(Market(YunGou, false, true));
        markets.push(Market(OpenSea, false, true));
        _transferOwnership(tx.origin);
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
