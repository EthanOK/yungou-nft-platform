// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract OneCoinRaffle is AccessControl, Pausable, ReentrancyGuard {
    bytes32 public constant OWNER_ROLE = keccak256("OWNER_ROLE");
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    using Counters for Counters.Counter;
    Counters.Counter public currentIssueId;

    struct PayToken {
        address token;
        uint256 amount;
    }

    struct issueData {
        uint64 numberCurrent;
        uint64 numberMax;
        uint64 countMaxPer;
        uint32 startTime;
        uint32 endTime;
        bool openState;
        PayToken payToken;
    }

    struct issueAccount {
        address[] participants;
        address[] winners;
    }

    // issueId => issueData
    mapping(uint256 => issueData) private issueDatas;

    // issueId => issueAccount
    mapping(uint256 => issueAccount) private issueAccounts;

    // account => issueId => count
    mapping(address => mapping(uint256 => uint256)) private participationCount;

    constructor(address owner, address operator) {
        _setupRole(DEFAULT_ADMIN_ROLE, tx.origin);

        _setupRole(OWNER_ROLE, owner);

        _setupRole(OPERATOR_ROLE, operator);
    }

    function setIssueData(
        uint256 issueId,
        uint64 numberMax,
        uint64 countMaxPer,
        uint32 startTime,
        uint32 endTime,
        address token,
        uint256 amount
    ) external onlyRole(OWNER_ROLE) {
        issueData storage _issueData = issueDatas[issueId];
        _issueData.numberMax = numberMax;
        _issueData.countMaxPer = countMaxPer;
        _issueData.startTime = startTime;
        _issueData.endTime = endTime;
        _issueData.payToken = PayToken(token, amount);
    }

    function addNewIssueData(
        uint64 numberMax,
        uint64 countMaxPer,
        uint32 startTime,
        uint32 endTime,
        address token,
        uint256 amount
    ) external onlyRole(OWNER_ROLE) {
        currentIssueId.increment();
        uint256 _issueId = currentIssueId.current();

        issueData storage _issueData = issueDatas[_issueId];
        _issueData.numberMax = numberMax;
        _issueData.countMaxPer = countMaxPer;
        _issueData.startTime = startTime;
        _issueData.endTime = endTime;
        _issueData.payToken = PayToken(token, amount);
    }

    function participate(
        uint256 _issueId,
        uint256 count
    ) external returns (bool) {
        address account = _msgSender();

        issueData storage _issueData = issueDatas[_issueId];

        require(
            block.timestamp > _issueData.startTime &&
                block.timestamp < _issueData.endTime,
            "Invalid Participate Time"
        );

        uint256 count_p = participationCount[account][_issueId];

        unchecked {
            uint256 count_current = count_p + count;

            require(
                count > 0 && count_current <= _issueData.countMaxPer,
                "Invalid Count"
            );

            participationCount[account][_issueId] = count_current;
        }

        {
            uint256 amountPay = count * _issueData.payToken.amount;
            address token = _issueData.payToken.token;
            _userPayToken(token, account, amountPay);
        }

        for (uint256 i = 0; i < count; ++i) {
            issueAccounts[_issueId].participants.push(account);
        }

        return true;
    }

    function _getRadom(uint256 salt) private view returns (uint256 _random) {
        // TODO:random
        return (block.timestamp % 50) + (salt % 50);
    }

    function _userPayToken(
        address token,
        address from,
        uint256 amount
    ) private {
        IERC20(token).transferFrom(from, address(this), amount);
    }
}
