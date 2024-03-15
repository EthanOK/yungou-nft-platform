// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

interface IERC721DropCloneable {
    struct FeeInfo {
        address account;
        uint96 fee;
    }

    function initialize(
        string calldata _name,
        string calldata _symbol,
        uint256 _totalSupply,
        address _owner,
        address _payToken,
        uint256 _unitPrice,
        FeeInfo calldata _earningFeeInfo,
        FeeInfo calldata _platformFeeInfo,
        string calldata __baseURI
    ) external;
}
