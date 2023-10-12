// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract CrossChainLockYGIOInETH is Ownable, Pausable, ReentrancyGuard {
    using ECDSA for bytes32;

    event ConvertYGIO(
        address indexed account,
        uint256 amount,
        uint256 convertId,
        uint256 blockNumber
    );

    event LockYGIO(
        uint256 lockId,
        address indexed account,
        uint256 amount,
        uint256 blockNumber
    );

    address signer;

    address YGIO;

    // convertId => bool
    mapping(uint256 => bool) convertStates;

    uint256 private totalLockYGIO;

    uint256 private totalConvertYGIO;

    uint256 public lockId;

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

    function getTotalConvertYGIO() external view returns (uint256) {
        return totalConvertYGIO;
    }

    function getTotalLockYGIO() external view returns (uint256) {
        return totalLockYGIO;
    }

    // Must approve
    function lockYGIO(
        uint256 _amount,
        uint256 _deadline,
        bytes calldata _signature
    ) external whenNotPaused nonReentrant returns (bool) {
        address _account = _msgSender();

        require(block.timestamp < _deadline, "Signature expired");

        bytes memory _data = abi.encode(YGIO, _account, _amount, _deadline);

        bytes32 _hash = keccak256(_data);

        _verifySignature(_hash, _signature);

        totalLockYGIO += _amount;

        ++lockId;

        // transfer (account --> Contract)
        IERC20(YGIO).transferFrom(_account, address(this), _amount);

        emit LockYGIO(lockId, _account, _amount, block.number);

        return true;
    }

    function convertYGIO(
        uint256 _convertId,
        address _account,
        uint256 _amount,
        uint256 _deadline,
        bytes calldata _signature
    ) external whenNotPaused nonReentrant returns (bool) {
        // address _account = _msgSender();

        require(block.timestamp < _deadline, "Signature expired");

        require(!convertStates[_convertId], "Invalid convertId");

        bytes memory _data = abi.encode(
            _convertId,
            YGIO,
            _account,
            _amount,
            _deadline
        );

        bytes32 _hash = keccak256(_data);

        _verifySignature(_hash, _signature);

        convertStates[_convertId] = true;

        totalConvertYGIO += _amount;

        // transfer (Contract --> account)
        IERC20(YGIO).transfer(_account, _amount);

        emit ConvertYGIO(_account, _amount, _convertId, block.number);

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
