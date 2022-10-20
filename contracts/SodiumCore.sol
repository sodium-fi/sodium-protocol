// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/IERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/ECDSAUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/draft-EIP712Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import "./interfaces/ISodiumWalletFactory.sol";
import "./interfaces/ISodiumWallet.sol";
import "./interfaces/ISodiumCore.sol";
import "./interfaces/IWETH.sol";

import "./libraries/Types.sol";
import "./libraries/Maths.sol";

/// @title Sodium Core Contract
/// @notice Manages loans and collateral auctions on the Sodium Protocol
/// @dev WARNING! This contract is vulnerable to ERC20-transfer reentrancy => this is to save gas
contract SodiumCore is
    ISodiumCore,
    Initializable,
    EIP712Upgradeable,
    ReentrancyGuardUpgradeable,
    OwnableUpgradeable,
    UUPSUpgradeable
{
    /* ===== LIBRARIES ===== */

    using SafeERC20Upgradeable for IERC20Upgradeable;

    /* ==================== STATE ==================== */

    /* ===== ADDRESSES ===== */

    // Used to deploy new Sodium Wallets
    ISodiumWalletFactory public sodiumWalletFactory;

    // The WETH contract used during ETH-loan-related functionality
    // See https://etherscan.io/token/0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2
    IWETH private constant WETH =
        IWETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

    // The address to which fees collected by the protocol are sent
    address payable public sodiumTreasury;

    // Validates meta-contributions as not having been withdrawn by meta-lenders
    address public metaContributionValidator;

    /* ===== PROTOCOL PARAMETERS ===== */

    // The protocol's fee is stored as a fraction
    uint256 public feeNumerator;
    uint256 public feeDenominator;

    // The length of the protocol's collateral auction in seconds
    uint256 public auctionLength;

    /* ===== PROTOCOL STATE ===== */

    // Maps a user to their Sodium Wallet
    mapping(address => address) private wallets;

    // Maps a loan's ID to its state-encapsulating `Loan` struct
    mapping(uint256 => Types.Loan) private loans;

    // Maps an auction's ID to its state-encapsulating `Auction` struct
    mapping(uint256 => Types.Auction) private auctions;

    /* ===== NONCES ===== */

    /// @notice Get a meta-lender's meta-contibution nonce
    mapping(uint256 => mapping(address => uint256)) public nonces;

    // Used to create distinct IDs for same-collateral ERC1155 loans
    uint256 private ERC1155Nonce;

    // EIP-712 type hash for meta-contributions
    bytes32 private constant META_CONTRIBUTION_TYPE_HASH =
        keccak256(
            "MetaContribution(uint256 id,uint256 available,uint256 APR,uint256 liquidityLimit,uint256 nonce)"
        );

    /* ===== MODIFIERS ===== */

    // Reverts unless in-auction
    modifier duringAuctionOnly(uint256 auctionId) {
        require(
            block.timestamp > loans[auctionId].end &&
                block.timestamp < loans[auctionId].auctionEnd,
            "19"
        );
        _;
    }

    /* ===== INITIALIZER ===== */

    /// @notice Proxy initializer function
    /// @param name The contract name used to verify EIP-712 meta-contribution signatures
    /// @param version The contract version used to verify EIP-712 meta-contribution signatures
    function initialize(
        string calldata name,
        string calldata version,
        uint256 numerator,
        uint256 denominator,
        uint256 length,
        address factory,
        address payable treasury,
        address validator
    ) public override initializer {
        __EIP712_init(name, version);
        __Ownable_init();
        feeNumerator = numerator;
        feeDenominator = denominator;
        auctionLength = length;
        sodiumWalletFactory = ISodiumWalletFactory(factory);
        sodiumTreasury = treasury;
        metaContributionValidator = validator;
    }

    /* ===== RECEIVE ===== */

    // Allows core to unwrap WETH
    receive() external payable {}

    /* ==================== LOANS ==================== */

    /* ===== MAKE REQUESTS ===== */

    /// @notice Initiates a loan request when called by an ERC721 contract during a `safeTransferFrom` call
    /// @param data Request parameters ABI-encoded into a `RequestParams` struct
    function onERC721Received(
        address requester,
        address,
        uint256 tokenId,
        bytes calldata data
    ) external override returns (bytes4) {
        // Block timestamp included in ID hash to ensure subsequent same-collateral loans have distinct IDs
        uint256 requestId = uint256(
            keccak256(abi.encode(tokenId, msg.sender, block.timestamp))
        );

        // Decode request information and execute request logic
        address wallet = _executeRequest(
            abi.decode(data, (Types.RequestParams)),
            requestId,
            tokenId,
            requester,
            msg.sender,
            Types.Collateral.ERC721
        );

        // Transfer collateral to wallet
        IERC721Upgradeable(msg.sender).transferFrom(
            address(this),
            wallet,
            tokenId
        );

        return this.onERC721Received.selector;
    }

    /// @notice Initiates a loan request when called by an ERC1155 contract during a `safeTransferFrom` call
    /// @param data Request parameters ABI-encoded into a `RequestParams` struct
    function onERC1155Received(
        address requester,
        address,
        uint256 tokenId,
        uint256 value,
        bytes calldata data
    ) external override returns (bytes4) {
        require(value == 1, "2");

        // Nonce included in hash to allow distinct IDs for same-collateral loans
        uint256 requestId = uint256(
            keccak256(abi.encode(tokenId, msg.sender, ERC1155Nonce))
        );

        // Increment nonce
        ERC1155Nonce++;

        // Decode request information and execute request logic
        address wallet = _executeRequest(
            abi.decode(data, (Types.RequestParams)),
            requestId,
            tokenId,
            requester,
            msg.sender,
            Types.Collateral.ERC1155
        );

        // Transfer collateral to wallet
        IERC1155Upgradeable(msg.sender).safeTransferFrom(
            address(this),
            wallet,
            tokenId,
            1,
            ""
        );

        return this.onERC1155Received.selector;
    }

    /* ===== CANCEL REQUESTS ===== */

    /// @notice Used by borrower to withdraw collateral from loan requests that have not been converted into active loans
    /// @param requestId The ID of the target request
    function withdraw(uint256 requestId) external override {
        // Check no unpaid lenders
        require(loans[requestId].lenders.length == 0, "5");

        // Ensure borrower calling
        address borrower = loans[requestId].borrower;
        require(msg.sender == borrower, "6");

        // Transfer collateral to borrower
        _transferCollateral(
            loans[requestId].tokenAddress,
            loans[requestId].tokenId,
            loans[requestId].wallet,
            borrower,
            loans[requestId].collateralType
        );

        delete loans[requestId];

        emit RequestWithdrawn(requestId);
    }

    /* ===== ADD META-CONTRIBUTIONS ===== */

    /// @notice Used by borrower to add funds to an ETH request/loan
    /// @dev Unwraps meta-lender WETH then sends resulting ETH to borrower
    /// @param id The ID of the target request/loan to which the meta-contributions are to be added
    /// @param metaContributions One or more signed lender meta-contributions
    /// @param amounts The amount of each meta-contribution's available funds that are to be added to the loan
    /// @param noWithdrawalSignature A signature of the meta-contributions that indicates they have not been withdrawn
    function borrowETH(
        uint256 id,
        Types.MetaContribution[] calldata metaContributions,
        uint256[] calldata amounts,
        Types.NoWithdrawalSignature calldata noWithdrawalSignature
    ) external override {
        Types.Loan storage loan = loans[id];

        require(loan.currency == address(0), "3");

        address borrower = _preAdditionLogic(
            loan,
            metaContributions,
            noWithdrawalSignature
        );

        // Keep track of liquidity using stack => initialise as current value
        uint256 liquidity = loan.liquidity;

        // Track total ETH added (sum of amounts)
        uint256 total = 0;

        // Iterate over meta-contributions in order
        for (uint256 i = 0; i < metaContributions.length; i++) {
            address lender = _processMetaContribution(
                id,
                amounts[i],
                liquidity,
                metaContributions[i]
            );

            // Transfer WETH to contract
            WETH.transferFrom(lender, address(this), amounts[i]);

            // Update tracked quantities
            total += amounts[i];
            liquidity += amounts[i];
        }

        // Convert all lender WETH into ETH
        WETH.withdraw(total);

        // Save loan's final liquidity
        loan.liquidity = liquidity;

        // Send ETH after state changes to avoid reentrancy
        payable(borrower).transfer(total);
    }

    /// @notice Used by borrower to add funds to an ERC20 loan
    /// @dev Transfers core-approved meta-lender tokens to the borrower
    /// @param id The ID of the target request/loan to which the meta-contributions are to be added
    /// @param metaContributions One or more signed lender meta-contributions
    /// @param amounts The amount of each meta-contribution's available funds that are to be added to the loan
    /// @param noWithdrawalSignature A signature of the meta-contributions that indicates they have not been withdrawn
    function borrowERC20(
        uint256 id,
        Types.MetaContribution[] calldata metaContributions,
        uint256[] calldata amounts,
        Types.NoWithdrawalSignature calldata noWithdrawalSignature
    ) external override {
        Types.Loan storage loan = loans[id];

        require(loan.currency != address(0), "4");

        address borrower = _preAdditionLogic(
            loan,
            metaContributions,
            noWithdrawalSignature
        );

        // Keep track of liquidity using stack
        uint256 liquidity = loan.liquidity;

        address currency = loan.currency;

        // Iterate over meta-contributions in order
        for (uint256 i = 0; i < metaContributions.length; i++) {
            address lender = _processMetaContribution(
                id,
                amounts[i],
                liquidity,
                metaContributions[i]
            );

            // Transfer funds to borrower
            IERC20Upgradeable(currency).safeTransferFrom(
                lender,
                borrower,
                amounts[i]
            );

            liquidity += amounts[i];
        }

        // Save new loan liquidity into storage
        loan.liquidity = liquidity;
    }

    /* ===== REPAY DEBT ===== */

    /// @notice Used to repay an ETH loan
    /// @dev No auth required as no gain to be made from repaying someone else's loan
    /// @dev Sent ETH (msg.value) is used for the repayment
    /// @param loanId The ID of the target loan
    function repayETH(uint256 loanId) external payable override {
        // Ensure ETH loan being repaid
        require(loans[loanId].currency == address(0), "3");

        // Wrap sent ETH to use for repayment
        WETH.deposit{value: msg.value}();

        // Set `from` to this contract as it owns the WETH
        _executeRepayment(loanId, msg.value, address(WETH), address(this));
    }

    /// @notice Used to repay an ERC20 loan
    /// @dev No auth required as no gain to be made from repaying someone else's loan
    /// @dev The Core must be granted approval over the tokens used for repayment
    /// @param loanId The ID of the target loan
    /// @param amount The amount of tokens to repay
    function repayERC20(uint256 loanId, uint256 amount) external override {
        _executeRepayment(loanId, amount, loans[loanId].currency, msg.sender);
    }

    /* ==================== AUCTION ==================== */

    /* ===== BID ===== */

    /// @notice Make an ETH bid in a collateral auction
    /// @dev WARNING: Do not bid higher than purchase amount => purchase instead
    /// @dev Set index parameter to the length of the lending queue if no boost available
    /// @param auctionId The ID of the target auction
    /// @param index The index of the caller in the lending queue => requests a boost
    function bidETH(uint256 auctionId, uint256 index)
        external
        payable
        override
        duringAuctionOnly(auctionId)
    {
        require(loans[auctionId].currency == address(0), "3");

        address previousBidder = auctions[auctionId].bidder;
        uint256 previousRawBid = auctions[auctionId].rawBid;

        _executeBid(auctionId, msg.value, index);

        // Repay previous bidder if needed
        if (previousBidder != address(0)) {
            _nonBlockingTransfer(previousBidder, previousRawBid);
        }
    }

    /// @notice Make an bid of some ERC20 tokens for some auctioned collateral
    /// @dev WARNING! Do not bid higher than purchase amount => purchase instead
    /// @dev Set index parameter to the length of the lending queue if no boost available
    /// @param auctionId The ID of the target auction
    /// @param index The index of the caller in the lending queue => requests a boost
    /// @param amount The amount of tokens to bid
    /// @param index The index of the caller in the lending queue => requests a boost
    function bidERC20(
        uint256 auctionId,
        uint256 amount,
        uint256 index
    ) external override duringAuctionOnly(auctionId) {
        address currency = loans[auctionId].currency;
        address bidder = auctions[auctionId].bidder;

        // Repay previous bidder if needed
        if (bidder != address(0)) {
            IERC20Upgradeable(currency).safeTransfer(
                bidder,
                auctions[auctionId].rawBid
            );
        }

        // Transfer bid to the Core
        // Call will fail if to zero address (cant't be used on ETH loans)
        IERC20Upgradeable(currency).safeTransferFrom(
            msg.sender,
            address(this),
            amount
        );

        _executeBid(auctionId, amount, index);
    }

    /* ===== PURCHASE ===== */

    /// @notice Purchase in-auction collateral instantly with ETH
    /// @dev Requires settling all unpaid lender debts plus any repayments the borrower has made
    /// @dev If the caller is an unpaid lender, a borrower who has repaid, or the most recent bidder, a purchase discount will be applied accordingly
    /// @param auctionId The ID of the collateral's auction
    function purchaseETH(uint256 auctionId)
        external
        payable
        override
        duringAuctionOnly(auctionId)
        nonReentrant
    {
        Types.Loan storage loan = loans[auctionId];
        Types.Auction memory auction = auctions[auctionId];

        require(loan.currency == address(0), "3");

        // Track funds remaing to carry out payments required for purchase
        uint256 remainingFunds = msg.value;

        if (msg.sender == auction.bidder) {
            // Add raw bid to purchase funds if bidder is the caller
            remainingFunds += auction.rawBid;
        } else {
            // Otherwise pay back bidder
            _nonBlockingTransfer(auction.bidder, auction.rawBid);
        }

        address borrower = loan.borrower;
        uint256 repayment = loan.repayment;

        if (borrower != msg.sender && repayment != 0) {
            // Pay back borrower's repayment
            _nonBlockingTransfer(borrower, repayment);

            // Update remaining funds
            remainingFunds -= repayment;
        }

        // Wrap remaining funds to pay meta-lenders back in WETH
        WETH.deposit{value: remainingFunds}();

        uint256 numberOfLenders = loan.lenders.length;

        for (uint256 i = 0; i < numberOfLenders; i++) {
            address lender = loan.lenders[i];

            // Repay lender if they are not the caller
            if (lender != msg.sender) {
                // Calculate total owed to lender
                uint256 owed = Maths.principalPlusInterest(
                    loan.principals[i],
                    loan.APRs[i],
                    loan.end - loan.timestamps[i]
                );

                // This will revert if insufficient funds sent to repay lenders
                remainingFunds -= owed;

                // Pay lender fully
                WETH.transfer(lender, owed);

                emit AuctionRepaymentMade(auctionId, lender, owed);
            }
        }

        _auctionCleanup(auctionId, msg.sender);

        emit PurchaseMade(auctionId);
    }

    /// @notice Purchase in-auction collateral instantly with ERC20
    /// @dev Requires settling all unpaid lender debts plus any repayments the borrower has made
    /// @dev If the caller is an unpaid lender, a borrower who has repaid, or the most recent bidder, a purchase discount will be applied accordingly
    /// @dev Tokens used for purchase must be approved to the core before calling
    /// @param auctionId The ID of the collateral's auction
    function purchaseERC20(uint256 auctionId)
        external
        override
        duringAuctionOnly(auctionId)
    {
        Types.Auction memory auction = auctions[auctionId];
        Types.Loan storage loan = loans[auctionId];

        address currency = loan.currency;
        require(currency != address(0), "4");

        if (auction.bidder != address(0)) {
            // Pay back bidder
            // Funds are returned before paying other debt if bidder is the caller
            IERC20Upgradeable(currency).safeTransfer(
                auction.bidder,
                auction.rawBid
            );
        }

        address borrower = loan.borrower;
        uint256 repayment = loan.repayment;

        if (borrower != msg.sender && repayment != 0) {
            // Pay back borrower if not the caller => will fail if to zero address
            IERC20Upgradeable(currency).safeTransferFrom(
                msg.sender,
                borrower,
                repayment
            );
        }

        uint256 numberOfLenders = loan.lenders.length;

        for (uint256 i = 0; i < numberOfLenders; i++) {
            address lender = loan.lenders[i];

            // Repay lender if they are not the caller
            if (lender != msg.sender) {
                // Calculate total owed to lender
                uint256 owed = Maths.principalPlusInterest(
                    loan.principals[i],
                    loan.APRs[i],
                    loan.end - loan.timestamps[i]
                );

                // Pay lender fully
                IERC20Upgradeable(currency).safeTransferFrom(
                    msg.sender,
                    lender,
                    owed
                );

                emit AuctionRepaymentMade(auctionId, lender, owed);
            }
        }

        _auctionCleanup(auctionId, msg.sender);

        emit PurchaseMade(auctionId);
    }

    /* ===== RESOLVE AUCTION ===== */

    /// @notice Resolve an ETH-auction after it has finished
    /// @dev Pays back debts using WETH and sends collateral to the auction winner
    /// @param auctionId The ID of the finished auction
    function resolveAuctionETH(uint256 auctionId) external override {
        require(loans[auctionId].currency == address(0), "3");

        WETH.deposit{value: auctions[auctionId].rawBid}();

        _resolveAuction(auctionId, address(WETH));
    }

    /// @notice Resolve an ERC20-auction after it has finished
    /// @dev Pays back debts using WETH and sends collateral to the auction winner
    /// @param auctionId The ID of the finished auction
    function resolveAuctionERC20(uint256 auctionId) external override {
        address currency = loans[auctionId].currency;

        require(currency != address(0), "4");

        _resolveAuction(auctionId, currency);
    }

    // /* ==================== GETTERS ==================== */

    // These are used for testing, but are not required for deployment

    // function getLoan(uint256 loanId) public view returns (Types.Loan memory) {
    //     return loans[loanId];
    // }

    // function getWallet(address borrower) public view returns (address) {
    //     return wallets[borrower];
    // }

    // function getAuction(uint256 auctionId)
    //     public
    //     view
    //     returns (Types.Auction memory)
    // {
    //     return auctions[auctionId];
    // }

    /* ==================== ADMIN ==================== */

    function setFee(uint256 numerator, uint256 denominator)
        external
        override
        onlyOwner
    {
        feeNumerator = numerator;
        feeDenominator = denominator;
        emit FeeUpdated(numerator, denominator);
    }

    function setAuctionLength(uint256 length) external override onlyOwner {
        auctionLength = length;
        emit AuctionLengthUpdated(length);
    }

    function setWalletFactory(address factory) external override onlyOwner {
        sodiumWalletFactory = ISodiumWalletFactory(factory);
        emit WalletFactoryUpdated(factory);
    }

    function setTreasury(address payable treasury) external override onlyOwner {
        sodiumTreasury = treasury;
        emit TreasuryUpdated(treasury);
    }

    function setValidator(address validator) external override onlyOwner {
        metaContributionValidator = validator;
        emit MetaContributionValidatorUpdated(validator);
    }

    /* ==================== INTERNAL ==================== */

    // Performs shared request logic:
    // - creates a new Sodium Wallet for the requester if they do not have one already
    // - saves request information in a `Loan` struct
    function _executeRequest(
        Types.RequestParams memory requestParams,
        uint256 requestId,
        uint256 tokenId,
        address requester,
        address tokenAddress,
        Types.Collateral collateralType
    ) internal returns (address) {
        address wallet = wallets[requester];

        // If user's wallet is zero address => their first loan => create a new wallet
        if (wallet == address(0)) {
            // Deploy
            wallet = sodiumWalletFactory.createWallet(requester);

            // Register
            wallets[requester] = wallet;
        }

        // Save request details
        loans[requestId] = Types.Loan(
            requestParams.length,
            0,
            0,
            tokenId,
            0,
            new address[](0),
            new uint256[](0),
            new uint256[](0),
            new uint256[](0),
            tokenAddress,
            requestParams.currency,
            requester,
            wallet,
            0,
            collateralType
        );

        // Log request details
        emit RequestMade(
            requestId,
            requester,
            tokenAddress,
            tokenId,
            requestParams.amount,
            requestParams.APR,
            requestParams.length,
            requestParams.currency
        );

        return wallet;
    }

    // Performs shared pre-fund addition logic:
    // - checks caller is borrower
    // - sets loan end if first time funds are added
    // - ensures auction has not started
    // - checks meta-contributions have not been recinded using `noWithdrawalSignature`
    function _preAdditionLogic(
        Types.Loan storage loan,
        Types.MetaContribution[] calldata metaContributions,
        Types.NoWithdrawalSignature calldata noWithdrawalSignature
    ) internal returns (address) {
        address borrower = loan.borrower;

        require(msg.sender == borrower, "6");

        if (loan.lenders.length == 0) {
            // Set end of loan if it is the first addition
            uint256 end = loan.length + block.timestamp;

            loan.end = end;

            // Fix loan's auction length at time of loan start
            loan.auctionEnd = end + auctionLength;
        } else {
            // Check that loan is not over (in auction)
            require(block.timestamp < loan.end, "14");
        }

        // Nonce in metaContributions ensures no replayability of signature
        bytes32 hash = keccak256(
            abi.encode(noWithdrawalSignature.deadline, metaContributions)
        );

        // Load signed message
        bytes32 signed = ECDSAUpgradeable.toEthSignedMessageHash(hash);

        // Determine signer
        address signer = ECDSAUpgradeable.recover(
            signed,
            noWithdrawalSignature.v,
            noWithdrawalSignature.r,
            noWithdrawalSignature.s
        );

        // Get assurance from validator that meta-contributions are non-withdrawn
        require(signer == metaContributionValidator, "7");

        require(block.timestamp <= noWithdrawalSignature.deadline, "8");

        return borrower;
    }

    // Verifies and executes a meta-contribution:
    // - checks meta-lender has offered sufficient funds
    // - checks meta-lender's liquidity limit is not surpassed
    // - derives lender from signature
    function _processMetaContribution(
        uint256 id,
        uint256 amount,
        uint256 currentLiquidity,
        Types.MetaContribution calldata contribution
    ) internal returns (address) {
        require(amount <= contribution.available, "9");

        require(amount + currentLiquidity <= contribution.liquidityLimit, "10");

        // Calculate lender's signed EIP712 message
        bytes32 hashStruct = keccak256(
            abi.encode(
                META_CONTRIBUTION_TYPE_HASH,
                id,
                contribution.available,
                contribution.APR,
                contribution.liquidityLimit,
                contribution.nonce
            )
        );
        bytes32 digest = _hashTypedDataV4(hashStruct);

        // Assume signer is lender
        address lender = ECDSAUpgradeable.recover(
            digest,
            contribution.v,
            contribution.r,
            contribution.s
        );

        // Avoid meta-contribution replay via lender nonce
        require(contribution.nonce == nonces[id][lender], "11");
        nonces[id][lender]++;

        // Update loan state
        loans[id].principals.push(amount);
        loans[id].lenders.push(lender);
        loans[id].APRs.push(contribution.APR);
        loans[id].timestamps.push(block.timestamp);

        emit FundsAdded(id, lender, amount, contribution.APR);

        return lender;
    }

    // Performs shared repayment logic:
    // - checks loan is ongoing
    // - pays back lenders from the top of the lending queue (loan.lenders)
    // - returns collateral if full repayment
    function _executeRepayment(
        uint256 loanId,
        uint256 amount,
        address currency,
        address from
    ) internal {
        Types.Loan storage loan = loans[loanId];

        // For front end convenience
        require(loan.borrower != address(0), "13");

        // Can only repay an active loan
        require(block.timestamp < loan.end, "14");

        // Track funds remaining for repayment
        uint256 remainingFunds = amount;

        // Borrowers must pay interest on at least half the requested loan length
        uint256 minimumDuration = loan.length / 2;

        // Iterate through lenders from top of lending queue and pay them back
        for (uint256 i = loan.lenders.length; 0 < i; i--) {
            uint256 principal = loan.principals[i - 1];

            // // Borrowers must pay interest on at least half the requested loan length
            // uint256 minimumDuration = loan.length / 2;

            uint256 timePassed = block.timestamp - loan.timestamps[i - 1];

            uint256 effectiveLoanDuration = timePassed > minimumDuration
                ? timePassed
                : minimumDuration;

            // Calculate outstanding interest and fee
            (uint256 interest, uint256 fee) = Maths.calculateInterestAndFee(
                principal,
                loan.APRs[i - 1],
                effectiveLoanDuration,
                feeNumerator,
                feeDenominator
            );

            address lender = loan.lenders[i - 1];

            // Partial vs complete lender repayment
            if (remainingFunds < principal + interest + fee) {
                // Get partial payment parameters
                (principal, interest, fee) = Maths.partialPaymentParameters(
                    remainingFunds,
                    loan.APRs[i - 1],
                    effectiveLoanDuration,
                    feeNumerator,
                    feeDenominator
                );

                // Update the outstanding principal of the debt owed to the lender
                loan.principals[i - 1] -= principal;

                // Ensure loop termination
                i = 1;
            } else if (remainingFunds == principal + interest + fee) {
                // Complete repayment of lender using all remaining funds
                loan.lenders.pop();

                // Ensure loop termination
                i = 1;
            } else {
                // Complete repayment with funds left over
                loan.lenders.pop();
            }

            // Repay lender
            IERC20Upgradeable(currency).safeTransferFrom(
                from,
                lender,
                principal + interest
            );

            // Send fee
            IERC20Upgradeable(currency).safeTransferFrom(
                from,
                sodiumTreasury,
                fee
            );

            // Decreasing funds available for further repayment
            remainingFunds -= principal + interest + fee;

            emit RepaymentMade(loanId, lender, principal, interest, fee);
        }

        if (loan.lenders.length == 0) {
            // If no lender debts => return collateral
            _transferCollateral(
                loan.tokenAddress,
                loan.tokenId,
                loan.wallet,
                loan.borrower,
                loan.collateralType
            );

            delete loans[loanId];
        } else {
            // Increase overall borrower repayment by repaid amount
            loan.repayment += amount;
        }
    }

    // Performs shared bid logic:
    // - attempts to apply boost if lender index passed
    // - checks effective bid is greater than previous
    function _executeBid(
        uint256 auctionId,
        uint256 amount,
        uint256 index
    ) internal {
        Types.Loan storage loan = loans[auctionId];
        Types.Auction storage auction = auctions[auctionId];

        // Save raw bid pre-boost
        auction.rawBid = amount;

        // Boost bid if lender index entered
        if (index != loan.lenders.length) {
            // Check caller is lender at index
            require(msg.sender == loan.lenders[index], "15");

            // Calculate starting boundary of lender liquidity
            uint256 lenderLiquidityStart = 0;
            for (uint256 i = 0; i < index; i++) {
                lenderLiquidityStart += Maths.principalPlusInterest(
                    loan.principals[i],
                    loan.APRs[i],
                    loan.end - loan.timestamps[i]
                );
            }

            // Boost bid with loaned lender liqudity
            if (amount >= lenderLiquidityStart) {
                amount += Maths.principalPlusInterest(
                    loan.principals[index],
                    loan.APRs[index],
                    loan.end - loan.timestamps[index]
                );
            }
        }

        // Check post-boost bid is greater than previous
        require(auction.effectiveBid < amount, "16");

        auction.effectiveBid = amount;
        auction.bidder = msg.sender;

        emit BidMade(auctionId, msg.sender, amount, index);
    }

    // Performs shared auction-resolution functionality:
    // - ensures loan's auction is over
    // - pays lenders from the bottom of the lending queue (loan.lenders)
    // - repays any borrower repayment with any funds remaining after lender repayment
    // - transfers collateral to winner (via _auctionCleanup)
    function _resolveAuction(uint256 auctionId, address currency) internal {
        Types.Loan storage loan = loans[auctionId];

        uint256 numberOfLenders = loan.lenders.length;

        // Check loan has lender debts => ensures loan.end is non-zero
        require(numberOfLenders != 0, "17");

        // Check auction has finished
        require(loan.auctionEnd < block.timestamp, "18");

        Types.Auction memory auction = auctions[auctionId];

        // Pay off all possible lenders with bid => start at bottom of lending queue
        for (uint256 i = 0; i < numberOfLenders; i++) {
            address lender = loan.lenders[i];

            // Repay lender if they are not the caller
            if (lender != msg.sender) {
                // Calculate total owed to lender
                uint256 owed = Maths.principalPlusInterest(
                    loan.principals[i],
                    loan.APRs[i],
                    loan.end - loan.timestamps[i]
                );

                if (auction.rawBid <= owed) {
                    // Pay lender with remaining
                    IERC20Upgradeable(currency).safeTransfer(
                        lender,
                        auction.rawBid
                    );

                    auction.rawBid = 0;

                    emit AuctionRepaymentMade(
                        auctionId,
                        lender,
                        auction.rawBid
                    );

                    // Stop payment iteration as no more available funds
                    break;
                } else {
                    // Pay lender fully
                    IERC20Upgradeable(currency).safeTransfer(lender, owed);

                    // Update remaining funds
                    auction.rawBid -= owed;

                    emit AuctionRepaymentMade(auctionId, lender, owed);
                }
            }
        }

        // Send remaining funds to borrower to compensate for any loan repayment they have made
        if (auction.rawBid != 0) {
            IERC20Upgradeable(currency).safeTransfer(
                loan.borrower,
                auction.rawBid
            );
        }

        // Set winner to first lender if no bids made
        address winner = auction.bidder == address(0)
            ? loan.lenders[0]
            : auction.bidder;

        _auctionCleanup(auctionId, winner);

        emit AuctionConcluded(auctionId, winner);
    }

    // Performs end-of-purchase logic that is shared between ETH & ERC20 purchases
    function _auctionCleanup(uint256 auctionId, address winner) internal {
        // Send collateral to purchaser
        _transferCollateral(
            loans[auctionId].tokenAddress,
            loans[auctionId].tokenId,
            loans[auctionId].wallet,
            winner,
            loans[auctionId].collateralType
        );

        delete auctions[auctionId];

        delete loans[auctionId];
    }

    // Transfers collateral from a sodium wallet to a recipient
    function _transferCollateral(
        address tokenAddress,
        uint256 tokenId,
        address from,
        address to,
        Types.Collateral collateralType
    ) internal {
        if (collateralType == Types.Collateral.ERC721) {
            ISodiumWallet(from).transferERC721(to, tokenAddress, tokenId);
        } else {
            ISodiumWallet(from).transferERC1155(to, tokenAddress, tokenId);
        }
    }

    // Avoids DOS resulting from from Core ETH transfers made to contracts that don't accept ETH
    function _nonBlockingTransfer(address recipient, uint256 amount) internal {
        // Attempt to send ETH to recipient
        (bool success, ) = recipient.call{value: amount}("");

        // If repayment fails => avoid blocking and send funds to treasury
        if (!success) {
            sodiumTreasury.transfer(amount);
        }
    }

    // Contract owner is authorized to perform upgrades (Open Zep UUPS)
    function _authorizeUpgrade(address) internal view override onlyOwner {}
}
