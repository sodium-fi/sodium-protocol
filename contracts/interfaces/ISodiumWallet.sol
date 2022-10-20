// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../libraries/Types.sol";

interface ISodiumWallet {
    function initialize(
        address _owner,
        address _core,
        address _registry
    ) external;

    function execute(
        address[] calldata contractAddresses,
        bytes[] memory calldatas,
        uint256[] calldata values
    ) external payable;

    function transferERC721(
        address recipient,
        address tokenAddress,
        uint256 tokenId
    ) external;

    function transferERC1155(
        address recipient,
        address tokenAddress,
        uint256 tokenId
    ) external;

    function isValidSignature(bytes32 hash, bytes memory signature)
        external
        view
        returns (bytes4);
}
