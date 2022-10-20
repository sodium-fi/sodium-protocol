const { ethers, upgrades } = require("hardhat");

// Deploy and configure protocol contracts afresh
async function deployProtocol(
  validator,
  treasury,
  feeNumerator = 5,
  feeDenominator = 100,
  auctionLength = 86400
) {
  // Factories
  const Core = await ethers.getContractFactory("SodiumCore");
  const Wallet = await ethers.getContractFactory("SodiumWallet");
  const WalletFactory = await ethers.getContractFactory("SodiumWalletFactory");
  const Registry = await ethers.getContractFactory("SodiumRegistry");

  // Deploy wallet implementation
  const walletImplementation = await Wallet.deploy();

  const registry = await Registry.deploy();

  const walletFactory = await WalletFactory.deploy(
    walletImplementation.address,
    registry.address
  );

  // Deploys a implementation contract
  // - deploys a proxy
  // - initializes it
  const core = await upgrades.deployProxy(Core, [
    "Sodium Core",
    "1.0",
    feeNumerator,
    feeDenominator,
    auctionLength,
    walletFactory.address,
    treasury.address,
    validator.address,
  ]);

  return { core, walletFactory, registry };
}

async function deployMockTokens() {
  // Factories
  const ERC721Factory = await ethers.getContractFactory("MockERC721");
  const ERC1155Factory = await ethers.getContractFactory("MockERC1155");
  const ERC20Factory = await ethers.getContractFactory("MockERC20");

  // Deploy tokens
  const ERC721 = await ERC721Factory.deploy("Mock ERC721", "MCK721");
  const ERC1155 = await ERC1155Factory.deploy();
  const ERC20 = await ERC20Factory.deploy("Mock ERC20", "MCK20");

  return { ERC721, ERC1155, ERC20 };
}

module.exports = {
  deployProtocol,
  deployMockTokens,
};
