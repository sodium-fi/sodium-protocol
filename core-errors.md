# Error codes

This file maps raw numerical error strings emitted by SodiumCore to human-readable error reasons.
This was done to reduce contract size.

#### Access
- `1` - Only owner
- `6` - Borrower only
- `15` - Caller must be specified lender

#### Loan types
- `3` - ETH loan only
- `4` - ERC20 loan only

#### Conditions
- `2` - Single token collateral only
- `5` - Borrower has unpaid debt
- `9` - Amount to add is greater than available
- `10` - Contribution would take lender above their liquidity limit
- `16` - Bid must be greater than the previous

#### Sigs
- `7` - Non-valid no-withdrawl signature
- `8` - No-withdrawal validation expired
- `11` - Non-valid nonce
- `12` - Non-valid meta-lender signature

#### Loan stages
- `13` - Loan has been repaid
- `14` - Loan has passed repayment deadline
- `17` - Collateral has not been auctioneed
- `18` - Auction has not finished
- `19` - During auction only
- `20` - Cannot add funds to loan after auction has started
