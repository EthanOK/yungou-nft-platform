// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "../interfaces/ErrorsInterface.sol";

// Define revert error function
function _revertInsufficientETH() pure {
    revert InsufficientETH();
}

function _revertOrderExpired() pure {
    revert OrderExpired();
}

function _revertSystemSignatureExpired() pure {
    revert SystemSignatureExpired();
}

function _revertIncorrectBuyAmount() pure {
    revert IncorrectBuyAmount();
}

function _revertIncorrectOrderType() pure {
    revert IncorrectOrderType();
}

function _revertOffererNotOwner() pure {
    revert OffererNotOwner();
}

function _revertInsufficientERC1155Balance() pure {
    revert InsufficientERC1155Balance();
}

function _revertIncorrectTotalPayment() pure {
    revert IncorrectTotalPayment();
}

function _revertIncorrectSystemSignature() pure {
    revert IncorrectSystemSignature();
}

function _revertIncorrectOrderSignature() pure {
    revert IncorrectOrderSignature();
}

function _revertIncorrectSignatureLength() pure {
    revert IncorrectSignatureLength();
}

function _revertOrderIsCancelled(bytes32 orderHash) pure {
    revert OrderIsCancelled(orderHash);
}

function _revertOrderAlreadyAllFilled(bytes32 orderHash) pure {
    revert OrderAlreadyAllFilled(orderHash);
}

function _revertNotOwnerOfOrder() pure {
    revert NotOwnerOfOrder();
}

function _revertExceededShelvesTotal() pure {
    revert ExceededShelvesTotal();
}

function _revertFailedCallOwnerOf() pure {
    revert FailedCallOwnerOf();
}

function _revertFailedCallBalanceOf() pure {
    revert FailedCallBalanceOf();
}

function _revertFailedTransferFromERC721() pure {
    revert FailedTransferFromERC721();
}

function _revertFailedSafeTransferFromERC1155() pure {
    revert FailedSafeTransferFromERC1155();
}
