// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract YgmeDividend is Pausable, Ownable, ReentrancyGuard {
    event Deposit(address indexed account, uint256 indexed amount);

    event Withdraw(
        uint256 indexed orderId,
        address indexed coinAddress,
        address indexed account,
        uint256 amount
    );

    address private withdrawSigner;

    mapping(uint256 => bool) private orderIsInvalid;

    constructor(address _withdrawSigner) {
        withdrawSigner = _withdrawSigner;
    }

    function setPause() external onlyOwner {
        if (!paused()) {
            _pause();
        } else {
            _unpause();
        }
    }

    function setWithdrawSigner(address _withdrawSigner) external onlyOwner {
        withdrawSigner = _withdrawSigner;
    }

    function withdrawETHOnlyOwner(address account) external onlyOwner {
        payable(account).transfer(address(this).balance);
    }

    function getWithdrawSigner() external view onlyOwner returns (address) {
        return withdrawSigner;
    }

    function getOrderIdState(uint256 orderId) external view returns (bool) {
        return orderIsInvalid[orderId];
    }

    function getETHBalance() external view returns (uint256) {
        return address(this).balance;
    }

    function getERC20Balance(
        address coinAddress
    ) external view returns (uint256) {
        return IERC20(coinAddress).balanceOf(address(this));
    }

    // TODO: ETH MainNet Remove
    function getData(
        uint256 orderId,
        address coinAddress,
        address account,
        uint256 amount,
        uint256 endTime
    ) external pure returns (bytes memory data, bytes32 hash) {
        data = abi.encode(orderId, coinAddress, account, amount, endTime);

        hash = keccak256(data);
    }

    function deposit() external payable returns (uint256 amount) {
        amount = msg.value;

        emit Deposit(msg.sender, amount);

        return amount;
    }

    function withdraw(
        bytes calldata data,
        bytes calldata signature
    ) external whenNotPaused nonReentrant returns (bool) {
        require(data.length > 0 && signature.length > 0, "Invalid data");

        (
            uint256 orderId,
            address coinAddress,
            address account,
            uint256 amount,
            uint256 endTime
        ) = abi.decode(data, (uint256, address, address, uint256, uint256));

        require(block.timestamp < endTime, "Signature expired");

        require(!orderIsInvalid[orderId], "Invalid orderId");

        require(account == _msgSender(), "Invalid account");

        bytes32 hash = keccak256(data);

        _verifySignature(hash, signature);

        orderIsInvalid[orderId] = true;

        // address(0) = 0x0000000000000000000000000000000000000000
        if (coinAddress == address(0)) {
            // withdraw ETH
            require(address(this).balance >= amount, "ETH Insufficient");

            payable(account).transfer(amount);
        } else {
            // withdraw ERC20
            require(
                IERC20(coinAddress).balanceOf(address(this)) >= amount,
                "ERC20 Insufficient"
            );

            _transferLowCall(coinAddress, account, amount);
        }

        emit Withdraw(orderId, coinAddress, account, amount);

        return true;
    }

    function _verifySignature(
        bytes32 hash,
        bytes calldata signature
    ) internal view {
        hash = _toEthSignedMessageHash(hash);

        address signer = _recover(hash, signature);

        require(signer == withdrawSigner, "Invalid signature");
    }

    function _toEthSignedMessageHash(
        bytes32 hash
    ) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encodePacked("\x19Ethereum Signed Message:\n32", hash)
            );
    }

    function _recover(
        bytes32 hash,
        bytes memory signature
    ) internal pure returns (address signer) {
        if (signature.length == 65) {
            bytes32 r;
            bytes32 s;
            uint8 v;

            assembly {
                r := mload(add(signature, 0x20))
                s := mload(add(signature, 0x40))
                v := byte(0, mload(add(signature, 0x60)))
            }

            signer = ecrecover(hash, v, r, s);
        } else {
            revert("Incorrect Signature Length");
        }
    }

    function _transferLowCall(
        address target,
        address to,
        uint256 value
    ) internal {
        bytes memory data = abi.encodeWithSelector(
            IERC20.transfer.selector,
            to,
            value
        );

        (bool success, ) = target.call(data);
        require(success, "Low-level call failed");
    }

    receive() external payable {}
}
