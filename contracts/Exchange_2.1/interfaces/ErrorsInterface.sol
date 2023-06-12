// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

// Define error
error InsufficientETH();

error OrderExpired();

error SystemSignatureExpired();

error IncorrectBuyAmount();

error OffererNotOwner();

error InsufficientERC1155Balance();

error IncorrectTotalPayment();

error IncorrectSystemSignature();

error IncorrectOrderSignature();

error IncorrectSignatureLength();

error OrderIsCancelled(bytes32);

error OrderAlreadyAllFilled(bytes32);

error NotOwnerOfOrder();

error ExceededShelvesTotal();
