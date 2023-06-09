// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "../interfaces/YunGouInterface.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {BasicOrderParameters, BasicOrder, OrderType} from "./YunGouStructsAndEnums.sol";

abstract contract Executor is YunGouInterface {
    function _excuteExchangeOrder(
        bytes32 orderHash,
        BasicOrder calldata order,
        address receiver
    ) internal {
        {
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
        }

        emit Exchange(
            orderHash,
            order.parameters.offerToken,
            order.parameters.offerTokenId,
            receiver,
            order.buyAmount,
            order.totalPayment,
            order.totalRoyaltyFee,
            order.totalPlatformFee
        );
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
