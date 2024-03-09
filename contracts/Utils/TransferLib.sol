// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library TransferLib {
    // bytes4(keccak256("transfer(address,uint256)"))
    bytes4 constant ERC20_TRANSFER_SELECTOR = 0xa9059cbb;

    // bytes4(keccak256("transferFrom(address,address,uint256)"))
    bytes4 constant ERC20_TRANSFERFROM_SELECTOR = 0x23b872dd;

    // bytes4(keccak256("transferFrom(address,address,uint256)"))
    bytes4 constant ERC721_TRANSFERFROM_SELECTOR = 0x23b872dd;

    // bytes4(keccak256("safeTransferFrom(address,address,uint256,uint256,bytes)"))
    bytes4 constant ERC1155_TRANSFERFROM_SELECTOR = 0xf242432a;

    // bytes4(keccak256("safeBatchTransferFrom(address,address,uint256[],uint256[],bytes)"))
    bytes4 constant ERC1155_BATCHTRANSFERFROM_SELECTOR = 0x2eb2c2d6;

    function safeTransferERC20(
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

    function safeTransferFromERC20(
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

    function safeTransferFromERC721(
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

    function safeTransferFromERC1155(
        address target,
        address from,
        address to,
        uint256 id,
        uint256 amount
    ) internal {
        (bool success, bytes memory data) = target.call(
            abi.encodeWithSelector(
                ERC1155_TRANSFERFROM_SELECTOR,
                from,
                to,
                id,
                amount,
                ""
            )
        );

        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "Low-level call failed"
        );
    }

    function safeBatchTransferFromERC1155(
        address target,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts
    ) internal {
        (bool success, bytes memory data) = target.call(
            abi.encodeWithSelector(
                ERC1155_BATCHTRANSFERFROM_SELECTOR,
                from,
                to,
                ids,
                amounts,
                ""
            )
        );

        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "Low-level call failed"
        );
    }
}
