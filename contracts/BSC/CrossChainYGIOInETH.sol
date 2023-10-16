// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract CrossChainYGIOInETH is Ownable, Pausable, ReentrancyGuard {
    using ECDSA for bytes32;

    event MintYGIO(
        address indexed account,
        uint256 amount,
        uint256 mintId,
        uint256 blockNumber
    );

    event BurnYGIO(
        uint256 lockId,
        address indexed account,
        uint256 amount,
        uint256 blockNumber
    );

    address signer;

    address YGIO;

    // mintId => bool
    mapping(uint256 => bool) mintIdStates;

    uint256 private totalBurnYGIO;

    uint256 private totalMintYGIO;

    uint256 public burnId;

    constructor(address _ygio, address _signer) {
        YGIO = _ygio;
        signer = _signer;
    }

    function setPause() external onlyOwner {
        if (!paused()) {
            _pause();
        } else {
            _unpause();
        }
    }

    function setSigner(address _signer) external onlyOwner {
        signer = _signer;
    }

    function getTotalMintYGIO() external view returns (uint256) {
        return totalMintYGIO;
    }

    function getTotalBurnYGIO() external view returns (uint256) {
        return totalBurnYGIO;
    }

    function getMintState(uint256 _mintId) external view returns (bool) {
        return mintIdStates[_mintId];
    }

    // It’s not really burn, It just locks the token in the contract.
    function burnYGIO(
        uint256 _amount,
        uint256 _deadline,
        bytes calldata _signature
    ) external whenNotPaused nonReentrant returns (bool) {
        address _account = _msgSender();

        require(block.timestamp < _deadline, "Signature expired");

        bytes memory _data = abi.encode(YGIO, _account, _amount, _deadline);

        bytes32 _hash = keccak256(_data);

        _verifySignature(_hash, _signature);

        totalBurnYGIO += _amount;

        ++burnId;

        // transfer (account --> Contract)
        IERC20(YGIO).transferFrom(_account, address(this), _amount);

        emit BurnYGIO(burnId, _account, _amount, block.number);

        return true;
    }

    // It's not a real mint, it just unlocks the tokens in the contract.
    function mintYGIO(
        uint256 _mintId,
        address _account,
        uint256 _amount,
        uint256 _deadline,
        bytes calldata _signature
    ) external whenNotPaused nonReentrant returns (bool) {
        // address _account = _msgSender();

        require(block.timestamp < _deadline, "Signature expired");

        require(!mintIdStates[_mintId], "Invalid convertId");

        bytes memory _data = abi.encode(
            _mintId,
            YGIO,
            _account,
            _amount,
            _deadline
        );

        bytes32 _hash = keccak256(_data);

        _verifySignature(_hash, _signature);

        mintIdStates[_mintId] = true;

        totalMintYGIO += _amount;

        // transfer (Contract --> account)
        IERC20(YGIO).transfer(_account, _amount);

        emit MintYGIO(_account, _amount, _mintId, block.number);

        return true;
    }

    function _verifySignature(
        bytes32 _hash,
        bytes calldata _signature
    ) internal view {
        _hash = _hash.toEthSignedMessageHash();

        address _signer = _hash.recover(_signature);

        require(signer == _signer, "Invalid signature");
    }
}
