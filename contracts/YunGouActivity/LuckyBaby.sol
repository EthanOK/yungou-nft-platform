// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";

contract LuckyBaby is AccessControl, Pausable, ReentrancyGuard, ERC721Holder {
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
        uint64 numberWinner;
        address token;
        uint256[] amounts;
        uint256[] tokenIds;
    }

    struct IssueData {
        uint64 numberCurrent;
        uint64 numberMax;
        uint64 countMaxPer;
        uint32 startTime;
        uint32 endTime;
        bool openState;
        PayToken payToken;
        Prize prize;
    }

    struct IssueAccount {
        address[] participants;
        address[] winners;
    }

    struct AccountState {
        uint64 countPart;
        uint64 index;
        bool stateWinner;
        bool stateRedeem;
    }

    event Participate(
        address indexed account,
        uint256 indexed issueId,
        uint256 count,
        uint256 timeParticipate
    );

    event RedeemPrize(
        address indexed account,
        uint256 indexed issueId,
        PrizeType prizeType,
        address token,
        uint256 amount,
        uint256[] tokenIds,
        uint256 timeRedeem
    );

    // issueId => issueData
    mapping(uint256 => IssueData) public issueDatas;

    // issueId => issueAccount
    mapping(uint256 => IssueAccount) private issueAccounts;

    // account => issueId => AccountState
    mapping(address => mapping(uint256 => AccountState)) public accountStates;

    // account => issueId => winnerState

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

        require(prize.numberWinner > 0, "Invalid Number Winner");

        if (prize.prizeType == PrizeType.ERC721) {
            require(prize.tokenIds.length > 0, "Invalid Prize Data");
        } else {
            require(prize.amounts.length > 0, "Invalid Prize amounts");
        }

        IssueData storage _issueData = issueDatas[issueId];
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

        require(prize.numberWinner > 0, "Invalid Number Winner");

        if (prize.prizeType == PrizeType.ERC721) {
            require(prize.tokenIds.length > 0, "Invalid Prize Data");
        } else {
            require(prize.amounts.length > 0, "Invalid Prize amounts");
        }

        IssueData storage _issueData = issueDatas[_issueId];
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
            accountStates[_account][_issueId].countPart;

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

        IssueData storage _issueData = issueDatas[_issueId];

        require(!_issueData.openState, "The Issue Already Awarded");

        require(
            block.timestamp > _issueData.startTime &&
                block.timestamp < _issueData.endTime,
            "Invalid Participate Time"
        );

        unchecked {
            uint256 count_current = accountStates[account][_issueId].countPart +
                count;

            require(
                count > 0 && count_current <= _issueData.countMaxPer,
                "Exceeding the Maximum Count Participation Per"
            );

            accountStates[account][_issueId].countPart = uint64(count_current);

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

    function redeemPrize(
        uint256 _issueId
    ) external whenNotPaused nonReentrant returns (bool) {
        address account = _msgSender();

        require(accountStates[account][_issueId].stateWinner, "Not A Winner");

        require(
            !accountStates[account][_issueId].stateRedeem,
            "Already Redeem"
        );

        accountStates[account][_issueId].stateRedeem = true;

        _distribute(account, _issueId);

        return true;
    }

    function _distribute(address account, uint256 _issueId) private {
        uint256 index = accountStates[account][_issueId].index;

        Prize memory prize = issueDatas[_issueId].prize;

        require(index < prize.amounts.length, "Invalid Index");

        uint256 amount = prize.amounts[index];

        if (prize.prizeType == PrizeType.NATIVE) {
            uint256[] memory _tokenIds;
            payable(account).transfer(amount);

            emit RedeemPrize(
                account,
                _issueId,
                prize.prizeType,
                prize.token,
                amount,
                _tokenIds,
                block.timestamp
            );
        } else if (prize.prizeType == PrizeType.ERC20) {
            uint256[] memory _tokenIds;
            _transferLowCall(prize.token, account, amount);

            emit RedeemPrize(
                account,
                _issueId,
                prize.prizeType,
                prize.token,
                amount,
                _tokenIds,
                block.timestamp
            );
        } else if (prize.prizeType == PrizeType.ERC721) {
            uint256[] memory _tokenIds = _getTokenIds(
                index,
                prize.amounts,
                prize.tokenIds
            );

            _batchTransferFrom(prize.token, account, _tokenIds);

            emit RedeemPrize(
                account,
                _issueId,
                prize.prizeType,
                prize.token,
                amount,
                _tokenIds,
                block.timestamp
            );
        }
    }

    function _getTokenIds(
        uint256 index,
        uint256[] memory amounts,
        uint256[] memory tokenIds
    ) private pure returns (uint256[] memory) {
        uint256 length = amounts[index];
        uint256[] memory _tokenIds = new uint256[](length);

        uint256 start = 0;

        if (index > 0) {
            for (uint256 j = 0; j < index; ++j) {
                start += amounts[j];
            }
        }

        for (uint256 j = 0; j < amounts[index]; ++j) {
            _tokenIds[j] = tokenIds[j + start];
        }

        return _tokenIds;
    }

    function _batchTransferFrom(
        address token,
        address account,
        uint256[] memory _tokenIds
    ) private {
        for (uint256 i = 0; i < _tokenIds.length; ++i) {
            IERC721(token).transferFrom(address(this), account, _tokenIds[i]);
        }
    }

    function openPrizePool(
        uint256 _issueId
    ) external onlyRole(OPERATOR_ROLE) returns (bool) {
        IssueData storage _issueData = issueDatas[_issueId];

        require(
            block.timestamp > _issueData.endTime,
            "Not Yet Time for Opening"
        );
        require(!_issueData.openState, "The Issue Already Opened");

        _issueData.openState = true;

        // Distribute Prizes
        uint256 numberWinner = _issueData.prize.numberWinner;
        address[] memory _participants = issueAccounts[_issueId].participants;
        uint256 numberParticipant = _participants.length;
        uint256 _number;
        uint256 i;
        unchecked {
            while (_number < numberWinner) {
                uint256 _random = _getRadom(
                    i,
                    _seed(_issueId),
                    numberParticipant
                );
                address accountRadom = _participants[_random];

                if (!accountStates[accountRadom][_issueId].stateWinner) {
                    accountStates[accountRadom][_issueId].stateWinner = true;

                    issueAccounts[_issueId].winners.push(accountRadom);

                    accountStates[accountRadom][_issueId].index = uint64(
                        _number
                    );

                    ++_number;
                }
                ++i;
            }
        }

        return true;
    }

    function _getRadom(
        uint256 index,
        bytes32 seed_,
        uint256 _modulus
    ) private view returns (uint256) {
        // TODO:random
        uint256 rand = uint256(
            keccak256(
                abi.encodePacked(
                    index,
                    seed_,
                    block.timestamp,
                    block.prevrandao,
                    block.coinbase
                )
            )
        );
        return rand % _modulus;
    }

    function _seed(uint256 _issueId) private view returns (bytes32) {
        return
            keccak256(abi.encodePacked(issueAccounts[_issueId].participants));
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

    function _transferLowCall(
        address target,
        address to,
        uint256 value
    ) internal {
        (bool success, bytes memory data) = target.call(
            abi.encodeWithSelector(ERC20_TRANSFER_SELECTOR, to, value)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "Low-level call failed"
        );
    }

    receive() external payable {}
}
