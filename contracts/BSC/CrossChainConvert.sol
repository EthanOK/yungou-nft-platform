// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

interface IYGIO {
    function mint(address to, uint256 amount) external;

    function burnFrom(address account, uint256 value) external;
}

contract CrossChainConvertYGIO is Ownable, Pausable, ReentrancyGuard {
    bytes4 public constant ERC20_TRANSFER_SELECTOR = 0xa9059cbb;

    using ECDSA for bytes32;

    event ConvertYGIO(
        address indexed account,
        uint256 amount,
        uint256 convertId,
        uint256 blockNumber
    );

    event BurnYGIO(
        address indexed account,
        uint256 amount,
        uint256 blockNumber
    );

    address signer;

    address YGIO;

    // convertId => bool
    mapping(uint256 => bool) convertStates;

    uint256 totalConvertYGIO;

    uint256 totalBurnYGIO;

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

    function getTotalConvertYGIO() external view returns (uint256) {
        return totalConvertYGIO;
    }

    function getTotalBurnYGIO() external view returns (uint256) {
        return totalBurnYGIO;
    }

    function convertYGIO(
        uint256 _convertId,
        uint256 _amount,
        uint256 _deadline,
        bytes calldata _signature
    ) external whenNotPaused nonReentrant returns (bool) {
        address _account = _msgSender();

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

        // mint YGIO
        IYGIO(YGIO).mint(_account, _amount);

        emit ConvertYGIO(_account, _amount, _convertId, block.number);

        return true;
    }

    // Must approve
    function burnYGIO(
        uint256 _amount,
        uint256 _deadline,
        bytes calldata _signature
    ) external whenNotPaused nonReentrant returns (bool) {
        address _account = _msgSender();

        require(block.timestamp < _deadline, "Signature expired");

        bytes memory _data = abi.encode(YGIO, _account, _amount, _deadline);

        bytes32 _hash = keccak256(_data);

        _verifySignature(_hash, _signature);

        totalBurnYGIO += _amount;

        // burn YGIO
        IYGIO(YGIO).burnFrom(_account, _amount);

        emit BurnYGIO(_account, _amount, block.number);

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
