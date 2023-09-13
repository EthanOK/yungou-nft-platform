// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract YGIOStaking is Pausable, Ownable, ReentrancyGuard {
    using Counters for Counters.Counter;

    enum StakeType {
        UNSTAKE,
        STAKING,
        UNSTAKEONLYOWNER
    }
    struct StakingData {
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
        StakeType indexed stakeType,
        uint256 indexed blockNumber
    );
    // constant:
    address public constant YGIO = 0xb06DcE9ae21c3b9163cD933E40c9EE563366b783;

    uint64 public constant ONE_CYCLE = 1 days;

    // variable:
    uint64[4] private stakingPeriods;

    // account => stakingOrderIds
    mapping(address => uint256[]) private stakingOrderIds;

    // stakingOrderId => StakingData
    mapping(uint256 => StakingData) private stakingDatas;

    Counters.Counter private _currentStakingOrderId;

    // Total account amount in Staking
    uint256 public accountStakingTotal;

    // Total YGIO amount in Staking
    uint256 public ygioStakingTotal;

    constructor() {
        stakingPeriods = [
            30 * ONE_CYCLE,
            90 * ONE_CYCLE,
            180 * ONE_CYCLE,
            360 * ONE_CYCLE
        ];
    }

    function setPause() external onlyOwner {
        if (!paused()) {
            _pause();
        } else {
            _unpause();
        }
    }

    function setStakingPeriods(uint64[4] calldata _days) external onlyOwner {
        for (uint i = 0; i < _days.length; i++) {
            stakingPeriods[i] = _days[i] * ONE_CYCLE;
        }
    }

    function getStakingOrderIds(
        address _account
    ) external view returns (uint256[] memory) {
        return stakingOrderIds[_account];
    }

    function getStakingData(
        uint256 _stakingOrderId
    ) external view returns (StakingData memory) {
        return stakingDatas[_stakingOrderId];
    }

    function getMulFactor(
        address _account
    ) external view returns (uint256 numerator, uint256 denominator) {
        uint256 weight = _caculateStakingWeight(_account);

        unchecked {
            numerator = weight + ygioStakingTotal;
            denominator = ygioStakingTotal;
        }
    }

    //_level: 1 ~ 4
    function stakingYGIO(
        uint256 _amount,
        uint256 _stakeDays
    ) external whenNotPaused nonReentrant {
        require(_amount > 0, "Invalid _amount");

        uint256 _stakeTime = _stakeDays * ONE_CYCLE;

        address _account = _msgSender();

        require(
            _stakeTime == stakingPeriods[0] ||
                _stakeTime == stakingPeriods[1] ||
                _stakeTime == stakingPeriods[2] ||
                _stakeTime == stakingPeriods[3],
            "Invalid stake time"
        );

        if (stakingOrderIds[_account].length == 0) {
            unchecked {
                accountStakingTotal += 1;
            }
        }

        uint256 _balance = IERC20(YGIO).balanceOf(_account);

        require(_amount <= _balance, "Insufficient balance");

        _currentStakingOrderId.increment();

        uint256 _stakeOrderId = _currentStakingOrderId.current();

        StakingData memory _data = StakingData({
            owner: _account,
            amount: _amount,
            startTime: uint128(block.timestamp),
            endTime: uint128(block.timestamp + _stakeTime)
        });

        stakingDatas[_stakeOrderId] = _data;

        if (stakingOrderIds[_account].length == 0) {
            stakingOrderIds[_account] = [_stakeOrderId];
        } else {
            stakingOrderIds[_account].push(_stakeOrderId);
        }

        IERC20(YGIO).transferFrom(_account, address(this), _amount);

        emit StakeYGIO(
            _stakeOrderId,
            _account,
            _amount,
            _data.startTime,
            _data.endTime,
            StakeType.STAKING,
            block.number
        );
        unchecked {
            ygioStakingTotal += _amount;
        }
    }

    function unStakeYGIO(
        uint256[] calldata _stakingOrderIds
    ) external whenNotPaused nonReentrant {
        uint256 _length = _stakingOrderIds.length;
        require(_length > 0, "Invalid stakeOrderIds");
        address _account = _msgSender();
        uint256 _sumAmount;

        for (uint256 i = 0; i < _length; ++i) {
            uint256 _stakingOrderId = _stakingOrderIds[i];

            StakingData memory _data = stakingDatas[_stakingOrderId];

            require(_data.owner == _account, "Invalid account");

            require(
                block.timestamp >= _data.endTime,
                "Not yet time to unStake"
            );

            uint256 _len = stakingOrderIds[_account].length;

            for (uint256 j = 0; j < _len; ++j) {
                if (stakingOrderIds[_account][j] == _stakingOrderId) {
                    stakingOrderIds[_account][j] = stakingOrderIds[_account][
                        _len - 1
                    ];
                    stakingOrderIds[_account].pop();
                    break;
                }
            }

            emit StakeYGIO(
                _stakingOrderId,
                _account,
                _data.amount,
                _data.startTime,
                _data.endTime,
                StakeType.UNSTAKE,
                block.number
            );

            _sumAmount += _data.amount;

            delete stakingDatas[_stakingOrderId];

            IERC20(YGIO).transfer(_account, _data.amount);
        }

        if (stakingOrderIds[_account].length == 0) {
            accountStakingTotal -= 1;
        }

        ygioStakingTotal -= _sumAmount;
    }

    function unStakeYGIOOnlyOwner(
        uint256[] calldata _stakingOrderIds
    ) external onlyOwner {
        uint256 _length = _stakingOrderIds.length;

        uint256 _sumAmount;

        for (uint256 i = 0; i < _length; ++i) {
            uint256 _stakingOrderId = _stakingOrderIds[i];

            StakingData memory _data = stakingDatas[_stakingOrderId];

            address _account = _data.owner;

            require(_data.amount > 0, "Invaild stakingOrderId");

            uint256 _len = stakingOrderIds[_account].length;

            for (uint256 j = 0; j < _len; ++j) {
                if (stakingOrderIds[_account][j] == _stakingOrderId) {
                    stakingOrderIds[_account][j] = stakingOrderIds[_account][
                        _len - 1
                    ];
                    stakingOrderIds[_account].pop();
                    break;
                }
            }

            emit StakeYGIO(
                _stakingOrderId,
                _account,
                _data.amount,
                _data.startTime,
                _data.endTime,
                StakeType.UNSTAKEONLYOWNER,
                block.number
            );

            _sumAmount += _data.amount;

            delete stakingDatas[_stakingOrderId];

            IERC20(YGIO).transfer(_account, _data.amount);

            if (stakingOrderIds[_account].length == 0) {
                accountStakingTotal -= 1;
            }
        }

        ygioStakingTotal -= _sumAmount;
    }

    function _caculateStakingWeight(
        address _account
    ) internal view returns (uint256) {
        uint256 _number = stakingOrderIds[_account].length;
        uint256 _sumAmount;
        for (uint i = 0; i < _number; ++i) {
            uint256 _stakingOrderId = stakingOrderIds[_account][i];
            _sumAmount += stakingDatas[_stakingOrderId].amount;
        }
        return _sumAmount;
    }
}
