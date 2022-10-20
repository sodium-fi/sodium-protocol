// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

import "./interfaces/ISodiumRegistry.sol";

/// @notice A registry contract that stores call permissions
/// @dev Used by Sodium wallets to check if an external call is safe during `execute` calls
/// Each call is defined by an address and a function signature
contract SodiumRegistry is ISodiumRegistry, Ownable {
    // Maps contract address => function signature => call permission
    mapping(address => mapping(bytes4 => bool)) public permissions;

    /// @notice Used by Registry owner to set permission for one or more calls
    /// @param contractAddresses The in-order addresses to which the calls in question are made
    /// @param functionSignatures The in-order signatures of each call
    /// @param permissions_ The in-order permissions to be assigned to the calls
    function setCallPermissions(
        address[] calldata contractAddresses,
        bytes4[] calldata functionSignatures,
        bool[] calldata permissions_
    ) external override onlyOwner {
        for (uint256 i = 0; i < contractAddresses.length; i++) {
            permissions[contractAddresses[i]][
                functionSignatures[i]
            ] = permissions_[i];
        }
    }

    /// @notice Used to obtain call permission
    /// @param contractAddress The address of the contract to which the calls are made
    /// @param functionSignature The address of the contract to which the calls are made
    /// @return Whether walllets are permitted to make calls with input address & signature combination
    function getCallPermission(
        address contractAddress,
        bytes4 functionSignature
    ) external view override returns (bool) {
        return permissions[contractAddress][functionSignature];
    }
}
