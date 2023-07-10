// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./MarketRegistry.sol";

contract YunGouAggregatorV2 is Ownable, ReentrancyGuard {
    bytes4 constant SELECTOR_TRANSFERFROM_ERC20_SELECTOR = 0x23b872dd;
    bytes4 constant SELECTOR_TRANSFER_ERC20_SELECTOR = 0xa9059cbb;

    MarketRegistry public marketRegistry;

    constructor(address _marketRegistry) {
        marketRegistry = MarketRegistry(_marketRegistry);
        _transferOwnership(tx.origin);
    }

    function setMarketRegistry(address _marketRegistry) external onlyOwner {
        marketRegistry = MarketRegistry(_marketRegistry);
    }

    function batchBuyWithETH(
        MarketRegistry.TradeDetails[] calldata tradeDetails
    ) external payable nonReentrant {
        // execute trades
        _trade(tradeDetails);

        // return remaining ETH (if any)
        assembly {
            if gt(selfbalance(), 0) {
                let callStatus := call(
                    gas(),
                    caller(),
                    selfbalance(),
                    0,
                    0,
                    0,
                    0
                )
            }
        }
    }

    function _trade(
        MarketRegistry.TradeDetails[] calldata _tradeDetails
    ) internal {
        for (uint256 i = 0; i < _tradeDetails.length; ) {
            // get market details
            (address _market, bool _isProxy, bool _isActive) = marketRegistry
                .markets(_tradeDetails[i].marketId);
            // market should be active
            require(_isActive, "_trade: InActive Market");
            // execute trade
            // if is Proxy delegatecall, else call
            (bool success, ) = _isProxy
                ? _market.delegatecall(_tradeDetails[i].tradeData)
                : _market.call{value: _tradeDetails[i].value}(
                    _tradeDetails[i].tradeData
                );
            // check if the call passed successfully
            _checkCallResult(success);
            unchecked {
                ++i;
            }
        }
    }

    function _checkCallResult(bool _success) internal pure {
        if (!_success) {
            // Copy revert reason from call
            assembly {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }
        }
    }

    receive() external payable {}
}
