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

contract CrossChainYGIOInBSC is Ownable, Pausable, ReentrancyGuard {
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

    address private signer;

    address public YGIO;

    // orderId => bool
    mapping(uint256 => bool) private orderStates;

    uint256 private totalMintYGIO;

    uint256 private totalBurnYGIO;

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

    function getSigner() external view onlyOwner returns (address) {
        return signer;
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

    // Mint YGIO
    function mintYGIO(
        uint256 _orderId,
        address _account,
        uint256 _amount,
        uint256 _deadline,
        bytes calldata _signature
    ) external whenNotPaused nonReentrant returns (bool) {
        // address _account = _msgSender();

        require(block.timestamp < _deadline, "Signature expired");

        require(!orderStates[_orderId], "Invalid orderId");

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

        // mint YGIO
        IYGIO(YGIO).mint(_account, _amount);

        emit MintYGIO(_orderId, _account, _amount, block.number);

        return true;
    }

    // Burn YGIO
    function burnYGIO(
        uint256 _orderId,
        uint256 _amount,
        uint256 _deadline,
        bytes calldata _signature
    ) external whenNotPaused nonReentrant returns (bool) {
        address _account = _msgSender();

        require(!orderStates[_orderId], "Invalid orderId");

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

        // burn YGIO
        IYGIO(YGIO).burnFrom(_account, _amount);

        emit BurnYGIO(_orderId, _account, _amount, block.number);

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
