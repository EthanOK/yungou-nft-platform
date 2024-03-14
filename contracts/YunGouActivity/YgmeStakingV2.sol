// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../Utils/TransferLib.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";

interface IYGME {
    function ownerOf(uint256 tokenId) external view returns (address owner);
}

abstract contract YgmeStakingDomain {
    struct StakingData {
        address owner;
        bool stakedState;
        uint128 startTime;
        uint128 endTime;
    }

    event Staking(
        address indexed account,
        uint256 indexed tokenId,
        address indexed nftContract,
        uint256 startTime,
        uint256 endTime,
        uint256 pledgeType
    );

    event WithdrawERC20(uint256 orderId, address account, uint256 amount);
}

contract YgmeStakingV2 is
    YgmeStakingDomain,
    Pausable,
    Ownable,
    ERC721Holder,
    ReentrancyGuard
{
    using ECDSA for bytes32;
    using TransferLib for address;

    uint64 public constant ONE_CYCLE = 1 days;

    uint64[3] private stakingPeriods;

    address public immutable ygme;

    address private withdrawSigner;

    mapping(uint256 => StakingData) public stakingDatas;

    mapping(address => uint256[]) private stakingTokenIds;

    mapping(uint256 => bool) public orderIsInvalid;

    uint128 public accountTotal;

    uint128 public ygmeTotal;

    constructor(address _ygme, address _withdrawSigner) {
        ygme = _ygme;
        withdrawSigner = _withdrawSigner;
        stakingPeriods = [30 * ONE_CYCLE, 60 * ONE_CYCLE, 90 * ONE_CYCLE];
    }

    function setPause() external onlyOwner {
        if (!paused()) {
            _pause();
        } else {
            _unpause();
        }
    }

    function setStakingPeriods(uint64[3] calldata _days) external onlyOwner {
        for (uint i = 0; i < _days.length; i++) {
            stakingPeriods[i] = _days[i] * ONE_CYCLE;
        }
    }

    function setWithdrawSigner(address _withdrawSigner) external onlyOwner {
        withdrawSigner = _withdrawSigner;
    }

    function getStakingTokenIds(
        address _account
    ) external view returns (uint256[] memory) {
        return stakingTokenIds[_account];
    }

    function getStakingNumber(
        address _account
    ) external view returns (uint256) {
        return stakingTokenIds[_account].length;
    }

    function getStakingPeriods()
        external
        view
        onlyOwner
        returns (uint64[3] memory)
    {
        return stakingPeriods;
    }

    function getWithdrawSigner() external view onlyOwner returns (address) {
        return withdrawSigner;
    }

    function staking(
        uint256[] calldata _tokenIds,
        uint256 _stakeDays
    ) external whenNotPaused nonReentrant returns (bool) {
        uint256 length = _tokenIds.length;
        uint256 _stakeTime = _stakeDays * ONE_CYCLE;
        address _account = _msgSender();

        require(length > 0, "Invalid tokenIds");

        require(
            _stakeTime == stakingPeriods[0] ||
                _stakeTime == stakingPeriods[1] ||
                _stakeTime == stakingPeriods[2],
            "Invalid StakeTime"
        );

        if (stakingTokenIds[_account].length == 0) {
            unchecked {
                accountTotal += 1;
            }
        }

        for (uint256 i = 0; i < length; ) {
            uint256 _tokenId = _tokenIds[i];

            require(!stakingDatas[_tokenId].stakedState, "Invalid StakeState");

            require(IYGME(ygme).ownerOf(_tokenId) == _account, "Invalid owner");

            StakingData memory _data = StakingData({
                owner: _account,
                stakedState: true,
                startTime: uint128(block.timestamp),
                endTime: uint128(block.timestamp + _stakeTime)
            });

            stakingDatas[_tokenId] = _data;

            if (stakingTokenIds[_account].length == 0) {
                stakingTokenIds[_account] = [_tokenId];
            } else {
                stakingTokenIds[_account].push(_tokenId);
            }

            ygme.safeTransferFromERC721(_account, address(this), _tokenId);

            emit Staking(
                _account,
                _tokenId,
                address(ygme),
                _data.startTime,
                _data.endTime,
                1
            );

            unchecked {
                ++i;
            }
        }

        unchecked {
            ygmeTotal += uint128(length);
        }

        return true;
    }

    function unStake(
        uint256[] calldata _tokenIds
    ) external whenNotPaused nonReentrant returns (bool) {
        uint256 length = _tokenIds.length;

        address _account = _msgSender();

        require(length > 0, "Invalid tokenIds");

        for (uint256 i = 0; i < length; ) {
            uint256 _tokenId = _tokenIds[i];

            StakingData memory _data = stakingDatas[_tokenId];

            require(_data.owner == _account, "Invalid account");

            require(_data.stakedState, "Invalid stake state");

            require(block.timestamp >= _data.endTime, "Too early to unStake");

            uint256 _len = stakingTokenIds[_account].length;

            for (uint256 j = 0; j < _len; ) {
                if (stakingTokenIds[_account][j] == _tokenId) {
                    stakingTokenIds[_account][j] = stakingTokenIds[_account][
                        _len - 1
                    ];
                    stakingTokenIds[_account].pop();
                    break;
                }

                unchecked {
                    ++j;
                }
            }

            emit Staking(
                _account,
                _tokenId,
                address(ygme),
                _data.startTime,
                block.timestamp,
                2
            );

            delete stakingDatas[_tokenId];

            ygme.safeTransferFromERC721(address(this), _account, _tokenId);

            unchecked {
                ++i;
            }
        }

        if (stakingTokenIds[_account].length == 0) {
            accountTotal -= 1;
        }

        ygmeTotal -= uint128(length);

        return true;
    }

    function unStakeOnlyOwner(uint256[] calldata _tokenIds) external onlyOwner {
        uint256 length = _tokenIds.length;

        for (uint256 i = 0; i < length; ) {
            uint256 _tokenId = _tokenIds[i];

            StakingData memory _data = stakingDatas[_tokenId];

            address _account = _data.owner;

            require(_data.stakedState, "Invalid StakeState");

            uint256 _len = stakingTokenIds[_account].length;

            for (uint256 j = 0; j < _len; ) {
                if (stakingTokenIds[_account][j] == _tokenId) {
                    stakingTokenIds[_account][j] = stakingTokenIds[_account][
                        _len - 1
                    ];

                    stakingTokenIds[_account].pop();

                    break;
                }

                unchecked {
                    ++j;
                }
            }

            emit Staking(
                _account,
                _tokenId,
                address(ygme),
                _data.startTime,
                block.timestamp,
                3
            );

            delete stakingDatas[_tokenId];

            ygme.safeTransferFromERC721(address(this), _account, _tokenId);

            if (stakingTokenIds[_account].length == 0) {
                accountTotal -= 1;
            }

            unchecked {
                ++i;
            }
        }

        ygmeTotal -= uint128(length);
    }

    // data = abi.encode(contract, orderId, account, token, amount, endTime)
    function withdrawERC20(
        bytes calldata data,
        bytes calldata signature
    ) external nonReentrant returns (bool) {
        require(data.length > 0, "Invalid data");

        bytes32 hash = keccak256(data);

        _verifySignature(hash, signature);

        (
            address this_contract,
            uint256 orderId,
            address account,
            address token,
            uint256 amount,
            uint256 endTime
        ) = abi.decode(
                data,
                (address, uint256, address, address, uint256, uint256)
            );

        require(this_contract == address(this), "Invalid contract");

        require(!orderIsInvalid[orderId], "Invalid orderId");

        require(block.timestamp < endTime, "Signature expired");

        require(account == _msgSender(), "Invalid account");

        orderIsInvalid[orderId] = true;

        token.safeTransferERC20(account, amount);

        emit WithdrawERC20(orderId, account, amount);

        return true;
    }

    function _verifySignature(
        bytes32 hash,
        bytes calldata signature
    ) internal view {
        hash = hash.toEthSignedMessageHash();

        address signer = hash.recover(signature);

        require(signer == withdrawSigner, "Invalid signature");
    }
}
