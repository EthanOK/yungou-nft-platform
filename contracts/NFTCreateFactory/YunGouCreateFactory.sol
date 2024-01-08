// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "./ERC721/Collection.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract YunGouCreateFactory is Ownable, Pausable, ReentrancyGuard {
    event CreateContract(
        address indexed owner,
        address token,
        uint256 blockTime
    );

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

    mapping(address => address[]) public collectionsOf;

    uint256 private createNumber;

    uint256 private platformFee;

    address private platformFeeAccount;

    constructor(address _platformFeeAccount) {
        platformFee = 1500;

        platformFeeAccount = _platformFeeAccount;
    }

    function setPlatformFee(
        uint256 _platformFee
    ) external onlyOwner returns (bool) {
        platformFee = _platformFee;

        return true;
    }

    function getCreateNumber() external view returns (uint256) {
        return createNumber;
    }

    function getCollectionNumberBy(
        address _user
    ) external view returns (uint256) {
        return collectionsOf[_user].length;
    }

    function getPlatformFee() external view returns (uint256, uint256) {
        return (platformFee, BASE_10000);
    }

    function createNFTContract(
        InitializeData calldata _data
    ) external whenNotPaused nonReentrant returns (bool) {
        _checkInitializeData(_data);

        Collection collection = new Collection();

        collection.initialize(
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

        collectionsOf[_msgSender()].push(address(collection));

        createNumber++;

        emit CreateContract(_msgSender(), address(collection), block.timestamp);

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
