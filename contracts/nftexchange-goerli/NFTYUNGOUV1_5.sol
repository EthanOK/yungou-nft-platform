// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ExchangeDomainV1_5.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract NFTYUNGOUV1_5 is
    ExchangeDomainV1_5,
    Initializable,
    PausableUpgradeable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable
{
    using SafeERC20 for IERC20;
    using ECDSA for bytes32;

    uint256 public constant FEE_10000 = 10000;
    string public constant NAME_YUNGOU = "YUNGOU";
    string public constant VERSION = "1.5";

    address payable private beneficiary;
    address private systemVerifier;

    function initialize(address payable _beneficiary) public initializer {
        beneficiary = _beneficiary;

        __ReentrancyGuard_init();
        __Pausable_init();
        __Ownable_init();
    }

    function setBeneficiary(address payable newBeneficiary) external onlyOwner {
        beneficiary = newBeneficiary;
    }

    function getBeneficiary() external view returns (address) {
        return beneficiary;
    }

    function setPause() external onlyOwner {
        if (!paused()) {
            _pause();
        } else {
            _unpause();
        }
    }

    function excuteWithETH(
        BasicOrder calldata order,
        address receiver
    ) external payable whenNotPaused nonReentrant returns (bool) {
        if (receiver == address(0)) {
            receiver = _msgSender();
        }
        uint256 valueETH = msg.value;
        uint256 currentTimestamp = block.timestamp;

        _validateOrder_ETH(
            order.parameters,
            order.expiryDate,
            order.buyAmount,
            currentTimestamp
        );

        _validateOrderSignature(order.parameters, order.orderSignature);

        _validateSystemSignature(
            order.orderSignature,
            order.buyAmount,
            order.totalRoyaltyFee,
            order.totalPlatformFee,
            order.totalAfterTaxIncome,
            order.totalPayment,
            order.expiryDate,
            order.systemSignature
        );

        require(valueETH >= order.totalPayment, "ETH insufficient");
        unchecked {
            uint256 totalFee = order.totalPlatformFee + order.totalRoyaltyFee;
            _excuteExchangeOrder(order, receiver, totalFee);
        }

        if (valueETH > order.totalPayment) {
            unchecked {
                uint256 _amount = valueETH - order.totalPayment;
                _transferETH(_msgSender(), _amount);
            }
        }

        return true;
    }

    function batchExcuteWithETH(
        BasicOrder[] calldata orders,
        address receiver
    ) external payable whenNotPaused nonReentrant returns (bool) {
        if (receiver == address(0)) {
            receiver = _msgSender();
        }
        uint256 valueETH = msg.value;
        uint256 currentTimestamp = block.timestamp;

        (uint256 totalFee, uint256 totalPayment) = _validateOrders(
            orders,
            currentTimestamp
        );

        require(valueETH >= totalPayment, "ETH insufficient");

        _excuteExchangeOrders(orders, receiver, totalFee);

        if (valueETH > totalPayment) {
            unchecked {
                uint256 _amount = valueETH - totalPayment;
                _transferETH(_msgSender(), _amount);
            }
        }

        return true;
    }

    function _validateOrders(
        BasicOrder[] calldata orders,
        uint256 currentTimestamp
    ) internal view returns (uint256 totalFee, uint256 totalPayment) {
        for (uint i = 0; i < orders.length; i++) {
            _validateOrder_ETH(
                orders[i].parameters,
                orders[i].expiryDate,
                orders[i].buyAmount,
                currentTimestamp
            );

            _validateOrderSignature(
                orders[i].parameters,
                orders[i].orderSignature
            );

            _validateSystemSignature(
                orders[i].orderSignature,
                orders[i].buyAmount,
                orders[i].totalRoyaltyFee,
                orders[i].totalPlatformFee,
                orders[i].totalAfterTaxIncome,
                orders[i].totalPayment,
                orders[i].expiryDate,
                orders[i].systemSignature
            );

            unchecked {
                totalFee =
                    totalFee +
                    orders[i].totalRoyaltyFee +
                    orders[i].totalPlatformFee;

                totalPayment = totalPayment + orders[i].totalPayment;
            }
        }
    }

    function _validateOrder_ETH(
        BasicOrderParameters calldata parameters,
        uint256 expiryDate,
        uint256 buyAmount,
        uint256 currentTimestamp
    ) internal pure {
        require(
            parameters.startTime <= currentTimestamp &&
                currentTimestamp <= parameters.endTime,
            "Order has expired"
        );
        require(currentTimestamp <= expiryDate, "system signature has expired");

        if (parameters.orderType == OrderType.ETH_TO_ERC721) {
            require(buyAmount == 1 && parameters.sellAmount == 1);
        } else if (parameters.orderType == OrderType.ETH_TO_ERC1155) {
            require(buyAmount > 0 && buyAmount <= parameters.sellAmount);
        } else {
            revert("Incorrect buyAmount");
        }
    }

    // bytes orderSignature;
    // uint256 buyAmount;
    // uint256 totalRoyaltyFee;
    // uint256 totalPlatformFee;
    // uint256 totalAfterTaxIncome;
    // uint256 totalPayment;
    // uint256 expiryDate;
    function _validateSystemSignature(
        bytes calldata orderSignature,
        uint256 buyAmount,
        uint256 totalRoyaltyFee,
        uint256 totalPlatformFee,
        uint256 totalAfterTaxIncome,
        uint256 totalPayment,
        uint256 expiryDate,
        bytes calldata systemSignature
    ) internal view {
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

        hash = hash.toEthSignedMessageHash();

        address signer = hash.recover(systemSignature);

        require(signer == systemVerifier, "Incorrect system signature");
    }

    function _validateOrderSignature(
        BasicOrderParameters calldata parameters,
        bytes calldata orderSignature
    ) internal view {
        bytes32 hash = keccak256(abi.encode(_getEIP712Domain(), parameters));

        hash = hash.toEthSignedMessageHash();

        address signer = hash.recover(orderSignature);

        require(signer == parameters.offerer, "Incorrect order signature");
    }

    function _getEIP712Domain() internal view returns (EIP712Domain memory) {
        EIP712Domain memory domain = EIP712Domain({
            name: NAME_YUNGOU,
            chainId: block.chainid,
            verifyingContract: address(this)
        });
        return domain;
    }

    function _excuteExchangeOrder(
        BasicOrder calldata order,
        address receiver,
        uint256 totalFee
    ) internal {
        _transferNftToBuyer(
            order.parameters.orderType,
            order.parameters.offerer,
            receiver,
            order.parameters.offerToken,
            order.parameters.offerTokenId,
            order.buyAmount
        );

        // transfer total Fee
        _transferETH(beneficiary, totalFee);

        // transfer After-Tax income to offerer
        _transferETH(order.parameters.offerer, order.totalAfterTaxIncome);

        emit Exchange(
            order.parameters.offerToken,
            order.parameters.offerTokenId,
            order.parameters.sellAmount,
            order.parameters.unitPrice,
            order.parameters.offerer,
            order.parameters.paymentToken,
            order.parameters.paymentTokenId,
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
        uint256 totalFee
    ) internal {
        // transfer total Fee
        _transferETH(beneficiary, totalFee);

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
                orders[i].parameters.offerToken,
                orders[i].parameters.offerTokenId,
                orders[i].parameters.sellAmount,
                orders[i].parameters.unitPrice,
                orders[i].parameters.offerer,
                orders[i].parameters.paymentToken,
                orders[i].parameters.paymentTokenId,
                receiver,
                orders[i].buyAmount,
                orders[i].totalPayment,
                orders[i].totalRoyaltyFee,
                orders[i].totalPlatformFee
            );
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

    function _transferETH(address account, uint256 payAmount) internal {
        payable(account).transfer(payAmount);
    }

    function withdrawEther(address account) external onlyOwner {
        payable(account).transfer(address(this).balance);
    }
}
