// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {BasicOrderParameters, BasicOrder, OrderType} from "../lib/YunGouStructsAndEnums.sol";

interface YunGouInterface {
    event Exchange(
        address indexed offerer,
        address indexed offerToken,
        uint256 indexed offerTokenId,
        address buyer,
        uint256 buyAmount,
        uint256 totalPayment,
        uint256 totalRoyaltyFee,
        uint256 totalPlatformFee
    );

    function setBeneficiary(address payable newBeneficiary) external;

    function setSystemVerifier(address _systemVerifier) external;

    function getBeneficiary() external view returns (address);

    function getSystemVerifier() external view returns (address);

    function setPause() external;

    function excuteWithETH(
        BasicOrder calldata order,
        address receiver
    ) external payable returns (bool);

    function batchExcuteWithETH(
        BasicOrder[] calldata orders,
        address receiver
    ) external payable returns (bool);

    function name() external pure returns (string memory contractName);

    function information()
        external
        view
        returns (string memory version, bytes32 domainSeparator);

    function getOrderHash(
        BasicOrderParameters calldata orderParameters
    ) external view returns (bytes32 orderHash);
}
