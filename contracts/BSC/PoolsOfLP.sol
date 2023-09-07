// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
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

contract PoolsOfLP is Pausable, Ownable, ReentrancyGuard {
    using ECDSA for bytes32;

    address public constant LPTOKEN_YGIO_USDT =
        0x54D7fb29e79907f41B1418562E3a4FeDc49Bec90;

    address public constant ZERO_ADDRESS = address(0);

    struct StakeLPData {
        uint256 amount;
        uint256 income;
        uint64 startTime;
        uint64 endTime;
        bool state;
    }

    string private poolName;

    address private inviteeSigner;

    address private mineOwner;

    // become Mine Owner Amount
    uint256 private amountBMO;

    // invitee =>  inviter
    mapping(address => address) private inviters;
    // stake balance
    mapping(address => uint256) private balances;

    mapping(address => mapping(uint256 => StakeLPData)) stakeLPDatas;

    mapping(address => uint256[]) stakeLPOrderIds;

    mapping(uint256 => address) orderIdOwner;

    // TODO:_amount = 100_000 LP
    constructor(
        string memory _poolName,
        uint256 _amount,
        address _inviteeSigner
    ) {
        poolName = _poolName;
        amountBMO = _amount * 10e18;
        inviteeSigner = _inviteeSigner;
    }

    function setPause() external onlyOwner {
        if (!paused()) {
            _pause();
        } else {
            _unpause();
        }
    }

    function getPoolName() external view returns (string memory) {
        return poolName;
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

        IPancakePair(LPTOKEN_YGIO_USDT).transferFrom(
            account,
            address(this),
            amountBMO
        );
    }

    function participateStaking(
        uint256 amount,
        address inviter,
        bytes calldata signature
    ) external whenNotPaused nonReentrant onlyInvited(inviter, signature) {
        address invitee = _msgSender();

        uint256 _balance = IPancakePair(LPTOKEN_YGIO_USDT).balanceOf(invitee);

        require(_balance >= amount && amount > 0, "Insufficient balance of LP");
    }

    modifier onlyInvited(address inviter, bytes calldata signature) {
        // Is the inviter valid?
        require(
            inviter == mineOwner || inviters[inviter] != ZERO_ADDRESS,
            "Invalid inviter"
        );

        // Whether the invitee has been invited?
        address invitee = _msgSender();

        bytes memory data = abi.encode(invitee, inviter, address(this));

        bytes32 hash = keccak256(data);

        _verifySignature(hash, signature);

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
}
