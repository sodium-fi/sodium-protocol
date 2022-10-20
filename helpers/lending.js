const { ethers } = require("hardhat");
const { time } = require("@nomicfoundation/hardhat-network-helpers");

const { mintAndApproveWETH, mintAndApproveERC20 } = require("./tokens.js");

// Wrapper for addFundsETH calls that:
// - manages the addition's no-withdrawal signature
// - mints and approves the required WETH to the core
async function addToETHLoan(
  core,
  id,
  lenders,
  contributions,
  borrower,
  amounts,
  validator
) {
  await Promise.all(
    lenders.map(async (lender, i) => {
      return await mintAndApproveWETH(lender, core, contributions[i].available);
    })
  );

  const metaContributions = await Promise.all(
    lenders.map(async (lender, i) => {
      return await makeMetaContribution(
        id,
        lender,
        core,
        contributions[i].available,
        contributions[i].APR,
        contributions[i].liquidityLimit
      );
    })
  );

  // Get signature that validates meta-contributions for next 100 secs
  const deadline = (await time.latest()) + 100;
  const { v, r, s } = await getValidationSig(
    validator,
    deadline,
    metaContributions
  );

  const tx = core.connect(borrower).borrowETH(id, metaContributions, amounts, {
    deadline: deadline,
    v: v,
    r: r,
    s: s,
  });

  return tx;
}

// Wrapper for addFundsERC20 calls that:
// - manages the addition's no-withdrawal signature
// - mints and approves the required tokens to the core
async function addToERC20Loan(
  core,
  ERC20,
  id,
  lenders,
  contributions,
  borrower,
  amounts,
  validator
) {
  await Promise.all(
    lenders.map(async (lender, i) => {
      return await mintAndApproveERC20(
        ERC20,
        lender,
        core,
        contributions[i].available
      );
    })
  );

  const metaContributions = await Promise.all(
    lenders.map(async (lender, i) => {
      return await makeMetaContribution(
        id,
        lender,
        core,
        contributions[i].available,
        contributions[i].APR,
        contributions[i].liquidityLimit
      );
    })
  );

  // Get signature that validates meta-contributions for next 100 secs
  const deadline = (await time.latest()) + 100;
  const { v, r, s } = await getValidationSig(
    validator,
    deadline,
    metaContributions
  );

  const tx = core
    .connect(borrower)
    .borrowERC20(id, metaContributions, amounts, {
      deadline: deadline,
      v: v,
      r: r,
      s: s,
    });

  return tx;
}

// Create lender meta-contribution
// `available` is the total liqudity offered by the lender in the meta-contribution
// The borrower may add up to `available` => provided that total loan liquidity does not surpass their `liquidityLimit`
const makeMetaContribution = async (
  id,
  lender,
  core,
  available,
  APR,
  liquidityLimit,
  version = "1.0"
) => {
  // EIP712 domain
  const coreDomain = {
    name: "Sodium Core",
    version: version,
    chainId: 1,
    verifyingContract: core.address,
  };

  // Lender signs contribution terms following EIP712
  const types = {
    MetaContribution: [
      {
        name: "id",
        type: "uint256",
      },
      {
        name: "available",
        type: "uint256",
      },
      {
        name: "APR",
        type: "uint256",
      },
      {
        name: "liquidityLimit",
        type: "uint256",
      },
      {
        name: "nonce",
        type: "uint256",
      },
    ],
  };

  const nonce = await core.nonces(id, lender.address);

  const values = {
    id: id,
    available: available,
    APR: APR,
    liquidityLimit: liquidityLimit,
    nonce: nonce,
  };

  const signature = await lender._signTypedData(coreDomain, types, values);
  const splitSignature = ethers.utils.splitSignature(signature);

  // Use split signatures to create Sodium meta-contribution
  const metaContribution = {
    r: splitSignature.r,
    s: splitSignature.s,
    v: splitSignature.v,
    available: available,
    APR: APR,
    liquidityLimit: liquidityLimit,
    nonce: nonce,
  };

  return metaContribution;
};

// Returns a signature of one or more meta-contributions made by a validator
// Used to verify that meta-contributions brought on-chain have not been withdrawn
const getValidationSig = async (validator, deadline, metaContributions) => {
  const encoding = ethers.utils.defaultAbiCoder.encode(
    [
      "uint256",
      "tuple(bytes32 r, bytes32 s, uint8 v, uint256 available, uint256 APR, uint256 liquidityLimit, uint256 nonce)[]",
    ],
    [deadline, metaContributions]
  );

  const hash = ethers.utils.keccak256(encoding);

  // Sign with validator
  const signature = await validator.signMessage(ethers.utils.arrayify(hash));
  const splitSignature = ethers.utils.splitSignature(signature);

  return { v: splitSignature.v, r: splitSignature.r, s: splitSignature.s };
};

module.exports = {
  makeMetaContribution,
  getValidationSig,
  addToETHLoan,
  addToERC20Loan,
};
