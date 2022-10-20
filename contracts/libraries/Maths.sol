// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// A library for performing calculations used by the Sodium Protocol

// Units:
// - Loan durations are in seconds
// - APRs are in basis points

// Interest
// - Meta-lenders earn interest on the bigger of the following:
//   - the loan's duration
//   - half the borrowers requested loan length
// - Interest increases discretely every hour

// Fees:
// - There are two components to protocol fees:
//   - The borrower pays a fee, equal to a fraction of the interest earned, on top of that interest
//   - This amount is also taken from the interest itself
// - Fraction is feeNumerator / feeDenominator

library Maths {
    // Calculate the interest and fee required for a given APR, principal, and duration
    function calculateInterestAndFee(
        uint256 principal,
        uint256 APR,
        uint256 duration,
        uint256 feeNumerator,
        uint256 feeDenominator
    ) internal pure returns (uint256, uint256) {
        // Interest increases every hour
        duration = (duration / 3600) * 3600;

        uint256 baseInterest = (principal * APR * duration) / 3650000 days;

        uint256 baseFee = (baseInterest * feeNumerator) / feeDenominator;

        return (baseInterest - baseFee, baseFee * 2);
    }

    function principalPlusInterest(
        uint256 principal,
        uint256 APR,
        uint256 duration
    ) internal pure returns (uint256) {
        // Interest increases every hour
        duration = (duration / 3600) * 3600;

        uint256 interest = (principal * APR * duration) / 3650000 days;

        return principal + interest;
    }

    // Calculates the maximum principal reduction for an input amount of available funds
    function partialPaymentParameters(
        uint256 available,
        uint256 APR,
        uint256 duration,
        uint256 feeNumerator,
        uint256 feeDenominator
    )
        internal
        pure
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        // Obtain max principal reduction via  => available funds = max reduction + corresponding interest + corresponding fee
        uint256 reductionNumerator = available * feeDenominator * 3650000 days;

        uint256 reductionDenominator = (feeDenominator * 3650000 days) +
            (duration * APR * (feeNumerator + feeDenominator));

        uint256 reduction = reductionNumerator / reductionDenominator;

        // Interest increases every hour
        duration = (duration / 3600) * 3600;

        uint256 baseInterest = (reduction * APR * duration) / 3650000 days;

        uint256 baseFee = (baseInterest * feeNumerator) / feeDenominator;

        return (reduction, baseInterest - baseFee, baseFee * 2);
    }
}
