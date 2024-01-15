// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

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
    event Convert(
        address indexed account,
        uint256 indexed amount,
        uint256 indexed convertType,
        uint256 blockTime
    );

    struct ConvertData {
        uint256 nextTime;
        uint256 totalAmount;
    }

    address public constant BURN_ADDRESS = address(1);
    uint256 public constant ONE_DAYS = 1 days;

    IYGME public immutable ygme;

    IYgmeStaking public immutable ygmeStaking;

    IYGIO public immutable ygio;

    uint256 public ONE_CYCLE = 1 days;

    uint256 public minAmount = 5000 * 1e18;

    uint256 public maxAmount = 10000 * 1e18;

    uint256 totalConvert;

    mapping(address => mapping(uint256 => ConvertData)) private convertDatas;

    constructor(address _ygme, address _ygmeStaking, address _ygio) {
        ygme = IYGME(_ygme);

        ygmeStaking = IYgmeStaking(_ygmeStaking);

        ygio = IYGIO(_ygio);
    }

    function setPause() external onlyOwner {
        if (!paused()) {
            _pause();
        } else {
            _unpause();
        }
    }

    function setOneCycle(uint256 _days) external onlyOwner {
        ONE_CYCLE = _days * 1 days;
    }

    function setAmountRange(
        uint256 _minAmount,
        uint256 _maxAmount
    ) external onlyOwner {
        minAmount = _minAmount;
        maxAmount = _maxAmount;
    }

    function getConvertData(
        address account,
        uint256 _convertType
    ) external view returns (ConvertData memory) {
        return convertDatas[account][_convertType];
    }

    function getAmountRange()
        external
        view
        onlyOwner
        returns (uint256, uint256)
    {
        return (minAmount, maxAmount);
    }

    function getTotalConvert() external view returns (uint256) {
        return totalConvert;
    }

    function convert(
        uint256 _amount,
        uint256 _convertType
    ) external whenNotPaused nonReentrant returns (bool) {
        address _account = _msgSender();

        require(
            block.timestamp > convertDatas[_account][_convertType].nextTime,
            "Time Limit"
        );

        require(minAmount <= _amount && _amount <= maxAmount, "Amount Limit");

        require(ygio.balanceOf(_account) >= _amount, "Insufficient YGIO");

        require(
            ygme.balanceOf(_account) > 0 ||
                ygmeStaking.getStakingTokenIds(_account).length > 0,
            "Insufficient YGME"
        );

        _updataConvertData(_account, _amount, _convertType);

        totalConvert += _amount;

        ygio.transferFrom(_account, BURN_ADDRESS, _amount);

        emit Convert(_account, _amount, _convertType, block.timestamp);

        return true;
    }

    function _updataConvertData(
        address _account,
        uint256 _amount,
        uint256 _convertType
    ) internal {
        convertDatas[_account][_convertType].totalAmount += _amount;

        convertDatas[_account][_convertType].nextTime =
            (block.timestamp / ONE_DAYS) *
            ONE_DAYS +
            (ONE_CYCLE - 8 hours);
    }
}
