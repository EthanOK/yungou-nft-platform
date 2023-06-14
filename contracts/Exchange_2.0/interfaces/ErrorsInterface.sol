// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

// 0x6a12f104
error InsufficientETH();

// 0xc56873ba
error OrderExpired();

// 0xdb100c45
error SystemSignatureExpired();

// 0x5f15d672
error NoContract(address);

// 0xac3fa527
error IncorrectBuyAmount();

// 0x9877fab2
error IncorrectOrderType();

// 0xb9561204
error OffererNotOwner();

// 0xad0c93bb
error InsufficientERC1155Balance();

// 0x05327e78
error IncorrectTotalPayment();

// 0x826ad6d1
error IncorrectSystemSignature();

// 0x544bf54e
error IncorrectOrderSignature();

// 0x6c98fafe
error IncorrectSignatureLength();

// 0x1a515574
error OrderIsCancelled(bytes32);

// 0x42ae4c39
error OrderAlreadyAllFilled(bytes32);

// 0x99c530f8
error NotOwnerOfOrder();

// 0x77f35310
error ExceededShelvesTotal();

// 0x91a48eaf
error FailedCallOwnerOf();

// 0x9d7baff1
error FailedCallBalanceOf();

// 0x38f5e42f
error FailedTransferFromERC721();

// 0xfc009303
error FailedSafeTransferFromERC1155();
