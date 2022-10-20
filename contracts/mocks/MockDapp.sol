// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

// Mock dapp contract for testing SodiumWallet's `execute` function
contract MockDapp is ERC20 {
    constructor() ERC20("Mock Dapp Tokens", "MDT") {}

    // Mints a single token if caller owns ERC721 token specified by `tokenAddress` and `tokenId`
    function mintIfERC721Owner(
        address tokenReceiver,
        address tokenAddress,
        uint256 tokenId
    ) public {
        require(IERC721(tokenAddress).ownerOf(tokenId) == msg.sender);
        _mint(tokenReceiver, 1);
    }
}
