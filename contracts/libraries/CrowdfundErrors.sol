// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

library CrowdfundErrors {
    /**
     * @dev Thrown when the caller is not an admin.
     */
    string constant NOT_ADMIN = "Not admin";

    /**
     * @dev Thrown when the caller is not a project.
     */
    string constant NOT_PROJECT = "Not project";

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
     * @dev Thrown when the sender or contract doesn't have enough balance for an operation.
     */
    string constant NOT_ENOUGH_BALANCE = "Not enough balance";

    /**
     * @dev Thrown when a token or native currency transfer fails.
     */
    string constant TRANSFER_FAILED = "Transfer failed";

    /**
     * @dev Thrown when an address parameter is the zero address.
     */
    string constant INVALID_ADDRESS = "Invalid address";

    /**
     * @dev Thrown when trying to perform an action on an address that is already in the desired state.
     */
    string constant ALREADY_EXISTS = "Already exists";

    /**
     * @dev Thrown when trying to perform an action on an address that doesn't exist.
     */
    string constant DOES_NOT_EXIST = "Does not exist";

    /**
     * @dev Thrown when only the primary admin can perform an action.
     */
    string constant ONLY_PRIMARY_ADMIN = "Only primary admin";

    /**
     * @dev Thrown when the investment period has not started yet.
     */
    string constant INVESTMENT_NOT_STARTED = "Investment not started";

    /**
     * @dev Thrown when the investment period has ended.
     */
    string constant INVESTMENT_ENDED = "Investment period ended";

    /**
     * @dev Thrown when trying to invest more than the remaining funding goal.
     */
    string constant EXCEEDS_FUNDING_GOAL = "Exceeds funding goal";

    /**
     * @dev Thrown when the project is not available for investment.
     */
    string constant PROJECT_NOT_AVAILABLE = "Project not available for investment";

    /**
     * @dev Thrown when trying to claim a refund but not eligible.
     */
    string constant NO_REFUND_AVAILABLE = "No refund available";

    /**
     * @dev Thrown when already claimed refund.
     */
    string constant ALREADY_CLAIMED = "Already claimed";

    /**
     * @dev Thrown when the project is not deferred.
     */
    string constant PROJECT_NOT_DEFERRED = "Project not deferred";

    /**
     * @dev Thrown when funds have already been withdrawn.
     */
    string constant ALREADY_WITHDRAWN = "Already withdrawn";

    /**
     * @dev Thrown when must withdraw funds first.
     */
    string constant MUST_WITHDRAW_FIRST = "Must withdraw funds first";

    /**
     * @dev Thrown when returns are not available yet.
     */
    string constant RETURNS_NOT_AVAILABLE = "Returns not available";

    /**
     * @dev Thrown when no investment found.
     */
    string constant NO_INVESTMENT = "No investment found";

    /**
     * @dev Thrown when already withdrawn returns.
     */
    string constant ALREADY_WITHDRAWN_RETURNS = "Already withdrawn returns";

    /**
     * @dev Thrown when repayment amount is insufficient.
     */
    string constant INSUFFICIENT_REPAYMENT = "Must repay at least raised amount";

    /**
     * @dev Thrown when only USDT payments are accepted.
     */
    string constant USDT_ONLY = "USDT only";

    /**
     * @dev Thrown when amount must be greater than zero.
     */
    string constant AMOUNT_ZERO = "Amount must be greater than 0";

    /**
     * @dev Thrown when cannot remove primary admin.
     */
    string constant CANNOT_REMOVE_PRIMARY = "Cannot remove primary admin";

    /**
     * @dev Thrown when admin contract must be a contract.
     */
    string constant ADMIN_MUST_BE_CONTRACT = "Admin must be contract";

    /**
     * @dev Thrown when payment token cannot be zero address.
     */
    string constant INVALID_PAYMENT_TOKEN = "Payment token cannot be zero address";

    /**
     * @dev Thrown when creator withdrawal deadline has not been reached.
     */
    string constant DEADLINE_NOT_REACHED = "Creator withdrawal deadline not reached";
}