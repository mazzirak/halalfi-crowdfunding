// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

/**
 * @title CrowdfundStructs
 * @author Mazyar Zirak
 * @dev This library defines shared enums and structs used by multiple contracts in the system.
 *      Date: 5/25/2025
 */

library CrowdfundStructs {
    /**
     * @dev Represents the lifecycle status of a crowdfunding project.
     * Used to control access and behavior based on the current state of the project.
     */
    enum ProjectStatus {
        Pending,        // Project selected => pending
        Rejected,       // Project reject => rejected
        Waiting,        // Project accept => waiting for start
        Active,         // Project accept and start date stated => started
        Completed,      // Project accept and end date ended + reached investment => completed
        Deferred        // Project accept and end date ended + not reached investment => deferred
    }

    /**
     * @dev Represents a document associated with a project (e.g., business plan, ID verification).
     * Stored using IPFS hash for decentralized file reference.
     */
    struct Document {
        string title;       // Title or label of the document
        string extension;   // File extension (e.g., "pdf", "jpg")
        string ipfsHash;    // IPFS content identifier
    }

    /**
     * @dev Contains metadata and configuration for a crowdfunding project.
     */
    struct ProjectInfo {
        address creator;             // Address of the project creator
        string title;                // Title of the project
        string description;          // Brief description of the project
        Document[] documents;        // List of supporting documents
        uint256 startDate;           // Timestamp when contributions can begin
        uint256 endDate;             // Timestamp when contributions end
        uint256 returnNotifyDate;    // Timestamp when returns will be distributed
        uint256 raiseAmount;         // Target amount to raise (in wei or token units)
        uint256 minInvestment;       // Minimum investment allowed from a single investor
        uint256 maxInvestment;       // Maximum investment allowed from a single investor
    }

    /**
     * @dev Tracks the return of funds from the creator to investors.
     */
    struct ProjectReturn {
        uint256 returnedAmount;      // Total amount returned by the creator
        uint256 profitPercentage;    // Profit percentage offered to investors
        uint256 returnDate;          // Timestamp when the funds were returned
        bool isReturned;             // Flag indicating whether funds have been returned
    }

    /**
     * @dev Records an individual investment made in a project.
     */
    struct Investment {
        address investor;            // Address of the investor
        uint256 amount;              // Amount invested
        uint256 timestamp;           // Time when the investment was made
    }
    /**
 * @dev Full project detail including dynamic state values like total raised, status, returns, etc.
 */
    struct ProjectDetail {
        address projectAddress;
        address creator;
        string title;
        string description;
        Document[] documents;
        uint256 startDate;
        uint256 endDate;
        uint256 returnNotifyDate;
        uint256 raiseAmount;
        uint256 minInvestment;
        uint256 maxInvestment;
        uint256 totalRaised;
        ProjectStatus status;
        address paymentToken;
        ProjectReturn returnInfo;
        string rejectionReason;
    }
}
