// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "./Executor.sol";
import "./Validator.sol";

abstract contract Consideration is Validator, Executor {
    function _excuteWithETH(
        BasicOrder calldata order,
        address receiver,
        address systemVerifier,
        address beneficiary
    ) internal returns (bool) {
        if (receiver == address(0)) {
            receiver = _msgSender();
        }
        uint256 valueETH = msg.value;

        uint256 currentTimestamp = block.timestamp;

        uint256 totalFee;

        uint256 totalPayment;

        _verifyAndExcute(order, receiver, systemVerifier, currentTimestamp);

        unchecked {
            totalFee = order.totalRoyaltyFee + order.totalPlatformFee;

            totalPayment = order.totalPayment;
        }

        if (totalFee > 0) {
            _transferETH(beneficiary, totalFee);
        }

        if (valueETH < totalPayment) {
            _revertInsufficientETH();
        } else if (valueETH > totalPayment) {
            unchecked {
                uint256 _amount = valueETH - totalPayment;

                _transferETH(receiver, _amount);
            }
        }
        return true;
    }

    function _batchExcuteWithETH(
        BasicOrder[] calldata orders,
        address receiver,
        address systemVerifier,
        address beneficiary
    ) internal returns (bool) {
        if (receiver == address(0)) {
            receiver = _msgSender();
        }

        uint256 valueETH = msg.value;
        uint256 currentTimestamp = block.timestamp;
        uint256 totalFee;
        uint256 totalPayment;

        {
            for (uint i = 0; i < orders.length; ) {
                _verifyAndExcute(
                    orders[i],
                    receiver,
                    systemVerifier,
                    currentTimestamp
                );

                unchecked {
                    totalFee =
                        totalFee +
                        orders[i].totalRoyaltyFee +
                        orders[i].totalPlatformFee;

                    totalPayment = totalPayment + orders[i].totalPayment;

                    ++i;
                }
            }
        }

        if (totalFee > 0) {
            _transferETH(beneficiary, totalFee);
        }

        if (valueETH < totalPayment) {
            _revertInsufficientETH();
        } else if (valueETH > totalPayment) {
            unchecked {
                uint256 _amount = valueETH - totalPayment;

                _transferETH(receiver, _amount);
            }
        }

        return true;
    }

    function _verifyAndExcute(
        BasicOrder calldata order,
        address receiver,
        address systemVerifier,
        uint256 currentTimestamp
    ) internal {
        _validateOrder_ETH(
            order.parameters,
            order.expiryDate,
            order.buyAmount,
            currentTimestamp,
            order.totalPayment
        );

        bytes32 orderHash = _validateSignatureAndUpdateStatus(
            order,
            systemVerifier
        );

        _excuteExchangeOrder(orderHash, order, receiver);
    }

    function _cancel(
        BasicOrderParameters[] calldata ordersParameters
    ) internal returns (bool cancelled) {
        OrderStatus storage _orderStatus;

        address _account = _msgSender();

        uint256 totalOrders = ordersParameters.length;

        for (uint256 i = 0; i < totalOrders; ) {
            BasicOrderParameters calldata parameters = ordersParameters[i];

            if (parameters.offerer != _account) {
                _revertNotOwnerOfOrder();
            }

            bytes32 orderHash = _getOrderHash(parameters);

            _orderStatus = ordersStatus[orderHash];

            // Update the order status as not valid and cancelled.
            _orderStatus.isValidated = false;

            _orderStatus.isCancelled = true;

            emit OrderCancelled(orderHash, _account);

            unchecked {
                ++i;
            }
        }

        cancelled = true;
    }

    function _information() internal view returns (string memory, bytes32) {
        string memory version = VERSION;
        // Derive the domain separator.
        bytes32 domainSeparator = _domainSeparatorV4();
        return (version, domainSeparator);
    }

    function _name() internal pure returns (string memory) {
        // Return the name of the contract.
        return NAME_YUNGOU;
    }
}
