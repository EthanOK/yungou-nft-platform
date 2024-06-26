// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

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

interface IYGIOStake {
    function getMulFactor(
        address account
    ) external pure returns (uint256 numerator, uint256 denominator);
}

abstract contract PoolsOfLPDomain {
    enum StakeState {
        NULL,
        STAKING,
        UNSTAKE,
        CONTINUESTAKE
    }

    struct StakeLPData {
        uint256 amountLP;
        uint256 amountLPWorking;
        // Accumulated income after staking settlement (stake again, or cancel staking)
        uint256 accruedIncomeYGIO;
        uint128 startBlockNumber;
        uint128 endBlockNumber;
    }

    struct InviterLPData {
        uint256 amountLPWorking;
        uint256 accruedIncomeYGIO;
        uint256 startBlockNumber;
    }

    event StakeLP(
        address indexed account,
        uint256 amount,
        uint256 startBlock,
        uint256 endBlock,
        uint256 countStakeLP,
        StakeState state
    );
}

contract PoolsOfLP is
    PoolsOfLPDomain,
    Pausable,
    AccessControl,
    ReentrancyGuard
{
    using ECDSA for bytes32;

    bytes32 public constant OWNER_ROLE = keccak256("OWNER_ROLE");
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    address public constant ZERO_ADDRESS = address(0);
    uint256 public constant REWARDRATE_BASE = 10_000;
    uint256 public constant ONEDAY = 1 days;

    address public immutable LPTOKEN_YGIO_USDT;
    address public immutable YGIO_STAKE;
    address public immutable YGIO;

    string private poolName;

    address private inviteeSigner;

    // one Cycle have 1 Block
    uint32 private oneCycle_BlockNumber = 1;

    // one Cycle YGIO Reward Per LP
    uint256 private oneCycle_Reward = 10_000_000;

    // Mine Owner
    address private mineOwner;

    // max reward Level
    uint8 public rewardLevelMax;

    // Mine Owner reward rate
    // uint32 private poolOwnerRate;

    // reward Rates
    uint32[8] private rewardRates;

    // become Mine Owner Amount
    uint256 private amountMineOwner;

    // total Staking LP Amount(Not included Balance of Pool Mine Owner)
    uint256 private totalStakingLP;

    // balance Pool Mine Owner
    uint256 private balancePoolOwner;

    // current Withdraw LP Amount Mine Owner
    uint256 private currentWithdrawLPAmount;

    // in one Cycle StakingVolume total StakingVolume
    // uint256 private StakingVolumeInOneCycle;

    // oneCycle Of Update Withdraw LP Amount
    uint128 private oneCycle_Days = 1 days;

    // lastest Update Time Of Withdraw LP Amount
    uint128 private lastestUpdateTime;

    // one week Stake Increment Amounts
    // weekStakeIncrementVolumes[0] : cureent Staking Volume In days
    uint256[8] private weekStakeIncrementVolumes;

    uint256 private countStakeLP;

    // invitee =>  inviter
    mapping(address => address) private inviters;

    // account => StakeLPData
    mapping(address => StakeLPData) private stakeLPDatas;

    // inviter => InviterLPData
    mapping(address => InviterLPData) private inviterLPDatas;

    //address withdrawed YGIO SUM
    mapping(address => uint256) amountWithdrawed;

    // TODO:_amount = 100_000 LP
    constructor(
        string memory _poolName,
        uint256 _amount,
        address _inviteeSigner,
        address _ygio,
        address _stake,
        address _lptoken
    ) {
        YGIO = _ygio;
        YGIO_STAKE = _stake;
        LPTOKEN_YGIO_USDT = _lptoken;

        _setupRole(DEFAULT_ADMIN_ROLE, tx.origin);

        _setupRole(OWNER_ROLE, tx.origin);

        poolName = _poolName;

        amountMineOwner = _amount * 1e18;

        inviteeSigner = _inviteeSigner;

        // [mineOwner, inviter1,inviter2,...,inviter5]
        rewardRates = [uint32(200), 500, 400, 300, 200, 100, 0, 0];

        rewardLevelMax = 5;
    }

    function setPause() external onlyRole(OWNER_ROLE) {
        if (!paused()) {
            _pause();
        } else {
            _unpause();
        }
    }

    function setRewardLevelMax(
        uint8 _rewardLevelMax
    ) external onlyRole(OWNER_ROLE) {
        rewardLevelMax = _rewardLevelMax;
    }

    function updateRewardRates(
        uint32[8] calldata _rewardRates
    ) external onlyRole(OWNER_ROLE) {
        rewardRates = _rewardRates;
    }

    function getPoolName() external view returns (string memory) {
        return poolName;
    }

    function getPoolFactor() external view returns (uint256, uint256) {
        return _getPoolFactor();
    }

    function getMineOwner() external view returns (address) {
        return mineOwner;
    }

    function getTotalStakeLP() external view returns (uint256) {
        return totalStakingLP;
    }

    function getInviteTotalBenefit(
        address _account
    ) external view returns (uint256) {
        return _getInviteTotalBenefit(_account);
    }

    function getTotalBenefit(address _account) external view returns (uint256) {
        return _getTotalBenefit(_account);
    }

    function getStakeTotalBenefit(
        address _account
    ) external view returns (uint256) {
        return _getStakeTotalBenefit(_account);
    }

    function getStakeIncrementVolumesInweek()
        external
        view
        returns (uint256[8] memory)
    {
        return weekStakeIncrementVolumes;
    }

    function getStakeLPData(
        address _account
    ) external view returns (StakeLPData memory) {
        return stakeLPDatas[_account];
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

    function getCurrentWithdrawLPAmountOfMineOwner()
        external
        view
        returns (uint256)
    {
        return currentWithdrawLPAmount;
    }

    function getLastestUpdateTime() external view returns (uint256) {
        return lastestUpdateTime;
    }

    function becomeMineOwner(
        bytes calldata _signature
    ) external whenNotPaused nonReentrant onlyNewPoolOwner(_signature) {
        require(mineOwner == ZERO_ADDRESS, "Mine owner exists");

        address poolOwner = _msgSender();

        // check condition
        require(
            IPancakePair(LPTOKEN_YGIO_USDT).balanceOf(poolOwner) >=
                amountMineOwner,
            "Insufficient balance of LP"
        );

        mineOwner = poolOwner;

        balancePoolOwner = amountMineOwner;

        lastestUpdateTime = _currentTimeStampRound();

        // transfer LP
        IPancakePair(LPTOKEN_YGIO_USDT).transferFrom(
            poolOwner,
            address(this),
            amountMineOwner
        );
    }

    function stakingLP(
        uint256 _amountLP,
        address _inviter,
        bytes calldata _signature
    ) external whenNotPaused nonReentrant onlyInvited(_inviter, _signature) {
        address _account = _msgSender();

        uint256 _balance = IPancakePair(LPTOKEN_YGIO_USDT).balanceOf(_account);

        require(
            _balance >= _amountLP && _amountLP > 0,
            "Insufficient balance of LP"
        );

        StakeLPData storage _stakelPData = stakeLPDatas[_account];

        // The user has lp working
        if (_stakelPData.amountLPWorking > 0) {
            {
                // caculate LP Working Reward
                uint256 rewardYGIO = _caculateLPWorkingReward(
                    _account,
                    _stakelPData.amountLPWorking,
                    _stakelPData.startBlockNumber,
                    uint128(block.number)
                );

                unchecked {
                    _stakelPData.accruedIncomeYGIO += rewardYGIO;

                    _stakelPData.amountLP += _amountLP;
                }
            }

            uint256 _amountLPWorking = _getAmountLPWorking(
                _account,
                _stakelPData.amountLP
            );

            _stakelPData.amountLPWorking = _amountLPWorking;

            _stakelPData.startBlockNumber = uint128(block.number);
        } else {
            _stakelPData.amountLP = _amountLP;

            _stakelPData.amountLPWorking = _getAmountLPWorking(
                _account,
                _amountLP
            );

            _stakelPData.startBlockNumber = uint128(block.number);
        }

        unchecked {
            totalStakingLP += _amountLP;
            ++countStakeLP;
        }

        // update Inviters Reward
        _updateInvitersRewardAdd(_account, _amountLP);

        _updateWithdrawLPAmount(_amountLP);

        // transfer LP
        IPancakePair(LPTOKEN_YGIO_USDT).transferFrom(
            _account,
            address(this),
            _amountLP
        );

        emit StakeLP(
            _account,
            _amountLP,
            _stakelPData.startBlockNumber,
            _stakelPData.endBlockNumber,
            countStakeLP,
            StakeState.STAKING
        );
    }

    function unStakeLP2(
        uint256 _amountRemove
    ) external whenNotPaused nonReentrant returns (bool) {
        address _account = _msgSender();

        StakeLPData storage _stakeLPData = stakeLPDatas[_account];

        require(
            _amountRemove <= _stakeLPData.amountLP &&
                _amountRemove <= totalStakingLP,
            "Invalid _amountRemove"
        );

        uint256 _amountLPWorkingRemove = _getAmountLPWorking(
            _account,
            _amountRemove
        );

        require(
            _amountLPWorkingRemove <= _stakeLPData.amountLPWorking,
            "Insufficient _amountLPWorking"
        );

        uint256 _currentStakingReward = _caculateLPWorkingReward(
            _account,
            _stakeLPData.amountLPWorking,
            _stakeLPData.startBlockNumber,
            uint128(block.number)
        );

        unchecked {
            _stakeLPData.accruedIncomeYGIO += _currentStakingReward;

            _stakeLPData.amountLPWorking -= _amountLPWorkingRemove;

            _stakeLPData.amountLP -= _amountRemove;

            totalStakingLP -= _amountRemove;

            ++countStakeLP;
        }

        _stakeLPData.endBlockNumber = uint128(block.number);

        if (_stakeLPData.amountLP > 0) {
            _stakeLPData.startBlockNumber = uint128(block.number);
        }

        // update Inviters Reward
        _updateInvitersRewardRemove(_account, _amountRemove);

        _updateWithdrawLPAmount(0);

        // transfer LP
        IPancakePair(LPTOKEN_YGIO_USDT).transfer(_account, _amountRemove);

        emit StakeLP(
            _account,
            _amountRemove,
            _stakeLPData.startBlockNumber,
            _stakeLPData.endBlockNumber,
            countStakeLP,
            StakeState.UNSTAKE
        );

        return true;
    }

    function unStakeLP() external whenNotPaused nonReentrant returns (bool) {
        address _account = _msgSender();

        StakeLPData storage _stakeLPData = stakeLPDatas[_account];

        uint256 _currentStakingReward = _caculateLPWorkingReward(
            _account,
            _stakeLPData.amountLPWorking,
            _stakeLPData.startBlockNumber,
            uint128(block.number)
        );

        unchecked {
            _stakeLPData.accruedIncomeYGIO += _currentStakingReward;
        }

        uint256 _amountLP = _stakeLPData.amountLP;

        delete _stakeLPData.amountLPWorking;

        delete _stakeLPData.amountLP;

        _stakeLPData.endBlockNumber = uint128(block.number);

        // update Inviters Reward
        _updateInvitersRewardRemove(_account, _amountLP);

        _updateWithdrawLPAmount(0);

        require(_amountLP <= totalStakingLP, "unStake Fail");

        unchecked {
            totalStakingLP -= _amountLP;

            ++countStakeLP;
        }

        // transfer LP
        IPancakePair(LPTOKEN_YGIO_USDT).transfer(_account, _amountLP);

        emit StakeLP(
            _account,
            _amountLP,
            _stakeLPData.startBlockNumber,
            _stakeLPData.endBlockNumber,
            countStakeLP,
            StakeState.UNSTAKE
        );

        return true;
    }

    function withdrawYGIO(
        uint256 _amount
    ) external whenNotPaused nonReentrant returns (bool) {
        unchecked {
            address _account = _msgSender();

            StakeLPData storage _stakelPData = stakeLPDatas[_account];

            if (_stakelPData.amountLPWorking > 0) {
                // update YGIO Reward In staking
                uint256 rewardYGIO = _caculateLPWorkingReward(
                    _account,
                    _stakelPData.amountLPWorking,
                    _stakelPData.startBlockNumber,
                    uint128(block.number)
                );

                _stakelPData.accruedIncomeYGIO += rewardYGIO;

                _stakelPData.startBlockNumber = uint128(block.number);
            }

            uint256 _total = _getTotalBenefit(_account);

            uint256 _amountWithdrawed = amountWithdrawed[_account];

            require(
                _amountWithdrawed <= _total,
                "Insufficient amountWithdrawed"
            );

            uint256 _remain = _total - _amountWithdrawed;

            require(_amount <= _remain, "Insufficient for withdrawal");

            amountWithdrawed[_account] += _amount;

            IERC20(YGIO).transfer(_account, _amount);
        }

        return true;
    }

    function withdrawLPOnlyMineOwner(
        uint256 _amount
    ) external whenNotPaused nonReentrant returns (bool) {
        address _account = _msgSender();

        require(_account == mineOwner, "Must mineOwner");

        require(_amount <= currentWithdrawLPAmount, "Withdrawal restrictions");

        require(_amount <= balancePoolOwner, "Insufficient balancePoolOwner");

        currentWithdrawLPAmount -= _amount;

        balancePoolOwner -= _amount;

        _updateWithdrawLPAmount(0);

        // transfer LP
        IPancakePair(LPTOKEN_YGIO_USDT).transfer(_account, _amount);

        return true;
    }

    function updateIncrementEveryDay()
        external
        whenNotPaused
        nonReentrant
        returns (bool)
    {
        _updateWithdrawLPAmount(0);
        return true;
    }

    // Return YGIO Reward(MUL Factor)
    function _caculateLPWorkingReward(
        address _account,
        uint256 _amountLPWorking,
        uint128 _startBlockNumber,
        uint128 _endBlockNumber
    ) internal view returns (uint256) {
        // working Cycle Number
        uint256 cycleNumber;

        unchecked {
            cycleNumber =
                (_endBlockNumber - _startBlockNumber) /
                oneCycle_BlockNumber;
        }

        if (cycleNumber == 0) {
            return 0;
        } else {
            uint256 _reward = cycleNumber * oneCycle_Reward * _amountLPWorking;

            // account Factor
            (uint256 _numerator, uint256 _denominator) = IYGIOStake(YGIO_STAKE)
                .getMulFactor(_account);

            (
                uint256 _numeratorPool,
                uint256 _denominatorPool
            ) = _getPoolFactor();

            _reward =
                (_reward * _numerator * _numeratorPool) /
                (_denominator * _denominatorPool);

            return _reward;
        }
    }

    modifier onlyInvited(address inviter, bytes calldata signature) {
        address invitee = _msgSender();

        require(invitee != mineOwner, "Mine owner cannot participate");

        if (inviters[invitee] == ZERO_ADDRESS) {
            if (inviter != mineOwner) {
                // Is the inviter valid?
                require(inviters[inviter] != ZERO_ADDRESS, "Invalid inviter");
            }
            // Whether the invitee has been invited?
            bytes memory data = abi.encode(invitee, inviter, address(this));

            bytes32 hash = keccak256(data);

            _verifySignature(hash, signature);

            inviters[invitee] = inviter;
        }
        _;
    }

    modifier onlyNewPoolOwner(bytes calldata _signature) {
        address poolOwner = _msgSender();

        bytes memory data = abi.encode(poolOwner, address(this));

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

    function _getPoolFactor() internal view returns (uint256, uint256) {
        // TODO 依据池子LP质押量动态变动 base 10000

        uint256 _numerator;

        if (totalStakingLP < 1000 * 1e18) {
            _numerator = 100;
        } else if (totalStakingLP < 10000 * 1e18) {
            _numerator = 120;
        } else if (totalStakingLP < 50000 * 1e18) {
            _numerator = 150;
        } else if (totalStakingLP < 100000 * 1e18) {
            _numerator = 180;
        } else if (totalStakingLP < 500000 * 1e18) {
            _numerator = 200;
        } else if (totalStakingLP < 1000000 * 1e18) {
            _numerator = 220;
        } else {
            _numerator = 250;
        }

        return (_numerator, 100);
    }

    function _updateInvitersRewardAdd(
        address _invitee,
        uint256 _amountLP
    ) internal {
        (
            address[] memory _mineOwnerAndInviters,
            uint256 _number
        ) = _queryMineOwnerAndInviters(_invitee, rewardLevelMax);

        for (uint i = 0; i < _number; ++i) {
            unchecked {
                InviterLPData storage _inviterLPData = inviterLPDatas[
                    _mineOwnerAndInviters[i]
                ];

                uint256 _rewardLPWorking = (_amountLP * rewardRates[i]) /
                    REWARDRATE_BASE;

                if (_inviterLPData.startBlockNumber == uint128(block.number)) {
                    _inviterLPData.amountLPWorking += _rewardLPWorking;
                } else {
                    // caculate inviter reward YGIO
                    uint256 _inviterRewardYGIO = _caculateInviterRewardYGIO(
                        _inviterLPData.amountLPWorking,
                        _inviterLPData.startBlockNumber
                    );

                    _inviterLPData.accruedIncomeYGIO += _inviterRewardYGIO;

                    _inviterLPData.amountLPWorking += _rewardLPWorking;

                    _inviterLPData.startBlockNumber = uint128(block.number);
                }
            }
        }
    }

    function _caculateInviterRewardYGIO(
        uint256 _amountLPWorking,
        uint256 _startBlockNumber
    ) internal view returns (uint256) {
        uint256 _rewardOneBlockOneLP = oneCycle_Reward / oneCycle_BlockNumber;

        uint256 _inviterRewardYGIO = _rewardOneBlockOneLP *
            _amountLPWorking *
            (uint128(block.number - _startBlockNumber));

        return _inviterRewardYGIO;
    }

    function _updateInvitersRewardRemove(
        address _invitee,
        uint256 _amountLP
    ) internal {
        (
            address[] memory _mineOwnerAndInviters,
            uint256 _number
        ) = _queryMineOwnerAndInviters(_invitee, rewardLevelMax);

        for (uint i = 0; i < _number; ++i) {
            InviterLPData storage _inviterLPData = inviterLPDatas[
                _mineOwnerAndInviters[i]
            ];

            uint256 _rewardLPWorking = (_amountLP * rewardRates[i]) /
                REWARDRATE_BASE;

            if (_inviterLPData.startBlockNumber == block.number) {
                _inviterLPData.amountLPWorking -= _rewardLPWorking;
            } else {
                // caculate inviter reward YGIO
                uint256 _inviterRewardYGIO = _caculateInviterRewardYGIO(
                    _inviterLPData.amountLPWorking,
                    _inviterLPData.startBlockNumber
                );

                _inviterLPData.accruedIncomeYGIO += _inviterRewardYGIO;

                _inviterLPData.amountLPWorking -= _rewardLPWorking;

                _inviterLPData.startBlockNumber = block.number;
            }
        }
    }

    function _getAmountLPWorking(
        address _account,
        uint256 _amountLP
    ) internal view returns (uint256 _amountLPWorking) {
        (, uint256 _number) = _queryMineOwnerAndInviters(
            _account,
            rewardLevelMax
        );

        uint32 rateSum;

        for (uint i = 0; i < _number; i++) {
            rateSum += rewardRates[i];
        }

        _amountLPWorking = _amountLP - (_amountLP * rateSum) / REWARDRATE_BASE;
    }

    function _getInviteTotalBenefit(
        address _account
    ) internal view returns (uint256) {
        InviterLPData memory _inviterLPData = inviterLPDatas[_account];

        uint256 _inviterRewardYGIO = _caculateInviterRewardYGIO(
            _inviterLPData.amountLPWorking,
            _inviterLPData.startBlockNumber
        );

        return _inviterLPData.accruedIncomeYGIO + _inviterRewardYGIO;
    }

    function _getStakeTotalBenefit(
        address _account
    ) internal view returns (uint256) {
        if (_account == mineOwner) return 0;
        StakeLPData memory _stakeLPData = stakeLPDatas[_account];
        if (_stakeLPData.endBlockNumber > _stakeLPData.startBlockNumber) {
            return _stakeLPData.accruedIncomeYGIO;
        } else {
            uint256 _currentStakingReward = _caculateLPWorkingReward(
                _account,
                _stakeLPData.amountLPWorking,
                _stakeLPData.startBlockNumber,
                uint128(block.number)
            );
            return _currentStakingReward + _stakeLPData.accruedIncomeYGIO;
        }
    }

    function _queryMineOwnerAndInviters(
        address _invitee,
        uint256 _numberLayers
    ) internal view returns (address[] memory, uint256) {
        address[] memory _inviters = new address[](_numberLayers + 1);

        _inviters[0] = mineOwner;

        uint256 _number = 1;

        for (uint i = 0; i < _numberLayers; ) {
            _invitee = inviters[_invitee];

            if (_invitee == ZERO_ADDRESS) break;

            _inviters[i + 1] = _invitee;

            unchecked {
                _number += 1;

                ++i;
            }
        }

        return (_inviters, _number);
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

    function _getTotalBenefit(
        address _account
    ) internal view returns (uint256) {
        return
            _getInviteTotalBenefit(_account) + _getStakeTotalBenefit(_account);
    }

    function _updateWithdrawLPAmount(uint256 _amount) internal {
        unchecked {
            if (block.timestamp < lastestUpdateTime + ONEDAY) {
                weekStakeIncrementVolumes[0] += _amount;
            } else {
                currentWithdrawLPAmount += weekStakeIncrementVolumes[0] / 2;

                uint256 day_ = (block.timestamp - lastestUpdateTime) / ONEDAY;

                day_ = day_ > 7 ? 7 : day_;

                for (uint256 i = 0; i <= 7 - day_; ++i) {
                    weekStakeIncrementVolumes[
                        7 - i
                    ] = weekStakeIncrementVolumes[7 - day_ - i];
                }

                for (uint256 j = 1; j < day_; ++j) {
                    delete weekStakeIncrementVolumes[j];
                }

                lastestUpdateTime = _currentTimeStampRound();

                weekStakeIncrementVolumes[0] = _amount;
            }
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
