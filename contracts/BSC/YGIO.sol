// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract YGIO_BSC is Pausable, Ownable, ERC20 {
    uint256 public constant BASE_10000 = 10_000;

    address private slippageAccount;

    // Base 10000
    mapping(address => uint256) private isTransactionPools;

    // white Lists
    mapping(address => bool) private whiteLists;

    constructor(address _slippageAccount) ERC20("BYGIO", "BYGIO") {
        slippageAccount = _slippageAccount;
    }

    function setPause() external onlyOwner {
        if (!paused()) {
            _pause();
        } else {
            _unpause();
        }
    }

    function setWhiteList(address _account) external onlyOwner {
        whiteLists[_account] = !whiteLists[_account];
    }

    function getWhiteList(address _account) external view returns (bool) {
        return whiteLists[_account];
    }

    function setTxPoolRate(address txPool, uint256 feeRate) external onlyOwner {
        isTransactionPools[txPool] = feeRate;
    }

    function getSlippageAccount() external view returns (address) {
        return slippageAccount;
    }

    function getPoolRate(address txPool) external view returns (uint256) {
        return isTransactionPools[txPool];
    }

    function setSlippageAccount(address _slippageAccount) external onlyOwner {
        slippageAccount = _slippageAccount;
    }

    function mint(address to, uint256 amount) external onlyOwnerOrWhiteList {
        _mint(to, amount);
    }

    function burnFrom(address account, uint256 value) external {
        _spendAllowance(account, _msgSender(), value);
        _burn(account, value);
    }

    function transfer(
        address to,
        uint256 amount
    ) public virtual override returns (bool) {
        address _account = _msgSender();

        // swap(pool => user) or removeLiquidity
        if (isTransactionPools[_account] == 0) {
            _transfer(_account, to, amount);
        } else {
            uint256 fees = (amount * isTransactionPools[_account]) / BASE_10000;

            _transfer(_account, slippageAccount, fees);

            // Deduct slippage
            _transfer(_account, to, amount - fees);
        }
        return true;
    }

    function batchTransfer(
        address[] calldata tos,
        uint256[] calldata amounts
    ) external returns (bool) {
        require(tos.length == amounts.length, "Invalid Paras");

        address _account = _msgSender();

        uint256 count = tos.length;

        for (uint i = 0; i < count; ++i) {
            _transfer(_account, tos[i], amounts[i]);
        }

        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual override returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, amount);

        // addLiquidity or swap(user => pool)
        if (isTransactionPools[to] == 0) {
            _transfer(from, to, amount);
        } else {
            uint256 fees = (amount * isTransactionPools[to]) / BASE_10000;

            _transfer(from, slippageAccount, fees);

            // Deduct slippage
            _transfer(from, to, amount - fees);
        }

        return true;
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override whenNotPaused {
        super._beforeTokenTransfer(from, to, amount);
    }

    modifier onlyOwnerOrWhiteList() {
        address _caller = _msgSender();

        require(owner() == _caller || whiteLists[_caller], "No permission");
        _;
    }
}
