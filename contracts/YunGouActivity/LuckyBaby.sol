// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";

contract LuckyBaby is AccessControl, Pausable, ReentrancyGuard {
    bytes32 public constant OWNER_ROLE = keccak256("OWNER_ROLE");
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    // bytes4(keccak256("transfer(address,uint256)"))
    bytes4 constant ERC20_TRANSFER_SELECTOR = 0xa9059cbb;

    // bytes4(keccak256("transferFrom(address,address,uint256)"))
    bytes4 constant ERC20_TRANSFERFROM_SELECTOR = 0x23b872dd;

    using Counters for Counters.Counter;
    Counters.Counter public currentIssueId;
    enum PayType {
        NATIVE,
        ERC20
    }
    enum PrizeType {
        NATIVE,
        ERC20,
        ERC721
    }

    struct PayToken {
        PayType payType;
        address token;
        uint256 amount;
    }

    struct Prize {
        PrizeType prizeType;
        address token;
        uint256 amount;
        uint256[] tokenIds;
    }

    struct issueData {
        uint64 numberCurrent;
        uint64 numberMax;
        uint64 countMaxPer;
        uint32 startTime;
        uint32 endTime;
        bool openState;
        PayToken payToken;
        Prize prize;
    }

    struct issueAccount {
        address[] participants;
        address[] winners;
    }

    event Participate(
        address indexed account,
        uint256 indexed issueId,
        uint256 count,
        uint256 time
    );

    // issueId => issueData
    mapping(uint256 => issueData) public issueDatas;

    // issueId => issueAccount
    mapping(uint256 => issueAccount) private issueAccounts;

    // account => issueId => count
    mapping(address => mapping(uint256 => uint256)) public participationCount;

    constructor(address owner, address operator) {
        _setupRole(DEFAULT_ADMIN_ROLE, tx.origin);

        _setupRole(OWNER_ROLE, owner);

        _setupRole(OPERATOR_ROLE, operator);
    }

    function updataIssueData(
        uint256 issueId,
        uint64 numberMax,
        uint64 countMaxPer,
        uint32 startTime,
        uint32 endTime,
        PayToken calldata payToken,
        Prize calldata prize
    ) external onlyRole(OWNER_ROLE) {
        require(
            issueId > 0 && issueId <= currentIssueId.current(),
            "Invalid  IssueId"
        );
        require(startTime < endTime, "Invalid Time");

        issueData storage _issueData = issueDatas[issueId];
        _issueData.numberMax = numberMax;
        _issueData.countMaxPer = countMaxPer;
        _issueData.startTime = startTime;
        _issueData.endTime = endTime;
        _issueData.payToken = payToken;
        _issueData.prize = prize;
    }

    function incrementNewIssue(
        uint64 numberMax,
        uint64 countMaxPer,
        uint32 startTime,
        uint32 endTime,
        PayToken calldata payToken,
        Prize calldata prize
    ) external onlyRole(OWNER_ROLE) {
        currentIssueId.increment();
        uint256 _issueId = currentIssueId.current();

        require(startTime < endTime, "Invalid Time");

        if (prize.prizeType == PrizeType.ERC721) {
            require(prize.tokenIds.length > 0, "Invalid Prize Data");
        } else {
            require(prize.amount > 0, "Invalid Prize Amount");
        }

        issueData storage _issueData = issueDatas[_issueId];
        _issueData.numberMax = numberMax;
        _issueData.countMaxPer = countMaxPer;
        _issueData.startTime = startTime;
        _issueData.endTime = endTime;
        _issueData.payToken = payToken;
        _issueData.prize = prize;
    }

    function setPause() external onlyRole(OWNER_ROLE) {
        if (!paused()) {
            _pause();
        } else {
            _unpause();
        }
    }

    function getNumberParticipants(
        uint256 _issueId
    ) external view returns (uint256) {
        require(
            _issueId > 0 && _issueId <= currentIssueId.current(),
            "Invalid  IssueId"
        );
        return issueDatas[_issueId].numberCurrent;
    }

    function getNumberRemain(uint256 _issueId) external view returns (uint256) {
        require(
            _issueId > 0 && _issueId <= currentIssueId.current(),
            "Invalid  IssueId"
        );
        return
            issueDatas[_issueId].numberMax - issueDatas[_issueId].numberCurrent;
    }

    function getCountRemainOfAccount(
        address _account,
        uint256 _issueId
    ) external view returns (uint256) {
        require(
            _issueId > 0 && _issueId <= currentIssueId.current(),
            "Invalid  IssueId"
        );
        uint256 _count = issueDatas[_issueId].countMaxPer -
            participationCount[_account][_issueId];

        return _count;
    }

    function getParticipants(
        uint256 _issueId
    ) external view returns (address[] memory) {
        require(
            _issueId > 0 && _issueId <= currentIssueId.current(),
            "Invalid  IssueId"
        );
        return issueAccounts[_issueId].participants;
    }

    function getWinners(
        uint256 _issueId
    ) external view returns (address[] memory) {
        require(
            _issueId > 0 && _issueId <= currentIssueId.current(),
            "Invalid  IssueId"
        );
        return issueAccounts[_issueId].winners;
    }

    function participate(
        uint256 _issueId,
        uint256 count
    ) external payable whenNotPaused nonReentrant returns (bool) {
        address account = _msgSender();
        uint256 ethAmount = msg.value;

        require(
            _issueId > 0 && _issueId <= currentIssueId.current(),
            "Invalid  IssueId"
        );

        issueData storage _issueData = issueDatas[_issueId];

        require(!_issueData.openState, "The Issue Already Awarded");

        require(
            block.timestamp > _issueData.startTime &&
                block.timestamp < _issueData.endTime,
            "Invalid Participate Time"
        );

        unchecked {
            uint256 count_current = participationCount[account][_issueId] +
                count;

            require(
                count > 0 && count_current <= _issueData.countMaxPer,
                "Exceeding the Maximum Count Participation Per"
            );

            participationCount[account][_issueId] = count_current;

            uint256 _numberCurrent = _issueData.numberCurrent + count;

            require(
                _numberCurrent <= _issueData.numberMax,
                "Exceeding the Maximum Participation Limit"
            );

            _issueData.numberCurrent = uint64(_numberCurrent);

            for (uint256 i = 0; i < count; ++i) {
                issueAccounts[_issueId].participants.push(account);
            }
        }

        _userPayToken(account, _issueData.payToken, count, ethAmount);

        emit Participate(account, _issueId, count, block.timestamp);

        return true;
    }

    function _getRadom(uint256 salt) private view returns (uint256 _random) {
        // TODO:random
        return (block.timestamp % 50) + (salt % 50);
    }

    function _userPayToken(
        address userAccount,
        PayToken memory payToken,
        uint256 count,
        uint256 ethAmount
    ) private {
        uint256 amountPay = count * payToken.amount;

        if (payToken.payType == PayType.NATIVE) {
            require(ethAmount >= amountPay, "Insufficient Payment");

            unchecked {
                uint256 remainAmount = ethAmount - amountPay;
                if (remainAmount > 0) {
                    payable(userAccount).transfer(remainAmount);
                }
            }
        } else if (payToken.payType == PayType.ERC20) {
            _transferFromLowCall(
                payToken.token,
                userAccount,
                address(this),
                amountPay
            );
        }
    }

    function _transferFromLowCall(
        address target,
        address from,
        address to,
        uint256 value
    ) private {
        (bool success, bytes memory data) = target.call(
            abi.encodeWithSelector(ERC20_TRANSFERFROM_SELECTOR, from, to, value)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "Low-level call failed"
        );
    }

    receive() external payable {}
}
