const { ethers } = require("hardhat");
const { time } = require("@nomicfoundation/hardhat-network-helpers");

// Make a loan request with ERC721 collateral
// - Mints the collateral to the borrower
// - Sends to core to request a loan
// Returns the ID of the loan
const requestWithERC721 = async (
  core,
  borrower,
  ERC721,
  tokenId,
  amount = ethers.utils.parseEther("10"),
  APR = 5,
  length = 864000,
  currency = ethers.constants.AddressZero
) => {
  // Mint NFT to the borrower
  await ERC721.mint(borrower.address, tokenId);

  // Encode request parameters
  const requestParams = ethers.utils.defaultAbiCoder.encode(
    ["tuple(uint256,uint256,uint256,address)"],
    [[amount, APR, length, currency]]
  );

  // Send token to the core with request parameters
  const tx = await ERC721.connect(borrower)[
    "safeTransferFrom(address,address,uint256,bytes)"
  ](borrower.address, core.address, tokenId, requestParams);

  // Calculate loan ID
  const timestamp = await time.latest();
  const requestHashInput = ethers.utils.defaultAbiCoder.encode(
    ["uint256", "address", "uint256"],
    [tokenId, ERC721.address, timestamp]
  );
  const requestId = ethers.BigNumber.from(
    ethers.utils.keccak256(requestHashInput)
  );

  return { requestId, tx };
};

// Request a loan by sending an ERC1155 token of a specific type to the Core contract
// Mints the collateral to the borrower
const requestWithERC1155 = async (
  core,
  borrower,
  ERC1155,
  tokenId,
  amount = ethers.utils.parseEther("10"),
  APR = 5,
  length = 864000,
  currency = ethers.constants.AddressZero,
  nonce = 0
) => {
  // Mint single token to the borrower
  await ERC1155.mint(borrower.address, tokenId, 1);

  // Encode request parameters
  const requestParams = ethers.utils.defaultAbiCoder.encode(
    ["tuple(uint256,uint256,uint256,address)"],
    [[amount, APR, length, currency]]
  );

  // Send single token to the core with request parameters
  const tx = await ERC1155.connect(borrower).safeTransferFrom(
    borrower.address,
    core.address,
    tokenId,
    1,
    requestParams
  );

  // Calculate request ID
  const requestHashInput = ethers.utils.defaultAbiCoder.encode(
    ["uint256", "address", "uint256"],
    [tokenId, ERC1155.address, nonce]
  );
  const requestId = ethers.BigNumber.from(
    ethers.utils.keccak256(requestHashInput)
  );

  return { requestId, tx };
};

module.exports = {
  requestWithERC721,
  requestWithERC1155,
};
