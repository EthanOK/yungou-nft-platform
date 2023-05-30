// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "./RevertErrors.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import {NAME_YUNGOU, VERSION, BASICORDER_TYPE_HASH} from "./YunGouConstants.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";
import {BasicOrderParameters, BasicOrder, OrderType} from "./YunGouStructsAndEnums.sol";

abstract contract Validator is
    Initializable,
    PausableUpgradeable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    EIP712Upgradeable
{
    function _validateOrders(
        BasicOrder[] calldata orders,
        uint256 currentTimestamp,
        address _systemVerifier
    ) internal view returns (uint256 totalFee, uint256 totalPayment_orders) {
        for (uint i = 0; i < orders.length; i++) {
            _validateOrder_ETH(
                orders[i].parameters,
                orders[i].expiryDate,
                orders[i].buyAmount,
                currentTimestamp,
                orders[i].totalPayment
            );

            _validateSignature(orders[i], _systemVerifier);

            unchecked {
                totalFee =
                    totalFee +
                    orders[i].totalRoyaltyFee +
                    orders[i].totalPlatformFee;

                totalPayment_orders =
                    totalPayment_orders +
                    orders[i].totalPayment;
            }
        }
    }

    function _validateOrder_ETH(
        BasicOrderParameters calldata parameters,
        uint256 expiryDate,
        uint256 buyAmount,
        uint256 currentTimestamp,
        uint256 totalPayment_order
    ) internal pure {
        if (
            currentTimestamp < parameters.startTime ||
            currentTimestamp > parameters.endTime
        ) {
            _revertOrderExpired();
        }

        if (currentTimestamp > expiryDate) {
            _revertSystemSignatureExpired();
        }

        if (parameters.orderType == OrderType.ETH_TO_ERC721) {
            require(buyAmount == 1 && parameters.sellAmount == 1);
        } else if (parameters.orderType == OrderType.ETH_TO_ERC1155) {
            require(buyAmount > 0 && buyAmount <= parameters.sellAmount);
        } else {
            _revertIncorrectBuyAmount();
        }

        unchecked {
            if (totalPayment_order != (buyAmount * parameters.unitPrice)) {
                _revertIncorrectTotalPayment();
            }
        }
    }

    function _validateSignature(
        BasicOrder calldata order,
        address _systemVerifier
    ) internal view {
        _validateOrderSignature(order.parameters, order.orderSignature);

        _validateSystemSignature(
            order.orderSignature,
            order.buyAmount,
            order.totalRoyaltyFee,
            order.totalPlatformFee,
            order.totalAfterTaxIncome,
            order.totalPayment,
            order.expiryDate,
            order.systemSignature,
            _systemVerifier
        );
    }

    function _validateSystemSignature(
        bytes calldata orderSignature,
        uint256 buyAmount,
        uint256 totalRoyaltyFee,
        uint256 totalPlatformFee,
        uint256 totalAfterTaxIncome,
        uint256 totalPayment,
        uint256 expiryDate,
        bytes calldata systemSignature,
        address _systemVerifier
    ) internal pure {
        bytes32 hash = keccak256(
            abi.encode(
                orderSignature,
                buyAmount,
                totalRoyaltyFee,
                totalPlatformFee,
                totalAfterTaxIncome,
                totalPayment,
                expiryDate
            )
        );

        hash = ECDSAUpgradeable.toEthSignedMessageHash(hash);

        address signer = ECDSAUpgradeable.recover(hash, systemSignature);

        if (signer != _systemVerifier) {
            _revertIncorrectSystemSignature();
        }
    }

    function _validateOrderSignature(
        BasicOrderParameters calldata parameters,
        bytes calldata orderSignature
    ) internal view {
        bytes32 hash = _getOrderHash(parameters);

        address signer = ECDSAUpgradeable.recover(hash, orderSignature);

        if (signer != parameters.offerer) {
            _revertIncorrectOrderSignature();
        }
    }

    function _getOrderHash(
        BasicOrderParameters calldata parameters
    ) internal view returns (bytes32 orderHash) {
        return
            _hashTypedDataV4(
                keccak256(abi.encode(BASICORDER_TYPE_HASH, parameters))
            );
    }
}