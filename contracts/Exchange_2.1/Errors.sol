// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

// Define error
error InsufficientETH();

error OrderExpired();

error SystemSignatureExpired();

error IncorrectBuyAmount();

error IncorrectTotalPayment();

error IncorrectSystemSignature();

error IncorrectOrderSignature();

error IncorrectSignatureLength();

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
