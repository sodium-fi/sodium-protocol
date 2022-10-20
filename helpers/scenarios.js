const { ethers } = require("hardhat");
const { time } = require("@nomicfoundation/hardhat-network-helpers");

const { requestWithERC721 } = require("./requesting.js");
const {
  addToETHLoan,
  addToERC20Loan,
  makeMetaContribution,
} = require("./lending.js");

// Helper methods that set up testing scenarios

// Currency = ETH | Collateral ERC721

// Change name to initiateETHAuctionForERC721
async function initiateERC721ETHAuction(
  core,
  borrower,
  ERC721,
  tokenId,
  requestAmount,
  requestAPR,
  length,
  metaLenders,
  contributions,
  amounts,
  validator
) {
  const { loanId: auctionId } = await initiateERC721CollateralisedETHLoan(
    core,
    borrower,
    ERC721,
    tokenId,
    requestAmount,
    requestAPR,
    length,
    metaLenders,
    contributions,
    amounts,
    validator
  );

  await time.increase(length);

  return auctionId;
}

// Setup up an ERC-721 collateralised ETH loan
// One or more meta-contributions added when turning request => active loan
async function initiateERC721CollateralisedETHLoan(
  core,
  borrower,
  ERC721,
  tokenId,
  requestAmount,
  requestAPR,
  length,
  metaLenders,
  contributions,
  amounts,
  validator
) {
  const { requestId } = await requestWithERC721(
    core,
    borrower,
    ERC721,
    tokenId,
    requestAmount,
    requestAPR,
    length,
    ethers.constants.AddressZero
  );

  const metaContributions = await Promise.all(
    metaLenders.map(async (metaLender, i) => {
      return await makeMetaContribution(
        requestId,
        metaLender,
        core,
        contributions[i].available,
        contributions[i].APR,
        contributions[i].liquidityLimit
      );
    })
  );

  const tx = await addToETHLoan(
    core,
    requestId,
    metaLenders,
    metaContributions,
    borrower,
    amounts,
    validator
  );

  return { loanId: requestId, tx };
}

// Currency = ERC20 | Collateral ERC721

async function initiateERC721ERC20Auction(
  core,
  borrower,
  ERC721,
  tokenId,
  ERC20,
  requestAmount,
  requestAPR,
  length,
  metaLenders,
  contributions,
  amounts,
  validator
) {
  const { loanId: auctionId } = await initiateERC721CollateralisedERC20Loan(
    core,
    borrower,
    ERC721,
    tokenId,
    ERC20,
    requestAmount,
    requestAPR,
    length,
    metaLenders,
    contributions,
    amounts,
    validator
  );

  await time.increase(length);

  return auctionId;
}

// Setup up an ERC-721 collateralised ETH loan
// One or more meta-contributions added when turning request => active loan
async function initiateERC721CollateralisedERC20Loan(
  core,
  borrower,
  ERC721,
  tokenId,
  ERC20,
  requestAmount,
  requestAPR,
  length,
  metaLenders,
  contributions,
  amounts,
  validator
) {
  const { requestId } = await requestWithERC721(
    core,
    borrower,
    ERC721,
    tokenId,
    requestAmount,
    requestAPR,
    length,
    ERC20.address
  );

  const metaContributions = await Promise.all(
    metaLenders.map(async (metaLender, i) => {
      return await makeMetaContribution(
        requestId,
        metaLender,
        core,
        contributions[i].available,
        contributions[i].APR,
        contributions[i].liquidityLimit
      );
    })
  );

  const tx = await addToERC20Loan(
    core,
    ERC20,
    requestId,
    metaLenders,
    metaContributions,
    borrower,
    amounts,
    validator
  );

  return { loanId: requestId, tx };
}

module.exports = {
  initiateERC721CollateralisedETHLoan,
  initiateERC721ETHAuction,
  initiateERC721CollateralisedERC20Loan,
  initiateERC721ERC20Auction,
};
