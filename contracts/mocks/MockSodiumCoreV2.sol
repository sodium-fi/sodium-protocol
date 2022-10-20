// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../SodiumCore.sol";

// Mock SodiumCore upgrade for testing the Sodium protocol

contract MockSodiumCoreV2 is SodiumCore {
    function reInitialize(string calldata name, string calldata version)
        public
        reinitializer(2)
    {
        __EIP712_init(name, version);
    }
}
