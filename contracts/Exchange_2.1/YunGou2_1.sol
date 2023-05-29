// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "./ValidateExcute.sol";

contract YunGou2_1 is ValidateExcute {
    string public constant NAME_YUNGOU = "YUNGOU";
    string public constant VERSION = "2.0";

    address payable private beneficiary;
    address private systemVerifier;

    function initialize(
        address payable _beneficiary,
        address _systemVerifier
    ) public initializer {
        beneficiary = _beneficiary;
        systemVerifier = _systemVerifier;

        __ReentrancyGuard_init();
        __Pausable_init();
        __Ownable_init();
        __EIP712_init(NAME_YUNGOU, VERSION);
    }

    function setBeneficiary(address payable newBeneficiary) external onlyOwner {
        beneficiary = newBeneficiary;
    }

    function setSystemVerifier(address _systemVerifier) external onlyOwner {
        systemVerifier = _systemVerifier;
    }

    function getBeneficiary() external view returns (address) {
        return beneficiary;
    }

    function getSystemVerifier() external view returns (address) {
        return systemVerifier;
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
            currentTimestamp,
            order.totalPayment
        );

        _validateSignature(order, systemVerifier);

        if (valueETH < order.totalPayment) {
            _revertInsufficientETH();
        }

        unchecked {
            uint256 totalFee = order.totalPlatformFee + order.totalRoyaltyFee;

            _excuteExchangeOrder(order, receiver, totalFee, beneficiary);
        }

        if (valueETH > order.totalPayment) {
            unchecked {
                uint256 _amount = valueETH - order.totalPayment;

                _transferETH(receiver, _amount);
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
            currentTimestamp,
            systemVerifier
        );

        if (valueETH < totalPayment) {
            _revertInsufficientETH();
        }

        _excuteExchangeOrders(orders, receiver, totalFee, beneficiary);

        if (valueETH > totalPayment) {
            unchecked {
                uint256 _amount = valueETH - totalPayment;

                _transferETH(receiver, _amount);
            }
        }

        return true;
    }

    function withdrawETH(address account) external onlyOwner {
        payable(account).transfer(address(this).balance);
    }
}
