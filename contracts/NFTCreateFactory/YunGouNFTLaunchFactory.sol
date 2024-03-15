// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "./ERC721/IERC721DropCloneable.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract YunGouNFTLaunchFactory is Ownable, Pausable, ReentrancyGuard {
    using Clones for address;

    string public constant VERSION = "1.0";

    event CreateContract(address indexed owner, address token, address impl);

    struct FeeInfo {
        address account;
        uint96 fee;
    }

    struct InitializeData {
        string name;
        string symbol;
        string baseURI;
        uint256 totalSupply;
        address owner;
        address payToken;
        uint256 unitPrice;
        address earningAccount;
    }

    uint96 public constant BASE_10000 = 10_000;

    uint256 private createNumber;

    FeeInfo public platformFeeInfo;

    address public implementation;

    mapping(address => address) public proxys;

    constructor(address _impl, address _feeAccount, address _owner) {
        implementation = _impl;

        platformFeeInfo = FeeInfo(_feeAccount, 1500);

        _transferOwnership(_owner);
    }

    function setPlatformFee(
        address _feeAccount,
        uint96 _platformFee
    ) external onlyOwner returns (bool) {
        platformFeeInfo = FeeInfo(_feeAccount, _platformFee);

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

    function getPlatformFeeInfo() external view returns (address, uint256) {
        return (platformFeeInfo.account, platformFeeInfo.fee);
    }

    function createNFTContract(
        InitializeData calldata _data
    ) external whenNotPaused nonReentrant returns (bool) {
        // Minimal Proxy
        address proxy = implementation.clone();

        IERC721DropCloneable(proxy).initialize(
            _data.name,
            _data.symbol,
            _data.totalSupply,
            _data.owner,
            _data.payToken,
            _data.unitPrice,
            IERC721DropCloneable.FeeInfo(
                _data.earningAccount,
                BASE_10000 - platformFeeInfo.fee
            ),
            IERC721DropCloneable.FeeInfo(
                platformFeeInfo.account,
                platformFeeInfo.fee
            ),
            _data.baseURI
        );

        createNumber++;

        emit CreateContract(_msgSender(), address(proxy), implementation);

        return true;
    }
}
