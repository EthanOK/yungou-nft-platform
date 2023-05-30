// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

string constant NAME_YUNGOU = "YunGou";

string constant VERSION = "2.0";

bytes32 constant BASICORDER_TYPE_HASH = keccak256(
    "BasicOrderParameters("
    "uint8 orderType,"
    "address offerer,"
    "address offerToken,"
    "uint256 offerTokenId,"
    "uint256 unitPrice,"
    "uint256 sellAmount,"
    "uint256 startTime,"
    "uint256 endTime,"
    "address paymentToken,"
    "uint256 paymentTokenId,"
    "uint256 salt,"
    "uint256 royaltyFee,"
    "uint256 platformFee,"
    "uint256 afterTaxPrice"
    ")"
);
