// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./YgStakingDomain.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract YgStaking is
    YgStakingDomain,
    Pausable,
    Ownable,
    ERC721Holder,
    ReentrancyGuard
{
    using SafeERC20 for IERC20;

    uint64[3] private stakingPeriods;

    IERC721 public ygme;

    address private withdrawAccount;

    address private withdrawSigner;

    mapping(uint256 => StakingData) public stakingDatas;

    mapping(address => uint256[]) private stakingTokenIds;

    mapping(uint256 => bool) public orderIsInvalid;

    mapping(address => bool) public operator;

    uint128 public accountTotal;

    uint128 public ygmeTotal;

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function setStakingPeriods(uint64[3] calldata _periods) external onlyOwner {
        stakingPeriods = _periods;
    }

    function setOperator(address _account) external onlyOwner {
        operator[_account] = !operator[_account];
    }

    function setWithdrawSigner(address _withdrawSigner) external onlyOwner {
        withdrawSigner = _withdrawSigner;
    }

    function getStakingTokenIds(
        address _account
    ) external view returns (uint256[] memory) {
        return stakingTokenIds[_account];
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

    constructor(
        address _ygme,
        address _withdrawSigner,
        uint64[3] memory _periods
    ) {
        ygme = IERC721(_ygme);
        withdrawSigner = _withdrawSigner;
        stakingPeriods = _periods;
    }

    function staking(
        uint256[] calldata _tokenIds,
        uint256 _stakeTime
    ) external whenNotPaused nonReentrant returns (bool) {
        uint256 length = _tokenIds.length;

        address _account = _msgSender();

        require(length > 0, "invalid _tokenIds");

        require(
            _stakeTime == stakingPeriods[0] ||
                _stakeTime == stakingPeriods[1] ||
                _stakeTime == stakingPeriods[2],
            "invalid staking time"
        );

        if (stakingTokenIds[_account].length == 0) {
            unchecked {
                accountTotal += 1;
            }
        }

        for (uint256 i = 0; i < length; ) {
            uint256 _tokenId = _tokenIds[i];

            require(!stakingDatas[_tokenId].stakedState, "invalid stake state");

            require(ygme.ownerOf(_tokenId) == _account, "invalid owner");

            StakingData memory _data = StakingData({
                owner: _account,
                startTime: uint128(block.timestamp),
                endTime: uint128(block.timestamp + _stakeTime),
                stakedState: true
            });

            stakingDatas[_tokenId] = _data;

            if (stakingTokenIds[_account].length == 0) {
                stakingTokenIds[_account] = [_tokenId];
            } else {
                stakingTokenIds[_account].push(_tokenId);
            }

            unchecked {
                ygmeTotal += 1;
            }

            ygme.safeTransferFrom(_account, address(this), _tokenId);

            emit Staking(
                _account,
                _tokenId,
                address(ygme),
                _data.startTime,
                _data.endTime
            );

            unchecked {
                ++i;
            }
        }
        return true;
    }

    function unStake(
        uint256[] calldata _tokenIds
    ) external whenNotPaused nonReentrant returns (bool) {
        uint256 length = _tokenIds.length;

        address _account = _msgSender();

        require(length > 0, "invalid tokenIds");

        for (uint256 i = 0; i < length; ) {
            uint256 _tokenId = _tokenIds[i];

            StakingData storage _data = stakingDatas[_tokenId];

            require(_data.owner == _account, "invalid account");

            require(stakingDatas[_tokenId].stakedState, "invalid stake state");

            require(
                block.timestamp >= _data.endTime,
                "It's not time to unStake"
            );

            uint256 _len = stakingTokenIds[_account].length;

            for (uint256 j = 0; j < _len; j++) {
                if (stakingTokenIds[_account][j] == _tokenId) {
                    stakingTokenIds[_account][j] = stakingTokenIds[_account][
                        _len - 1
                    ];
                    stakingTokenIds[_account].pop();
                    break;
                }
            }

            if (stakingTokenIds[_account].length == 0) {
                accountTotal -= 1;
            }

            ygmeTotal -= 1;

            emit UnStake(
                _account,
                _tokenId,
                address(ygme),
                _data.startTime,
                block.timestamp
            );

            delete stakingDatas[_tokenId];

            ygme.safeTransferFrom(address(this), _account, _tokenId);

            unchecked {
                ++i;
            }
        }
        return true;
    }

    function withdrawERC20(
        bytes calldata data,
        Sig calldata sig
    ) external nonReentrant returns (bool) {
        bytes32 hash = keccak256(data);

        _verifySignature(hash, sig);

        (
            uint256 orderId,
            address erc20,
            address account,
            uint256 amount,
            string memory random
        ) = abi.decode(data, (uint256, address, address, uint256, string));

        require(!orderIsInvalid[orderId], "order is invalid");

        require(account == msg.sender, "caller is not the account");

        orderIsInvalid[orderId] = true;

        IERC20(erc20).safeTransferFrom(address(this), account, amount);

        emit WithdrawERC20(orderId, erc20, account, amount, random);

        return true;
    }

    function _verifySignature(bytes32 hash, Sig calldata sig) internal view {
        hash = _toEthSignedMessageHash(hash);

        address signer = ecrecover(hash, sig.v, sig.r, sig.s);

        require(signer == withdrawSigner, "incorrect withdraw signature");
    }

    function _toEthSignedMessageHash(
        bytes32 hash
    ) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encodePacked("\x19Ethereum Signed Message:\n32", hash)
            );
    }

    function aggregateStaticCall(
        Call[] calldata calls
    ) external view returns (uint256 blockNumber, bytes[] memory returnData) {
        require(operator[msg.sender], "you're not operator");

        blockNumber = block.number;

        uint256 length = calls.length;

        returnData = new bytes[](length);

        Call calldata call;

        for (uint256 i = 0; i < length; ) {
            bool success;
            call = calls[i];
            (success, returnData[i]) = call.target.staticcall(call.callData);
            require(success, "Multicall3: call failed");
            unchecked {
                ++i;
            }
        }
    }

    function validateSignature(
        bytes32 hash,
        Sig calldata sig,
        address signer
    ) external view returns (bool) {
        require(operator[msg.sender], "you're not operator");

        hash = _toEthSignedMessageHash(hash);

        address signer_ = ecrecover(hash, sig.v, sig.r, sig.s);

        return signer == signer_;
    }
}
