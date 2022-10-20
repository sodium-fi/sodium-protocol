const { ethers } = require("hardhat");

// Calculate the interest and fee owed on an outstanding loan
function calculateInterestAndFee(
  principal,
  APR,
  duration,
  feeNumerator,
  feeDenominator
) {
  // Interest ticks up every hour
  duration = ethers.BigNumber.from("3600").mul(
    ethers.BigNumber.from(duration).div(ethers.BigNumber.from("3600"))
  );

  const baseInterest = principal
    .mul(APR)
    .mul(duration)
    .div(ethers.BigNumber.from(86400).mul(365).mul(10000));

  // Fee is a fraction of the interest earned
  const baseFee = baseInterest.mul(feeNumerator).div(feeDenominator);

  // Return effective interest payment
  const interest = baseInterest.sub(baseFee);

  const fee = baseFee.add(baseFee);

  return { interest, fee };
}

// Calculate the prinicpal reduction and corresponding interest/fee of a loan for a partial repayment
function calculatePartialPayment(
  available,
  APR,
  duration,
  feeNumerator,
  feeDenominator
) {
  // Numerator of maximum reduction
  const reductionNum = available
    .mul(feeDenominator)
    .mul(ethers.BigNumber.from("315360000000"));

  // Denominator of maximum reduction
  const reductionDenom = ethers.BigNumber.from(feeDenominator)
    .mul(ethers.BigNumber.from("315360000000"))
    .add(
      ethers.BigNumber.from(duration)
        .mul(APR)
        .mul(ethers.BigNumber.from(feeNumerator).add(feeDenominator))
    );

  const reduction = reductionNum.div(reductionDenom);

  // Interest ticks up every hour
  duration = ethers.BigNumber.from("3600").mul(
    ethers.BigNumber.from(duration).div(ethers.BigNumber.from("3600"))
  );

  const baseInterest = reduction
    .mul(APR)
    .mul(duration)
    .div(ethers.BigNumber.from("315360000000"));

  const baseFee = baseInterest.mul(feeNumerator).div(feeDenominator);

  const interest = baseInterest.sub(baseFee);

  const fee = baseFee.add(baseFee);

  return { reduction, interest, fee };
}

module.exports = {
  calculateInterestAndFee,
  calculatePartialPayment,
};
