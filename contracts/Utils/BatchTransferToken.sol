// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract BatchTransferToken is Pausable, Ownable {
    // bytes4(keccak256("transferFrom(address,address,uint256)"))
    bytes4 constant ERC20_TRANSFERFROM_SELECTOR = 0x23b872dd;

    // bytes4(keccak256("transferFrom(address,address,uint256)"))
    bytes4 constant ERC721_TRANSFERFROM_SELECTOR = 0x23b872dd;

    // bytes4(keccak256("safeTransferFrom(address,address,uint256,uint256,bytes)"))
    bytes4 constant ERC1155_TRANSFERFROM_SELECTOR = 0xf242432a;

    // bytes4(keccak256("safeBatchTransferFrom(address,address,uint256[],uint256[],bytes)"))
    bytes4 constant ERC1155_BATCHTRANSFERFROM_SELECTOR = 0x2eb2c2d6;

    uint256 public default_fees = 0.002 ether;

    mapping(address => uint256) Fees;

    function setFees(address token, uint256 fees) external onlyOwner {
        Fees[token] = fees;
    }

    function setDefaultFees(uint256 fees) external onlyOwner {
        default_fees = fees;
    }

    function withdrawFees(address receiver) external onlyOwner {
        payable(receiver).transfer(address(this).balance);
    }

    function batchTransferETH(
        address[] calldata _tos,
        uint256[] calldata _amounts
    ) external payable returns (bool) {
        address _token = address(0);

        uint256 _pay = msg.value;

        uint256 _sumAmount;

        require(_tos.length == _amounts.length, "Invalid Length");

        for (uint256 i = 0; i < _tos.length; ++i) {
            _sumAmount += _amounts[i];

            payable(_tos[i]).transfer(_amounts[i]);
        }

        require(_pay > _sumAmount, "insufficient Payment");

        require(
            (_pay - _sumAmount) >=
                (Fees[_token] > 0 ? Fees[_token] : default_fees),
            "Insufficient fees"
        );

        return true;
    }

    function batchTransferERC721(
        address _token,
        address _to,
        uint256[] calldata _tokenIds
    ) external payable returns (bool) {
        uint256 fees = msg.value;

        address _account = _msgSender();

        require(
            fees >= (Fees[_token] > 0 ? Fees[_token] : default_fees),
            "Insufficient fees"
        );

        for (uint256 i = 0; i < _tokenIds.length; ++i) {
            _safeTransferFromERC721(_token, _account, _to, _tokenIds[i]);
        }

        return true;
    }

    function batchTransferERC721(
        address _token,
        address[] calldata _tos,
        uint256[] calldata _tokenIds
    ) external payable returns (bool) {
        uint256 fees = msg.value;

        address _account = _msgSender();

        require(
            fees >= (Fees[_token] > 0 ? Fees[_token] : default_fees),
            "Insufficient fees"
        );

        require(_tos.length == _tokenIds.length, "Invalid Length");

        for (uint256 i = 0; i < _tokenIds.length; ++i) {
            _safeTransferFromERC721(_token, _account, _tos[i], _tokenIds[i]);
        }

        return true;
    }

    function batchTransferERC1155(
        address _token,
        address _to,
        uint256[] memory _ids,
        uint256[] memory _amounts
    ) external payable returns (bool) {
        uint256 fees = msg.value;

        address _account = _msgSender();

        require(
            fees >= (Fees[_token] > 0 ? Fees[_token] : default_fees),
            "Insufficient fees"
        );

        require(_amounts.length == _ids.length, "Invalid Length");

        for (uint256 i = 0; i < _ids.length; ++i) {
            _safeBatchTransferFromERC1155(
                _token,
                _account,
                _to,
                _ids,
                _amounts
            );
        }

        return true;
    }

    function batchTransferERC1155(
        address _token,
        address[] calldata _tos,
        uint256[] calldata _ids,
        uint256[] calldata _amounts
    ) external payable returns (bool) {
        uint256 fees = msg.value;

        address _account = _msgSender();

        require(
            fees >= (Fees[_token] > 0 ? Fees[_token] : default_fees),
            "Insufficient fees"
        );

        require(
            _tos.length == _ids.length && _tos.length == _amounts.length,
            "Invalid Length"
        );

        for (uint256 i = 0; i < _tos.length; ++i) {
            _safeTransferFromERC1155(
                _token,
                _account,
                _tos[i],
                _ids[i],
                _amounts[i]
            );
        }

        return true;
    }

    function batchTransferERC20(
        address _token,
        address[] calldata _tos,
        uint256[] calldata _amounts
    ) external payable returns (bool) {
        uint256 fees = msg.value;

        address _account = _msgSender();

        require(
            fees >= (Fees[_token] > 0 ? Fees[_token] : default_fees),
            "Insufficient fees"
        );

        require(_tos.length == _amounts.length, "Invalid Length");

        for (uint256 i = 0; i < _amounts.length; ++i) {
            _safeTransferFromERC20(_token, _account, _tos[i], _amounts[i]);
        }

        return true;
    }

    receive() external payable {}

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

    function _safeTransferFromERC1155(
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

    function _safeBatchTransferFromERC1155(
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
