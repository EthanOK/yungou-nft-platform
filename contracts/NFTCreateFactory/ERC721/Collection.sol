// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "./ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract Collection is Ownable, Pausable, ReentrancyGuard, ERC721 {
    event SafeMint(
        address indexed account,
        uint256 tokenId,
        uint256 price,
        uint256 mintTime
    );

    string public constant LAUNCH_PLATFORM = "YunGou";
    bytes4 constant ERC20_TRANSFERFROM_SELECTOR = 0x23b872dd;
    bytes4 constant ERC20_TRANSFER_SELECTOR = 0xa9059cbb;
    uint256 public constant BASE_10000 = 10_000;
    address constant ZERO_ADDRESS = address(0);

    struct PriceData {
        bool special;
        uint256 price;
    }

    bool initializeState;

    address private platformFeeAccount;

    uint256 private platformFee;

    address public payToken;

    uint256 public unitPrice;

    string public baseURI;

    uint256 private totalSales;

    uint256 private totalIncome;

    uint256 public totalSupply_MAX;

    address[] private receivers;

    uint256[] private percentages;

    uint256[] private mintedTokenIds;

    mapping(uint256 => PriceData) priceDatas;

    mapping(address => bool) private whiteLists;

    constructor() ERC721() {}

    function initialize(
        string calldata _name,
        string calldata _symbol,
        uint256 _totalSupply,
        address _owner,
        address _payToken,
        uint256 _unitPrice,
        address _platformFeeAccount,
        uint256 _platformFee,
        address[] calldata _receivers,
        uint256[] calldata _percentages,
        string calldata __baseURI
    ) external initializer {
        _initialize(_name, _symbol);

        _transferOwnership(_owner);

        totalSupply_MAX = _totalSupply;

        payToken = _payToken;

        unitPrice = _unitPrice;

        receivers = _receivers;

        percentages = _percentages;

        baseURI = __baseURI;

        platformFeeAccount = _platformFeeAccount;

        platformFee = _platformFee;
    }

    function setPause() external onlyOwner {
        if (!paused()) {
            _pause();
        } else {
            _unpause();
        }
    }

    function setPercentages(
        address[] calldata _receivers,
        uint256[] calldata _percentages
    ) external onlyOwner {
        receivers = _receivers;
        percentages = _percentages;
    }

    function setPayToken(
        address _payToken,
        uint256 _unitPrice
    ) external onlyOwner {
        payToken = _payToken;
        unitPrice = _unitPrice;
    }

    function setTokenPrices(
        uint256[] calldata _tokenIds,
        bool _special,
        uint256[] calldata _prices
    ) external onlyOwner {
        require(_tokenIds.length == _prices.length, "Invalid prices");

        for (uint256 i = 0; i < _tokenIds.length; ++i) {
            priceDatas[_tokenIds[i]] = PriceData(_special, _prices[i]);
        }
    }

    // function setBaseURI(string calldata _baseURI_) external onlyOwner {
    //     baseURI = _baseURI_;
    // }

    function setWhiteList(address _account) external onlyOwner {
        whiteLists[_account] = !whiteLists[_account];
    }

    // function setMAX_totalSupply(uint256 _totalSupply_MAX) external onlyOwner {
    //     totalSupply_MAX = _totalSupply_MAX;
    // }

    function getPercentages()
        external
        view
        returns (address[] memory _receivers, uint256[] memory _percentages)
    {
        return (receivers, percentages);
    }

    function getWhiteList(address _account) external view returns (bool) {
        return whiteLists[_account];
    }

    function getMintedTokenIds() external view returns (uint256[] memory) {
        return mintedTokenIds;
    }

    function getTotalSafeMintData() external view returns (uint256, uint256) {
        return (totalSales, totalIncome);
    }

    function safeMint(
        uint256[] calldata _tokenIds,
        address _receiver
    ) external payable whenNotPaused nonReentrant returns (bool) {
        address _account = _msgSender();

        uint256 _amount = _tokenIds.length;

        (uint256 _totalPayPrice, uint256[] memory _prices) = _calcTotalPayPrice(
            _tokenIds
        );

        // mint NFT To receiver
        _mintNFT(_receiver, _tokenIds, _prices);

        unchecked {
            totalIncome += _totalPayPrice;

            totalSales += _amount;
        }

        // account pay Token
        _pay(_account, payToken, _totalPayPrice, msg.value);

        return true;
    }

    function swap(
        address _receiver,
        uint256[] calldata _tokenIds
    ) external onlyOwnerOrWhiteList whenNotPaused nonReentrant returns (bool) {
        uint256[] memory _prices = new uint256[](_tokenIds.length);

        _mintNFT(_receiver, _tokenIds, _prices);

        return true;
    }

    function swap2(
        address[] calldata _receivers,
        uint256[] calldata _tokenIds
    ) external onlyOwnerOrWhiteList whenNotPaused nonReentrant returns (bool) {
        require(_receivers.length == _tokenIds.length, "Invalid length");

        uint256[] memory _prices = new uint256[](_tokenIds.length);

        _mintNFT2(_receivers, _tokenIds, _prices);

        return true;
    }

    function withdraw(
        address _target,
        address _account,
        uint256 _value
    ) external onlyOwner {
        if (payToken == ZERO_ADDRESS) {
            _safeTransferETH(_account, _value);
        } else {
            _safeTransferERC20(_target, _account, _value);
        }
    }

    function totalSupply() external view returns (uint256) {
        return mintedTokenIds.length;
    }

    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

    function _safeTransferETH(address to, uint256 value) internal {
        (bool success, ) = payable(to).call{value: value}("");

        require(success, "Transfer ETH failed");
    }

    function _safeTransferERC20(
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

    function _safeTransferFromERC20(
        address target,
        address from,
        address to,
        uint256 value
    ) internal {
        (bool success, bytes memory data) = target.call(
            abi.encodeWithSelector(ERC20_TRANSFERFROM_SELECTOR, from, to, value)
        );

        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "Low-level call failed"
        );
    }

    modifier onlyOwnerOrWhiteList() {
        address _caller = _msgSender();

        require(owner() == _caller || whiteLists[_caller], "No permission");
        _;
    }

    modifier initializer() {
        require(!initializeState, "Already initialized");
        _;
        initializeState = true;
    }

    function _mintNFT(
        address _receiver,
        uint256[] calldata _tokenIds,
        uint256[] memory _prices
    ) internal returns (bool) {
        uint256 _amount = _tokenIds.length;

        for (uint256 i = 0; i < _amount; ++i) {
            uint256 _tokenId = _tokenIds[i];

            require(
                _tokenId > 0 && _tokenId <= totalSupply_MAX,
                "Invalid tokenId"
            );

            mintedTokenIds.push(_tokenId);

            _safeMint(_receiver, _tokenId);

            emit SafeMint(_receiver, _tokenId, _prices[i], block.timestamp);
        }

        return true;
    }

    function _mintNFT2(
        address[] calldata _receivers,
        uint256[] calldata _tokenIds,
        uint256[] memory _prices
    ) internal returns (bool) {
        uint256 _amount = _tokenIds.length;

        for (uint256 i = 0; i < _amount; ++i) {
            uint256 _tokenId = _tokenIds[i];

            require(
                _tokenId > 0 && _tokenId <= totalSupply_MAX,
                "Invalid tokenId"
            );

            mintedTokenIds.push(_tokenId);

            _safeMint(_receivers[i], _tokenId);

            emit SafeMint(_receivers[i], _tokenId, _prices[i], block.timestamp);
        }

        return true;
    }

    function _calcTotalPayPrice(
        uint256[] calldata _tokenIds
    ) internal view returns (uint256, uint256[] memory) {
        uint256 _totalPayPrice;

        uint256[] memory _prices = new uint256[](_tokenIds.length);

        for (uint256 i = 0; i < _tokenIds.length; ++i) {
            PriceData memory priceData = priceDatas[_tokenIds[i]];

            uint256 _tokenPrice;

            if (priceData.special) {
                _tokenPrice = priceData.price;
            } else {
                _tokenPrice = unitPrice;
            }

            _prices[i] = _tokenPrice;

            _totalPayPrice += _tokenPrice;
        }

        return (_totalPayPrice, _prices);
    }

    function _pay(
        address _account,
        address _payToken,
        uint256 _totalPayPrice,
        uint256 _msgValue
    ) internal {
        if (_payToken == ZERO_ADDRESS) {
            require(_msgValue >= _totalPayPrice, "ETH Insufficient");

            // 1: address(this) => receivers
            for (uint256 i = 0; i < receivers.length; ++i) {
                uint256 _amount = (_totalPayPrice * percentages[i]) /
                    BASE_10000;

                _safeTransferETH(receivers[i], _amount);
            }

            // 2: address(this) => platformFeeAccount
            _safeTransferETH(
                platformFeeAccount,
                (_totalPayPrice * platformFee) / BASE_10000
            );
        } else {
            // 1: account => address(this)
            _safeTransferFromERC20(
                payToken,
                _account,
                address(this),
                _totalPayPrice
            );

            // 2: address(this) => receivers
            for (uint256 i = 0; i < receivers.length; ++i) {
                uint256 _amount = (_totalPayPrice * percentages[i]) /
                    BASE_10000;

                _safeTransferERC20(payToken, receivers[i], _amount);
            }

            // 3: address(this) => platformFeeAccount
            _safeTransferERC20(
                payToken,
                platformFeeAccount,
                (_totalPayPrice * platformFee) / BASE_10000
            );
        }
    }

    receive() external payable {}
}
