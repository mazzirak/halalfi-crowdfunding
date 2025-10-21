// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

library CrowdfundErrors {
    /**
     * @dev Thrown when the caller is not an admin.
     */
    string constant NOT_ADMIN = "Not admin";

    /**
      * @dev Thrown when the caller is not an project.
     */
    string constant NOT_PROJECT = "Not Project";

    /**
     * @dev Thrown when the caller is not the creator of the project.
     */
    string constant NOT_CREATOR = "Not creator";

    /**
     * @dev Thrown when the caller is not a valid investor in the project.
     */
    string constant NOT_INVESTOR = "Not investor";

    /**
     * @dev Thrown when attempting to interact with a project that hasn't been approved yet.
     */
    string constant PROJECT_NOT_APPROVED = "Project not approved";

    /**
     * @dev Thrown when attempting to interact with a project that is not active.
     */
    string constant PROJECT_NOT_ACTIVE = "Project not active";

    /**
     * @dev Thrown when attempting to access functionality that requires the project to be completed.
     */
    string constant PROJECT_NOT_COMPLETED = "Project not completed";

    /**
     * @dev Thrown when an investment is below the minimum allowed amount.
     */
    string constant INVESTMENT_BELOW_MIN = "Investment below minimum";

    /**
     * @dev Thrown when an investment exceeds the maximum allowed amount.
     */
    string constant INVESTMENT_ABOVE_MAX = "Investment above maximum";

    /**
     * @dev Thrown when the requested funding amount has already been reached.
     */
    string constant FUNDING_COMPLETED = "Funding already completed";

    /**
     * @dev Thrown when expecting a completed funding round but it's not yet completed.
     */
    string constant FUNDING_NOT_COMPLETED = "Funding not completed";

    /**
     * @dev Thrown when trying to return funds again after they have already been returned.
     */
    string constant ALREADY_RETURNED = "Funds already returned";

    /**
     * @dev Thrown when a provided date range is invalid (e.g., start > end).
     */
    string constant INVALID_DATE = "Invalid date range";

    /**
     * @dev Thrown when a provided amount or value is invalid or inconsistent.
     */
    string constant INVALID_AMOUNT = "Invalid amount";

    /**
     * @dev Thrown when the current status of the project does not allow the operation.
     */
    string constant INVALID_STATUS = "Invalid project status";

    /**
     * @dev Thrown when the sender or contract doesn’t have enough balance for an operation.
     */
    string constant NOT_ENOUGH_BALANCE = "Not enough balance";

    /**
     * @dev Thrown when a token or native currency transfer fails.
     */
    string constant TRANSFER_FAILED = "Transfer failed";
}
