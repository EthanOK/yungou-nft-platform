// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "../interfaces/YunGouInterface.sol";
import {BasicOrderParameters, BasicOrder, OrderType} from "./YunGouStructsAndEnums.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

abstract contract Executor is YunGouInterface {
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
