// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract YunGouSwap is Pausable, Ownable, ReentrancyGuard {
    using ECDSA for bytes32;

    enum CoinType {
        NULL,
        ERC20,
        ERC721
    }

    event Convert(
        uint256 indexed coinId,
        address indexed account,
        uint256 indexed amountTotal,
        uint256 orderId
    );

    struct CoinData {
        CoinType coinType;
        address coinAddress;
    }

    // bytes4(keccak256("transferFrom(address,address,uint256)"))
    bytes4 constant ERC20_TRANSFERFROM_SELECTOR = 0x23b872dd;

    // bytes4(keccak256("transferFrom(address,address,uint256)"))
    bytes4 constant ERC721_TRANSFERFROM_SELECTOR = 0x23b872dd;

    address private receiver;

    address private systemSigner;

    mapping(address => uint256) private totalSwapAmounts;

    mapping(uint256 => CoinData) public payCoinDatas;

    mapping(uint256 => bool) private orderIsInvalid;

    // _receiver: 0x20B04Ce868A6FD40F7df2B89AeEFaD18873ba444
    constructor(
        address _ygio,
        address _usdt,
        address _receiver,
        address _signer
    ) {
        payCoinDatas[1] = CoinData(CoinType.ERC20, _ygio);

        payCoinDatas[2] = CoinData(CoinType.ERC20, _usdt);

        receiver = _receiver;

        systemSigner = _signer;
    }

    function setPause() external onlyOwner {
        if (!paused()) {
            _pause();
        } else {
            _unpause();
        }
    }

    function setSystemSigner(address _signer) external onlyOwner {
        systemSigner = _signer;
    }

    function setReceiver(address _receiver) external onlyOwner {
        receiver = _receiver;
    }

    function setPayCoin(
        uint256 _coinId,
        CoinType _coinType,
        address _coinAddr
    ) external onlyOwner {
        payCoinDatas[_coinId] = CoinData(_coinType, _coinAddr);
    }

    function getTotalSwapAmount(
        uint256 _coinId
    ) external view returns (uint256) {
        return totalSwapAmounts[payCoinDatas[_coinId].coinAddress];
    }

    function getOrderIdState(uint256 orderId) external view returns (bool) {
        return orderIsInvalid[orderId];
    }

    function sawp(
        uint256 _orderId,
        uint256 _coinId,
        uint256 _amountTotal,
        uint256[] calldata _tokenIds,
        uint256 _endTime,
        bytes calldata _signature
    ) external whenNotPaused nonReentrant returns (bool) {
        address _account = _msgSender();

        require(_amountTotal > 0, "Invalid amount");

        require(!orderIsInvalid[_orderId], "Invalid orderId");

        require(block.timestamp < _endTime, "Signature expired");

        CoinType _coinType = payCoinDatas[_coinId].coinType;

        require(_coinType != CoinType.NULL, "Invalid coinId");

        bytes memory _data = abi.encode(
            address(this),
            _orderId,
            _coinId,
            _account,
            _amountTotal,
            _tokenIds,
            _endTime
        );

        bytes32 _hash = keccak256(_data);

        _verifySignature(_hash, _signature);

        address _payCoinAddr = payCoinDatas[_coinId].coinAddress;

        _updataData(_payCoinAddr, _amountTotal);

        orderIsInvalid[_orderId] = true;

        if (CoinType.ERC20 == _coinType) {
            _safeTransferFromERC20(
                _payCoinAddr,
                _account,
                receiver,
                _amountTotal
            );
        } else if (CoinType.ERC721 == _coinType) {
            require(_amountTotal == _tokenIds.length, "Invalid tokenIds");

            for (uint256 i = 0; i < _tokenIds.length; ++i) {
                _safeTransferFromERC721(
                    _payCoinAddr,
                    _account,
                    receiver,
                    _tokenIds[i]
                );
            }
        }

        emit Convert(_coinId, _account, _amountTotal, _orderId);

        return true;
    }

    function _updataData(address _payCoinAddr, uint256 _amountTotal) internal {
        unchecked {
            totalSwapAmounts[_payCoinAddr] += _amountTotal;
        }
    }

    function _verifySignature(
        bytes32 _hash,
        bytes calldata _signature
    ) internal view {
        _hash = _hash.toEthSignedMessageHash();

        address signer = _hash.recover(_signature);

        require(systemSigner == signer, "Invalid signature");
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

    function _safeTransferFromERC721(
        address target,
        address from,
        address to,
        uint256 tokenId
    ) internal {
        (bool success, bytes memory data) = target.call(
            abi.encodeWithSelector(
                ERC721_TRANSFERFROM_SELECTOR,
                from,
                to,
                tokenId
            )
        );

        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "Low-level call failed"
        );
    }
}
