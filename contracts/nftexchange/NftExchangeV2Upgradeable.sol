// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ExchangeDomainV1.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

contract NftExchangeV2Upgradeable is
    ExchangeDomainV1,
    Initializable,
    PausableUpgradeable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable
{
    using SafeERC20 for IERC20;

    bytes4 private constant INTERFACE_ID_ERC721 = 0x80ac58cd;
    bytes4 private constant INTERFACE_ID_ERC1155 = 0xd9b67a26;
    uint256 public constant FEE_10000 = 10000;

    address payable public beneficiary;
    address private royaltyFeeSigner;
    uint256 public platformFee;

    function initialize(
        address payable _beneficiary,
        address _royaltyFeeSigner,
        uint256 _platformFee
    ) public initializer {
        beneficiary = _beneficiary;
        royaltyFeeSigner = _royaltyFeeSigner;
        platformFee = _platformFee;

        __ReentrancyGuard_init();
        __Pausable_init();
        __Ownable_init();
    }

    function setBeneficiary(address payable newBeneficiary) external onlyOwner {
        beneficiary = newBeneficiary;
    }

    function setRoyaltyFeeSigner(
        address newRoyaltyFeeSigner
    ) external onlyOwner {
        royaltyFeeSigner = newRoyaltyFeeSigner;
    }

    function setPlatformFee(uint256 newPlatformFee) external onlyOwner {
        platformFee = newPlatformFee;
    }

    function getRoyaltyFeeSigner() external view onlyOwner returns (address) {
        return royaltyFeeSigner;
    }

    function setPause() external onlyOwner {
        if (!paused()) {
            _pause();
        } else {
            _unpause();
        }
    }

    function exchange(
        Order calldata order,
        Sig calldata sig,
        uint256 amount,
        uint256 endTime,
        uint256 royaltyFee,
        Sig calldata royaltySig
    ) external payable whenNotPaused nonReentrant returns (bool) {
        address buyer = _msgSender();

        require(block.timestamp <= endTime, "royalty sig has expired");

        require(amount > 0, "amount cannot be zero");

        require(
            order.startTime <= block.timestamp &&
                block.timestamp <= order.endTime,
            "order has expired"
        );

        require(
            order.key.sellAsset.assetType == AssetType.ERC721 ||
                order.key.sellAsset.assetType == AssetType.ERC721Deprecated ||
                order.key.sellAsset.assetType == AssetType.ERC1155,
            "sell asset type must NFT"
        );

        require(
            order.key.buyAsset.assetType == AssetType.ETH ||
                order.key.buyAsset.assetType == AssetType.ERC20,
            "buy asset type must ETH or ERC20"
        );

        _validateOrderSig(order, sig);

        _validateRoyaltyFeeSig(order, royaltyFee, endTime, royaltySig);

        if (
            order.key.sellAsset.assetType == AssetType.ERC721 ||
            order.key.sellAsset.assetType == AssetType.ERC721Deprecated ||
            IERC165(order.key.sellAsset.token).supportsInterface(
                INTERFACE_ID_ERC721
            )
        ) {
            require(amount == 1, "invalid ERC721 amount");
        } else if (
            order.key.sellAsset.assetType == AssetType.ERC1155 ||
            IERC165(order.key.sellAsset.token).supportsInterface(
                INTERFACE_ID_ERC1155
            )
        ) {
            _verifyOrderAmount(order.key, order.sellAmount, amount);
        }

        uint256 payPrice = order.unitPrice * amount;

        if (order.key.buyAsset.assetType == AssetType.ETH) {
            require(msg.value >= payPrice, "ETH insufficient");
        } else if (order.key.buyAsset.assetType == AssetType.ERC20) {
            uint256 allowanceAmount = IERC20(order.key.buyAsset.token)
                .allowance(buyer, address(this));
            require(payPrice <= allowanceAmount, "allowance not enough");
        }

        _transferNftToBuyer(
            order.key.sellAsset.assetType,
            order.key.sellAsset.token,
            order.key.owner,
            buyer,
            order.key.sellAsset.tokenId,
            amount
        );

        uint256 _totalFeeETH = _transferBuyTokenToSeller(
            order.key.buyAsset.assetType,
            order.key.buyAsset.token,
            buyer,
            order.key.owner,
            payPrice,
            royaltyFee
        );

        emit Exchange(
            order.key.sellAsset.token,
            order.key.sellAsset.tokenId,
            order.sellAmount,
            order.unitPrice,
            order.key.owner,
            order.key.buyAsset.token,
            order.key.buyAsset.tokenId,
            buyer,
            amount,
            payPrice,
            royaltyFee
        );

        if (_totalFeeETH > 0) {
            payable(beneficiary).transfer(_totalFeeETH);
        }

        return true;
    }

    function exchangeMul(
        Order[] calldata orders,
        Sig[] calldata sigs,
        uint256[] calldata amounts,
        uint256 endTime,
        uint256[] calldata royaltyFees,
        Sig calldata royaltySig
    ) external payable whenNotPaused nonReentrant returns (bool) {
        address buyer = _msgSender();

        uint256 len = orders.length;

        require(
            len > 0 &&
                len == sigs.length &&
                len == amounts.length &&
                len == royaltyFees.length,
            "invalid length"
        );

        require(block.timestamp <= endTime, "royalty sig has expired");

        _validateRoyaltyFeeSigMul(orders, royaltyFees, endTime, royaltySig);

        uint256 totalFeeETH;

        for (uint256 i = 0; i < len; ++i) {
            require(amounts[i] > 0, "amount should > 0");

            require(
                orders[i].startTime <= block.timestamp &&
                    block.timestamp <= orders[i].endTime,
                "order has expired"
            );

            require(
                orders[i].key.sellAsset.assetType == AssetType.ERC721 ||
                    orders[i].key.sellAsset.assetType ==
                    AssetType.ERC721Deprecated ||
                    orders[i].key.sellAsset.assetType == AssetType.ERC1155,
                "sell asset type must NFT"
            );

            require(
                orders[i].key.buyAsset.assetType == AssetType.ETH ||
                    orders[i].key.buyAsset.assetType == AssetType.ERC20,
                "buy asset type must ETH or ERC20"
            );

            _validateOrderSig(orders[i], sigs[i]);

            if (
                orders[i].key.sellAsset.assetType == AssetType.ERC721 ||
                orders[i].key.sellAsset.assetType ==
                AssetType.ERC721Deprecated ||
                IERC165(orders[i].key.sellAsset.token).supportsInterface(
                    INTERFACE_ID_ERC721
                )
            ) {
                require(amounts[i] == 1, "invalid ERC721 amount");
            } else if (
                orders[i].key.sellAsset.assetType == AssetType.ERC1155 ||
                IERC165(orders[i].key.sellAsset.token).supportsInterface(
                    INTERFACE_ID_ERC1155
                )
            ) {
                _verifyOrderAmount(
                    orders[i].key,
                    orders[i].sellAmount,
                    amounts[i]
                );
            }

            uint256 payPrice = orders[i].unitPrice * amounts[i];

            if (orders[i].key.buyAsset.assetType == AssetType.ETH) {
                require(msg.value >= payPrice, "ETH insufficient");
            } else if (orders[i].key.buyAsset.assetType == AssetType.ERC20) {
                uint256 allowanceAmount = IERC20(orders[i].key.buyAsset.token)
                    .allowance(buyer, address(this));
                require(payPrice <= allowanceAmount, "allowance not enough");
            }

            _transferNftToBuyer(
                orders[i].key.sellAsset.assetType,
                orders[i].key.sellAsset.token,
                orders[i].key.owner,
                buyer,
                orders[i].key.sellAsset.tokenId,
                amounts[i]
            );

            uint256 _totalFeeETH = _transferBuyTokenToSeller(
                orders[i].key.buyAsset.assetType,
                orders[i].key.buyAsset.token,
                buyer,
                orders[i].key.owner,
                payPrice,
                royaltyFees[i]
            );

            if (_totalFeeETH > 0) {
                totalFeeETH += _totalFeeETH;
            }

            emit Exchange(
                orders[i].key.sellAsset.token,
                orders[i].key.sellAsset.tokenId,
                orders[i].sellAmount,
                orders[i].unitPrice,
                orders[i].key.owner,
                orders[i].key.buyAsset.token,
                orders[i].key.buyAsset.tokenId,
                buyer,
                amounts[i],
                payPrice,
                royaltyFees[i]
            );
        }

        if (totalFeeETH > 0) {
            payable(beneficiary).transfer(totalFeeETH);
        }

        return true;
    }

    function _transferNftToBuyer(
        AssetType assertType,
        address nftAddress,
        address fromAccount,
        address toAccount,
        uint256 tokenId,
        uint256 amount
    ) internal {
        if (assertType == AssetType.ERC721) {
            IERC721(nftAddress).safeTransferFrom(
                fromAccount,
                toAccount,
                tokenId
            );
        } else if (assertType == AssetType.ERC721Deprecated) {
            IERC721(nftAddress).transferFrom(fromAccount, toAccount, tokenId);
        } else if (assertType == AssetType.ERC1155) {
            IERC1155(nftAddress).safeTransferFrom(
                fromAccount,
                toAccount,
                tokenId,
                amount,
                "0x"
            );
        }
    }

    function _transferBuyTokenToSeller(
        AssetType assertType,
        address erc20Address,
        address fromAccount,
        address toAccount,
        uint256 payAmount,
        uint256 royaltyFee
    ) internal returns (uint256 totalFeeETH) {
        uint256 totalFee = ((royaltyFee + platformFee) * payAmount) / FEE_10000;

        uint256 actualPrice = payAmount - totalFee;

        if (assertType == AssetType.ETH) {
            payable(toAccount).transfer(actualPrice);
            // payable(beneficiary).transfer(totalFee);
            totalFeeETH = totalFee;
        } else if (assertType == AssetType.ERC20) {
            IERC20(erc20Address).safeTransferFrom(
                fromAccount,
                toAccount,
                actualPrice
            );
            IERC20(erc20Address).safeTransferFrom(
                fromAccount,
                beneficiary,
                totalFee
            );
            totalFeeETH = 0;
        }
    }

    function _validateOrderSig(
        Order memory order,
        Sig memory sig
    ) internal pure {
        bytes32 hash = keccak256(abi.encode(order));
        hash = _toEthSignedMessageHash(hash);
        address signer = ecrecover(hash, sig.v, sig.r, sig.s);
        require(signer == order.key.owner, "incorrect order signature");
    }

    function _validateRoyaltyFeeSig(
        Order calldata order,
        uint256 royaltyFee,
        uint256 endTime,
        Sig calldata royaltySig
    ) internal view {
        bytes32 hash = keccak256(abi.encode(order, royaltyFee, endTime));
        hash = _toEthSignedMessageHash(hash);
        address signer = ecrecover(
            hash,
            royaltySig.v,
            royaltySig.r,
            royaltySig.s
        );
        require(signer == royaltyFeeSigner, "incorrect royalty fee signature");
    }

    function _validateRoyaltyFeeSigMul(
        Order[] calldata orders,
        uint256[] calldata royaltyFees,
        uint256 endTime,
        Sig calldata royaltySig
    ) internal view {
        bytes32 hash = keccak256(abi.encode(orders, royaltyFees, endTime));
        hash = _toEthSignedMessageHash(hash);
        address signer = ecrecover(
            hash,
            royaltySig.v,
            royaltySig.r,
            royaltySig.s
        );
        require(signer == royaltyFeeSigner, "incorrect royalty fee signature");
    }

    function _toEthSignedMessageHash(
        bytes32 hash
    ) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encodePacked("\x19Ethereum Signed Message:\n32", hash)
            );
    }

    function _verifyOrderAmount(
        OrderKey memory key,
        uint256 sellAmount,
        uint256 amount
    ) internal view {
        uint256 amountOnline = IERC1155(key.sellAsset.token).balanceOf(
            key.owner,
            key.sellAsset.tokenId
        );
        require(
            amount <= sellAmount && amount <= amountOnline,
            "insufficient Sales"
        );
    }

    function withdrawEther(address account) external onlyOwner {
        payable(account).transfer(address(this).balance);
    }
}
