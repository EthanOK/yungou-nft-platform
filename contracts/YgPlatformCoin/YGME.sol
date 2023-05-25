// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

interface IERC20 {
    function decimals() external view returns (uint8);

    function transfer(address to, uint256 amount) external returns (bool);

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
}

interface IERC20USDT {
    function transferFrom(address from, address to, uint256 value) external;

    function transfer(address to, uint256 value) external;
}

contract YGME is ERC721, Ownable {
    using Counters for Counters.Counter;
    using SafeMath for uint256;

    Counters.Counter _tokenIdCounter;

    uint256 MAX = 30000;

    uint256 public PAY = 300000000;

    uint256 public MinMax = 20;

    mapping(address => bool) public isWhite;

    mapping(address => address) public recommender;

    uint256 public maxLevel = 3;
    mapping(uint256 => uint256) public rewardLevelAmount;

    address receicve_address_first;
    uint256 receicve_amount_first;

    address receicve_address_second;
    uint256 receicve_amount_second;

    bool public start = true;

    bool lock;

    IERC20USDT payCon;

    IERC20 rewardCon;

    string public baseUri;
    string public orgUri;

    constructor(address pay, address reward) ERC721("YGME_T", "YGME") {
        payCon = IERC20USDT(pay);

        rewardCon = IERC20(reward);

        _tokenIdCounter.reset();
    }

    function totalSupply() public view virtual returns (uint256) {
        return _tokenIdCounter.current();
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

    function setOrgURI(string calldata _orgUri) external onlyOwner {
        orgUri = _orgUri;
    }

    function swap(
        address to,
        address _recommender,
        uint256 mintNum
    ) external onlyWhiter mintMax(mintNum) isLock {
        if (recommender[to] == address(0)) {
            recommender[to] = _recommender;
        }

        for (uint256 i = 0; i < mintNum; i++) {
            _safeMint(to);
        }
    }

    function safeMint(
        address _recommender,
        uint256 mintNum
    ) external checkRecommender(_recommender) mintMax(mintNum) isLock {
        require(start, "no start");
        address from = _msgSender();
        address self = address(this);

        payCon.transferFrom(from, self, PAY.mul(mintNum));
        distribute(mintNum);

        for (uint256 i = 0; i < mintNum; i++) {
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
        address zero = address(0);
        if (receicve_address_first != zero && 0 != receicve_amount_first) {
            payCon.transfer(
                receicve_address_first,
                receicve_amount_first.mul(mintNum)
            );
        }

        if (receicve_address_second != zero && 0 != receicve_amount_second) {
            payCon.transfer(
                receicve_address_second,
                receicve_amount_second.mul(mintNum)
            );
        }
    }

    function _safeMint(address to) internal {
        _tokenIdCounter.increment();
        uint256 tokenId = _tokenIdCounter.current();
        _safeMint(to, tokenId);
    }

    function _rewardMint(address to, uint256 mintNum) private {
        address rewward;
        address zero = address(0);
        for (uint256 i = 0; i <= maxLevel; i++) {
            if (0 == i) {
                rewward = to;
            } else {
                rewward = recommender[rewward];
            }

            if (rewward != zero && 0 != rewardLevelAmount[i]) {
                rewardCon.transfer(rewward, rewardLevelAmount[i].mul(mintNum));
            }
        }
    }

    modifier onlyWhiter() {
        address sender = _msgSender();

        require(isWhite[sender] || sender == owner(), "not whiter");

        _;
    }

    modifier checkRecommender(address _recommender) {
        require(_recommender != address(0), "recommender can not be zero");
        require(_recommender != msg.sender, "recommender can not be self");
        require(0 < balanceOf(_recommender), "invalid recommender");

        if (recommender[msg.sender] == address(0)) {
            recommender[msg.sender] = _recommender;
        } else {
            require(
                recommender[msg.sender] == _recommender,
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
            MAX >= _tokenIdCounter.current() + mintNum - 1,
            "already minted token of max"
        );
        _;
    }
}
