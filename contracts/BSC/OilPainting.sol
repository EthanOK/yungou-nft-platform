// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract OilPainting is Ownable, Pausable, ReentrancyGuard, ERC721 {
    using ECDSA for bytes32;

    event SafeMint(
        address indexed account,
        uint256 tokenId,
        uint256 price,
        uint256 mintTime
    );

    // bytes4(keccak256("transfer(address,uint256)"))
    bytes4 constant ERC20_TRANSFER_SELECTOR = 0xa9059cbb;

    // bytes4(keccak256("transferFrom(address,address,uint256)"))
    bytes4 constant ERC20_TRANSFERFROM_SELECTOR = 0x23b872dd;

    uint256 public constant BASE_10000 = 10_000;

    string public baseURI;

    // USDT
    address private payToken = 0x965A558b312E288F5A77F851F7685344e1e73EdF;

    uint256 public totalIssue = 1000;

    uint256 private totalSafeMintNumber;

    uint256 private totalVolume;

    address[] private projectPartys;

    uint256[] private incomeDistributions;

    uint256[] private mintedTokenIds;

    // White Lists
    mapping(address => bool) private whiteLists;

    mapping(address => bool) private systemSigners;

    constructor(
        address[] memory _projectPartys,
        uint256[] memory _incomeDistributions,
        address _signer,
        string memory _baseURI_
    ) ERC721("OilPainting", "OP") {
        projectPartys = _projectPartys;

        incomeDistributions = _incomeDistributions;

        systemSigners[_signer] = true;

        baseURI = _baseURI_;
    }

    function setPause() external onlyOwner {
        if (!paused()) {
            _pause();
        } else {
            _unpause();
        }
    }

    function setIncomeDistribution(
        address[] calldata _projectPartys,
        uint256[] calldata _incomeDistributions
    ) external onlyOwner {
        projectPartys = _projectPartys;

        incomeDistributions = _incomeDistributions;
    }

    function setBaseURI(string memory _baseURI_) external onlyOwner {
        baseURI = _baseURI_;
    }

    function setWhiteList(address _account) external onlyOwner {
        whiteLists[_account] = !whiteLists[_account];
    }

    function setPayToken(address _payToken) external onlyOwner {
        payToken = _payToken;
    }

    function getWhiteList(address _account) external view returns (bool) {
        return whiteLists[_account];
    }

    function getPayToken() external view returns (address) {
        return payToken;
    }

    function getMintedTokenIds() external view returns (uint256[] memory) {
        return mintedTokenIds;
    }

    function getTotalSafeMintData() external view returns (uint256, uint256) {
        return (totalSafeMintNumber, totalVolume);
    }

    function safeMint(
        uint256[] calldata _tokenIds,
        uint256[] calldata _prices,
        uint256 _deadline,
        bytes calldata _signature
    ) external whenNotPaused nonReentrant returns (bool) {
        address _account = _msgSender();

        uint256 _amount = _tokenIds.length;

        require(_amount > 0 && _amount == _prices.length, "Invalid paras");

        require(block.timestamp < _deadline, "Signature has expired");

        bytes memory _data = abi.encode(
            address(this),
            _account,
            _tokenIds,
            _prices,
            _deadline
        );

        bytes32 _hash = keccak256(_data);

        _verifySignature(_hash, _signature);

        uint256 _totalPayPrice;

        for (uint256 i = 0; i < _amount; ++i) {
            uint256 _tokenId = _tokenIds[i];

            require(_tokenId > 0 && _tokenId <= totalIssue, "Invalid tokenId");

            mintedTokenIds.push(_tokenId);

            _totalPayPrice += _prices[i];

            _mint(_account, _tokenId);

            emit SafeMint(_account, _tokenId, _prices[i], block.timestamp);
        }

        unchecked {
            totalVolume += _totalPayPrice;

            totalSafeMintNumber += _amount;
        }

        for (uint256 i = 0; i < projectPartys.length; ++i) {
            uint256 _amount0 = (_totalPayPrice * incomeDistributions[i]) /
                BASE_10000;

            _safeTransferFromERC20(
                payToken,
                _account,
                projectPartys[i],
                _amount0
            );
        }

        return true;
    }

    function swap(
        address to,
        uint256[] calldata _tokenIds
    ) external onlyOwnerOrWhiteList whenNotPaused nonReentrant returns (bool) {
        for (uint256 i = 0; i < _tokenIds.length; ++i) {
            uint256 _tokenId = _tokenIds[i];

            require(_tokenId > 0 && _tokenId <= totalIssue, "Invalid tokenId");

            mintedTokenIds.push(_tokenId);

            _mint(to, _tokenId);
        }

        return true;
    }

    function totalSupply() external view returns (uint256) {
        return mintedTokenIds.length;
    }

    function _baseURI() internal view override returns (string memory) {
        return baseURI;
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

    function _verifySignature(
        bytes32 _hash,
        bytes calldata _signature
    ) internal view {
        _hash = _hash.toEthSignedMessageHash();

        address signer = _hash.recover(_signature);

        require(systemSigners[signer], "Invalid signature");
    }
}