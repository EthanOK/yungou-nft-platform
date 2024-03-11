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

    function transfer(address to, uint256 amount) external returns (bool);
}

contract YGIOConvertV2 is Pausable, Ownable, ReentrancyGuard {
    using ECDSA for bytes32;

    enum PayType {
        LYGIO,
        YGIO
    }

    event Convert(
        uint256 indexed convertType,
        address indexed account,
        uint256 indexed amount,
        uint256 orderId
    );

    struct ClearData {
        address account;
        uint256 convertType;
    }

    IYGME public immutable ygme;

    IYgmeStaking public immutable ygmeStaking;

    IYGIO public immutable ygio;

    bool public switchNextTime;

    address public BURN_ADDRESS = address(1);

    address private systemSigner;

    uint256 private totalConvert;

    mapping(uint256 => bool) private orderIsInvalid;

    // account => convertType => nextTime
    mapping(address => mapping(uint256 => uint256)) private nextTime;

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

    function setSwitchNextTime() external onlyOwner {
        switchNextTime = !switchNextTime;
    }

    function setBurnAddress(address burn) external onlyOwner {
        BURN_ADDRESS = burn;
    }

    function clearNextTime(ClearData[] calldata clearDatas) external onlyOwner {
        for (uint256 i = 0; i < clearDatas.length; ) {
            delete nextTime[clearDatas[i].account][clearDatas[i].convertType];
            unchecked {
                ++i;
            }
        }
    }

    function setSystemSigner(address _signer) external onlyOwner {
        systemSigner = _signer;
    }

    function getTotalConvert() external view returns (uint256) {
        return totalConvert;
    }

    function getOrderIdState(uint256 orderId) external view returns (bool) {
        return orderIsInvalid[orderId];
    }

    function getYGMEAmount(address account) external view returns (uint256) {
        return _getYGMEAmount(account);
    }

    function execute(
        address to,
        uint256 value,
        bytes calldata data
    ) external onlyOwner returns (bool success) {
        (success, ) = to.call{value: value}(data);

        require(success, "execute Failure");
    }

    function convert(
        uint256 _orderId,
        PayType _payType,
        uint256 _convertType,
        uint256 _amount,
        uint256 _endTime,
        uint256 _nextTime,
        bytes calldata _signature
    ) external whenNotPaused nonReentrant returns (bool) {
        address _account = _msgSender();

        require(_getYGMEAmount(_account) > 0, "Insufficient YGME");

        require(!orderIsInvalid[_orderId], "Invalid orderId");

        if (_payType == PayType.LYGIO) {
            require(block.timestamp < _endTime, "Signature expired");
        }

        if (!switchNextTime) {
            require(
                block.timestamp >= nextTime[_account][_convertType],
                "Invalid nextTime"
            );
        }

        bytes memory _data = abi.encode(
            address(this),
            _orderId,
            _payType,
            _convertType,
            _account,
            _amount,
            _endTime,
            _nextTime
        );

        bytes32 _hash = keccak256(_data);

        _verifySignature(_hash, _signature);

        _updataData(_orderId, _convertType, _account, _amount, _nextTime);

        _excuteBurn(_payType, _account, _amount);

        emit Convert(_convertType, _account, _amount, _orderId);

        return true;
    }

    function _updataData(
        uint256 _orderId,
        uint256 _convertType,
        address _account,
        uint256 _amount,
        uint256 _nextTime
    ) internal {
        unchecked {
            nextTime[_account][_convertType] = _nextTime;

            totalConvert += _amount;

            orderIsInvalid[_orderId] = true;
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

    function _getYGMEAmount(address account) internal view returns (uint256) {
        return
            ygme.balanceOf(account) +
            ygmeStaking.getStakingTokenIds(account).length;
    }

    function _excuteBurn(
        PayType _payType,
        address _account,
        uint256 _amount
    ) internal {
        if (_payType == PayType.LYGIO) {
            ygio.transfer(BURN_ADDRESS, _amount);
        } else {
            ygio.transferFrom(_account, BURN_ADDRESS, _amount);
        }
    }

    receive() external payable {}
}
