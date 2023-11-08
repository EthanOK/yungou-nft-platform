// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "./LPStakingDomain.sol";
import "./YGIOStakingDomain.sol";
import "./YGMEStakingDomain.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract MinePoolsV3 is
    YGIOStakingDomain,
    YGMEStakingDomain,
    LPStakingDomain,
    ReentrancyGuard,
    Pausable,
    Ownable
{
    using ECDSA for bytes32;
    using Counters for Counters.Counter;

    enum MinerRole {
        NULL,
        // FIRST LEVEL MINER OWNER
        FIRSTLEVEL,
        // SECOND LEVEL  MINER OWNER
        SECONDLEVEL,
        // MINER
        MINER
    }

    address public constant ZERO_ADDRESS = address(0);
    // TODO:uint256 public constant ONEDAY = 1 days;
    uint256 public ONEDAY = 1;

    // TODO:immutable
    address public YGIO;
    address public YGME;
    address public LPTOKEN;

    address private systemSigner;

    uint256 private rewardsTotal = 100_000_000 * 1e18;

    // stakingDays: 0 100 300 0
    uint64[4] private stakingDays;

    uint256 private callCount;

    address[] private mineOwners;

    uint256 private firstLevelCondition;

    uint256 private secondLevelCondition;

    uint256 private firstLevelNumber;

    uint256 private secondLevelNumber;

    // account => MinerRole
    mapping(address => MinerRole) private minerRoles;

    // mineOwner => lp balance
    mapping(address => uint256) private balanceMineOwners;

    // invitee => inviter
    mapping(address => address) private inviters;

    // orderIds => bool
    mapping(uint256 => bool) private orderStates;

    // account => withdrawReward balance
    mapping(address => uint256) private accumulatedWithdrawRewards;

    // total Accumulated withdrawReward
    uint256 private totalAccumulatedWithdraws;

    constructor(
        address _ygio,
        address _ygme,
        address _lptoken,
        address _inviteeSigner
    ) {
        YGIO = _ygio;
        YGME = _ygme;
        LPTOKEN = _lptoken;

        systemSigner = _inviteeSigner;

        stakingDays = [0, 100, 300, 0];

        firstLevelCondition = 177000 * 1e18;

        secondLevelCondition = 88000 * 1e18;
    }

    function setPause() external onlyOwner {
        if (!paused()) {
            _pause();
        } else {
            _unpause();
        }
    }

    function setTokensAddress(
        address _ygio,
        address _ygme,
        address _lptoken
    ) external onlyOwner {
        YGIO = _ygio;
        YGME = _ygme;
        LPTOKEN = _lptoken;
    }

    function setStakingDays(
        uint64[4] calldata _stakingDays,
        uint256 _second
    ) external onlyOwner {
        stakingDays = _stakingDays;
        ONEDAY = _second;
    }

    function setMineOwnerConditions(
        uint256 _firstLevelCondition,
        uint256 _secondLevelCondition
    ) external onlyOwner {
        firstLevelCondition = _firstLevelCondition;

        secondLevelCondition = _secondLevelCondition;
    }

    function setSigner(address _signer) external onlyOwner {
        systemSigner = _signer;
    }

    function getStakingDays() external view returns (uint64[4] memory) {
        return stakingDays;
    }

    function getMineOwnerConditions() external view returns (uint256, uint256) {
        return (firstLevelCondition, secondLevelCondition);
    }

    function getMinePoolNumberOfLevel()
        external
        view
        returns (uint256, uint256)
    {
        return (firstLevelNumber, secondLevelNumber);
    }

    function getOrderState(uint256 _orderId) external view returns (bool) {
        return orderStates[_orderId];
    }

    function getMinerRole(address _account) external view returns (MinerRole) {
        return minerRoles[_account];
    }

    function getSigner() external view onlyOwner returns (address) {
        return systemSigner;
    }

    function getMineOwners() external view returns (address[] memory) {
        return mineOwners;
    }

    function getMinePoolNumber() external view returns (uint256) {
        return mineOwners.length;
    }

    function getTotalStakeLPAll() external view returns (uint256) {
        return totalStakingLP;
    }

    function getTotalStakeLP(address _account) external view returns (uint256) {
        if (minerRoles[_account] != MinerRole.NULL) {
            return
                balanceMineOwners[_account] +
                stakeLPDatas[_account].totalStaking;
        } else {
            return stakeLPDatas[_account].totalStaking;
        }
    }

    function getBalanceMineOwner(
        address _mineOwner
    ) external view returns (uint256) {
        return balanceMineOwners[_mineOwner];
    }

    function getStakeLPData(
        address _account
    ) external view returns (StakeLPData memory) {
        return stakeLPDatas[_account];
    }

    function getStakeLPOrderData(
        uint256 _orderId
    ) external view returns (StakeLPOrderData memory) {
        return stakeLPOrderDatas[_orderId];
    }

    function getStakeYGIOOrderData(
        uint256 _orderId
    ) external view returns (StakeYGIOOrderData memory) {
        return stakeYGIOOrderDatas[_orderId];
    }

    function getStakingYGMEData(
        uint256 _orderId
    ) external view returns (StakingYGMEData memory) {
        return stakingYGMEDatas[_orderId];
    }

    function getStakeLPState(address _account) external view returns (bool) {
        StakeLPData memory _stakeLPData = stakeLPDatas[_account];

        if (_stakeLPData.cash > 0 || _stakeLPData.stakingOrderIds.length > 0) {
            return true;
        } else {
            return false;
        }
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

    // TODO:Only Test
    function removeAllLPAccount(address _account) external onlyOwner {
        require(minerRoles[_account] != MinerRole.NULL);

        uint256 _sumAmount;

        StakeLPData storage _stakeLPData = stakeLPDatas[_account];

        _sumAmount += _stakeLPData.totalStaking;

        delete _stakeLPData.cash;

        delete _stakeLPData.totalStaking;

        uint256[] memory _stakingOrderIds = _stakeLPData.stakingOrderIds;

        for (uint256 i = 0; i < _stakingOrderIds.length; ++i) {
            delete stakeLPOrderDatas[_stakingOrderIds[i]];
        }

        delete _stakeLPData.stakingOrderIds;

        if (minerRoles[_account] != MinerRole.MINER) {
            _sumAmount += balanceMineOwners[_account];

            delete balanceMineOwners[_account];

            if (minerRoles[_account] == MinerRole.FIRSTLEVEL) {
                firstLevelNumber--;
            } else {
                secondLevelNumber--;
            }
        }

        unchecked {
            totalStakingLP -= _sumAmount;
        }

        uint256 _len = mineOwners.length;

        for (uint j = 0; j < _len; ++j) {
            if (mineOwners[j] == _account) {
                mineOwners[j] = mineOwners[_len - 1];
                mineOwners.pop();
                break;
            }
        }
        minerRoles[_account] = MinerRole.NULL;

        IERC20(LPTOKEN).transfer(_account, _sumAmount);
    }

    function applyMineOwner(
        uint256 _orderId,
        uint256 _applyType,
        MinerRole _mineRole,
        uint256 _amount,
        uint256 _deadline,
        bytes calldata _signature
    ) external whenNotPaused nonReentrant returns (bool) {
        require(!orderStates[_orderId], "Invalid orderId");

        address _account = _msgSender();

        require(stakingYGMEAmounts[_account] > 0, "Insufficient Staked YGME");

        // 0: Apply directly 1：Miner upgrade
        require(_applyType == 0 || _applyType == 1, "Invalid apply type");

        require(
            (_mineRole == MinerRole.FIRSTLEVEL ||
                _mineRole == MinerRole.SECONDLEVEL) &&
                minerRoles[_account] != _mineRole,
            "Invalid mineRole"
        );

        uint256 _amountNeed = _mineRole == MinerRole.FIRSTLEVEL
            ? firstLevelCondition
            : secondLevelCondition;

        _verifyMinerOwner(
            _orderId,
            _applyType,
            _account,
            _mineRole,
            _deadline,
            _signature
        );

        if (
            minerRoles[_account] == MinerRole.NULL ||
            minerRoles[_account] == MinerRole.MINER
        ) {
            mineOwners.push(_account);

            if (_mineRole == MinerRole.FIRSTLEVEL) {
                ++firstLevelNumber;
            } else {
                ++secondLevelNumber;
            }
        } else {
            ++firstLevelNumber;

            secondLevelNumber--;
        }

        orderStates[_orderId] = true;

        minerRoles[_account] = _mineRole;

        // Apply directly to the mine owner
        if (_applyType == 0) {
            require(_amountNeed == _amount, "Invalid amount");

            unchecked {
                balanceMineOwners[_account] = _amountNeed;

                totalStakingLP += _amountNeed;
            }

            // transfer LP (account --> contract)
            IERC20(LPTOKEN).transferFrom(_account, address(this), _amountNeed);

            emit NewLPPool(_orderId, _account, _amountNeed, block.number);
        } else {
            // Miner upgraded to mine owner

            StakeLPData storage _stakeLPData = stakeLPDatas[_account];

            uint256 _amountStaking = _stakeLPData.totalStaking;

            require(_amountStaking == _amount, "Invalid amount");

            require(
                _amountStaking + balanceMineOwners[_account] >= _amountNeed,
                "StakingLP: Insufficient"
            );

            delete _stakeLPData.cash;

            delete _stakeLPData.totalStaking;

            uint256[] memory _stakingOrderIds = _stakeLPData.stakingOrderIds;

            for (uint256 i = 0; i < _stakingOrderIds.length; ++i) {
                delete stakeLPOrderDatas[_stakingOrderIds[i]];
            }

            delete _stakeLPData.stakingOrderIds;

            unchecked {
                balanceMineOwners[_account] += _amountStaking;
            }

            emit NewLPPool(_orderId, _account, _amountStaking, block.number);
        }

        return true;
    }

    function applyWithdrawLP(
        uint256 _orderId,
        uint256 _amount,
        uint256 _deadline,
        bytes calldata _signature
    ) external whenNotPaused nonReentrant returns (bool) {
        require(!orderStates[_orderId], "Invalid orderId");

        address _account = _msgSender();

        require(
            minerRoles[_account] == MinerRole.FIRSTLEVEL ||
                minerRoles[_account] == MinerRole.SECONDLEVEL,
            "Must MineOwner"
        );

        require(block.timestamp < _deadline, "Signature expired");

        bytes memory data = abi.encode(
            _orderId,
            LPTOKEN,
            _account,
            _amount,
            _deadline
        );

        bytes32 _hash = keccak256(data);

        _verifySignature(_hash, _signature);

        {
            balanceMineOwners[_account] -= _amount;

            totalStakingLP -= _amount;
        }

        orderStates[_orderId] = true;

        // transfer LP (contract --> account)
        IERC20(LPTOKEN).transfer(_account, _amount);

        emit RemoveLPPool(_orderId, _account, _amount, block.number);

        return true;
    }

    function stakingLP(
        uint256 _orderId,
        StakingLPParas calldata _paras,
        uint256 _deadline,
        bytes calldata _signature
    ) external whenNotPaused nonReentrant returns (bool) {
        require(!orderStates[_orderId], "Invalid orderId");

        address _account = _msgSender();

        require(stakingYGMEAmounts[_account] > 0, "Insufficient Staked YGME");

        _checkStakeDays(_paras.stakeDays);

        _verifyStakeLP(_orderId, _account, _paras, _deadline, _signature);

        uint256 _balance = IERC20(LPTOKEN).balanceOf(_account);

        require(
            _balance >= _paras.amount && _paras.amount > 0,
            "LP: Insufficient Balance"
        );

        StakeLPData storage _stakeLPData = stakeLPDatas[_account];

        StakeLPType _stakeType = StakeLPType.STAKING_HAS_DEADLINE;

        uint256 _stakeOrderId = _orderId;

        _stakeLPData.stakingOrderIds.push(_stakeOrderId);

        stakeLPOrderDatas[_stakeOrderId] = StakeLPOrderData({
            owner: _account,
            amount: _paras.amount,
            startTime: uint128(block.timestamp),
            endTime: uint128(block.timestamp + _paras.stakeDays * ONEDAY)
        });

        if (_paras.stakeDays == 0) {
            _stakeType = StakeLPType.STAKING_NO_DEADLINE;

            _stakeLPData.cash += _paras.amount;
        }

        unchecked {
            totalStakingLP += _paras.amount;

            _stakeLPData.totalStaking += _paras.amount;

            ++callCount;
        }

        orderStates[_orderId] = true;

        // transfer LP (account --> contract)
        IERC20(LPTOKEN).transferFrom(_account, address(this), _paras.amount);

        emit StakeLP(
            _orderId,
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
        uint256 _orderId,
        uint256[] calldata _amounts,
        uint256[] calldata _stakingOrderIds,
        uint256 _deadline,
        bytes calldata _signature
    ) external whenNotPaused nonReentrant returns (bool) {
        require(!orderStates[_orderId], "Invalid orderId");

        require(
            _amounts.length > 0 && _stakingOrderIds.length > 0,
            "Invalid Paras"
        );

        _verifyUnStakeLPOrYGIO(
            _orderId,
            _amounts,
            _stakingOrderIds,
            _deadline,
            _signature
        );

        address _account = _msgSender();

        uint256 _sumAmountLP;

        StakeLPData storage _stakeLPData = stakeLPDatas[_account];

        ++callCount;

        for (uint i = 0; i < _stakingOrderIds.length; ++i) {
            uint256 _stakingOrderId = _stakingOrderIds[i];

            StakeLPOrderData memory _data = stakeLPOrderDatas[_stakingOrderId];

            require(_data.owner == _account, "Invalid account");

            require(_amounts[i] <= _data.amount, "Invalid amounts");

            uint256 _len = _stakeLPData.stakingOrderIds.length;

            if (_amounts[i] < _data.amount) {
                require(_data.startTime == _data.endTime, "Must Unlimited");

                stakeLPOrderDatas[_stakingOrderId].amount =
                    _data.amount -
                    _amounts[i];
            } else {
                require(
                    _data.startTime == _data.endTime ||
                        block.timestamp >= _data.endTime,
                    "Too early to unStake"
                );

                for (uint256 j = 0; j < _len; ++j) {
                    if (_stakeLPData.stakingOrderIds[j] == _stakingOrderId) {
                        _stakeLPData.stakingOrderIds[j] = _stakeLPData
                            .stakingOrderIds[_len - 1];
                        _stakeLPData.stakingOrderIds.pop();
                        break;
                    }
                }

                delete stakeLPOrderDatas[_stakingOrderId];
            }

            StakeLPType stakeLPType = StakeLPType.UNSTAKEORDER;

            if (_data.startTime == _data.endTime) {
                _stakeLPData.cash -= _amounts[i];

                stakeLPType = StakeLPType.UNSTAKECASH;
            }

            unchecked {
                _sumAmountLP += _amounts[i];
            }

            emit StakeLP(
                _orderId,
                _account,
                _amounts[i],
                _data.startTime,
                _data.endTime,
                stakeLPType,
                _stakingOrderId,
                callCount,
                block.number
            );
        }

        {
            totalStakingLP -= _sumAmountLP;

            _stakeLPData.totalStaking -= _sumAmountLP;
        }

        orderStates[_orderId] = true;

        // transfer LP (contract --> account)
        IERC20(LPTOKEN).transfer(_account, _sumAmountLP);

        return true;
    }

    function stakingYGIO(
        uint256 _orderId,
        StakingYGIOParas calldata _paras,
        uint256 _deadline,
        bytes calldata _signature
    ) external whenNotPaused nonReentrant returns (bool) {
        require(!orderStates[_orderId], "Invalid orderId");

        address _account = _msgSender();

        require(stakingYGMEAmounts[_account] > 0, "Insufficient Staked YGME");

        _checkStakeDays(_paras.stakeDays);

        _verifyStakeYGIO(_orderId, _account, _paras, _deadline, _signature);

        uint256 _balance = IERC20(YGIO).balanceOf(_account);

        require(
            _balance >= _paras.amount && _paras.amount > 0,
            "YGIO: Insufficient Balance"
        );

        StakeYGIOData storage _stakeYGIOData = stakeYGIODatas[_account];

        StakeYGIOType _stakeType = StakeYGIOType.STAKING_HAS_DEADLINE;

        uint256 _stakeOrderId = _orderId;

        _stakeYGIOData.stakingOrderIds.push(_stakeOrderId);

        stakeYGIOOrderDatas[_stakeOrderId] = StakeYGIOOrderData({
            owner: _account,
            amount: _paras.amount,
            startTime: uint128(block.timestamp),
            endTime: uint128(block.timestamp + _paras.stakeDays * ONEDAY)
        });

        if (_paras.stakeDays == 0) {
            _stakeType = StakeYGIOType.STAKING_NO_DEADLINE;

            _stakeYGIOData.cash += _paras.amount;
        }
        unchecked {
            totalStakingYGIO += _paras.amount;

            _stakeYGIOData.totalStaking += _paras.amount;

            ++callCount;
        }

        orderStates[_orderId] = true;

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
        uint256 _orderId,
        uint256[] calldata _amounts,
        uint256[] calldata _stakingOrderIds,
        uint256 _deadline,
        bytes calldata _signature
    ) external whenNotPaused nonReentrant returns (bool) {
        require(!orderStates[_orderId], "Invalid orderId");

        require(
            _amounts.length > 0 && _stakingOrderIds.length > 0,
            "Invalid Paras"
        );

        _verifyUnStakeLPOrYGIO(
            _orderId,
            _amounts,
            _stakingOrderIds,
            _deadline,
            _signature
        );

        address _account = _msgSender();

        uint256 _sumAmountYGIO;

        StakeYGIOData storage _stakeYGIOData = stakeYGIODatas[_account];

        ++callCount;

        for (uint i = 0; i < _stakingOrderIds.length; ++i) {
            uint256 _stakingOrderId = _stakingOrderIds[i];

            StakeYGIOOrderData memory _data = stakeYGIOOrderDatas[
                _stakingOrderId
            ];

            require(_data.owner == _account, "Invalid account");

            require(_amounts[i] <= _data.amount, "Invalid amounts");

            uint256 _len = _stakeYGIOData.stakingOrderIds.length;

            if (_amounts[i] < _data.amount) {
                require(_data.startTime == _data.endTime, "Must Unlimited");

                stakeYGIOOrderDatas[_stakingOrderId].amount =
                    _data.amount -
                    _amounts[i];
            } else {
                require(
                    _data.startTime == _data.endTime ||
                        block.timestamp >= _data.endTime,
                    "Too early to unStake"
                );

                for (uint256 j = 0; j < _len; ++j) {
                    if (_stakeYGIOData.stakingOrderIds[j] == _stakingOrderId) {
                        _stakeYGIOData.stakingOrderIds[j] = _stakeYGIOData
                            .stakingOrderIds[_len - 1];
                        _stakeYGIOData.stakingOrderIds.pop();
                        break;
                    }
                }

                delete stakeYGIOOrderDatas[_stakingOrderId];
            }

            StakeYGIOType stakeYGIOType = StakeYGIOType.UNSTAKEORDER;

            if (_data.startTime == _data.endTime) {
                _stakeYGIOData.cash -= _amounts[i];

                stakeYGIOType = StakeYGIOType.UNSTAKECASH;
            }

            unchecked {
                _sumAmountYGIO += _amounts[i];
            }

            emit StakeYGIO(
                _account,
                _data.amount,
                _data.startTime,
                _data.endTime,
                stakeYGIOType,
                _stakingOrderId,
                callCount,
                block.number
            );
        }

        {
            totalStakingYGIO -= _sumAmountYGIO;

            _stakeYGIOData.totalStaking -= _sumAmountYGIO;
        }

        orderStates[_orderId] = true;

        // transfer YGIO
        IERC20(YGIO).transfer(_account, _sumAmountYGIO);

        return true;
    }

    function stakingYGME(
        uint256 _orderId,
        StakingYGMEParas calldata _paras,
        uint256 _deadline,
        bytes calldata _signature
    ) external whenNotPaused nonReentrant returns (bool) {
        require(!orderStates[_orderId], "Invalid orderId");

        uint256 _len = _paras.tokenIds.length;

        require(_len > 0, "Invalid tokenIds");

        address _account = _msgSender();

        _checkStakeDays(_paras.stakeDays);

        _verifyStakeYGME(_orderId, _account, _paras, _deadline, _signature);

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

            stakingTokenIds[_account].push(_tokenId);

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
        }

        orderStates[_orderId] = true;

        return true;
    }

    function unStakeYGME(
        uint256 _orderId,
        uint256[] calldata _tokenIds,
        uint256 _deadline,
        bytes calldata _signature
    ) external whenNotPaused nonReentrant returns (bool) {
        require(!orderStates[_orderId], "Invalid orderId");

        _verifyUnStakeYGME(_orderId, _tokenIds, _deadline, _signature);

        uint256 _length = _tokenIds.length;

        address _account = _msgSender();

        require(_length > 0, "Invalid tokenIds");

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

            delete stakingYGMEDatas[_tokenId];

            //transfer YGME
            IERC721(YGME).safeTransferFrom(address(this), _account, _tokenId);
        }

        totalStakingYGME -= _length;

        stakingYGMEAmounts[_account] -= _length;

        orderStates[_orderId] = true;

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

        require(!orderStates[orderId], "Invalid orderId");

        require(account == _msgSender(), "Invalid account");

        require(tokenAddress == YGIO, "Invalid tokenAddress");

        bytes32 _hash = keccak256(_data);

        _verifySignature(_hash, _signature);

        orderStates[orderId] = true;

        uint256 _balance = IERC20(tokenAddress).balanceOf(address(this));

        // Lock staked YGIO
        require(amount <= _balance - totalStakingYGIO, "YGIO Insufficient");

        unchecked {
            totalAccumulatedWithdraws += amount;

            accumulatedWithdrawRewards[account] += amount;
        }

        // transfer reward( contract--> account)
        IERC20(tokenAddress).transfer(account, amount);

        emit WithdrawReward(
            orderId,
            tokenAddress,
            account,
            amount,
            block.number
        );
        return true;
    }

    function _verifyStakeLP(
        uint256 _orderId,
        address _account,
        StakingLPParas calldata _paras,
        uint256 _deadline,
        bytes calldata _signature
    ) internal {
        require(block.timestamp < _deadline, "Signature has expired");

        if (minerRoles[_account] != MinerRole.NULL) {
            // _account is Old User

            return;
        } else {
            // _account is New User

            if (minerRoles[_paras.inviter] == MinerRole.MINER) {
                // _account's superior is not mineOwner

                // check superior's stakeLPAmount
                require(
                    stakeLPDatas[_paras.inviter].totalStaking > 0,
                    "Insufficient StakedLP Of inviter"
                );
            }

            bytes memory data = abi.encode(
                _orderId,
                _account,
                _paras.amount,
                _paras.stakeDays,
                _paras.inviter,
                _deadline
            );

            bytes32 hash = keccak256(data);

            _verifySignature(hash, _signature);

            inviters[_account] = _paras.inviter;

            minerRoles[_account] = MinerRole.MINER;
        }
    }

    function _verifyStakeYGIO(
        uint256 _orderId,
        address _account,
        StakingYGIOParas calldata _paras,
        uint256 _deadline,
        bytes calldata _signature
    ) internal view {
        require(block.timestamp < _deadline, "Signature has expired");

        bytes memory data = abi.encode(
            _orderId,
            _account,
            _paras.amount,
            _paras.stakeDays,
            _deadline
        );

        bytes32 _hash = keccak256(data);

        _verifySignature(_hash, _signature);
    }

    function _verifyStakeYGME(
        uint256 _orderId,
        address _account,
        StakingYGMEParas calldata _paras,
        uint256 _deadline,
        bytes calldata _signature
    ) internal view {
        require(block.timestamp < _deadline, "Signature has expired");

        bytes memory data = abi.encode(
            _orderId,
            _account,
            _paras.tokenIds,
            _paras.stakeDays,
            _deadline
        );

        bytes32 _hash = keccak256(data);

        _verifySignature(_hash, _signature);
    }

    function _verifyMinerOwner(
        uint256 _orderId,
        uint256 _applyType,
        address _account,
        MinerRole _mineRole,
        uint256 _deadline,
        bytes calldata _signature
    ) internal view {
        require(block.timestamp < _deadline, "Signature expired");

        bytes memory data = abi.encode(
            _orderId,
            _applyType,
            _account,
            _mineRole,
            _deadline
        );

        bytes32 _hash = keccak256(data);

        _verifySignature(_hash, _signature);
    }

    function _verifyUnStakeLPOrYGIO(
        uint256 _orderId,
        uint256[] calldata _amounts,
        uint256[] calldata _stakingOrderIds,
        uint256 _deadline,
        bytes calldata _signature
    ) internal view {
        require(block.timestamp < _deadline, "Signature has expired");

        bytes memory data = abi.encode(
            _orderId,
            _amounts,
            _stakingOrderIds,
            _deadline
        );

        bytes32 _hash = keccak256(data);

        _verifySignature(_hash, _signature);
    }

    function _verifyUnStakeYGME(
        uint256 _orderId,
        uint256[] calldata _tokenIds,
        uint256 _deadline,
        bytes calldata _signature
    ) internal view {
        require(block.timestamp < _deadline, "Signature has expired");

        bytes memory data = abi.encode(_orderId, _tokenIds, _deadline);

        bytes32 _hash = keccak256(data);

        _verifySignature(_hash, _signature);
    }

    function _verifySignature(
        bytes32 _hash,
        bytes calldata _signature
    ) internal view {
        _hash = _hash.toEthSignedMessageHash();

        address signer = _hash.recover(_signature);

        require(signer == systemSigner, "Invalid signature");
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
