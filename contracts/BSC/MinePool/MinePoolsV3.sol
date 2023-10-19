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

    bytes4 public constant ERC20_TRANSFER_SELECTOR = 0xa9059cbb;
    address public constant ZERO_ADDRESS = address(0);
    // TODO:uint256 public constant ONEDAY = 1 days;
    uint256 public ONEDAY = 1;

    // TODO:immutable
    address public YGIO;
    address public YGME;
    address public LPTOKEN;

    address private systemSigner;

    Counters.Counter private _currentStakingLPOrderId;
    Counters.Counter private _currentStakingYGIOOrderId;

    uint256 private rewardsTotal = 100_000_000 * 1e18;

    // stakingDays 0 100 300 0
    uint64[4] private stakingDays;

    uint256 private callCount;

    uint256[] private poolIds;

    // poolId => mineOwner
    mapping(uint256 => address) private mineOwners;

    // mineOwner => lp balance
    mapping(address => uint256) private balanceMineOwners;

    // poolId => total stakingLPAmount
    mapping(uint256 => uint256) private stakingLPAmountsOfPool;

    // account => poolId
    mapping(address => uint256) private poolIdOfAccount;

    // invitee => inviter
    mapping(address => address) private inviters;

    // withdrawOrderIds => bool
    mapping(uint256 => bool) private withdrawOrderIds;

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

    function setSigner(address _signer) external onlyOwner {
        systemSigner = _signer;
    }

    function getStakingDays() external view returns (uint64[4] memory) {
        return stakingDays;
    }

    function getOrderState(uint256 _orderId) external view returns (bool) {
        return withdrawOrderIds[_orderId];
    }

    function getMineOwner(uint256 _poolNumber) external view returns (address) {
        return mineOwners[_poolNumber];
    }

    function getSigner() external view onlyOwner returns (address) {
        return systemSigner;
    }

    function getPoolIds() external view returns (uint256[] memory) {
        return poolIds;
    }

    function getPoolNumber() external view returns (uint256) {
        return poolIds.length;
    }

    function getTotalStakeLPAll() external view returns (uint256) {
        return totalStakingLP;
    }

    function getTotalStakeLP(address _account) external view returns (uint256) {
        uint256 _poolId = poolIdOfAccount[_account];

        if (_account == mineOwners[_poolId]) {
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
        uint256 _poolId,
        uint256 _amount,
        uint256 _deadline,
        bytes calldata _signature
    ) external whenNotPaused nonReentrant returns (bool) {
        require(_poolId > 0, "Invalid PoolNumber");

        require(mineOwners[_poolId] == ZERO_ADDRESS, "poolNumber exists");

        address _poolOwner = _msgSender();

        _verifyMinerOwner(_poolId, _poolOwner, _amount, _deadline, _signature);

        require(
            IERC20(LPTOKEN).balanceOf(_poolOwner) >= _amount,
            "Insufficient balance of LP"
        );

        mineOwners[_poolId] = _poolOwner;

        balanceMineOwners[_poolOwner] = _amount;

        poolIdOfAccount[_poolOwner] = _poolId;

        poolIds.push(_poolId);

        unchecked {
            totalStakingLP += _amount;

            stakingLPAmountsOfPool[_poolId] += _amount;
        }

        // transfer LP (account --> contract)
        IERC20(LPTOKEN).transferFrom(_poolOwner, address(this), _amount);

        emit NewLPPool(_poolId, _poolOwner, _amount, block.number);

        return true;
    }

    function applyWithdrawLP(
        uint256 _orderId,
        uint256 _poolNumber,
        uint256 _amount,
        uint256 _deadline,
        bytes calldata _signature
    )
        external
        whenNotPaused
        nonReentrant
        onlyMineOwner(_poolNumber)
        returns (bool)
    {
        require(!withdrawOrderIds[_orderId], "Invalid orderId");

        address _account = _msgSender();

        require(block.timestamp < _deadline, "Signature expired");

        bytes memory data = abi.encode(
            _orderId,
            _poolNumber,
            _account,
            _amount,
            _deadline
        );

        bytes32 _hash = keccak256(data);

        _verifySignature(_hash, _signature);

        {
            balanceMineOwners[_account] -= _amount;

            totalStakingLP -= _amount;

            stakingLPAmountsOfPool[_poolNumber] -= _amount;
        }

        withdrawOrderIds[_orderId] = true;

        // transfer LP (contract --> account)
        IERC20(LPTOKEN).transfer(_account, _amount);

        emit RemoveLPPool(_poolNumber, _account, _amount, block.number);

        return true;
    }

    function stakingLP(
        StakingLPParas calldata _paras,
        bytes calldata _signature
    ) external whenNotPaused nonReentrant returns (bool) {
        address _account = _msgSender();

        _checkStakeDays(_paras.stakeDays);

        _verifyStakeLP(_account, _paras, _signature);

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
                    poolId: _paras.poolId,
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

            stakingLPAmountsOfPool[_paras.poolId] += _paras.amount;

            stakingLPDays[_account] += _paras.stakeDays;

            ++callCount;
        }

        // transfer LP (account --> contract)
        IERC20(LPTOKEN).transferFrom(_account, address(this), _paras.amount);

        emit StakeLP(
            _paras.poolId,
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
        uint256 _poolNumber,
        uint256 _amountCash,
        uint256[] calldata _stakingOrderIds
    ) external whenNotPaused nonReentrant returns (bool) {
        require(!withdrawOrderIds[_orderId], "Invalid orderId");

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

                require(_data.poolId == _poolNumber, "Invalid poolNumber");

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

        withdrawOrderIds[_orderId] = true;

        // transfer LP (contract --> account)
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
        uint256 _orderId,
        uint256 _amountCash,
        uint256[] calldata _stakingOrderIds
    ) external whenNotPaused nonReentrant returns (bool) {
        require(!withdrawOrderIds[_orderId], "Invalid orderId");

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

        withdrawOrderIds[_orderId] = true;

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

        require(!withdrawOrderIds[orderId], "Invalid orderId");

        require(account == _msgSender(), "Invalid account");

        bytes32 _hash = keccak256(_data);

        _verifySignature(_hash, _signature);

        withdrawOrderIds[orderId] = true;

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

    function _verifyStakeLP(
        address _invitee,
        StakingLPParas calldata _paras,
        bytes calldata _signature
    ) internal {
        require(block.timestamp < _paras.deadline, "Signature has expired");

        require(
            mineOwners[_paras.poolId] != ZERO_ADDRESS && _paras.poolId > 0,
            "Invalid poolNumber"
        );

        if (poolIdOfAccount[_invitee] > 0) {
            // _account is Old User

            require(
                poolIdOfAccount[_invitee] == _paras.poolId,
                "Error poolNumber"
            );

            return;
        } else {
            // _account is New User

            // check superior's poolId, superior is old user
            require(
                poolIdOfAccount[_paras.inviter] == _paras.poolId,
                "Invalid poolId"
            );

            if (_paras.inviter != mineOwners[_paras.poolId]) {
                // _account's superior is not mineOwner

                // check superior's stakeLPAmount
                require(
                    stakeLPDatas[_paras.inviter].totalStaking > 0,
                    "Insufficient StakedLP Of inviter"
                );
            }

            bytes memory data = abi.encode(
                _paras.poolId,
                _invitee,
                _paras.inviter,
                _paras.deadline
            );

            bytes32 hash = keccak256(data);

            _verifySignature(hash, _signature);

            inviters[_invitee] = _paras.inviter;

            poolIdOfAccount[_invitee] = _paras.poolId;
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

    function _verifyMinerOwner(
        uint256 _poolNumber,
        address _account,
        uint256 _amount,
        uint256 _deadline,
        bytes calldata _signature
    ) internal view {
        require(poolIdOfAccount[_account] == 0, "Invalid poolOwner");

        require(block.timestamp < _deadline, "Signature expired");

        bytes memory data = abi.encode(
            _poolNumber,
            _account,
            _amount,
            _deadline
        );

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

    modifier onlyMineOwner(uint256 _poolNumber) {
        require(
            mineOwners[_poolNumber] == _msgSender(),
            "caller not MineOwner"
        );
        _;
    }
}
