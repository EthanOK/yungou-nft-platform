// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

interface IYGME {
    function balanceOf(address owner) external view returns (uint256 balance);
}

interface IYgmeStaking {
    function getStakingTokenIds(
        address account
    ) external view returns (uint256[] memory);
}

interface IYGIO {
    function balanceOf(address account) external view returns (uint256);

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
}

contract YgioConvert is Pausable, Ownable, ReentrancyGuard {
    using ECDSA for bytes32;

    event Convert(
        uint256 indexed convertType,
        address indexed account,
        uint256 indexed amount,
        uint256 blockTime
    );

    struct ConvertData {
        uint256 nextTime;
        uint256 totalAmount;
    }

    address public constant BURN_ADDRESS = address(1);

    IYGME public immutable ygme;

    IYgmeStaking public immutable ygmeStaking;

    IYGIO public immutable ygio;

    address private systemSigner;

    // All Account Convert YGIO Total Amount
    uint256 private totalConvert;

    // The Account Convert YGIO Total Amount
    mapping(address => uint256) private totalConvertOfAccount;

    // YGIO Total Amount In ConvertType
    mapping(uint256 => uint256) private totalConvertOfType;

    // account => convertType => ConvertData
    mapping(address => mapping(uint256 => ConvertData)) private convertDatas;

    constructor(
        address _ygme,
        address _ygmeStaking,
        address _ygio,
        address _signer
    ) {
        ygme = IYGME(_ygme);

        ygmeStaking = IYgmeStaking(_ygmeStaking);

        ygio = IYGIO(_ygio);

        systemSigner = _signer;
    }

    function setPause() external onlyOwner {
        if (!paused()) {
            _pause();
        } else {
            _unpause();
        }
    }

    function setSystemSigner(address _signer) external onlyOwner {
        systemSigner = _signer;
    }

    function getConvertData(
        address account,
        uint256 convertType
    ) external view returns (ConvertData memory) {
        return convertDatas[account][convertType];
    }

    function getTotalConvert() external view returns (uint256) {
        return totalConvert;
    }

    function getTotalConvertOfAccount(
        address account
    ) external view returns (uint256) {
        return totalConvertOfAccount[account];
    }

    function getTotalConvertOfType(
        uint256 convertType
    ) external view returns (uint256) {
        return totalConvertOfType[convertType];
    }

    function convert(
        uint256 _convertType,
        uint256 _amount,
        uint256 _nextTime,
        bytes calldata _signature
    ) external whenNotPaused nonReentrant returns (bool) {
        address _account = _msgSender();

        require(
            block.timestamp >= convertDatas[_account][_convertType].nextTime &&
                block.timestamp < _nextTime,
            "Time Limit"
        );

        require(ygio.balanceOf(_account) >= _amount, "Insufficient YGIO");

        require(
            ygme.balanceOf(_account) > 0 ||
                ygmeStaking.getStakingTokenIds(_account).length > 0,
            "Insufficient YGME"
        );

        bytes memory _data = abi.encode(
            address(this),
            _convertType,
            _account,
            _amount,
            _nextTime
        );

        bytes32 _hash = keccak256(_data);

        _verifySignature(_hash, _signature);

        _updataData(_convertType, _account, _amount, _nextTime);

        ygio.transferFrom(_account, BURN_ADDRESS, _amount);

        emit Convert(_convertType, _account, _amount, block.timestamp);

        return true;
    }

    function _updataData(
        uint256 _convertType,
        address _account,
        uint256 _amount,
        uint256 _nextTime
    ) internal {
        unchecked {
            convertDatas[_account][_convertType].totalAmount += _amount;

            convertDatas[_account][_convertType].nextTime = _nextTime;

            totalConvertOfAccount[_account] += _amount;

            totalConvertOfType[_convertType] += _amount;

            totalConvert += _amount;
        }
    }

    function _verifySignature(
        bytes32 _hash,
        bytes calldata _signature
    ) internal view {
        _hash = _hash.toEthSignedMessageHash();

        address signer = _hash.recover(_signature);

        require(systemSigner == signer, "Invalid signature");
    }
}
