// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "./Errors.sol";
import "./YunGouDomain.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";

contract ValidateExcute is
    YunGouDomain,
    Initializable,
    PausableUpgradeable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    EIP712Upgradeable
{
    bytes32 constant BASICORDER_TYPE_HASH =
        keccak256(
            "BasicOrderParameters(uint8 orderType,address offerer,address offerToken,uint256 offerTokenId,uint256 unitPrice,uint256 sellAmount,uint256 startTime,uint256 endTime,address paymentToken,uint256 paymentTokenId,uint256 salt,uint256 royaltyFee,uint256 platformFee,uint256 afterTaxPrice)"
        );

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
        bytes32 hash = _hashTypedDataV4(
            keccak256(abi.encode(BASICORDER_TYPE_HASH, parameters))
        );

        address signer = ECDSAUpgradeable.recover(hash, orderSignature);

        if (signer != parameters.offerer) {
            _revertIncorrectOrderSignature();
        }
    }

    function _excuteExchangeOrder(
        BasicOrder calldata order,
        address receiver,
        uint256 totalFee,
        address _beneficiary
    ) internal {
        _transferNftToBuyer(
            order.parameters.orderType,
            order.parameters.offerer,
            receiver,
            order.parameters.offerToken,
            order.parameters.offerTokenId,
            order.buyAmount
        );

        // transfer After-Tax income to offerer
        _transferETH(order.parameters.offerer, order.totalAfterTaxIncome);

        if (totalFee > 0) {
            // transfer total Fee
            _transferETH(_beneficiary, totalFee);
        }

        emit Exchange(
            order.parameters.offerer,
            order.parameters.offerToken,
            order.parameters.offerTokenId,
            receiver,
            order.buyAmount,
            order.totalPayment,
            order.totalRoyaltyFee,
            order.totalPlatformFee
        );
    }

    function _excuteExchangeOrders(
        BasicOrder[] calldata orders,
        address receiver,
        uint256 totalFee,
        address _beneficiary
    ) internal {
        for (uint256 i = 0; i < orders.length; ++i) {
            _transferNftToBuyer(
                orders[i].parameters.orderType,
                orders[i].parameters.offerer,
                receiver,
                orders[i].parameters.offerToken,
                orders[i].parameters.offerTokenId,
                orders[i].buyAmount
            );

            // transfer After-Tax income to offerer
            _transferETH(
                orders[i].parameters.offerer,
                orders[i].totalAfterTaxIncome
            );

            emit Exchange(
                orders[i].parameters.offerer,
                orders[i].parameters.offerToken,
                orders[i].parameters.offerTokenId,
                receiver,
                orders[i].buyAmount,
                orders[i].totalPayment,
                orders[i].totalRoyaltyFee,
                orders[i].totalPlatformFee
            );
        }

        if (totalFee > 0) {
            // transfer total Fee
            _transferETH(_beneficiary, totalFee);
        }
    }

    function _transferNftToBuyer(
        OrderType orderType,
        address fromAccount,
        address toAccount,
        address offerToken,
        uint256 offerTokenId,
        uint256 amount
    ) internal {
        if (fromAccount != toAccount) {
            if (orderType == OrderType.ETH_TO_ERC721) {
                IERC721(offerToken).transferFrom(
                    fromAccount,
                    toAccount,
                    offerTokenId
                );
            } else if (orderType == OrderType.ETH_TO_ERC1155) {
                IERC1155(offerToken).safeTransferFrom(
                    fromAccount,
                    toAccount,
                    offerTokenId,
                    amount,
                    "0x"
                );
            }
        }
    }

    function _transferETH(address account, uint256 payAmount) internal {
        payable(account).transfer(payAmount);
    }
}
