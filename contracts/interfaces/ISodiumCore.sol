// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../libraries/Types.sol";

interface ISodiumCore {
    /* ===== EVENTS ===== */

    // Emitted when a user requests a loan by sending collateral to the Core
    event RequestMade(
        uint256 indexed id,
        address indexed requester,
        address tokenAddress,
        uint256 tokenId,
        uint256 amount,
        uint256 APR,
        uint256 length,
        address currency
    );

    // Emitted when a borrower cancels their request before adding any funds and converting it to an active loan
    event RequestWithdrawn(uint256 indexed requestId);

    // Emitted when a meta-lenders funds are added to a loan
    // One emitted each meta-contribution => can be multiple in a single call
    event FundsAdded(
        uint256 indexed loanId,
        address lender,
        uint256 amount,
        uint256 APR
    );

    // Emitted when a borrower repays an amount of loan debt to a lender
    event RepaymentMade(
        uint256 indexed loanId,
        address indexed lender,
        uint256 principal,
        uint256 interest,
        uint256 fee
    );

    // Emitted when a bid is made on an auction for liquidated collateral
    event BidMade(
        uint256 indexed id,
        address indexed bidder,
        uint256 bid,
        uint256 index
    );

    // Emitted when a user instant-purchases auctioned collateral
    event PurchaseMade(uint256 indexed id);

    // Emitted when auction proceeds reimburse a lender
    // Seperate event to `RepaymentMade` as no fees are collected in auction
    event AuctionRepaymentMade(
        uint256 indexed auctionId,
        address indexed lender,
        uint256 amount
    );

    // Emitted when a collateral auction is resolved.
    event AuctionConcluded(uint256 indexed id, address indexed winner);

    // Emitted when protocol parameter setters are called by Core owner
    event FeeUpdated(uint256 feeNumerator, uint256 feeDenominator);
    event AuctionLengthUpdated(uint256 auctionLength);
    event WalletFactoryUpdated(address walletFactory);
    event TreasuryUpdated(address treasury);
    event MetaContributionValidatorUpdated(address validator);

    /* ===== METHODS ===== */

    function initialize(
        string calldata name,
        string calldata version,
        uint256 numerator,
        uint256 denominator,
        uint256 length,
        address factory,
        address payable treasury,
        address validator
    ) external;

    function onERC721Received(
        address requester,
        address,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4);

    function onERC1155Received(
        address requester,
        address,
        uint256 tokenId,
        uint256 value,
        bytes calldata data
    ) external returns (bytes4);

    function withdraw(uint256 requestId) external;

    function borrowETH(
        uint256 loanId,
        Types.MetaContribution[] calldata metaContributions,
        uint256[] calldata amounts,
        Types.NoWithdrawalSignature calldata noWithdrawalSignature
    ) external;

    function borrowERC20(
        uint256 loanId,
        Types.MetaContribution[] calldata metaContributions,
        uint256[] calldata amounts,
        Types.NoWithdrawalSignature calldata noWithdrawalSignature
    ) external;

    function repayETH(uint256 loanId) external payable;

    function repayERC20(uint256 loanId, uint256 amount) external;

    function bidETH(uint256 auctionId, uint256 index) external payable;

    function bidERC20(
        uint256 auctionId,
        uint256 amount,
        uint256 index
    ) external;

    function purchaseETH(uint256 auctionId) external payable;

    function purchaseERC20(uint256 auctionId) external;

    function resolveAuctionETH(uint256 auctionId) external;

    function resolveAuctionERC20(uint256 auctionId) external;

    // function getLoan(uint256 loanId) external view returns (Types.Loan memory);

    // function getWallet(address borrower) external view returns (address);

    // function getAuction(uint256 auctionId)
    //     external
    //     view
    //     returns (Types.Auction memory);

    function setFee(uint256 numerator, uint256 denominator) external;

    function setAuctionLength(uint256 length) external;

    function setWalletFactory(address factory) external;

    function setTreasury(address payable treasury) external;

    function setValidator(address validator) external;
}
