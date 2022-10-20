// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/proxy/Clones.sol";

import "./interfaces/ISodiumWalletFactory.sol";
import "./interfaces/ISodiumWallet.sol";

/// @notice Simple clone factory for creating minimal proxy Sodium Wallets
contract SodiumWalletFactory is ISodiumWalletFactory {
    /* ===== STATE ===== */

    // Wallet implementation contract
    address public implementation;

    // The address of the current Sodium Registry
    address public registry;

    /* ===== CONSTRUCTOR ===== */

    /// @param implementation_ The contract to which wallets deployed by this contract delegate their calls
    /// @param registry_ Used by the wallets to determine external call permission
    constructor(address implementation_, address registry_) {
        implementation = implementation_;
        registry = registry_;
    }

    /* ===== CORE METHODS ===== */

    /// @notice Called by the Core to create new wallets
    /// @dev Deploys a minimal EIP-1167 proxy that delegates its calls to `implementation`
    /// @param requester The owner of the new wallet
    function createWallet(address requester)
        external
        override
        returns (address)
    {
        // Deploy
        address wallet = Clones.clone(implementation);

        // Configure
        ISodiumWallet(wallet).initialize(requester, msg.sender, registry);

        emit WalletCreated(requester, wallet);

        // Pass address back to Core
        return wallet;
    }
}
