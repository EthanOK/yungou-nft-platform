// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract YGIOStake is Pausable, Ownable, ReentrancyGuard {
    address public constant YGIO = 0xb06DcE9ae21c3b9163cD933E40c9EE563366b783;
    uint64[4] private stakePeriods;

    constructor() {
        stakePeriods = [uint64(30 days), 90 days, 180 days, 360 days];
    }

    function getMulFactor(
        address account
    ) external pure returns (uint256 numerator, uint256 denominator) {
        return (150, 100);
    }

    //_level: 1 ~ 4
    function stakingYGIO(
        uint256 _amount,
        uint256 _level
    ) external whenNotPaused nonReentrant {
        require(
            _amount > 0 && _level > 0 && _level <= 4,
            "incorrect parameter"
        );

        address _account = _msgSender();

        uint256 _balance = IERC20(YGIO).balanceOf(_account);

        require(_amount <= _balance, "Insufficient balance");
    }

    function unStakeYGIO() external whenNotPaused nonReentrant {}
}
