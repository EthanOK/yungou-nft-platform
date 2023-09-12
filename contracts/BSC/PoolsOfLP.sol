// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

interface IPancakePair {
    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);

    function name() external pure returns (string memory);

    function symbol() external pure returns (string memory);

    function decimals() external pure returns (uint8);

    function totalSupply() external view returns (uint);

    function balanceOf(address owner) external view returns (uint);

    function allowance(
        address owner,
        address spender
    ) external view returns (uint);

    function approve(address spender, uint value) external returns (bool);

    function transfer(address to, uint value) external returns (bool);

    function transferFrom(
        address from,
        address to,
        uint value
    ) external returns (bool);

    function DOMAIN_SEPARATOR() external view returns (bytes32);

    function PERMIT_TYPEHASH() external pure returns (bytes32);

    function nonces(address owner) external view returns (uint);

    function permit(
        address owner,
        address spender,
        uint value,
        uint deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    event Mint(address indexed sender, uint amount0, uint amount1);

    event Burn(
        address indexed sender,
        uint amount0,
        uint amount1,
        address indexed to
    );

    event Swap(
        address indexed sender,
        uint amount0In,
        uint amount1In,
        uint amount0Out,
        uint amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);

    function MINIMUM_LIQUIDITY() external pure returns (uint);

    function factory() external view returns (address);

    function token0() external view returns (address);

    function token1() external view returns (address);

    function getReserves()
        external
        view
        returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);

    function price0CumulativeLast() external view returns (uint);

    function price1CumulativeLast() external view returns (uint);

    function kLast() external view returns (uint);

    function mint(address to) external returns (uint liquidity);

    function burn(address to) external returns (uint amount0, uint amount1);

    function swap(
        uint amount0Out,
        uint amount1Out,
        address to,
        bytes calldata data
    ) external;

    function skim(address to) external;

    function sync() external;

    function initialize(address, address) external;
}

interface IYGIOStake {
    function getMulFactor(
        address account
    ) external pure returns (uint256 numerator, uint256 denominator);
}

contract PoolsOfLP is Pausable, AccessControl, ReentrancyGuard {
    using ECDSA for bytes32;
    using Counters for Counters.Counter;

    bytes32 public constant OWNER_ROLE = keccak256("OWNER_ROLE");
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    address public constant LPTOKEN_YGIO_USDT =
        0x54D7fb29e79907f41B1418562E3a4FeDc49Bec90;
    address public constant YGIO_STAKE =
        0x54D7fb29e79907f41B1418562E3a4FeDc49Bec90;
    address public constant ZERO_ADDRESS = address(0);
    uint256 public constant REWARDRATE_BASE = 10_000;
    uint256 public constant stakePeriod = 30 days;

    enum StakeState {
        STAKING,
        UNSTAKE,
        CONTINUESTAKE
    }

    struct StakeLPData {
        StakeState state;
        uint256 amountLP;
        uint256 amountLPWorking;
        // Accumulated income after staking settlement (stake again, or cancel staking)
        uint256 accruedIncomeYGIO;
        uint64 startBlockNumber;
        uint64 endBlockNumber;
    }

    struct InviterLPData {
        uint256 amountLPWorking;
        uint256 accruedIncomeYGIO;
        uint64 startBlockNumber;
    }

    event StakeLP(
        uint256 orderId,
        address indexed account,
        uint256 amount,
        uint256 startTime,
        uint256 endTime,
        StakeState state
    );

    string private poolName;

    address private inviteeSigner;

    // one Cycle have 10 Block
    uint32 private oneCycle_BlockNumber = 10;
    //  one Cycle YGIO Reward Per LP
    uint256 private oneCycle_Reward = 10_000_000;

    address private mineOwner;
    // max reward Level
    uint8 public rewardLevelMax;

    uint32 private poolOwnerRate;
    // reward Rates
    uint32[8] private rewardRates;

    // become Mine Owner Amount
    uint256 private amountBMO;

    uint256 private _totalStakeLP;

    uint256 private balancePoolOwner;

    // invitee =>  inviter
    mapping(address => address) private inviters;

    // account => StakeLPData
    mapping(address => StakeLPData) private stakeLPDatas;

    // inviter => InviterLPData
    mapping(address => InviterLPData) private inviterLPDatas;

    // TODO:_amount = 100_000 LP
    constructor(
        string memory _poolName,
        uint256 _amount,
        address _inviteeSigner
    ) {
        _setupRole(DEFAULT_ADMIN_ROLE, tx.origin);
        _setupRole(OWNER_ROLE, tx.origin);

        poolName = _poolName;
        amountBMO = _amount * 10e18;
        inviteeSigner = _inviteeSigner;

        rewardRates = [uint32(500), 400, 300, 200, 100, 0, 0, 0];
        rewardLevelMax = 5;
        poolOwnerRate = 200;
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

    function getTotalStakeLP() external view returns (uint256) {
        return _totalStakeLP;
    }

    function getInviteTotalBenefit(
        address _account
    ) external view returns (uint256) {
        InviterLPData memory _inviterLPData = inviterLPDatas[_account];
    }

    function getStakeTotalBenefit(
        address _account
    ) external view returns (uint256) {
        StakeLPData memory _stakeLPData = stakeLPDatas[_account];
        if (_stakeLPData.endBlockNumber > _stakeLPData.startBlockNumber) {
            return _stakeLPData.accruedIncomeYGIO;
        } else {
            uint256 _currentStakingReward = _caculateLPWorkingReward(
                _account,
                _stakeLPData.amountLPWorking,
                _stakeLPData.startBlockNumber,
                uint64(block.number)
            );
            return _currentStakingReward + _stakeLPData.accruedIncomeYGIO;
        }
    }

    function getStakeLPData(
        address _account
    ) external view returns (StakeLPData memory) {
        return stakeLPDatas[_account];
    }

    function queryInviters(
        address _invitee,
        uint256 _numberLayers
    ) external view returns (address[] memory) {
        (address[] memory _inviters, ) = _queryInviters(
            _invitee,
            _numberLayers
        );
        return _inviters;
    }

    function _queryInviters(
        address _invitee,
        uint256 _numberLayers
    ) internal view returns (address[] memory, uint256) {
        address[] memory _inviters = new address[](_numberLayers);

        // The number of superiors of the invitee
        uint256 _number;

        for (uint i = 0; i < _numberLayers; ++i) {
            _invitee = inviters[_invitee];

            if (_invitee == ZERO_ADDRESS) break;

            _inviters[i] = _invitee;

            _number = i + 1;
        }

        return (_inviters, _number);
    }

    function becomeMineOwner(
        bytes calldata _signature
    ) external whenNotPaused nonReentrant onlyNewPoolOwner(_signature) {
        require(mineOwner == ZERO_ADDRESS, "mine owner exists");

        address poolOwner = _msgSender();

        // check condition
        require(
            IPancakePair(LPTOKEN_YGIO_USDT).balanceOf(poolOwner) >= amountBMO,
            "Insufficient balance of LP"
        );

        mineOwner = poolOwner;

        balancePoolOwner = amountBMO;

        _totalStakeLP += amountBMO;

        // transfer LP
        IPancakePair(LPTOKEN_YGIO_USDT).transferFrom(
            poolOwner,
            address(this),
            amountBMO
        );
    }

    function participateStaking(
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
            // caculate LP Working Reward
            uint256 rewardYGIO = _caculateLPWorkingReward(
                _account,
                _stakelPData.amountLPWorking,
                _stakelPData.startBlockNumber,
                uint64(block.number)
            );

            _stakelPData.accruedIncomeYGIO += rewardYGIO;

            _stakelPData.amountLP += _amountLP;

            uint256 _amountLPWorking = _getAmountLPWorking(
                _account,
                _stakelPData.amountLP
            );

            _stakelPData.amountLPWorking = _amountLPWorking;

            _stakelPData.startBlockNumber = uint64(block.number);
        } else {
            _stakelPData.amountLP = _amountLP;

            _stakelPData.amountLPWorking = _getAmountLPWorking(
                _account,
                _amountLP
            );

            _stakelPData.startBlockNumber = uint64(block.number);
        }

        _totalStakeLP += _amountLP;

        // update Inviters Reward
        _updateInvitersRewardAdd(_account, _amountLP);

        // transfer LP
        IPancakePair(LPTOKEN_YGIO_USDT).transferFrom(
            _account,
            address(this),
            _amountLP
        );
    }

    function unStake() external whenNotPaused nonReentrant {
        address _account = _msgSender();

        StakeLPData storage _stakeLPData = stakeLPDatas[_account];

        uint256 _currentStakingReward = _caculateLPWorkingReward(
            _account,
            _stakeLPData.amountLPWorking,
            _stakeLPData.startBlockNumber,
            uint64(block.number)
        );
        _stakeLPData.accruedIncomeYGIO += _currentStakingReward;

        uint256 _amountLP = _stakeLPData.amountLP;

        delete _stakeLPData.amountLPWorking;

        delete _stakeLPData.amountLP;

        _stakeLPData.endBlockNumber = uint64(block.number);
        // update Inviters Reward
        _updateInvitersRewardRemove(_account, _amountLP);
        // transfer LP
        IPancakePair(LPTOKEN_YGIO_USDT).transfer(_account, _amountLP);
    }

    // Return YGIO Reward(MUL Factor)
    function _caculateLPWorkingReward(
        address _account,
        uint256 _amountLPWorking,
        uint64 _startBlockNumber,
        uint64 _endBlockNumber
    ) internal view returns (uint256) {
        // working Cycle Number
        uint256 cycleNumber = (_endBlockNumber - _startBlockNumber) /
            oneCycle_BlockNumber;

        uint256 _reward = cycleNumber * oneCycle_Reward * _amountLPWorking;

        // account Factor
        (uint256 _numerator, uint256 _denominator) = IYGIOStake(YGIO_STAKE)
            .getMulFactor(_account);

        (uint256 _numeratorPool, uint256 _denominatorPool) = _getPoolFactor();

        _reward =
            (_reward * _numerator * _numeratorPool) /
            (_denominator * _denominatorPool);
        return _reward;
    }

    modifier onlyInvited(address inviter, bytes calldata signature) {
        address invitee = _msgSender();

        require(invitee != mineOwner, "mine owner cannot participate");

        if (inviters[invitee] == ZERO_ADDRESS) {
            // Is the inviter valid?
            require(inviters[inviter] != ZERO_ADDRESS, "Invalid inviter");

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
        // TODO 依据池子LP质押量动态变动
        _totalStakeLP;
        return (150, 100);
    }

    function _updateInvitersRewardAdd(
        address _invitee,
        uint256 _amountLP
    ) internal {
        (address[] memory _inviters, uint256 _number) = _queryInviters(
            _invitee,
            rewardLevelMax
        );
        if (_number > 0) {
            for (uint i = 0; i < _number; ++i) {
                InviterLPData storage _inviterLPData = inviterLPDatas[
                    _inviters[i]
                ];
                uint256 _rewardLPWorking = (_amountLP * rewardRates[i]) /
                    REWARDRATE_BASE;
                if (_inviterLPData.startBlockNumber == uint64(block.number)) {
                    _inviterLPData.amountLPWorking += _rewardLPWorking;
                } else {
                    // caculate reward YGIO
                    uint256 _rewardOneBlockOneLP = oneCycle_Reward /
                        oneCycle_BlockNumber;

                    uint256 _rewardYGIO = _rewardOneBlockOneLP *
                        _inviterLPData.amountLPWorking *
                        (uint64(block.number) -
                            _inviterLPData.startBlockNumber);

                    _inviterLPData.accruedIncomeYGIO += _rewardYGIO;

                    _inviterLPData.amountLPWorking += _rewardLPWorking;

                    _inviterLPData.startBlockNumber = uint64(block.number);
                }
            }
        }
    }

    function _updateInvitersRewardRemove(
        address _invitee,
        uint256 _amountLP
    ) internal {
        (address[] memory _inviters, uint256 _number) = _queryInviters(
            _invitee,
            rewardLevelMax
        );
        if (_number > 0) {
            for (uint i = 0; i < _number; ++i) {
                InviterLPData storage _inviterLPData = inviterLPDatas[
                    _inviters[i]
                ];
                uint256 _rewardLPWorking = (_amountLP * rewardRates[i]) /
                    REWARDRATE_BASE;

                if (_inviterLPData.startBlockNumber == uint64(block.number)) {
                    _inviterLPData.amountLPWorking -= _rewardLPWorking;
                } else {
                    // caculate reward YGIO
                    uint256 _rewardOneBlockOneLP = oneCycle_Reward /
                        oneCycle_BlockNumber;

                    uint256 _rewardYGIO = _rewardOneBlockOneLP *
                        _inviterLPData.amountLPWorking *
                        (uint64(block.number) -
                            _inviterLPData.startBlockNumber);

                    _inviterLPData.accruedIncomeYGIO += _rewardYGIO;

                    _inviterLPData.amountLPWorking -= _rewardLPWorking;

                    _inviterLPData.startBlockNumber = uint64(block.number);
                }
            }
        }
    }

    function _getAmountLPWorking(
        address _account,
        uint256 _amountLP
    ) internal view returns (uint256 _amountLPWorking) {
        (, uint256 _number) = _queryInviters(_account, rewardLevelMax);

        uint32 rateSum;

        for (uint i = 0; i < _number; i++) {
            rateSum += rewardRates[0];
        }

        _amountLPWorking = _amountLP - (_amountLP * rateSum) / REWARDRATE_BASE;
    }
}
