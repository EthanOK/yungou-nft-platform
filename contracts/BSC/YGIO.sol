// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract YGIO_B is Pausable, Ownable, ERC20 {
    uint256 public constant BASE_10000 = 10_000;

    address private slippageAccount;
    // Base 10000
    mapping(address => uint256) private isTransactionPools;

    constructor(address _slippageAccount) ERC20("YGIO", "YGIO") {
        slippageAccount = _slippageAccount;
        mint(_msgSender(), 10_000_000 * 10e18);
    }

    function setPause() external onlyOwner {
        if (!paused()) {
            _pause();
        } else {
            _unpause();
        }
    }

    function setSlippageAccount(
        address txPool,
        uint256 feeRate
    ) external onlyOwner {
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

        if (isTransactionPools[owner] == 0) {
            _transfer(owner, to, amount);
        } else {
            uint256 fees = (amount * isTransactionPools[owner]) / BASE_10000;

            _transfer(slippageAccount, to, fees);

            // Deduct slippage
            _transfer(owner, to, amount - fees);
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
