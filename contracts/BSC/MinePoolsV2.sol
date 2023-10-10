// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

// LP interface
interface IPancakePair {
    function decimals() external pure returns (uint8);

    function totalSupply() external view returns (uint);

    function balanceOf(address owner) external view returns (uint);

    function transfer(address to, uint value) external returns (bool);

    function transferFrom(
        address from,
        address to,
        uint value
    ) external returns (bool);
}

// YGIOStakingDomain
abstract contract YGIOStakingDomain {
    enum StakeYGIOType {
        NULL,
        STAKING,
        UNSTAKE,
        UNSTAKEONLYOWNER
    }

    struct StakingYGIOData {
        address owner;
        uint256 amount;
        uint128 startTime;
        uint128 endTime;
    }

    event StakeYGIO(
        uint256 orderId,
        address indexed account,
        uint256 amount,
        uint256 startTime,
        uint256 endTime,
        StakeYGIOType indexed stakeType,
        uint256 indexed blockNumber
    );
}

// YGMEStakingDomain
abstract contract YGMEStakingDomain {
    enum StakeYGMEType {
        NULL,
        STAKING,
        UNSTAKE,
        UNSTAKEONLYOWNER
    }

    struct StakingYGMEData {
        address owner;
        bool stakedState;
        uint128 startTime;
        uint128 endTime;
    }

    event StakingYGME(
        address indexed account,
        uint256 tokenId,
        uint256 startTime,
        uint256 endTime,
        StakeYGMEType indexed stakeType,
        uint256 indexed blockNumber
    );
}

abstract contract MinePoolsDomain {
    enum StakeLPType {
        NULL,
        STAKING_HAS_DEADLINE,
        STAKING_NO_DEADLINE,
        UNSTAKECASH,
        UNSTAKEORDER,
        UNSTAKEONLYOWNER
    }

    struct StakeLPData {
        address owner;
        uint256 poolNumber;
        uint256 amountLP;
        uint128 startTime;
        uint128 endTime;
    }

    struct StakeLPAccount {
        uint256 cashLP;
        uint256[] stakingOrderIds;
        uint256 totalStakingLP;
    }

    event StakeLP(
        uint256 poolNumber,
        address indexed account,
        uint256 amount,
        uint256 startTime,
        uint256 endTime,
        StakeLPType indexed stakeType,
        uint256 stakingOrderId,
        uint256 callCount,
        uint256 indexed blockNumber
    );

    event NewPool(
        uint256 poolNumber,
        address mineOwner,
        uint256 amount,
        uint256 blockNumber
    );
}

contract MinePoolsV2 is MinePoolsDomain, Pausable, Ownable, ReentrancyGuard {
    using Counters for Counters.Counter;
    using ECDSA for bytes32;

    address public constant ZERO_ADDRESS = address(0);
    uint256 public constant REWARDRATE_BASE = 10_000;
    uint256 public constant ONEDAY = 1 days;

    address public immutable LPTOKEN_YGIO_USDT;
    address public immutable YGIO;
    address public immutable YGME;

    Counters.Counter private _currentStakingLPOrderId;

    address private inviteeSigner;

    uint256 private rewardsTotal = 100_000_000 * 1e18;

    // Rewards per Block 10 YGIO
    uint256 private rewardsPerBlock = 10e18;

    uint256 private startBlockNumber;

    uint256 private callCount;

    // total Staking LP Amount(Not included Balance of Pool Mine Owner)
    uint256 private totalStakingLP;

    // total Staking LP days(All user)
    uint256 private totalStakingLPDays;

    // total Staking YGIO days(All user)
    uint256 private totalStakingYGIODays;

    // total Staking YGME days(All user)
    uint256 private totalStakingYGMEDays;

    // User => total staking LP Days
    mapping(address => uint256) stakingLPDaysOfAccount;

    // User => total staking YGIO Days
    mapping(address => uint256) stakingYGIODaysOfAccount;

    // User => total staking YGME Days
    mapping(address => uint256) stakingYGMEDaysOfAccount;

    // pool1 => mineOwner
    mapping(uint256 => address) mineOwners;

    // Conditions for becoming a mine owner
    // pool => amount
    mapping(uint256 => uint256) conditionmMineOwnerPools;

    // mineOwner => lp balance
    mapping(address => uint256) balanceMineOwners;

    // Pool => total stakingLPAmount
    mapping(uint256 => uint256) private stakingLPAmountsOfPool;

    // User => total stakingLPAmount
    mapping(address => uint256) private stakingLPAmountsOfAccount;

    // User  => participation pool
    mapping(address => uint256[]) private poolsOfAccount;

    // pool1 => (invitee =>  inviter)
    mapping(uint256 => mapping(address => address)) private inviters;

    // stakingOrderId => StakeLPData
    mapping(uint256 => StakeLPData) private stakeLPDatas;

    // pool1 =>  Account's Cash LP
    mapping(uint256 => mapping(address => StakeLPAccount))
        private stakeLPAccountsInPools;

    constructor(
        address _ygio,
        address _ygme,
        address _lptoken,
        address _inviteeSigner
    ) {
        YGIO = _ygio;
        YGME = _ygme;
        LPTOKEN_YGIO_USDT = _lptoken;

        inviteeSigner = _inviteeSigner;
    }

    function setPause() external onlyOwner {
        if (!paused()) {
            _pause();
        } else {
            _unpause();
        }
    }

    function setConditionMineOwner(
        uint256[] calldata _poolNumbers,
        uint256[] calldata _amounts
    ) external onlyOwner {
        _setConditionMineOwner(_poolNumbers, _amounts);
    }

    function _setConditionMineOwner(
        uint256[] calldata _poolNumbers,
        uint256[] calldata _amounts
    ) internal {
        require(_poolNumbers.length == _amounts.length, "Invalid Paras");

        for (uint i = 0; i < _poolNumbers.length; ++i) {
            conditionmMineOwnerPools[_poolNumbers[i]] = _amounts[i];
        }
    }

    function getMineOwner(uint256 _poolNumber) external view returns (address) {
        return mineOwners[_poolNumber];
    }

    function getTotalStakeLPAll() external view returns (uint256) {
        return totalStakingLP;
    }

    function getTotalStakeLPInPools(
        uint256 _poolNumber
    ) external view returns (uint256) {
        return stakingLPAmountsOfPool[_poolNumber];
    }

    function getTotalStakeLPofAccount(
        address _account
    ) external view returns (uint256) {
        return stakingLPAmountsOfAccount[_account];
    }

    function getTotalStakeLPofAccountInPools(
        uint256 _poolNumber,
        address _account
    ) external view returns (uint256) {
        return stakeLPAccountsInPools[_poolNumber][_account].totalStakingLP;
    }

    function queryInviters(
        uint256 _poolNumber,
        address _invitee,
        uint256 _numberLayers
    ) external view returns (address[] memory, uint256) {
        (address[] memory _inviters, uint256 _nubmer) = _queryInviters(
            _poolNumber,
            _invitee,
            _numberLayers
        );

        return (_inviters, _nubmer);
    }

    function applyMineOwner(
        uint256 _poolNumber,
        bytes calldata _signature
    )
        external
        whenNotPaused
        nonReentrant
        checkPoolNumber(_poolNumber, _signature)
        returns (bool)
    {
        require(mineOwners[_poolNumber] == ZERO_ADDRESS, "Mine owner exists");

        address poolOwner = _msgSender();

        uint256 needAmount = conditionmMineOwnerPools[_poolNumber];

        // check condition
        require(
            IPancakePair(LPTOKEN_YGIO_USDT).balanceOf(poolOwner) >= needAmount,
            "Insufficient balance of LP"
        );

        mineOwners[_poolNumber] = poolOwner;

        balanceMineOwners[poolOwner] = needAmount;

        // transfer LP
        IPancakePair(LPTOKEN_YGIO_USDT).transferFrom(
            poolOwner,
            address(this),
            needAmount
        );

        emit NewPool(_poolNumber, poolOwner, needAmount, block.number);

        return true;
    }

    function stakingLP(
        uint256 _poolNumber,
        uint256 _amountLP,
        uint256 _days,
        address _inviter,
        uint256 _deadline,
        bytes calldata _signature
    )
        external
        whenNotPaused
        nonReentrant
        checkInviter(_poolNumber, _inviter, _deadline, _signature)
        returns (bool)
    {
        uint256 _stakeTime = _days * ONEDAY;

        address _account = _msgSender();

        uint256 _balance = IPancakePair(LPTOKEN_YGIO_USDT).balanceOf(_account);

        require(
            _balance >= _amountLP && _amountLP > 0,
            "Insufficient balance of LP"
        );

        StakeLPAccount storage _stakeLPAccount = stakeLPAccountsInPools[
            _poolNumber
        ][_account];

        if (!_checkAccountInPool(_poolNumber, _account)) {
            if (poolsOfAccount[_account].length == 0) {
                poolsOfAccount[_account] = [_poolNumber];
            } else {
                poolsOfAccount[_account].push(_poolNumber);
            }
        }

        StakeLPType _stakeType;
        uint256 _stakeOrderId;

        if (_stakeTime == 0) {
            _stakeType = StakeLPType.STAKING_NO_DEADLINE;

            _stakeLPAccount.cashLP += _amountLP;
        } else {
            _stakeType = StakeLPType.STAKING_HAS_DEADLINE;

            // stakingLPOrderId
            _currentStakingLPOrderId.increment();

            _stakeOrderId = _currentStakingLPOrderId.current();

            if (_stakeLPAccount.stakingOrderIds.length == 0) {
                _stakeLPAccount.stakingOrderIds = [_stakeOrderId];
            } else {
                _stakeLPAccount.stakingOrderIds.push(_stakeOrderId);

                stakeLPDatas[_stakeOrderId] = StakeLPData({
                    owner: _account,
                    poolNumber: _poolNumber,
                    amountLP: _amountLP,
                    startTime: uint128(block.timestamp),
                    endTime: uint128(block.timestamp + _stakeTime)
                });
            }
        }

        unchecked {
            totalStakingLP += _amountLP;

            totalStakingLPDays += _days;

            _stakeLPAccount.totalStakingLP += _amountLP;

            stakingLPAmountsOfPool[_poolNumber] += _amountLP;

            stakingLPAmountsOfAccount[_account] += _amountLP;

            stakingLPDaysOfAccount[_account] += _days;

            ++callCount;
        }

        // transfer LP
        IPancakePair(LPTOKEN_YGIO_USDT).transferFrom(
            _account,
            address(this),
            _amountLP
        );

        emit StakeLP(
            _poolNumber,
            _account,
            _amountLP,
            block.timestamp,
            block.timestamp + _stakeTime,
            _stakeType,
            _stakeOrderId,
            callCount,
            block.number
        );

        return true;
    }

    function unStakeLP(
        uint256 _poolNumber,
        uint256 _amountCash,
        uint256[] calldata _stakingOrderIds
    ) external whenNotPaused nonReentrant returns (bool) {
        require(
            (_amountCash > 0 && _stakingOrderIds.length == 0) ||
                (_amountCash == 0 && _stakingOrderIds.length > 0),
            "Invalid Paras"
        );

        address _account = _msgSender();

        uint256 _sumAmountLP;

        uint256 _sumTimes;

        StakeLPAccount storage _stakeLPAccount = stakeLPAccountsInPools[
            _poolNumber
        ][_account];

        if (_amountCash > 0) {
            require(_amountCash <= _stakeLPAccount.cashLP);
            _stakeLPAccount.cashLP -= _amountCash;

            _sumAmountLP = _amountCash;

            ++callCount;

            emit StakeLP(
                _poolNumber,
                _account,
                _amountCash,
                0,
                0,
                StakeLPType.UNSTAKECASH,
                0,
                callCount,
                block.number
            );
        } else if (_stakingOrderIds.length > 0) {
            ++callCount;

            for (uint i = 0; i < _stakingOrderIds.length; ++i) {
                uint256 _stakingOrderId = _stakingOrderIds[i];

                StakeLPData memory _stakeLPData = stakeLPDatas[_stakingOrderId];

                require(_stakeLPData.owner == _account, "Invalid account");

                require(
                    _stakeLPData.poolNumber == _poolNumber,
                    "Invalid poolNumber"
                );

                require(
                    block.timestamp >= _stakeLPData.endTime,
                    "Too early to unStake"
                );

                uint256 _len = _stakeLPAccount.stakingOrderIds.length;

                for (uint256 j = 0; j < _len; ++j) {
                    if (_stakeLPAccount.stakingOrderIds[j] == _stakingOrderId) {
                        _stakeLPAccount.stakingOrderIds[j] = _stakeLPAccount
                            .stakingOrderIds[_len - 1];
                        _stakeLPAccount.stakingOrderIds.pop();
                        break;
                    }
                }

                unchecked {
                    _sumAmountLP += _stakeLPData.amountLP;

                    _sumTimes += (_stakeLPData.endTime -
                        _stakeLPData.startTime);
                }

                emit StakeLP(
                    _poolNumber,
                    _account,
                    _stakeLPData.amountLP,
                    _stakeLPData.startTime,
                    _stakeLPData.endTime,
                    StakeLPType.UNSTAKEORDER,
                    _stakingOrderId,
                    callCount,
                    block.number
                );

                delete stakeLPDatas[_stakingOrderId];
            }
        }

        {
            uint256 _days = _sumTimes / ONEDAY;

            totalStakingLP -= _sumAmountLP;

            totalStakingLPDays -= _days;

            _stakeLPAccount.totalStakingLP -= _sumAmountLP;

            stakingLPAmountsOfPool[_poolNumber] -= _sumAmountLP;

            stakingLPAmountsOfAccount[_account] -= _sumAmountLP;

            stakingLPDaysOfAccount[_account] -= _days;
        }

        // transfer LP
        IPancakePair(LPTOKEN_YGIO_USDT).transfer(_account, _sumAmountLP);

        if (!_checkAccountInPool(_poolNumber, _account)) {
            uint256 _len = poolsOfAccount[_account].length;

            for (uint256 j = 0; j < _len; ++j) {
                if (poolsOfAccount[_account][j] == _poolNumber) {
                    poolsOfAccount[_account][j] = poolsOfAccount[_account][
                        _len - 1
                    ];
                    poolsOfAccount[_account].pop();
                    break;
                }
            }
        }

        return true;
    }

    modifier checkInviter(
        uint256 _poolNumber,
        address inviter,
        uint256 _deadline,
        bytes calldata signature
    ) {
        address invitee = _msgSender();

        require(block.timestamp < _deadline, "Signature has expired");

        require(
            invitee != mineOwners[_poolNumber],
            "Mine owner cannot participate"
        );

        require(mineOwners[_poolNumber] != ZERO_ADDRESS, "Invalid poolNumber");

        if (inviters[_poolNumber][invitee] == ZERO_ADDRESS) {
            if (inviter != mineOwners[_poolNumber]) {
                // Is the inviter valid?
                require(
                    inviters[_poolNumber][inviter] != ZERO_ADDRESS,
                    "Invalid inviter"
                );
            }
            // Whether the invitee has been invited?
            bytes memory data = abi.encode(
                _poolNumber,
                invitee,
                inviter,
                _deadline
            );

            bytes32 hash = keccak256(data);

            _verifySignature(hash, signature);

            inviters[_poolNumber][invitee] = inviter;
        }
        _;
    }

    modifier checkPoolNumber(uint256 _poolNumber, bytes calldata _signature) {
        require(_poolNumber > 0, "Invalid PoolNumber");

        address poolOwner = _msgSender();

        bytes memory data = abi.encode(_poolNumber, poolOwner);

        bytes32 hash = keccak256(data);

        _verifySignature(hash, _signature);

        _;
    }

    function _verifySignature(
        bytes32 hash,
        bytes calldata signature
    ) internal view {
        hash = hash.toEthSignedMessageHash();

        address signer = hash.recover(signature);

        require(signer == inviteeSigner, "Invalid signature");
    }

    function _queryInviters(
        uint256 _poolNumber,
        address _invitee,
        uint256 _numberLayers
    ) internal view returns (address[] memory, uint256) {
        address[] memory _inviters = new address[](_numberLayers);

        // The number of superiors of the invitee
        uint256 _number;

        for (uint i = 0; i < _numberLayers; ) {
            _invitee = inviters[_poolNumber][_invitee];

            if (_invitee == ZERO_ADDRESS) break;

            _inviters[i] = _invitee;

            unchecked {
                _number += 1;

                ++i;
            }
        }

        return (_inviters, _number);
    }

    function _checkAccountInPool(
        uint256 _poolNumber,
        address _account
    ) internal view returns (bool) {
        StakeLPAccount memory stakeLPAccount = stakeLPAccountsInPools[
            _poolNumber
        ][_account];

        if (
            stakeLPAccount.cashLP > 0 ||
            stakeLPAccount.stakingOrderIds.length > 0
        ) {
            return true;
        } else {
            return false;
        }
    }

    function _currentTimeStampRound()
        internal
        view
        returns (uint128 _cTimeStamp)
    {
        unchecked {
            _cTimeStamp = uint128(((block.timestamp) / ONEDAY) * ONEDAY);
        }
    }
}
