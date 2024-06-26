// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract YunGouMember is ERC721, Ownable {
    using Counters for Counters.Counter;
    using Strings for uint256;

    address public constant ZERO_ADDRESS = address(0);

    Counters.Counter _tokenIdCounter;

    uint256 public MAX = 10000;

    uint256 public PAY = 300 * 1e18;

    uint256 public MinMax = 50;

    uint256 public maxLevel = 3;

    mapping(address => bool) public isWhite;

    mapping(address => address) public recommender;

    mapping(uint256 => uint256) public rewardLevelAmount;

    address receicve_address_first;

    address receicve_address_second;

    bool public start = true;

    bool lock;

    uint256 receicve_amount_first;

    uint256 receicve_amount_second;

    IERC20 payCon;

    IERC20 rewardCon;

    string public baseUri;

    string public orgUri;

    constructor(
        address pay,
        address reward,
        address newOwner,
        string memory _baseUri
    ) ERC721("YGME", "YGME") {
        payCon = IERC20(pay);

        rewardCon = IERC20(reward);

        isWhite[reward] = start;

        _transferOwnership(newOwner);

        baseUri = _baseUri;
    }

    function totalSupply() external view returns (uint256) {
        return _tokenIdCounter.current();
    }

    function tokenURI(
        uint256 tokenId
    ) public view virtual override returns (string memory) {
        _requireMinted(tokenId);

        string memory baseURI = _baseURI();

        string memory orgURI = _orgURI();

        return
            bytes(orgURI).length > 0
                ? string(abi.encodePacked(orgURI, tokenId.toString()))
                : baseURI;
    }

    function _baseURI() internal view override returns (string memory) {
        return baseUri;
    }

    function _orgURI() internal view returns (string memory) {
        return orgUri;
    }

    function setBaseURI(string calldata _baseUri) external onlyOwner {
        baseUri = _baseUri;
    }

    function setRewardCon(address _rewardCon) external onlyOwner {
        rewardCon = IERC20(_rewardCon);
    }

    // Open Box
    function setOrgURI(string calldata _orgUri) external onlyOwner {
        // "ipfs://QmeSjSinHpPnmXmspMjwiXyN6zS4E9zccariGR3jxcaWtq/" or ""
        orgUri = _orgUri;
    }

    function swap(
        address to,
        address _recommender,
        uint256 mintNum
    ) external onlyWhiter mintMax(mintNum) isLock {
        if (recommender[to] == ZERO_ADDRESS) {
            recommender[to] = _recommender;
        }

        for (uint256 i = 0; i < mintNum; ++i) {
            _safeMint(to);
        }
    }

    function safeMint(
        address _recommender,
        uint256 mintNum
    ) external checkRecommender(_recommender) mintMax(mintNum) isLock {
        require(start, "no start");

        address from = _msgSender();

        uint256 _payAmount = PAY * mintNum;

        payCon.transferFrom(from, address(this), _payAmount);

        distribute(mintNum);

        for (uint256 i = 0; i < mintNum; ++i) {
            _safeMint(from);
        }

        _rewardMint(from, mintNum);
    }

    function setPay(uint256 pay) external onlyOwner {
        if (PAY != pay) {
            PAY = pay;
        }
    }

    function setStart() external onlyOwner {
        start = !start;
    }

    function setWhite(address _white) external onlyOwner {
        isWhite[_white] = !isWhite[_white];
    }

    function setMaxMint(uint256 max) external onlyOwner {
        if (MinMax != max) {
            MinMax = max;
        }
    }

    function setMaxLevel(uint256 max) external onlyOwner {
        if (max != maxLevel) {
            maxLevel = max;
        }
    }

    function setLevelAmount(uint256 level, uint256 amount) external onlyOwner {
        require(level <= maxLevel, "level invalid");

        if (rewardLevelAmount[level] != amount) {
            rewardLevelAmount[level] = amount;
        }
    }

    function setReceiveFirst(address first, uint256 amount) external onlyOwner {
        receicve_address_first = first;

        receicve_amount_first = amount;
    }

    function setReceiveSecond(
        address second,
        uint256 amount
    ) external onlyOwner {
        receicve_address_second = second;

        receicve_amount_second = amount;
    }

    function withdrawPay(address addr, uint256 amount) external onlyOwner {
        payCon.transfer(addr, amount);
    }

    function withdrawRewar(address addr, uint256 amount) external onlyOwner {
        rewardCon.transfer(addr, amount);
    }

    function getReceiveFirst()
        external
        view
        onlyOwner
        returns (address, uint256)
    {
        return (receicve_address_first, receicve_amount_first);
    }

    function getReceiveSecond()
        external
        view
        onlyOwner
        returns (address, uint256)
    {
        return (receicve_address_second, receicve_amount_second);
    }

    function distribute(uint256 mintNum) private {
        if (
            receicve_address_first != ZERO_ADDRESS && 0 != receicve_amount_first
        ) {
            payCon.transfer(
                receicve_address_first,
                receicve_amount_first * mintNum
            );
        }

        if (
            receicve_address_second != ZERO_ADDRESS &&
            0 != receicve_amount_second
        ) {
            payCon.transfer(
                receicve_address_second,
                receicve_amount_second * mintNum
            );
        }
    }

    function _safeMint(address to) private returns (uint256) {
        _tokenIdCounter.increment();

        uint256 tokenId = _tokenIdCounter.current();

        _safeMint(to, tokenId);

        return tokenId;
    }

    function _rewardMint(address to, uint256 mintNum) private {
        address rewward;

        for (uint256 i = 0; i <= maxLevel; ++i) {
            if (0 == i) {
                rewward = to;
            } else {
                rewward = recommender[rewward];
            }

            if (rewward != ZERO_ADDRESS && 0 != rewardLevelAmount[i]) {
                rewardCon.transfer(rewward, rewardLevelAmount[i] * mintNum);
            }
        }
    }

    modifier onlyWhiter() {
        address sender = _msgSender();

        require(isWhite[sender] || sender == owner(), "not whiter");

        _;
    }

    modifier checkRecommender(address _recommender) {
        address _account = _msgSender();

        require(_recommender != ZERO_ADDRESS, "recommender can not be zero");

        require(_recommender != _account, "recommender can not be self");

        require(0 < balanceOf(_recommender), "invalid recommender");

        if (recommender[_account] == ZERO_ADDRESS) {
            recommender[_account] = _recommender;
        } else {
            require(
                recommender[_account] == _recommender,
                "recommender is different"
            );
        }

        _;
    }

    modifier isLock() {
        require(!lock, "wait for other to mint ");
        lock = true;
        _;
        lock = false;
    }

    modifier mintMax(uint256 mintNum) {
        require(0 < mintNum && mintNum <= MinMax, "mintNum invalid");

        require(
            _tokenIdCounter.current() + mintNum <= MAX,
            "already minted token of max"
        );

        _;
    }
}
