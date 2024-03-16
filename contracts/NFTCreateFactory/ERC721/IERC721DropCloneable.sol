// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

interface IERC721DropCloneable {
    struct FeeInfo {
        address account;
        uint96 fee;
    }

    struct InitializeParam {
        string _name;
        string _symbol;
        uint256 _totalSupply;
        address _owner;
        address _payToken;
        uint256 _unitPrice;
        FeeInfo _earningFeeInfo;
        FeeInfo _platformFeeInfo;
        string _baseURI;
    }

    function initialize(InitializeParam calldata param) external;
}
