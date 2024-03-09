// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./TransferLib.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract BatchTransferToken is Pausable, Ownable {
    using TransferLib for address;

    struct Call {
        address target;
        bytes callData;
    }

    struct ParaERC20 {
        address to;
        uint256 amount;
    }

    struct ParaERC721 {
        address to;
        uint256 tokenId;
    }

    struct ParaERC1155 {
        address to;
        uint256 id;
        uint256 amount;
    }

    uint256 public default_fees = 0.002 ether;

    mapping(address => uint256) public Fees;

    mapping(address => bool) public whiteList;

    function setFees(address token, uint256 fees) external onlyOwner {
        Fees[token] = fees;
    }

    function setDefaultFees(uint256 fees) external onlyOwner {
        default_fees = fees;
    }

    function withdrawFees(address receiver) external onlyOwner {
        payable(receiver).transfer(address(this).balance);
    }

    function setWhiteList(address _white) external onlyOwner {
        whiteList[_white] = !whiteList[_white];
    }

    function setPause() external onlyOwner {
        if (!paused()) {
            _pause();
        } else {
            _unpause();
        }
    }

    function aggregate(
        Call[] calldata calls
    )
        external
        payable
        onlyWhiter
        returns (uint256 blockNumber, bytes[] memory returnData)
    {
        blockNumber = block.number;
        uint256 length = calls.length;
        returnData = new bytes[](length);
        Call calldata call;
        for (uint256 i = 0; i < length; ) {
            bool success;
            call = calls[i];
            (success, returnData[i]) = call.target.call(call.callData);
            require(success, "Multicall3: call failed");
            unchecked {
                ++i;
            }
        }
    }

    function batchTransferETH(
        ParaERC20[] calldata paras
    ) external payable whenNotPaused returns (bool) {
        address _token = address(0);

        uint256 _pay = msg.value;

        uint256 _sumAmount;

        for (uint256 i = 0; i < paras.length; ) {
            unchecked {
                _sumAmount += paras[i].amount;
            }

            bool success;

            (success, ) = paras[i].to.call{value: paras[i].amount}("");

            require(success, "Transfer Err");

            unchecked {
                ++i;
            }
        }

        require(_pay > _sumAmount, "Insufficient Payment");

        unchecked {
            require(
                (_pay - _sumAmount) >=
                    (Fees[_token] > 0 ? Fees[_token] : default_fees),
                "Insufficient fees"
            );
        }

        return true;
    }

    function batchTransferERC20(
        address _token,
        ParaERC20[] calldata paras
    ) external payable whenNotPaused returns (bool) {
        uint256 fees = msg.value;

        address _account = _msgSender();

        require(
            fees >= (Fees[_token] > 0 ? Fees[_token] : default_fees),
            "Insufficient fees"
        );

        for (uint256 i = 0; i < paras.length; ) {
            _token.safeTransferFromERC20(
                _account,
                paras[i].to,
                paras[i].amount
            );

            unchecked {
                ++i;
            }
        }

        return true;
    }

    function batchTransferERC721(
        address _token,
        address _to,
        uint256[] calldata _tokenIds
    ) external payable whenNotPaused returns (bool) {
        uint256 fees = msg.value;

        address _account = _msgSender();

        require(
            fees >= (Fees[_token] > 0 ? Fees[_token] : default_fees),
            "Insufficient fees"
        );

        for (uint256 i = 0; i < _tokenIds.length; ) {
            _token.safeTransferFromERC721(_account, _to, _tokenIds[i]);

            unchecked {
                ++i;
            }
        }

        return true;
    }

    function batchTransferERC721(
        address _token,
        ParaERC721[] calldata _paras
    ) external payable whenNotPaused returns (bool) {
        uint256 fees = msg.value;

        address _account = _msgSender();

        require(
            fees >= (Fees[_token] > 0 ? Fees[_token] : default_fees),
            "Insufficient fees"
        );

        for (uint256 i = 0; i < _paras.length; ) {
            _token.safeTransferFromERC721(
                _account,
                _paras[i].to,
                _paras[i].tokenId
            );

            unchecked {
                ++i;
            }
        }

        return true;
    }

    function batchTransferERC1155(
        address _token,
        address _to,
        uint256[] memory _ids,
        uint256[] memory _amounts
    ) external payable whenNotPaused returns (bool) {
        uint256 fees = msg.value;

        address _account = _msgSender();

        require(
            fees >= (Fees[_token] > 0 ? Fees[_token] : default_fees),
            "Insufficient fees"
        );

        require(_amounts.length == _ids.length, "Invalid Length");

        for (uint256 i = 0; i < _ids.length; ) {
            _token.safeBatchTransferFromERC1155(_account, _to, _ids, _amounts);

            unchecked {
                ++i;
            }
        }

        return true;
    }

    function batchTransferERC1155(
        address _token,
        ParaERC1155[] calldata _paras
    ) external payable whenNotPaused returns (bool) {
        uint256 fees = msg.value;

        address _account = _msgSender();

        require(
            fees >= (Fees[_token] > 0 ? Fees[_token] : default_fees),
            "Insufficient fees"
        );

        for (uint256 i = 0; i < _paras.length; ) {
            _token.safeTransferFromERC1155(
                _account,
                _paras[i].to,
                _paras[i].id,
                _paras[i].amount
            );

            unchecked {
                ++i;
            }
        }

        return true;
    }

    receive() external payable {}

    modifier onlyWhiter() {
        address sender = _msgSender();

        require(whiteList[sender] || sender == owner(), "Not whiter");

        _;
    }
}
