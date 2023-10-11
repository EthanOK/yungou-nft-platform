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

// import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.9.3/contracts/access/Ownable.sol";
// import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.9.3/contracts/utils/Counters.sol";
// import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.9.3/contracts/security/Pausable.sol";
// import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.9.3/contracts/token/ERC20/IERC20.sol";
// import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.9.3/contracts/token/ERC721/IERC721.sol";
// import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.9.3/contracts/security/ReentrancyGuard.sol";
// import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.9.3/contracts/utils/cryptography/ECDSA.sol";
// import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.9.3/contracts/token/ERC721/utils/ERC721Holder.sol";

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
        uint256 blockNumber
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
abstract contract YGMEStakingDomain is ERC721Holder {
    enum StakeYGMEType {
        NULL,
        STAKING,
        UNSTAKE,
        UNSTAKEONLYOWNER
    }

    struct StakingYGMEParas {
        uint256[] tokenIds;
        uint256 stakeDays;
        uint256 deadline;
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
        uint256 callCount,
        uint256 blockNumber
    );

    // total Staking YGME
    uint256 totalStakingYGME;

    // total Staking YGME days(All user)
    uint256 totalStakingYGMEDays;

    // account => total staking YGME Days
    mapping(address => uint256) stakingYGMEDays;

    // tokenId => StakingYGMEData
    mapping(uint256 => StakingYGMEData) stakingYGMEDatas;

    // account => staking tokenIds
    mapping(address => uint256[]) stakingTokenIds;

    // account => token amount
    mapping(address => uint256) stakingYGMEAmounts;
}

// LPStakingDomain
abstract contract LPStakingDomain {
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
        uint256 indexed poolNumber,
        address indexed account,
        uint256 amount,
        uint256 startTime,
        uint256 endTime,
        StakeLPType indexed stakeType,
        uint256 stakingOrderId,
        uint256 callCount,
        uint256 blockNumber
    );

    event NewPool(
        uint256 poolNumber,
        address mineOwner,
        uint256 amount,
        uint256 blockNumber
    );

    event WithdrawReward(
        uint256 orderId,
        address indexed tokenAddress,
        address indexed account,
        uint256 amount,
        uint256 blockNumber
    );

    // total Staking LP Amount(All user exclude mineOwner)
    uint256 totalStakingLP;

    // total Staking LP days(All user)
    uint256 totalStakingLPDays;

    // account => total staking LP Days
    mapping(address => uint256) stakingLPDays;

    // account => StakeLPData
    mapping(address => StakeLPData) stakeLPDatas;

    // orderId => StakeLPOrderData
    mapping(uint256 => StakeLPOrderData) stakeLPOrderDatas;
}

contract MinePoolsV2 is
    Pausable,
    Ownable,
    YGIOStakingDomain,
    YGMEStakingDomain,
    LPStakingDomain,
    ReentrancyGuard
{
    using Counters for Counters.Counter;
    using ECDSA for bytes32;

    address public constant ZERO_ADDRESS = address(0);
    uint256 public constant REWARDRATE_BASE = 10_000;
    uint256 public constant ONEDAY = 1 days;
    bytes4 public constant ERC20_TRANSFER_SELECTOR = 0xa9059cbb;

    address public immutable LPTOKEN;
    address public immutable YGIO;
    address public immutable YGME;

    Counters.Counter private _currentStakingLPOrderId;
    Counters.Counter private _currentStakingYGIOOrderId;

    address private inviteeSigner;

    uint256 private rewardsTotal = 100_000_000 * 1e18;

    // stakingDays 0 100 300
    uint64[4] private stakingDays;

    uint256 private callCount;

    // poolId => mineOwner
    mapping(uint256 => address) mineOwners;

    // Conditions for becoming a mine owner
    // poolId => amount
    mapping(uint256 => uint256) conditionmMineOwnerPools;

    // mineOwner => lp balance
    mapping(address => uint256) balanceMineOwners;

    // poolId => total stakingLPAmount
    mapping(uint256 => uint256) private stakingLPAmountsOfPool;

    // account  =>  pool
    mapping(address => uint256) private poolIdOfAccount;

    // invitee =>  inviter
    mapping(address => address) private inviters;

    // withdrawRewardOrderId => bool
    mapping(uint256 => bool) private withdrawRewardOrderIds;

    // total Accumulated withdrawReward
    uint256 private totalAccumulatedWithdraws;

    // account => withdrawReward balance
    mapping(address => uint256) private accumulatedWithdrawRewards;

    constructor(
        address _ygio,
        address _ygme,
        address _lptoken,
        address _inviteeSigner
    ) {
        YGIO = _ygio;
        YGME = _ygme;
        LPTOKEN = _lptoken;

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

    function getTotalStakeLP(address _account) external view returns (uint256) {
        return stakeLPDatas[_account].totalStaking;
    }

    function getTotalStakeYGIO(
        address _account
    ) external view returns (uint256) {
        return stakeYGIODatas[_account].totalStaking;
    }

    function getTotalStakeYGME(
        address _account
    ) external view returns (uint256) {
        return stakingYGMEAmounts[_account];
    }

    function getTotalStakeYGIOAll() external view returns (uint256) {
        return totalStakingYGIO;
    }

    function getTotalStakeYGMEAll() external view returns (uint256) {
        return totalStakingYGME;
    }

    function getTotalStakeDays() external view returns (uint256) {
        return totalStakingLPDays + totalStakingYGIODays + totalStakingYGMEDays;
    }

    function getTotalStakeLPDays() external view returns (uint256) {
        return totalStakingLPDays;
    }

    function getTotalStakeLPDaysOf(
        address _account
    ) external view returns (uint256) {
        return stakingLPDays[_account];
    }

    function getTotalStakeYGIODays() external view returns (uint256) {
        return totalStakingYGIODays;
    }

    function getTotalStakeYGIODaysOf(
        address _account
    ) external view returns (uint256) {
        return stakingYGIODays[_account];
    }

    function getTotalStakeYGMEDays() external view returns (uint256) {
        return totalStakingYGMEDays;
    }

    function getTotalStakeYGMEDaysOf(
        address _account
    ) external view returns (uint256) {
        return stakingYGMEDays[_account];
    }

    function getTotalStakeLPInPools(
        uint256 _poolNumber
    ) external view returns (uint256) {
        return stakingLPAmountsOfPool[_poolNumber];
    }

    function queryInviters(
        address _invitee,
        uint256 _numberLayers
    ) external view returns (address[] memory, uint256) {
        (address[] memory _inviters, uint256 _nubmer) = _queryInviters(
            _invitee,
            _numberLayers
        );

        return (_inviters, _nubmer);
    }

    function applyMineOwner(
        uint256 _poolNumber,
        uint256 _amount,
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

        // check condition
        require(
            IERC20(LPTOKEN).balanceOf(poolOwner) >= _amount,
            "Insufficient balance of LP"
        );

        mineOwners[_poolNumber] = poolOwner;

        balanceMineOwners[poolOwner] = _amount;

        StakeLPData storage _stakeLPData = stakeLPDatas[poolOwner];

        unchecked {
            totalStakingLP += _amount;

            stakingLPAmountsOfPool[_poolNumber] += _amount;
        }

        // transfer LP
        IERC20(LPTOKEN).transferFrom(poolOwner, address(this), _amount);

        emit NewPool(_poolNumber, poolOwner, _amount, block.number);

        return true;
    }

    function stakingLP(
        StakingLPParas calldata _paras,
        bytes calldata _signature
    ) external whenNotPaused nonReentrant returns (bool) {
        address _account = _msgSender();

        _checkStakeDays(_paras.stakeDays);

        _verifyInviter(_account, _paras, _signature);

        uint256 _balance = IERC20(LPTOKEN).balanceOf(_account);

        require(
            _balance >= _paras.amount && _paras.amount > 0,
            "LP: Insufficient Balance"
        );

        StakeLPData storage _stakeLPData = stakeLPDatas[_account];

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

            stakingLPDays[_account] += _paras.stakeDays;

            ++callCount;
        }

        // transfer LP
        IERC20(LPTOKEN).transferFrom(_account, address(this), _paras.amount);

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

        StakeLPData storage _stakeLPData = stakeLPDatas[_account];

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

                StakeLPOrderData memory _data = stakeLPOrderDatas[
                    _stakingOrderId
                ];

                require(_data.owner == _account, "Invalid account");

                require(_data.poolNumber == _poolNumber, "Invalid poolNumber");

                require(
                    block.timestamp >= _data.endTime,
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
                    _sumAmountLP += _data.amount;

                    _sumTimes += (_data.endTime - _data.startTime);
                }

                emit StakeLP(
                    _poolNumber,
                    _account,
                    _data.amount,
                    _data.startTime,
                    _data.endTime,
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

            stakingLPDays[_account] -= _days;
        }

        // transfer LP
        IERC20(LPTOKEN).transfer(_account, _sumAmountLP);

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

    function unStakeYGIO(
        uint256 _amountCash,
        uint256[] calldata _stakingOrderIds
    ) external whenNotPaused nonReentrant returns (bool) {
        require(
            (_amountCash > 0 && _stakingOrderIds.length == 0) ||
                (_amountCash == 0 && _stakingOrderIds.length > 0),
            "Invalid Paras"
        );

        address _account = _msgSender();

        uint256 _sumAmountYGIO;

        uint256 _sumTimes;

        StakeYGIOData storage _stakeYGIOData = stakeYGIODatas[_account];

        if (_amountCash > 0) {
            require(_amountCash <= _stakeYGIOData.cash);
            _stakeYGIOData.cash -= _amountCash;

            _sumAmountYGIO = _amountCash;

            ++callCount;

            emit StakeYGIO(
                _account,
                _amountCash,
                0,
                0,
                StakeYGIOType.UNSTAKECASH,
                0,
                callCount,
                block.number
            );
        } else if (_stakingOrderIds.length > 0) {
            ++callCount;

            for (uint i = 0; i < _stakingOrderIds.length; ++i) {
                uint256 _stakingOrderId = _stakingOrderIds[i];

                StakeYGIOOrderData memory _data = stakeYGIOOrderDatas[
                    _stakingOrderId
                ];

                require(_data.owner == _account, "Invalid account");

                require(
                    block.timestamp >= _data.endTime,
                    "Too early to unStake"
                );

                uint256 _len = _stakeYGIOData.stakingOrderIds.length;

                for (uint256 j = 0; j < _len; ++j) {
                    if (_stakeYGIOData.stakingOrderIds[j] == _stakingOrderId) {
                        _stakeYGIOData.stakingOrderIds[j] = _stakeYGIOData
                            .stakingOrderIds[_len - 1];
                        _stakeYGIOData.stakingOrderIds.pop();
                        break;
                    }
                }

                unchecked {
                    _sumAmountYGIO += _data.amount;

                    _sumTimes += (_data.endTime - _data.startTime);
                }

                emit StakeYGIO(
                    _account,
                    _data.amount,
                    _data.startTime,
                    _data.endTime,
                    StakeYGIOType.UNSTAKEORDER,
                    _stakingOrderId,
                    callCount,
                    block.number
                );

                delete stakeYGIOOrderDatas[_stakingOrderId];
            }
        }

        {
            uint256 _days = _sumTimes / ONEDAY;

            totalStakingYGIO -= _sumAmountYGIO;

            totalStakingYGIODays -= _days;

            _stakeYGIOData.totalStaking -= _sumAmountYGIO;

            stakingYGIODays[_account] -= _days;
        }

        // transfer YGIO
        IERC20(YGIO).transfer(_account, _sumAmountYGIO);

        return true;
    }

    function stakingYGME(
        StakingYGMEParas calldata _paras,
        bytes calldata _signature
    ) external whenNotPaused nonReentrant returns (bool) {
        uint256 _len = _paras.tokenIds.length;

        require(_len > 0, "Invalid tokenIds");

        address _account = _msgSender();

        _checkStakeDays(_paras.stakeDays);

        _verifyStakeYGME(_account, _paras, _signature);

        ++callCount;

        for (uint256 i = 0; i < _len; ++i) {
            uint256 _tokenId = _paras.tokenIds[i];

            require(
                !stakingYGMEDatas[_tokenId].stakedState,
                "Invalid stake state"
            );

            require(
                IERC721(YGME).ownerOf(_tokenId) == _account,
                "Invalid owner"
            );

            StakingYGMEData memory _data = StakingYGMEData({
                owner: _account,
                stakedState: true,
                startTime: uint128(block.timestamp),
                endTime: uint128(block.timestamp + _paras.stakeDays * ONEDAY)
            });

            stakingYGMEDatas[_tokenId] = _data;

            if (stakingTokenIds[_account].length == 0) {
                stakingTokenIds[_account] = [_tokenId];
            } else {
                stakingTokenIds[_account].push(_tokenId);
            }

            //transfer YGME
            IERC721(YGME).safeTransferFrom(_account, address(this), _tokenId);

            emit StakingYGME(
                _account,
                _tokenId,
                _data.startTime,
                _data.endTime,
                StakeYGMEType.STAKING,
                callCount,
                block.number
            );
        }

        unchecked {
            totalStakingYGME += _len;

            stakingYGMEAmounts[_account] += _len;

            totalStakingYGMEDays += (_paras.stakeDays * _len);

            stakingYGMEDays[_account] += (_paras.stakeDays * _len);
        }

        return true;
    }

    function unStakeYGME(
        uint256[] calldata _tokenIds
    ) external whenNotPaused nonReentrant returns (bool) {
        uint256 _length = _tokenIds.length;

        address _account = _msgSender();

        require(_length > 0, "Invalid tokenIds");

        uint256 _sumTimes;

        ++callCount;

        for (uint256 i = 0; i < _length; ++i) {
            uint256 _tokenId = _tokenIds[i];

            StakingYGMEData memory _data = stakingYGMEDatas[_tokenId];

            require(_data.owner == _account, "Invalid account");

            require(_data.stakedState, "Invalid stake state");

            require(block.timestamp >= _data.endTime, "Too early to unStake");

            uint256 _len = stakingTokenIds[_account].length;

            for (uint256 j = 0; j < _len; ++j) {
                if (stakingTokenIds[_account][j] == _tokenId) {
                    stakingTokenIds[_account][j] = stakingTokenIds[_account][
                        _len - 1
                    ];
                    stakingTokenIds[_account].pop();
                    break;
                }
            }

            emit StakingYGME(
                _account,
                _tokenId,
                _data.startTime,
                _data.endTime,
                StakeYGMEType.UNSTAKE,
                callCount,
                block.number
            );

            _sumTimes += (_data.endTime - _data.startTime);

            delete stakingYGMEDatas[_tokenId];

            //transfer YGME
            IERC721(YGME).safeTransferFrom(address(this), _account, _tokenId);
        }

        uint256 _days = _sumTimes / ONEDAY;

        totalStakingYGME -= _length;

        stakingYGMEAmounts[_account] -= _length;

        totalStakingYGMEDays -= _days;

        stakingYGMEDays[_account] -= _days;

        return true;
    }

    function withdrawReward(
        bytes calldata _data,
        bytes calldata _signature
    ) external whenNotPaused nonReentrant returns (bool) {
        require(_data.length > 0 && _signature.length > 0, "Invalid data");

        (
            uint256 orderId,
            address tokenAddress,
            address account,
            uint256 amount,
            uint256 deadline
        ) = abi.decode(_data, (uint256, address, address, uint256, uint256));

        require(block.timestamp < deadline, "Signature expired");

        require(!withdrawRewardOrderIds[orderId], "Invalid orderId");

        require(account == _msgSender(), "Invalid account");

        bytes32 _hash = keccak256(_data);

        _verifySignature(_hash, _signature);

        withdrawRewardOrderIds[orderId] = true;

        uint256 _balance = IERC20(tokenAddress).balanceOf(address(this));

        // Lock staked YGIO
        require(amount <= _balance - totalStakingYGIO, "YGIO Insufficient");

        unchecked {
            totalAccumulatedWithdraws += amount;

            accumulatedWithdrawRewards[account] += amount;
        }

        // transfer reward( contract--> account)
        _transferLowCall(tokenAddress, account, amount);

        emit WithdrawReward(
            orderId,
            tokenAddress,
            account,
            amount,
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
            mineOwners[_paras.poolNumber] != ZERO_ADDRESS,
            "Invalid poolNumber"
        );

        if (inviters[_invitee] == ZERO_ADDRESS) {
            if (_paras.inviter != mineOwners[_paras.poolNumber]) {
                // Is the inviter valid?
                require(
                    inviters[_paras.inviter] != ZERO_ADDRESS,
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

            inviters[_invitee] = _paras.inviter;
        }
    }

    function _verifyStakeYGIO(
        address _account,
        StakingYGIOParas calldata _paras,
        bytes calldata _signature
    ) internal view {
        require(block.timestamp < _paras.deadline, "Signature has expired");

        bytes memory data = abi.encode(
            _account,
            _paras.amount,
            _paras.stakeDays,
            _paras.deadline
        );

        bytes32 _hash = keccak256(data);

        _verifySignature(_hash, _signature);
    }

    function _verifyStakeYGME(
        address _account,
        StakingYGMEParas calldata _paras,
        bytes calldata _signature
    ) internal view {
        require(block.timestamp < _paras.deadline, "Signature has expired");

        bytes memory data = abi.encode(
            _account,
            _paras.tokenIds,
            _paras.stakeDays,
            _paras.deadline
        );

        bytes32 _hash = keccak256(data);

        _verifySignature(_hash, _signature);
    }

    modifier checkPoolNumber(uint256 _poolNumber, bytes calldata _signature) {
        require(_poolNumber > 0, "Invalid PoolNumber");

        address poolOwner = _msgSender();

        bytes memory data = abi.encode(_poolNumber, poolOwner);

        bytes32 _hash = keccak256(data);

        _verifySignature(_hash, _signature);

        _;
    }

    function _verifySignature(
        bytes32 _hash,
        bytes calldata _signature
    ) internal view {
        _hash = _hash.toEthSignedMessageHash();

        address signer = _hash.recover(_signature);

        require(signer == inviteeSigner, "Invalid signature");
    }

    function _queryInviters(
        address _invitee,
        uint256 _numberLayers
    ) internal view returns (address[] memory, uint256) {
        address[] memory _inviters = new address[](_numberLayers);

        // The number of superiors of the invitee
        uint256 _number;

        for (uint i = 0; i < _numberLayers; ) {
            _invitee = inviters[_invitee];

            if (_invitee == ZERO_ADDRESS) break;

            _inviters[i] = _invitee;

            unchecked {
                _number += 1;

                ++i;
            }
        }

        return (_inviters, _number);
    }

    function checkStakeLPState(address _account) external view returns (bool) {
        StakeLPData memory _stakeLPData = stakeLPDatas[_account];

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
}
