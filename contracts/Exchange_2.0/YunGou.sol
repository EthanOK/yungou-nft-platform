// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "./lib/Consideration.sol";

contract YunGou is Consideration {
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

    function getSystemVerifier() external view onlyOwner returns (address) {
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
        bool result = _excuteWithETH(
            order,
            receiver,
            systemVerifier,
            beneficiary
        );
        return result;
    }

    function batchExcuteWithETH(
        BasicOrder[] calldata orders,
        address receiver
    ) external payable whenNotPaused nonReentrant returns (bool) {
        bool result = _batchExcuteWithETH(
            orders,
            receiver,
            systemVerifier,
            beneficiary
        );
        return result;
    }

    function cancel(
        BasicOrderParameters[] calldata ordersParameters
    ) external whenNotPaused nonReentrant returns (bool cancelled) {
        cancelled = _cancel(ordersParameters);
    }

    function name() external pure returns (string memory contractName) {
        // Return the name of the contract.
        return _name();
    }

    function information()
        external
        view
        returns (string memory version, bytes32 domainSeparator)
    {
        return _information();
    }

    function getOrderHash(
        BasicOrderParameters calldata orderParameters
    ) external pure returns (bytes32 orderHash) {
        return _getOrderHash(orderParameters);
    }

    function getOrderStatus(
        bytes32 orderHash
    ) external view returns (OrderStatus memory _orderStatus) {
        _orderStatus = _getOrderStatus(orderHash);
    }
}
