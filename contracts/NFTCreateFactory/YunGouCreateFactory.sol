// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./ERC721/Collection.sol";

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

    uint256 private createNumber;

    function getCreateNumber() external view returns (uint256) {
        return createNumber;
    }

    constructor() {}

    function createNFTContract(
        InitializeData calldata _data
    ) external whenNotPaused nonReentrant returns (bool) {
        createNumber++;

        Collection collection = new Collection();

        collection.initialize(
            _data.name,
            _data.symbol,
            _data.totalSupply,
            _data.owner,
            _data.payToken,
            _data.unitPrice,
            _data.receivers,
            _data.percentages,
            _data.baseURI
        );

        emit CreateContract(_msgSender(), address(collection), block.timestamp);

        return true;
    }
}
