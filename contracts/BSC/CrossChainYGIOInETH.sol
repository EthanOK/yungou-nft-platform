// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract CrossChainYGIOInETH is Ownable, Pausable, ReentrancyGuard {
    using ECDSA for bytes32;

    enum CCTYPE {
        NULL,
        MINT,
        BURN
    }

    event MintYGIO(
        uint256 orderId,
        address indexed account,
        uint256 amount,
        uint256 blockNumber
    );

    event BurnYGIO(
        uint256 orderId,
        address indexed account,
        uint256 amount,
        uint256 blockNumber
    );

    address signer;

    address YGIO;

    // orderId => bool
    mapping(uint256 => bool) private orderStates;

    uint256 private totalBurnYGIO;

    uint256 private totalMintYGIO;

    constructor(address _ygio, address _signer) {
        YGIO = _ygio;
        signer = _signer;
    }

    function setPause() external onlyOwner {
        if (!paused()) {
            _pause();
        } else {
            _unpause();
        }
    }

    function setSigner(address _signer) external onlyOwner {
        signer = _signer;
    }

    function getTotalMintYGIO() external view returns (uint256) {
        return totalMintYGIO;
    }

    function getTotalBurnYGIO() external view returns (uint256) {
        return totalBurnYGIO;
    }

    function getOrderState(uint256 _orderId) external view returns (bool) {
        return orderStates[_orderId];
    }

    // It’s not really burn, It just locks the token in the contract.
    function burnYGIO(
        uint256 _orderId,
        uint256 _amount,
        uint256 _deadline,
        bytes calldata _signature
    ) external whenNotPaused nonReentrant returns (bool) {
        address _account = _msgSender();

        require(!orderStates[_orderId], "Invalid _orderId");

        require(block.timestamp < _deadline, "Signature expired");

        bytes memory _data = abi.encode(
            address(this),
            CCTYPE.BURN,
            _orderId,
            _account,
            _amount,
            _deadline
        );

        bytes32 _hash = keccak256(_data);

        _verifySignature(_hash, _signature);

        totalBurnYGIO += _amount;

        orderStates[_orderId] = true;

        // transfer (account --> Contract)
        IERC20(YGIO).transferFrom(_account, address(this), _amount);

        emit BurnYGIO(_orderId, _account, _amount, block.number);

        return true;
    }

    // It's not a real mint, it just unlocks the tokens in the contract.
    function mintYGIO(
        uint256 _orderId,
        address _account,
        uint256 _amount,
        uint256 _deadline,
        bytes calldata _signature
    ) external whenNotPaused nonReentrant returns (bool) {
        // address _account = _msgSender();

        require(block.timestamp < _deadline, "Signature expired");

        require(!orderStates[_orderId], "Invalid convertId");

        bytes memory _data = abi.encode(
            address(this),
            CCTYPE.MINT,
            _orderId,
            _account,
            _amount,
            _deadline
        );

        bytes32 _hash = keccak256(_data);

        _verifySignature(_hash, _signature);

        totalMintYGIO += _amount;

        orderStates[_orderId] = true;

        // transfer (Contract --> account)
        IERC20(YGIO).transfer(_account, _amount);

        emit MintYGIO(_orderId, _account, _amount, block.number);

        return true;
    }

    function _verifySignature(
        bytes32 _hash,
        bytes calldata _signature
    ) internal view {
        _hash = _hash.toEthSignedMessageHash();

        address _signer = _hash.recover(_signature);

        require(signer == _signer, "Invalid signature");
    }
}
