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

contract NftExchangeV1Upgradeable is
    ExchangeDomainV1,
    Initializable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable,
    OwnableUpgradeable
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

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function exchange(
        Order calldata order,
        Sig calldata sig,
        uint256 amount,
        uint256 endTime,
        uint256 royaltyFee,
        Sig calldata royaltySig
    ) external payable whenNotPaused nonReentrant {
        address buyer = _msgSender();

        require(block.timestamp <= endTime, "royalty sig has expired");

        require(amount > 0, "amount should > 0");

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
            amount = 1;
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

        _transferBuyTokenToSeller(
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
    ) internal {
        uint256 totalFee = ((royaltyFee + platformFee) * payAmount) / FEE_10000;

        uint256 actualPrice = payAmount - totalFee;

        if (assertType == AssetType.ETH) {
            payable(toAccount).transfer(actualPrice);
            payable(beneficiary).transfer(totalFee);
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
        Order memory order,
        uint256 royaltyFee,
        uint256 endTime,
        Sig memory royaltySig
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
