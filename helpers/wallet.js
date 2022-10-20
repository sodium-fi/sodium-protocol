const { ethers } = require("hardhat");

// Returns a contract instance of the latest wallet deployed by an input wallet factory
const getLatestWallet = async (walletFactory) => {
  // Get wallet address from event logs
  const walletCreatedFilter = walletFactory.filters.WalletCreated;

  const walletCreatedEvents = await walletFactory.queryFilter(
    walletCreatedFilter
  );

  const walletAddress = walletCreatedEvents[0].args.wallet;

  // Create ethers contract instance
  const Wallet = await ethers.getContractFactory("SodiumWallet");
  const wallet = Wallet.attach(walletAddress);

  return wallet;
};

// Assign a address + selector pair as permitted on the Registry
const grantPermission = async (registry, address, signature, owner) => {
  const registryInterface = new ethers.utils.Interface([
    "function " + signature,
  ]);

  // const selector = registryInterface.getSighash("mintIfERC721Owner");
  const selector = registryInterface.getSighash(signature);

  await registry
    .connect(owner)
    .setCallPermissions([address], [selector], [true]);
};

module.exports = {
  getLatestWallet,
  grantPermission,
};
