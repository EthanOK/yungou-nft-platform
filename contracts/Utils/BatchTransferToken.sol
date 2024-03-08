// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./TransferLib.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract BatchTransferToken is Pausable, Ownable {
    struct Call {
        address target;
        bytes callData;
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
        address[] calldata _tos,
        uint256[] calldata _amounts
    ) external payable whenNotPaused returns (bool) {
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

    function batchTransferERC20(
        address _token,
        address[] calldata _tos,
        uint256[] calldata _amounts
    ) external payable whenNotPaused returns (bool) {
        uint256 fees = msg.value;

        address _account = _msgSender();

        require(
            fees >= (Fees[_token] > 0 ? Fees[_token] : default_fees),
            "Insufficient fees"
        );

        require(_tos.length == _amounts.length, "Invalid Length");

        for (uint256 i = 0; i < _amounts.length; ++i) {
            TransferLib._safeTransferFromERC20(
                _token,
                _account,
                _tos[i],
                _amounts[i]
            );
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

        for (uint256 i = 0; i < _tokenIds.length; ++i) {
            TransferLib._safeTransferFromERC721(
                _token,
                _account,
                _to,
                _tokenIds[i]
            );
        }

        return true;
    }

    function batchTransferERC721(
        address _token,
        address[] calldata _tos,
        uint256[] calldata _tokenIds
    ) external payable whenNotPaused returns (bool) {
        uint256 fees = msg.value;

        address _account = _msgSender();

        require(
            fees >= (Fees[_token] > 0 ? Fees[_token] : default_fees),
            "Insufficient fees"
        );

        require(_tos.length == _tokenIds.length, "Invalid Length");

        for (uint256 i = 0; i < _tokenIds.length; ++i) {
            TransferLib._safeTransferFromERC721(
                _token,
                _account,
                _tos[i],
                _tokenIds[i]
            );
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

        for (uint256 i = 0; i < _ids.length; ++i) {
            TransferLib._safeBatchTransferFromERC1155(
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
    ) external payable whenNotPaused returns (bool) {
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
            TransferLib._safeTransferFromERC1155(
                _token,
                _account,
                _tos[i],
                _ids[i],
                _amounts[i]
            );
        }

        return true;
    }

    receive() external payable {}

    modifier onlyWhiter() {
        address sender = _msgSender();

        require(whiteList[sender] || sender == owner(), "not whiter");

        _;
    }
}
