// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ISodiumRegistry {
    function setCallPermissions(
        address[] calldata contractAddresses,
        bytes4[] calldata functionSignatures,
        bool[] calldata permissions_
    ) external;

    function getCallPermission(
        address contractAddress,
        bytes4 functionSignature
    ) external view returns (bool);
}
