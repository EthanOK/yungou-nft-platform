// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

contract OpenseaProxy {
    function execute(bytes memory data) external payable {
        require(data.length - 4 >= 32, "Invalid calldata size");

        (bool success, ) = address(0x00000000000000ADc04C56Bf30aC9d3c0aAF14dC)
            .call{value: msg.value}(data);
        require(success, "External call failed");
    }

    fallback() external {
        revert();
    }
}
