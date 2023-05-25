// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./MarketRegistry.sol";

contract YunGouAggregators is Ownable, ReentrancyGuard {
    bytes4 constant SELECTOR_TRANSFERFROM_ERC20_SELECTOR = 0x23b872dd;
    bytes4 constant SELECTOR_TRANSFER_ERC20_SELECTOR = 0xa9059cbb;

    struct TradeDetails {
        uint256 marketId;
        uint256 value;
        bytes tradeData;
    }
    struct ERC20Details {
        address[] tokenAddrs;
        uint256[] amounts;
    }

    struct ConverstionDetails {
        bytes conversionData;
    }

    MarketRegistry public marketRegistry;
    address public converter;
    bool public withERC20sSwitch;

    function setConverter(address _converter) external onlyOwner {
        converter = _converter;
    }

    function setRewardSwitch() external onlyOwner {
        withERC20sSwitch = !withERC20sSwitch;
    }

    constructor(address _marketRegistry) {
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
        for (uint256 i = 0; i < _tradeDetails.length; i++) {
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

    function batchBuyWithERC20s(
        ERC20Details calldata erc20Details,
        MarketRegistry.TradeDetails[] calldata tradeDetails,
        ConverstionDetails[] calldata converstionDetails,
        address[] calldata dustTokens
    ) external payable nonReentrant {
        require(withERC20sSwitch, "ERC20s Switch is Off");

        // transfer ERC20 tokens from the sender to this contract
        for (uint256 i = 0; i < erc20Details.tokenAddrs.length; i++) {
            (bool success, ) = erc20Details.tokenAddrs[i].call(
                abi.encodeWithSelector(
                    SELECTOR_TRANSFERFROM_ERC20_SELECTOR,
                    msg.sender,
                    address(this),
                    erc20Details.amounts[i]
                )
            );
            // check if the call passed successfully
            _checkCallResult(success);
        }

        // Convert any assets if needed
        _conversionHelper(converstionDetails);

        // execute trades
        _trade(tradeDetails);

        // return dust tokens (if any)
        _returnDust(dustTokens);
    }

    function _conversionHelper(
        ConverstionDetails[] memory _converstionDetails
    ) internal {
        for (uint256 i = 0; i < _converstionDetails.length; i++) {
            // convert to desired asset
            (bool success, ) = converter.delegatecall(
                _converstionDetails[i].conversionData
            );
            // check if the call passed successfully
            _checkCallResult(success);
        }
    }

    function _returnDust(address[] memory _tokens) internal {
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
        // return remaining tokens (if any)
        for (uint256 i = 0; i < _tokens.length; i++) {
            if (IERC20(_tokens[i]).balanceOf(address(this)) > 0) {
                (bool success, ) = _tokens[i].call(
                    abi.encodeWithSelector(
                        SELECTOR_TRANSFER_ERC20_SELECTOR,
                        msg.sender,
                        IERC20(_tokens[i]).balanceOf(address(this))
                    )
                );
                // check if the call passed successfully
                _checkCallResult(success);
            }
        }
    }
}
