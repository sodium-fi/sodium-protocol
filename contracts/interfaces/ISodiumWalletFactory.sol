// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ISodiumWalletFactory {
    /* ===== EVENTS ===== */

    // Emitted when a Sodium Wallet is created for a user
    event WalletCreated(address indexed owner, address wallet);

    /* ===== METHODS ===== */

    function createWallet(address borrower) external returns (address);
}
