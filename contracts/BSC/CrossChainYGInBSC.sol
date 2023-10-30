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

interface IYGME {
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    function swap(address to, address _recommender, uint256 mintNum) external;
}

contract CrossChainYGInBSC is Ownable, Pausable, ReentrancyGuard {
    using ECDSA for bytes32;

    enum CCTYPE {
        NULL,
        SEND,
        CLAIM
    }

    event ClaimYGIO(
        uint256 orderId,
        address indexed account,
        uint256 amount,
        uint256 blockNumber
    );

    event SendYGIO(
        uint256 orderId,
        address indexed account,
        uint256 amount,
        uint256 blockNumber
    );

    event SendYGME(
        uint256 orderId,
        address indexed account,
        uint256 amount,
        uint256[] tokenIds,
        uint256 blockNumber
    );

    event ClaimYGME(
        uint256 orderId,
        address indexed account,
        uint256 amount,
        uint256 blockNumber
    );

    address private signer;

    address public YGIO;

    address public YGME;

    uint256 private totalSendYGIO;

    uint256 private totalClaimYGIO;

    uint256 private totalSendYGME;

    uint256 private totalClaimYGME;

    // mint - burn in BSC
    uint256 private liquidityYGIO;

    uint256[] private lockedYGME;

    // orderId => bool
    mapping(uint256 => bool) private orderStates;

    constructor(address _ygio, address _ygme, address _signer) {
        YGIO = _ygio;

        YGME = _ygme;

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

    function getTotalClaimYGIO() external view returns (uint256) {
        return totalClaimYGIO;
    }

    function getTotalSendYGIO() external view returns (uint256) {
        return totalSendYGIO;
    }

    function getOrderState(uint256 _orderId) external view returns (bool) {
        return orderStates[_orderId];
    }

    function getLockedYGMEAmount() external view returns (uint256) {
        return lockedYGME.length;
    }

    function getLockedYGMELists() external view returns (uint256[] memory) {
        return lockedYGME;
    }

    function getLiquidityYGIOAmount() external view returns (uint256) {
        return liquidityYGIO;
    }

    // Claim YGIO
    function claimYGIO(
        uint256 _orderId,
        uint256 _amount,
        uint256 _deadline,
        bytes calldata _signature
    ) external whenNotPaused nonReentrant returns (bool) {
        address _account = _msgSender();

        require(block.timestamp < _deadline, "Signature expired");

        require(!orderStates[_orderId], "Invalid orderId");

        bytes memory _data = abi.encode(
            address(this),
            CCTYPE.CLAIM,
            YGIO,
            _orderId,
            _account,
            _amount,
            _deadline
        );

        bytes32 _hash = keccak256(_data);

        _verifySignature(_hash, _signature);

        totalClaimYGIO += _amount;

        liquidityYGIO += _amount;

        orderStates[_orderId] = true;

        // mint YGIO
        IYGIO(YGIO).mint(_account, _amount);

        emit ClaimYGIO(_orderId, _account, _amount, block.number);

        return true;
    }

    // Send YGIO
    function sendYGIO(
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
            CCTYPE.SEND,
            YGIO,
            _orderId,
            _account,
            _amount,
            _deadline
        );

        bytes32 _hash = keccak256(_data);

        _verifySignature(_hash, _signature);

        totalSendYGIO += _amount;

        liquidityYGIO -= _amount;

        orderStates[_orderId] = true;

        // burn YGIO
        IYGIO(YGIO).burnFrom(_account, _amount);

        emit SendYGIO(_orderId, _account, _amount, block.number);

        return true;
    }

    function sendYGME(
        uint256 _orderId,
        uint256[] calldata _tokenIds,
        uint256 _deadline,
        bytes calldata _signature
    ) external whenNotPaused nonReentrant returns (bool) {
        address _account = _msgSender();

        require(!orderStates[_orderId], "Invalid orderId");

        require(block.timestamp < _deadline, "Signature expired");

        uint256 _amount = _tokenIds.length;

        bytes memory _data = abi.encode(
            address(this),
            CCTYPE.SEND,
            YGME,
            _orderId,
            _account,
            _amount,
            _deadline
        );

        bytes32 _hash = keccak256(_data);

        _verifySignature(_hash, _signature);

        totalSendYGME += _amount;

        orderStates[_orderId] = true;

        for (uint256 i = 0; i < _amount; ++i) {
            uint256 _tokenId = _tokenIds[i];

            if (lockedYGME.length == 0) {
                lockedYGME = [_tokenId];
            } else {
                lockedYGME.push(_tokenId);
            }

            IYGME(YGME).safeTransferFrom(_account, address(this), _tokenId);
        }

        emit SendYGME(_orderId, _account, _amount, _tokenIds, block.number);

        return true;
    }

    function claimYGME(
        uint256 _orderId,
        uint256 _amount,
        uint256 _deadline,
        bytes calldata _signature
    ) external whenNotPaused nonReentrant returns (bool) {
        address _account = _msgSender();

        require(block.timestamp < _deadline, "Signature expired");

        require(!orderStates[_orderId], "Invalid orderId");

        bytes memory _data = abi.encode(
            address(this),
            CCTYPE.CLAIM,
            YGME,
            _orderId,
            _account,
            _amount,
            _deadline
        );

        bytes32 _hash = keccak256(_data);

        _verifySignature(_hash, _signature);

        totalClaimYGME += _amount;

        orderStates[_orderId] = true;

        if (_amount > lockedYGME.length) {
            // TODO:_recommender
            IYGME(YGME).swap(_account, address(this), _amount);
        } else {
            for (uint256 i = 0; i < _amount; ++i) {
                uint256 _tokenId = lockedYGME[lockedYGME.length - 1];

                lockedYGME.pop();

                IYGME(YGME).safeTransferFrom(address(this), _account, _tokenId);
            }
        }

        emit ClaimYGME(_orderId, _account, _amount, block.number);

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
