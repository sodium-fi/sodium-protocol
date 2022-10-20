// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// A library containing structs and enums used on the Sodium Protocol

library Types {
    // Indicates type of collateral
    enum Collateral {
        ERC721,
        ERC1155
    }

    // Represents an ongoing loan
    struct Loan {
        // Requested loan length
        uint256 length;
        // End of loan
        uint256 end;
        // End of potential loan auction
        uint256 auctionEnd;
        // ID of collateral
        uint256 tokenId;
        // Total funds added to the loan
        uint256 liquidity;
        // Loan lenders in lending queue order
        address[] lenders;
        // In-order principals of lenders in `lenders`
        uint256[] principals;
        // In-order APRs of said prinicpals
        uint256[] APRs;
        // Timestamps at which  contributions of lenders in `lenders` were added
        uint256[] timestamps;
        // Address of collateral's contract
        address tokenAddress;
        // The currency the loan is made in
        address currency;
        // The loan's borrower
        address borrower;
        // Address holding loan collateral
        address wallet;
        // Debt repaid by borrower
        uint256 repayment;
        // Indicates type of collateral
        Collateral collateralType;
    }

    // Encapsulates information required for a lender's meta-transaction
    struct MetaContribution {
        // Signature - used to infer meta-lender's address
        bytes32 r;
        bytes32 s;
        uint8 v;
        // Total funds the meta-lender has offered
        uint256 available;
        // The APR the meta-lender has offered said funds at
        uint256 APR;
        // The limit up to which the funds can be used to increase loan liquidity
        uint256 liquidityLimit;
        // Lender's loan-specific meta-contribution nonce
        uint256 nonce;
    }

    // Encapsulates a collateral auction's state
    struct Auction {
        // Address of current highest bidder
        address bidder;
        // Their non-boosted bid => equal to the actual funds they sent
        uint256 rawBid;
        // Their boosted bid
        uint256 effectiveBid;
    }

    // Parameters for a loan request via Sodium Core
    struct RequestParams {
        // The requested amount
        uint256 amount;
        // Their starting APR
        uint256 APR;
        // Requested length of the loan
        uint256 length;
        // Loan currency - zero address used for an ETH loan
        address currency;
    }

    // Contains information needed to validate that a set of meta-contributions have not been withdrawn
    struct NoWithdrawalSignature {
        // The deadline up to which the signature is valid
        uint256 deadline;
        // Signature
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    // Used to identify a token (ERC721) or type of token
    struct Token {
        // Address of the token's contract
        address tokenAddress;
        // ID of the token
        uint256 tokenId;
    }
}
