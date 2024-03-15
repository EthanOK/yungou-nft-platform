// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

interface ICollection {
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
    ) external;
}

contract YunGouCollectionsFactory is Ownable, Pausable, ReentrancyGuard {
    using Clones for address;

    event CreateContract(address indexed owner, address token, address impl);

    struct InitializeData {
        string name;
        string symbol;
        string baseURI;
        uint256 totalSupply;
        address owner;
        address payToken;
        uint256 unitPrice;
        address[] receivers;
        uint256[] percentages;
    }

    uint256 public constant BASE_10000 = 10_000;

    uint256 private createNumber;

    uint256 private platformFee;

    address private platformFeeAccount;

    address public implementation;

    mapping(address => address) public proxys;

    constructor(address _platformFeeAccount, address _implementation) {
        platformFee = 1500;

        platformFeeAccount = _platformFeeAccount;

        implementation = _implementation;
    }

    function setPlatformFee(
        uint256 _platformFee
    ) external onlyOwner returns (bool) {
        platformFee = _platformFee;

        return true;
    }

    function setImplementation(
        address _implementation
    ) external onlyOwner returns (bool) {
        implementation = _implementation;

        return true;
    }

    function getCreateNumber() external view returns (uint256) {
        return createNumber;
    }

    function getPlatformFee() external view returns (uint256, uint256) {
        return (platformFee, BASE_10000);
    }

    function createNFTContract(
        InitializeData calldata _data
    ) external whenNotPaused nonReentrant returns (bool) {
        _checkInitializeData(_data);

        // Minimal Proxy
        address proxy = implementation.clone();

        ICollection(proxy).initialize(
            _data.name,
            _data.symbol,
            _data.totalSupply,
            _data.owner,
            _data.payToken,
            _data.unitPrice,
            platformFeeAccount,
            platformFee,
            _data.receivers,
            _data.percentages,
            _data.baseURI
        );

        createNumber++;

        emit CreateContract(_msgSender(), address(proxy), implementation);

        return true;
    }

    function _checkInitializeData(InitializeData calldata _data) internal view {
        require(
            _data.receivers.length == _data.percentages.length,
            "Invalid Array length"
        );

        uint256 _sum;

        for (uint256 i = 0; i < _data.percentages.length; ++i) {
            _sum += _data.percentages[i];
        }

        require(_sum == BASE_10000 - platformFee, "Invalid percentages");
    }
}
