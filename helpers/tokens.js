const { ethers } = require("hardhat");

// Mint WETH to an account and grant their approval to another to spend it
// Requires approver to have sufficient ETH for WETH mint (via deposit call)
async function mintAndApproveWETH(approver, spender, amount) {
  const WETH = getWETH();
  await WETH.connect(approver).deposit({ value: amount });
  await WETH.connect(approver).approve(spender.address, amount);
}

// Mint ERC20 tokens to an account and grant their approval to another to spend them
async function mintAndApproveERC20(ERC20, approver, spender, amount) {
  await ERC20.mint(approver.address, amount);
  await ERC20.connect(approver).approve(spender.address, amount);
}

// Reset an account's WETH balance
async function resetWETHBalance(target) {
  const WETH = getWETH();
  const balance = await WETH.balanceOf(target.address);

  // Transfer balance to zero address
  await WETH.connect(target).transfer(ethers.constants.AddressZero, balance);
}

// Reset an account's WETH balance
async function resetWETHBalances(targets) {
  for (let i = 0; i < targets.length; i++) {
    await resetWETHBalance(targets[i]);
  }
}

// Create and return an ethers WETH contract instance
function getWETH() {
  const WETH_ABI = [
    "function deposit() public payable",
    "function approve(address, uint256)",
    "function transfer(address, uint256)",
    "function balanceOf(address) view returns (uint256)",
    "function allowance(address, address) view returns (uint256)",
  ];

  const WETH_ADDRESS = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";
  const WETH = new ethers.Contract(WETH_ADDRESS, WETH_ABI, ethers.provider);

  return WETH;
}

module.exports = {
  mintAndApproveWETH,
  mintAndApproveERC20,
  resetWETHBalance,
  resetWETHBalances,
  getWETH,
};
