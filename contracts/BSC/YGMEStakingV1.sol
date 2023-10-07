// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";

abstract contract YGMEStakingDomain {
    enum StakeType {
        NULL,
        STAKING,
        UNSTAKE,
        UNSTAKEONLYOWNER
    }

    struct StakingData {
        address owner;
        bool stakedState;
        uint128 startTime;
        uint128 endTime;
    }

    event Staking(
        address indexed account,
        uint256 tokenId,
        uint256 startTime,
        uint256 endTime,
        StakeType indexed stakeType,
        uint256 indexed blockNumber
    );
}

contract YGMEStakingV1 is
    YGMEStakingDomain,
    Pausable,
    Ownable,
    ERC721Holder,
    ReentrancyGuard
{
    uint64 public constant ONE_CYCLE = 1 days;

    uint256 public constant FACTOR_BASE = 10_000;

    IERC721 public immutable ygme;

    // check Time in unStake
    bool public switchCheckTime;

    uint64[4] private stakingPeriods;

    mapping(uint256 => StakingData) private stakingDatas;

    mapping(address => uint256[]) private stakingTokenIds;

    uint128 public accountStakingTotal;

    uint128 public ygmeStakingTotal;

    uint256 public daysStakingTotal;

    constructor(address _ygme) {
        ygme = IERC721(_ygme);

        stakingPeriods = [0, 100 * ONE_CYCLE, 300 * ONE_CYCLE, 0];

        switchCheckTime = true;
    }

    function setPause() external onlyOwner {
        if (!paused()) {
            _pause();
        } else {
            _unpause();
        }
    }

    function setSwitchCheckTime() external onlyOwner {
        switchCheckTime = !switchCheckTime;
    }

    function setStakingPeriods(uint64[4] calldata _days) external onlyOwner {
        for (uint i = 0; i < _days.length; i++) {
            stakingPeriods[i] = _days[i] * ONE_CYCLE;
        }
    }

    function getStakingTokenIds(
        address _account
    ) external view returns (uint256[] memory) {
        return stakingTokenIds[_account];
    }

    function getStakingData(
        uint256 _tokenId
    ) external view returns (StakingData memory) {
        return stakingDatas[_tokenId];
    }

    function getStakingPeriods()
        external
        view
        onlyOwner
        returns (uint64[4] memory)
    {
        return stakingPeriods;
    }

    function staking(
        uint256[] calldata _tokenIds,
        uint256 _stakeDays
    ) external whenNotPaused nonReentrant returns (bool) {
        uint256 length = _tokenIds.length;

        uint256 _stakeTime = _stakeDays * ONE_CYCLE;

        address _account = _msgSender();

        require(length > 0, "Invalid tokenIds");

        require(
            _stakeTime == stakingPeriods[0] ||
                _stakeTime == stakingPeriods[1] ||
                _stakeTime == stakingPeriods[2],
            "Invalid stake time"
        );

        if (stakingTokenIds[_account].length == 0) {
            unchecked {
                accountStakingTotal += 1;
            }
        }

        for (uint256 i = 0; i < length; ++i) {
            uint256 _tokenId = _tokenIds[i];

            require(!stakingDatas[_tokenId].stakedState, "Invalid stake state");

            require(ygme.ownerOf(_tokenId) == _account, "Invalid owner");

            StakingData memory _data = StakingData({
                owner: _account,
                stakedState: true,
                startTime: uint128(block.timestamp),
                endTime: uint128(block.timestamp + _stakeTime)
            });

            stakingDatas[_tokenId] = _data;

            if (stakingTokenIds[_account].length == 0) {
                stakingTokenIds[_account] = [_tokenId];
            } else {
                stakingTokenIds[_account].push(_tokenId);
            }

            ygme.safeTransferFrom(_account, address(this), _tokenId);

            emit Staking(
                _account,
                _tokenId,
                _data.startTime,
                _data.endTime,
                StakeType.STAKING,
                block.number
            );
        }

        unchecked {
            ygmeStakingTotal += uint128(length);
            daysStakingTotal += (_stakeDays * length);
        }

        return true;
    }

    function unStakeIgnoreTime(
        uint256[] calldata _tokenIds
    ) external whenNotPaused nonReentrant returns (bool) {
        _unStake(_tokenIds, switchCheckTime);
        return true;
    }

    function unStake(
        uint256[] calldata _tokenIds
    ) external whenNotPaused nonReentrant returns (bool) {
        _unStake(_tokenIds, true);
        return true;
    }

    function _unStake(uint256[] calldata _tokenIds, bool _checkTime) internal {
        uint256 length = _tokenIds.length;

        address _account = _msgSender();

        require(length > 0, "Invalid tokenIds");

        uint256 _sumDays;

        for (uint256 i = 0; i < length; ++i) {
            uint256 _tokenId = _tokenIds[i];

            StakingData memory _data = stakingDatas[_tokenId];

            require(_data.owner == _account, "Invalid account");

            require(_data.stakedState, "Invalid stake state");

            if (_checkTime) {
                require(
                    block.timestamp >= _data.endTime,
                    "Too early to unStake"
                );
            }

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

            emit Staking(
                _account,
                _tokenId,
                _data.startTime,
                _data.endTime,
                StakeType.UNSTAKE,
                block.number
            );

            _sumDays += (stakingDatas[_tokenId].endTime -
                stakingDatas[_tokenId].startTime);

            delete stakingDatas[_tokenId];

            ygme.safeTransferFrom(address(this), _account, _tokenId);
        }

        if (stakingTokenIds[_account].length == 0) {
            accountStakingTotal -= 1;
        }

        ygmeStakingTotal -= uint128(length);

        daysStakingTotal -= _sumDays / ONE_CYCLE;
    }

    function unStakeOnlyOwner(uint256[] calldata _tokenIds) external onlyOwner {
        uint256 length = _tokenIds.length;

        uint256 _sumDays;

        for (uint256 i = 0; i < length; ++i) {
            uint256 _tokenId = _tokenIds[i];

            StakingData memory _data = stakingDatas[_tokenId];

            address _account = _data.owner;

            require(_data.stakedState, "Invalid stake state");

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

            emit Staking(
                _account,
                _tokenId,
                _data.startTime,
                _data.endTime,
                StakeType.UNSTAKEONLYOWNER,
                block.number
            );

            _sumDays += (stakingDatas[_tokenId].endTime -
                stakingDatas[_tokenId].startTime);

            delete stakingDatas[_tokenId];

            ygme.safeTransferFrom(address(this), _account, _tokenId);

            if (stakingTokenIds[_account].length == 0) {
                accountStakingTotal -= 1;
            }
        }

        ygmeStakingTotal -= uint128(length);

        daysStakingTotal -= _sumDays / ONE_CYCLE;
    }

    function getMulFactor(
        address _account
    )
        external
        view
        returns (
            uint256 numerator0,
            uint256 denominator0,
            uint256 numerator1,
            uint256 denominator1
        )
    {
        (uint256 _amount, uint256 _days) = _caculateStakingWeight(_account);

        unchecked {
            numerator0 = (_amount * FACTOR_BASE) / ygmeStakingTotal;

            denominator0 = FACTOR_BASE;

            numerator1 = (_days * FACTOR_BASE) / daysStakingTotal;

            denominator1 = FACTOR_BASE;
        }
    }

    function _caculateStakingWeight(
        address _account
    ) internal view returns (uint256, uint256) {
        uint256 _number = stakingTokenIds[_account].length;

        uint256 _sumDays;

        for (uint i = 0; i < _number; ++i) {
            uint256 _stakingOrderId = stakingTokenIds[_account][i];

            unchecked {
                _sumDays += (stakingDatas[_stakingOrderId].endTime -
                    stakingDatas[_stakingOrderId].startTime);
            }
        }
        return (_number, _sumDays / ONE_CYCLE);
    }
}
