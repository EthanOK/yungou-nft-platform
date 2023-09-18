// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract YGIO_B is Pausable, Ownable, ERC20 {
    uint256 public constant BASE_10000 = 10_000;

    address private slippageAccount;

    // Base 10000
    mapping(address => uint256) private isTransactionPools;

    constructor(address _slippageAccount) ERC20("YGIO", "YGIO") {
        slippageAccount = _slippageAccount;

        mint(_msgSender(), 10_000 * 1e18);
    }

    function setPause() external onlyOwner {
        if (!paused()) {
            _pause();
        } else {
            _unpause();
        }
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

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

    function transfer(
        address to,
        uint256 amount
    ) public virtual override returns (bool) {
        address owner = _msgSender();

        // swap(pool => user) or removeLiquidity
        if (isTransactionPools[owner] == 0) {
            _transfer(owner, to, amount);
        } else {
            uint256 fees = (amount * isTransactionPools[owner]) / BASE_10000;

            _transfer(owner, slippageAccount, fees);

            // Deduct slippage
            _transfer(owner, to, amount - fees);
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

        //  addLiquidity or swap(user => pool)
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
}
