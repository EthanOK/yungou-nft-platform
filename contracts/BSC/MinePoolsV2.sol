// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";

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
        STAKING_HAS_DEADLINE,
        STAKING_NO_DEADLINE,
        UNSTAKECASH,
        UNSTAKEORDER,
        UNSTAKEONLYOWNER
    }

    struct StakingYGIOParas {
        uint256 amount;
        uint256 stakeDays;
        uint256 deadline;
    }

    struct StakeYGIOData {
        uint256 cash;
        uint256[] stakingOrderIds;
        uint256 totalStaking;
    }

    struct StakeYGIOOrderData {
        address owner;
        uint256 amount;
        uint128 startTime;
        uint128 endTime;
    }

    event StakeYGIO(
        address indexed account,
        uint256 amount,
        uint256 startTime,
        uint256 endTime,
        StakeYGIOType indexed stakeType,
        uint256 orderId,
        uint256 callCount,
        uint256 indexed blockNumber
    );

    // total Staking YGIO
    uint256 totalStakingYGIO;

    // total Staking YGIO days(All user)
    uint256 totalStakingYGIODays;

    // account => total staking YGIO Days
    mapping(address => uint256) stakingYGIODays;

    // account => StakeYGIOrderData
    mapping(address => StakeYGIOData) stakeYGIODatas;

    // orderId => StakeYGIOOrderData
    mapping(uint256 => StakeYGIOOrderData) stakeYGIOOrderDatas;
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

    struct StakingLPParas {
        uint256 poolNumber;
        uint256 amount;
        uint256 stakeDays;
        address inviter;
        uint256 deadline;
    }

    struct StakeLPOrderData {
        address owner;
        uint256 poolNumber;
        uint256 amount;
        uint128 startTime;
        uint128 endTime;
    }

    struct StakeLPData {
        uint256 cash;
        uint256[] stakingOrderIds;
        uint256 totalStaking;
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

contract MinePoolsV2 is
    YGIOStakingDomain,
    MinePoolsDomain,
    Pausable,
    Ownable,
    ReentrancyGuard
{
    using Counters for Counters.Counter;
    using ECDSA for bytes32;

    address public constant ZERO_ADDRESS = address(0);
    uint256 public constant REWARDRATE_BASE = 10_000;
    uint256 public constant ONEDAY = 1 days;

    address public immutable LPTOKEN_YGIO_USDT;
    address public immutable YGIO;
    address public immutable YGME;

    Counters.Counter private _currentStakingLPOrderId;
    Counters.Counter private _currentStakingYGIOOrderId;

    address private inviteeSigner;

    uint256 private rewardsTotal = 100_000_000 * 1e18;

    //
    uint64[4] private stakingDays;

    // Rewards per Block 10 YGIO
    uint256 private rewardsPerBlock = 10e18;

    uint256 private startBlockNumber;

    uint256 private callCount;

    // total Staking LP Amount(Not included Balance of Pool Mine Owner)
    uint256 private totalStakingLP;

    // total Staking LP days(All user)
    uint256 private totalStakingLPDays;

    // total Staking YGME days(All user)
    uint256 private totalStakingYGMEDays;

    // account => total staking LP Days
    mapping(address => uint256) stakingLPDays;

    // account => total staking YGME Days
    mapping(address => uint256) stakingYGMEDays;

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
    mapping(address => uint256) private stakingLPAmounts;

    // User  => participation pool
    mapping(address => uint256[]) private poolsOfAccount;

    // pool1 => (invitee =>  inviter)
    mapping(uint256 => mapping(address => address)) private inviters;

    // stakingOrderId => StakeLPOrderData
    mapping(uint256 => StakeLPOrderData) private stakeLPOrderDatas;

    // pool1 =>  Account's Cash LP
    mapping(uint256 => mapping(address => StakeLPData)) private stakeLPDatas;

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

        stakingDays = [0, 100, 300, 0];
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
        return stakingLPAmounts[_account];
    }

    function getTotalStakeLPofAccountInPools(
        uint256 _poolNumber,
        address _account
    ) external view returns (uint256) {
        return stakeLPDatas[_poolNumber][_account].totalStaking;
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
        StakingLPParas calldata _paras,
        bytes calldata _signature
    ) external whenNotPaused nonReentrant returns (bool) {
        address _account = _msgSender();

        _checkStakeDays(_paras.stakeDays);

        _verifyInviter(_account, _paras, _signature);

        uint256 _balance = IPancakePair(LPTOKEN_YGIO_USDT).balanceOf(_account);

        require(
            _balance >= _paras.amount && _paras.amount > 0,
            "LP: Insufficient Balance"
        );

        StakeLPData storage _stakeLPData = stakeLPDatas[_paras.poolNumber][
            _account
        ];

        if (!_checkAccountInPool(_paras.poolNumber, _account)) {
            if (poolsOfAccount[_account].length == 0) {
                poolsOfAccount[_account] = [_paras.poolNumber];
            } else {
                poolsOfAccount[_account].push(_paras.poolNumber);
            }
        }

        StakeLPType _stakeType;

        uint256 _stakeOrderId;

        if (_paras.stakeDays == 0) {
            _stakeType = StakeLPType.STAKING_NO_DEADLINE;

            _stakeLPData.cash += _paras.amount;
        } else {
            _stakeType = StakeLPType.STAKING_HAS_DEADLINE;

            // stakingLPOrderId
            _currentStakingLPOrderId.increment();

            _stakeOrderId = _currentStakingLPOrderId.current();

            if (_stakeLPData.stakingOrderIds.length == 0) {
                _stakeLPData.stakingOrderIds = [_stakeOrderId];
            } else {
                _stakeLPData.stakingOrderIds.push(_stakeOrderId);

                stakeLPOrderDatas[_stakeOrderId] = StakeLPOrderData({
                    owner: _account,
                    poolNumber: _paras.poolNumber,
                    amount: _paras.amount,
                    startTime: uint128(block.timestamp),
                    endTime: uint128(
                        block.timestamp + _paras.stakeDays * ONEDAY
                    )
                });
            }
        }

        unchecked {
            totalStakingLP += _paras.amount;

            totalStakingLPDays += _paras.stakeDays;

            _stakeLPData.totalStaking += _paras.amount;

            stakingLPAmountsOfPool[_paras.poolNumber] += _paras.amount;

            stakingLPAmounts[_account] += _paras.amount;

            stakingLPDays[_account] += _paras.stakeDays;

            ++callCount;
        }

        // transfer LP
        IPancakePair(LPTOKEN_YGIO_USDT).transferFrom(
            _account,
            address(this),
            _paras.amount
        );

        emit StakeLP(
            _paras.poolNumber,
            _account,
            _paras.amount,
            block.timestamp,
            block.timestamp + _paras.stakeDays * ONEDAY,
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

        StakeLPData storage _stakeLPData = stakeLPDatas[_poolNumber][_account];

        if (_amountCash > 0) {
            require(_amountCash <= _stakeLPData.cash);
            _stakeLPData.cash -= _amountCash;

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

                StakeLPOrderData memory _stakeLPOrderData = stakeLPOrderDatas[
                    _stakingOrderId
                ];

                require(_stakeLPOrderData.owner == _account, "Invalid account");

                require(
                    _stakeLPOrderData.poolNumber == _poolNumber,
                    "Invalid poolNumber"
                );

                require(
                    block.timestamp >= _stakeLPOrderData.endTime,
                    "Too early to unStake"
                );

                uint256 _len = _stakeLPData.stakingOrderIds.length;

                for (uint256 j = 0; j < _len; ++j) {
                    if (_stakeLPData.stakingOrderIds[j] == _stakingOrderId) {
                        _stakeLPData.stakingOrderIds[j] = _stakeLPData
                            .stakingOrderIds[_len - 1];
                        _stakeLPData.stakingOrderIds.pop();
                        break;
                    }
                }

                unchecked {
                    _sumAmountLP += _stakeLPOrderData.amount;

                    _sumTimes += (_stakeLPOrderData.endTime -
                        _stakeLPOrderData.startTime);
                }

                emit StakeLP(
                    _poolNumber,
                    _account,
                    _stakeLPOrderData.amount,
                    _stakeLPOrderData.startTime,
                    _stakeLPOrderData.endTime,
                    StakeLPType.UNSTAKEORDER,
                    _stakingOrderId,
                    callCount,
                    block.number
                );

                delete stakeLPOrderDatas[_stakingOrderId];
            }
        }

        {
            uint256 _days = _sumTimes / ONEDAY;

            totalStakingLP -= _sumAmountLP;

            totalStakingLPDays -= _days;

            _stakeLPData.totalStaking -= _sumAmountLP;

            stakingLPAmountsOfPool[_poolNumber] -= _sumAmountLP;

            stakingLPAmounts[_account] -= _sumAmountLP;

            stakingLPDays[_account] -= _days;
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

    function stakingYGIO(
        StakingYGIOParas calldata _paras,
        bytes calldata _signature
    ) external whenNotPaused nonReentrant returns (bool) {
        address _account = _msgSender();

        _checkStakeDays(_paras.stakeDays);

        _verifyStakeYGIO(_account, _paras, _signature);

        uint256 _balance = IERC20(YGIO).balanceOf(_account);

        require(
            _balance >= _paras.amount && _paras.amount > 0,
            "YGIO: Insufficient Balance"
        );

        StakeYGIOData storage _stakeYGIOData = stakeYGIODatas[_account];

        StakeYGIOType _stakeType;

        uint256 _stakeOrderId;

        if (_paras.stakeDays == 0) {
            _stakeType = StakeYGIOType.STAKING_NO_DEADLINE;

            _stakeYGIOData.cash += _paras.amount;
        } else {
            _stakeType = StakeYGIOType.STAKING_HAS_DEADLINE;

            // stakingYGIOOrderId
            _currentStakingYGIOOrderId.increment();

            _stakeOrderId = _currentStakingYGIOOrderId.current();

            if (_stakeYGIOData.stakingOrderIds.length == 0) {
                _stakeYGIOData.stakingOrderIds = [_stakeOrderId];
            } else {
                _stakeYGIOData.stakingOrderIds.push(_stakeOrderId);

                stakeYGIOOrderDatas[_stakeOrderId] = StakeYGIOOrderData({
                    owner: _account,
                    amount: _paras.amount,
                    startTime: uint128(block.timestamp),
                    endTime: uint128(
                        block.timestamp + _paras.stakeDays * ONEDAY
                    )
                });
            }
        }

        unchecked {
            totalStakingYGIO += _paras.amount;

            totalStakingYGIODays += _paras.stakeDays;

            _stakeYGIOData.totalStaking += _paras.amount;

            stakingYGIODays[_account] += _paras.stakeDays;

            ++callCount;
        }

        // transfer YGIO
        IERC20(YGIO).transferFrom(_account, address(this), _paras.amount);

        emit StakeYGIO(
            _account,
            _paras.amount,
            block.timestamp,
            block.timestamp + _paras.stakeDays * ONEDAY,
            _stakeType,
            _stakeOrderId,
            callCount,
            block.number
        );

        return true;
    }

    function _verifyInviter(
        address _invitee,
        StakingLPParas calldata _paras,
        bytes calldata _signature
    ) internal {
        require(block.timestamp < _paras.deadline, "Signature has expired");

        require(
            _invitee != mineOwners[_paras.poolNumber],
            "Mine owner cannot participate"
        );

        require(
            mineOwners[_paras.poolNumber] != ZERO_ADDRESS,
            "Invalid poolNumber"
        );

        if (inviters[_paras.poolNumber][_invitee] == ZERO_ADDRESS) {
            if (_paras.inviter != mineOwners[_paras.poolNumber]) {
                // Is the inviter valid?
                require(
                    inviters[_paras.poolNumber][_paras.inviter] != ZERO_ADDRESS,
                    "Invalid inviter"
                );
            }
            // Whether the invitee has been invited?
            bytes memory data = abi.encode(
                _paras.poolNumber,
                _invitee,
                _paras.inviter,
                _paras.deadline
            );

            bytes32 hash = keccak256(data);

            _verifySignature(hash, _signature);

            inviters[_paras.poolNumber][_invitee] = _paras.inviter;
        }
    }

    function _verifyStakeYGIO(
        address _account,
        StakingYGIOParas calldata _paras,
        bytes calldata _signature
    ) internal {
        require(block.timestamp < _paras.deadline, "Signature has expired");

        bytes memory data = abi.encode(
            _account,
            _paras.amount,
            _paras.stakeDays,
            _paras.deadline
        );

        bytes32 hash = keccak256(data);

        _verifySignature(hash, _signature);
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
        StakeLPData memory _stakeLPData = stakeLPDatas[_poolNumber][_account];

        if (_stakeLPData.cash > 0 || _stakeLPData.stakingOrderIds.length > 0) {
            return true;
        } else {
            return false;
        }
    }

    function _checkStakeDays(uint256 _stakeDays) internal view {
        require(
            _stakeDays == stakingDays[0] ||
                _stakeDays == stakingDays[1] ||
                _stakeDays == stakingDays[2] ||
                _stakeDays == stakingDays[3],
            "Invalid stakeDays"
        );
    }
}
