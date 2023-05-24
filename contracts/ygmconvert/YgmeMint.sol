// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
}

interface IERC20USDT {
    function transferFrom(address from, address to, uint value) external;

    function transfer(address to, uint value) external;
}

interface IYGME {
    function swap(address to, address _recommender, uint mintNum) external;

    function balanceOf(address owner) external view returns (uint256 balance);

    function PAY() external view returns (uint256 pay);

    function maxLevel() external view returns (uint256 level);

    function recommender(
        address _account
    ) external view returns (address _recommender);

    function rewardLevelAmount(
        uint256 _level
    ) external view returns (uint256 amount);
}

interface IYgmeStake {
    function getStakingTokenIds(
        address _account
    ) external view returns (uint256[] memory);
}

contract YgmeMint is Ownable, ReentrancyGuard {
    address constant ZERO_ADDRESS = address(0);

    IERC20USDT public immutable usdt;

    IYGME public immutable ygme;

    IYgmeStake public immutable ygmestake;

    IERC20 public immutable ygio;

    bool public rewardSwitch;

    // TODO: main
    // _usdt 0xdAC17F958D2ee523a2206206994597C13D831ec7
    // _ygme 0x1b489201D974D37DDd2FaF6756106a7651914A63
    // _ygmestake 0xdAC17F958D2ee523a2206206994597C13D831ec7
    // _ygio 0x19C996c4E4596aADDA9b7756B34bBa614376FDd4
    // TODO: Goerli
    // _usdt 0x965A558b312E288F5A77F851F7685344e1e73EdF
    // _ygme 0x28d1bc817de02c9f105a6986ef85cb04863c3042
    // _ygmestake 0xEF6B5e06D3ED692729a01a7F471D386677943C85
    // _ygio 0xd042eF5cF97c902bF8F53244F4a81ec4f8E465Ab
    constructor(
        address _usdt,
        address _ygme,
        address _ygmestake,
        address _ygio
    ) {
        usdt = IERC20USDT(_usdt);
        ygme = IYGME(_ygme);
        ygmestake = IYgmeStake(_ygmestake);
        ygio = IERC20(_ygio);
    }

    function setRewardSwitch() external onlyOwner {
        rewardSwitch = !rewardSwitch;
    }

    function safeMint(
        address _recommender,
        uint256 mintNum
    ) external nonReentrant {
        address account = _msgSender();

        require(_recommender != ZERO_ADDRESS, "recommender can not be zero");

        require(_recommender != account, "recommender can not be self");

        require(
            ygme.balanceOf(_recommender) > 0 ||
                ygmestake.getStakingTokenIds(_recommender).length > 0,
            "invalid recommender"
        );

        uint256 unitPrice = ygme.PAY();

        usdt.transferFrom(account, address(ygme), mintNum * unitPrice);

        ygme.swap(account, _recommender, mintNum);

        if (rewardSwitch) {
            _rewardMint(account, mintNum);
        }
    }

    function _rewardMint(address to, uint mintNum) private {
        address rewward;
        for (uint i = 0; i <= ygme.maxLevel(); i++) {
            if (0 == i) {
                rewward = to;
            } else {
                rewward = ygme.recommender(rewward);
            }

            if (rewward != ZERO_ADDRESS && 0 != ygme.rewardLevelAmount(i)) {
                ygio.transfer(rewward, ygme.rewardLevelAmount(i) * mintNum);
            }
        }
    }
}
