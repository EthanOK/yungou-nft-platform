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

contract PoolsOfLP is Pausable, AccessControl, ReentrancyGuard {
    using ECDSA for bytes32;
    using Counters for Counters.Counter;

    bytes32 public constant OWNER_ROLE = keccak256("OWNER_ROLE");
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    address public constant LPTOKEN_YGIO_USDT =
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
        address owner;
        StakeState state;
        uint256 amount;
        uint256 income;
        uint64 startTime;
        uint64 endTime;
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

    address private mineOwner;
    // max reward Level
    uint8 public rewardLevelMax;
    // reward Rates
    uint32[8] private rewardRates;

    // become Mine Owner Amount
    uint256 private amountBMO;

    uint256 private _totalStakeLP;

    Counters.Counter private _currentStakeLPOrderId;

    // invitee =>  inviter
    mapping(address => address) private inviters;
    // account => balance
    mapping(address => uint256) private balances;
    // stakeLPOrderId => StakeLPData
    mapping(uint256 => StakeLPData) private stakeLPDatas;
    // account => stakeLPOrderIds
    mapping(address => uint256[]) private stakeLPOrderIds;
    // inviter's Rewards
    mapping(address => uint256) private inviterRewards;

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

    function getTotalStakeLP() external view returns (uint256) {
        return _totalStakeLP;
    }

    function getCurrentStakeLPOrderId() external view returns (uint256) {
        return _currentStakeLPOrderId.current();
    }

    function getStakeLPData(
        uint256 _stakeLPOrderId
    ) external view returns (StakeLPData memory) {
        return stakeLPDatas[_stakeLPOrderId];
    }

    function getStakeLPOrderIdsOfAccount(
        address _account
    ) external view returns (uint256[] memory) {
        return stakeLPOrderIds[_account];
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

    function becomeMineOwner() external whenNotPaused nonReentrant {
        require(mineOwner == ZERO_ADDRESS, "mine owner exists");

        address account = _msgSender();

        // check condition
        require(
            IPancakePair(LPTOKEN_YGIO_USDT).balanceOf(account) >= amountBMO,
            "Insufficient balance of LP"
        );

        mineOwner = account;

        balances[account] += amountBMO;

        _totalStakeLP += amountBMO;

        // transfer LP
        IPancakePair(LPTOKEN_YGIO_USDT).transferFrom(
            account,
            address(this),
            amountBMO
        );
    }

    function participateStaking(
        uint256 _amountLP,
        address _inviter,
        bytes calldata _signature
    ) external whenNotPaused nonReentrant onlyInvited(_inviter, _signature) {
        address _invitee = _msgSender();

        uint256 _balance = IPancakePair(LPTOKEN_YGIO_USDT).balanceOf(_invitee);

        require(
            _balance >= _amountLP && _amountLP > 0,
            "Insufficient balance of LP"
        );

        // TODO:caculate income
        uint256 _income = _caculateIncome(_amountLP);

        _currentStakeLPOrderId.increment();

        uint256 stakeLPOrderId = _currentStakeLPOrderId.current();

        stakeLPDatas[stakeLPOrderId] = StakeLPData({
            owner: _invitee,
            state: StakeState.STAKING,
            amount: _amountLP,
            income: _income,
            startTime: uint64(block.timestamp),
            endTime: uint64(block.timestamp + stakePeriod)
        });

        balances[_invitee] += _amountLP;

        _totalStakeLP += _amountLP;

        stakeLPOrderIds[_invitee].push(stakeLPOrderId);

        //update Inviters Reward
        _updateInvitersReward(_invitee, _income);

        // transfer LP
        IPancakePair(LPTOKEN_YGIO_USDT).transferFrom(
            _invitee,
            address(this),
            _amountLP
        );
    }

    function updateStakeLPDatas(
        uint256 _stakeLPOrderId,
        uint256 _endTime
    ) external onlyRole(OPERATOR_ROLE) {
        stakeLPDatas[_stakeLPOrderId].endTime = uint64(_endTime);
    }

    modifier onlyInvited(address inviter, bytes calldata signature) {
        address invitee = _msgSender();

        if (invitee != mineOwner && inviters[invitee] == ZERO_ADDRESS) {
            // Is the inviter valid?
            require(
                inviter == mineOwner || inviters[inviter] != ZERO_ADDRESS,
                "Invalid inviter"
            );

            // Whether the invitee has been invited?

            bytes memory data = abi.encode(invitee, inviter, address(this));

            bytes32 hash = keccak256(data);

            _verifySignature(hash, signature);

            inviters[invitee] = inviter;
        }
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

    function _caculateIncome(uint256 _amount) internal pure returns (uint256) {
        return _amount * 2;
    }

    function _updateInvitersReward(address _invitee, uint256 _income) internal {
        (address[] memory _inviters, uint256 _number) = _queryInviters(
            _invitee,
            rewardLevelMax
        );
        if (_number > 0) {
            for (uint i = 0; i < _number; ++i) {
                // caculate reward
                uint256 _reward = (_income * rewardRates[i]) / REWARDRATE_BASE;

                if (_reward > 0) {
                    inviterRewards[_inviters[i]] += _reward;
                }
            }
        }
    }
}
