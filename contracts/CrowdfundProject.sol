// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./interfaces/ICrowdfundProject.sol";
import "./interfaces/ICrowdfundInvestor.sol";
import "./interfaces/ICrowdfundAdmin.sol";
import "./libraries/CrowdfundErrors.sol";
import "./libraries/CrowdfundStructs.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

/**
 * @title CrowdfundProject
 * @author Mazyar Zirak <mazyarzirak1@gmail.com>
 */
contract CrowdfundProject is ICrowdfundProject, ICrowdfundInvestor, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    struct ProjectStorage {
        CrowdfundStructs.ProjectStatus status;
        uint128 totalRaised;
        uint128 raiseAmount;
        string rejectionReason;
    }

    CrowdfundStructs.ProjectInfo private projectInfo;
    CrowdfundStructs.ProjectReturn private returnInfo;
    ProjectStorage private projectStorage;
    address public immutable admin;
    address public immutable factory;
    address public immutable creator;
    address public immutable paymentToken;

    mapping(address => uint256) public investments;
    mapping(address => bool) public hasClaimedRefund;
    mapping(address => bool) public hasWithdrawnReturns;
    address[] public investors;

    event FundsInvested(address indexed investor, uint256 amount);
    event FundsWithdrawn(address indexed creator, uint256 amount);
    event PlatformFeeTransferred(address indexed admin, uint256 amount);
    event FundsReturned(uint256 amount, uint256 profitPercentage);
    event ReturnsWithdrawn(address indexed investor, uint256 amount);
    event ProjectApproved(address indexed approver);
    event ProjectRejected(address indexed rejector, string reason);
    event ProjectMarkedAsDefaulted(address indexed admin, string reason);

    bool public hasCreatorWithdrawnFunds;
    uint256 public constant PLATFORM_FEE_PERCENT = 1; // 1% platform fee
    uint256 public constant CREATOR_WITHDRAWAL_DEADLINE = 7 days; // 7 days to withdraw after funding complete

    constructor(
        address _admin,
        CrowdfundStructs.ProjectInfo memory init,
        address _paymentToken
    ) {
        require(init.endDate > init.startDate, CrowdfundErrors.INVALID_DATE);
        require(init.returnNotifyDate > init.endDate, CrowdfundErrors.INVALID_DATE);
        require(init.minInvestment <= init.maxInvestment, CrowdfundErrors.INVALID_AMOUNT);
        require(init.maxInvestment <= init.raiseAmount, CrowdfundErrors.INVALID_AMOUNT);
        require(_paymentToken != address(0), CrowdfundErrors.INVALID_PAYMENT_TOKEN);

        admin = _admin;
        factory = msg.sender;
        creator = init.creator;
        paymentToken = _paymentToken;

        _initProjectInfo(init);

        require(init.raiseAmount <= type(uint128).max, CrowdfundErrors.INVALID_AMOUNT);
        projectStorage = ProjectStorage({
            status: CrowdfundStructs.ProjectStatus.Pending,
            totalRaised: 0,
            raiseAmount: uint128(init.raiseAmount),
            rejectionReason: ""
        });
        hasCreatorWithdrawnFunds = false;
    }
/**
 * @dev Checks if a user has claimed a refund for this project.
 * @param user The address of the user to check
 * @return bool True if the user has claimed a refund, false otherwise
 */
    function hasUserClaimedRefund(address user) external view returns (bool) {
        return hasClaimedRefund[user];
    }

/**
 * @dev Checks if a user has withdrawn returns for this project.
 * @param user The address of the user to check
 * @return bool True if the user has withdrawn returns, false otherwise
 */
    function hasUserWithdrawnReturns(address user) external view returns (bool) {
        return hasWithdrawnReturns[user];
    }

/**
 * @dev Checks if the creator has repaid the funds for this project.
 * @return bool True if the creator has repaid the funds, false otherwise
 */
    function hasCreatorRepaid() external view returns (bool) {
        return returnInfo.isReturned;
    }

/**
 * @dev Internal function to initialize project information from deployment parameters.
 * Copies all fields from the initialization struct to storage.
 * @param init The initial project information struct
 */
    function _initProjectInfo(CrowdfundStructs.ProjectInfo memory init) internal {
        CrowdfundStructs.ProjectInfo storage pi = projectInfo;
        pi.creator = init.creator;
        pi.title = init.title;
        pi.description = init.description;
        pi.startDate = init.startDate;
        pi.endDate = init.endDate;
        pi.returnNotifyDate = init.returnNotifyDate;
        pi.raiseAmount = init.raiseAmount;
        pi.minInvestment = init.minInvestment;
        pi.maxInvestment = init.maxInvestment;
        for (uint256 i = 0; i < init.documents.length; i++) {
            pi.documents.push(init.documents[i]);
        }
    }

/**
 * @dev Allows users to invest in the project by transferring USDT tokens.
 * Handles investment validation, token transfer, and project status updates.
 * @param amount The amount of tokens to invest
 */
    function invest(uint256 amount) external payable override nonReentrant {
        ProjectStorage storage ps = projectStorage;

        require(msg.value == 0, CrowdfundErrors.USDT_ONLY); // Disallow native token payments
        require(amount > 0, CrowdfundErrors.AMOUNT_ZERO); // Validate investment amount
        require(
            ps.status == CrowdfundStructs.ProjectStatus.Waiting ||
            ps.status == CrowdfundStructs.ProjectStatus.Active,
            CrowdfundErrors.PROJECT_NOT_AVAILABLE // Check project availability
        );
        require(block.timestamp >= projectInfo.startDate, CrowdfundErrors.INVESTMENT_NOT_STARTED); // Check start date
        require(block.timestamp <= projectInfo.endDate, CrowdfundErrors.INVESTMENT_ENDED); // Check end date
        require(amount >= projectInfo.minInvestment, CrowdfundErrors.INVESTMENT_BELOW_MIN); // Validate minimum investment
        require(amount <= projectInfo.maxInvestment, CrowdfundErrors.INVESTMENT_ABOVE_MAX); // Validate maximum investment
        require(ps.totalRaised + amount <= projectInfo.raiseAmount, CrowdfundErrors.EXCEEDS_FUNDING_GOAL); // Check funding goal

        // Transfer USDT from investor to this contract using SafeERC20
        IERC20(paymentToken).safeTransferFrom(msg.sender, address(this), amount);

        // Add new investor to the list if first investment
        if (investments[msg.sender] == 0) investors.push(msg.sender);
        investments[msg.sender] += amount; // Record investment amount
        ps.totalRaised += uint128(amount); // Update total raised

        // Automatically set project to Active if funding goal is reached
        if (ps.totalRaised == ps.raiseAmount) {
            ps.status = CrowdfundStructs.ProjectStatus.Active;
        }

        emit FundsInvested(msg.sender, amount); // Log the investment event
    }

/**
 * @dev Approves the project for investment after admin review.
 * Can only be called by an admin and changes status from Pending to Waiting.
 */
    function approveProject() external override onlyAdmin {
        ProjectStorage storage ps = projectStorage;
        require(ps.status == CrowdfundStructs.ProjectStatus.Pending, CrowdfundErrors.INVALID_STATUS); // Must be pending
        ps.status = CrowdfundStructs.ProjectStatus.Waiting; // Change to waiting status
        emit ProjectApproved(msg.sender); // Log approval event
    }

/**
 * @dev Rejects the project after admin review with a reason.
 * Can only be called by an admin and changes status to Rejected.
 * @param reason The reason for rejecting the project
 */
    function rejectProject(string memory reason) external override onlyAdmin {
        ProjectStorage storage ps = projectStorage;
        require(ps.status == CrowdfundStructs.ProjectStatus.Pending, CrowdfundErrors.INVALID_STATUS); // Must be pending
        ps.status = CrowdfundStructs.ProjectStatus.Rejected; // Change to rejected status
        ps.rejectionReason = reason; // Store rejection reason
        emit ProjectRejected(msg.sender, reason); // Log rejection event
    }

/**
 * @dev Returns the reason for project rejection.
 * @return string The rejection reason if project was rejected
 */
    function getRejectionReason() external view override returns (string memory) {
        return projectStorage.rejectionReason;
    }

/**
 * @dev Returns the project information struct.
 * @return CrowdfundStructs.ProjectInfo The complete project information
 */
    function getProjectInfo() external view override returns (CrowdfundStructs.ProjectInfo memory) {
        return projectInfo;
    }

/**
 * @dev Determines the current effective status of the project based on time and conditions.
 * Handles status transitions based on timestamps and funding levels.
 * @return CrowdfundStructs.ProjectStatus The current project status
 */
    function _determineStatus() internal view returns (CrowdfundStructs.ProjectStatus) {
        ProjectStorage storage ps = projectStorage;

        // Return immutable statuses
        if (ps.status == CrowdfundStructs.ProjectStatus.Pending) return CrowdfundStructs.ProjectStatus.Pending;
        if (ps.status == CrowdfundStructs.ProjectStatus.Rejected) return CrowdfundStructs.ProjectStatus.Rejected;
        if (ps.status == CrowdfundStructs.ProjectStatus.Deferred) return CrowdfundStructs.ProjectStatus.Deferred;

        // Handle waiting status transitions
        if (ps.status == CrowdfundStructs.ProjectStatus.Waiting) {
            if (block.timestamp < projectInfo.startDate) {
                return CrowdfundStructs.ProjectStatus.Waiting; // Before start date
            } else if (block.timestamp <= projectInfo.endDate) {
                return CrowdfundStructs.ProjectStatus.Active; // During investment period
            } else {
                // After end date - check if funding goal was met
                if (ps.totalRaised >= ps.raiseAmount) {
                    return CrowdfundStructs.ProjectStatus.Completed; // Goal met
                } else {
                    return CrowdfundStructs.ProjectStatus.Deferred; // Goal not met
                }
            }
        }

        return ps.status; // Return current status for other cases
    }

/**
 * @dev Returns the project address and investment amount for a specific investor.
 * Since this function is called from the project contract, it returns only this project's data.
 * @param investor The address of the investor to query
 * @return address[] Array containing this project's address if invested, empty otherwise
 * @return uint256[] Array containing investment amount if invested, empty otherwise
 */
    function getInvestorProjectsWithAmounts(address investor) external view override returns (address[] memory, uint256[] memory) {
        // Check if the investor has any investment in this project
        uint256 investment = investments[investor];

        if (investment > 0) {
            // Return this project and the investment amount
            address[] memory projectList = new address[](1);
            uint256[] memory amountList = new uint256[](1);

            projectList[0] = address(this);
            amountList[0] = investment;

            return (projectList, amountList);
        } else {
            // Return empty arrays if no investment
            address[] memory emptyProjects = new address[](0);
            uint256[] memory emptyAmounts = new uint256[](0);

            return (emptyProjects, emptyAmounts);
        }
    }

/**
 * @dev Allows investors to claim refunds when project is deferred (funding goal not met).
 * Transfers the invested amount back to the investor.
 */
    function claimRefund() external nonReentrant override {
        require(_determineStatus() == CrowdfundStructs.ProjectStatus.Deferred, CrowdfundErrors.PROJECT_NOT_DEFERRED); // Must be deferred
        require(investments[msg.sender] > 0, CrowdfundErrors.NO_INVESTMENT); // Must have invested
        require(!hasClaimedRefund[msg.sender], CrowdfundErrors.ALREADY_CLAIMED); // Must not have claimed before

        uint256 amount = investments[msg.sender]; // Get investment amount
        investments[msg.sender] = 0; // Clear investment record
        hasClaimedRefund[msg.sender] = true; // Mark as refunded

        // Use SafeERC20 for USDT transfer back to investor
        IERC20(paymentToken).safeTransfer(msg.sender, amount);
    }

/**
 * @dev Returns the current project status considering time-based transitions.
 * @return CrowdfundStructs.ProjectStatus The effective project status
 */
    function getStatus() external view override returns (CrowdfundStructs.ProjectStatus) {
        return _determineStatus();
    }

/**
 * @dev Returns the total amount raised by the project.
 * @return uint256 The total amount raised in tokens
 */
    function getTotalRaised() external view override returns (uint256) {
        return projectStorage.totalRaised;
    }

/**
 * @dev Returns the list of all investors in this project.
 * @return address[] Array of investor addresses
 */
    function getInvestors() external view override returns (address[] memory) {
        return investors;
    }

/**
 * @dev Returns the investment amount for a specific investor.
 * @param investor The address of the investor to query
 * @return uint256 The amount invested by the specified investor
 */
    function getInvestment(address investor) external view override returns (uint256) {
        return investments[investor];
    }

/**
 * @dev Returns the return information for the project.
 * @return CrowdfundStructs.ProjectReturn The project return details
 */
    function getReturnInfo() external view override returns (CrowdfundStructs.ProjectReturn memory) {
        return returnInfo;
    }

/**
 * @dev Returns the payment token address used for this project.
 * @return address The ERC20 token contract address
 */
    function getPaymentToken() external view override returns (address) {
        return paymentToken;
    }

/**
 * @dev Allows the project creator to withdraw funds after project is active.
 * Deducts platform fees and transfers the remaining amount to the creator.
 */
    function withdrawFunds() external nonReentrant onlyCreator {
        require(projectStorage.status == CrowdfundStructs.ProjectStatus.Active, CrowdfundErrors.PROJECT_NOT_ACTIVE); // Must be active
        require(block.timestamp > projectInfo.endDate, CrowdfundErrors.INVALID_DATE); // Must be after end date
        require(!hasCreatorWithdrawnFunds, CrowdfundErrors.ALREADY_WITHDRAWN); // Must not have withdrawn before
        uint256 balance = IERC20(paymentToken).balanceOf(address(this)); // Get contract balance
        require(balance > 0, CrowdfundErrors.NOT_ENOUGH_BALANCE); // Must have balance

        uint256 feeAmount = (projectStorage.totalRaised * PLATFORM_FEE_PERCENT) / 100; // Calculate platform fee
        uint256 creatorAmount = balance - feeAmount; // Calculate creator's share

        hasCreatorWithdrawnFunds = true; // Mark as withdrawn

        // Transfer fee to admin using SafeERC20
        IERC20(paymentToken).safeTransfer(admin, feeAmount);
        // Transfer remaining to creator using SafeERC20
        IERC20(paymentToken).safeTransfer(creator, creatorAmount);

        emit FundsWithdrawn(creator, creatorAmount); // Log creator withdrawal
        emit PlatformFeeTransferred(admin, feeAmount); // Log platform fee
    }

/**
 * @dev Allows the creator to return funds to investors after withdrawing funds.
 * Calculates profit percentage and updates project return information.
 * @param amount The amount to return (must be >= total raised)
 */
    function returnFunds(uint256 amount) external payable nonReentrant onlyCreator onlyActive {
        require(msg.value == 0, CrowdfundErrors.USDT_ONLY); // Disallow native token payments
        require(!returnInfo.isReturned, CrowdfundErrors.ALREADY_RETURNED); // Must not have returned before
        require(hasCreatorWithdrawnFunds, CrowdfundErrors.MUST_WITHDRAW_FIRST); // Creator must have withdrawn first

        uint256 totalRaised = projectStorage.totalRaised; // Get original raised amount
        require(amount >= totalRaised, CrowdfundErrors.INSUFFICIENT_REPAYMENT); // Must return at least original amount

        // Use SafeERC20 for USDT transfer from creator
        IERC20(paymentToken).safeTransferFrom(msg.sender, address(this), amount);

        uint256 profit = amount - totalRaised; // Calculate profit
        uint256 profitPercentage = (profit * 100) / totalRaised; // Calculate profit percentage

        // Update return information
        returnInfo = CrowdfundStructs.ProjectReturn({
            returnedAmount: amount, // Total returned amount
            profitPercentage: profitPercentage, // Profit percentage
            returnDate: block.timestamp, // Return timestamp
            isReturned: true // Mark as returned
        });

        projectStorage.status = CrowdfundStructs.ProjectStatus.Completed; // Update status

        emit FundsReturned(returnInfo.returnedAmount, profitPercentage); // Log return event
    }

/**
 * @dev Allows investors to withdraw their returns after funds are returned by creator.
 * Distributes returns proportionally based on investment share.
 */
    function withdrawReturns() external nonReentrant override {
        require(returnInfo.isReturned, CrowdfundErrors.RETURNS_NOT_AVAILABLE); // Must have returns available
        require(investments[msg.sender] > 0, CrowdfundErrors.NO_INVESTMENT); // Must have invested
        require(!hasWithdrawnReturns[msg.sender], CrowdfundErrors.ALREADY_WITHDRAWN_RETURNS); // Must not have withdrawn before

        uint256 investment = investments[msg.sender]; // Get investor's investment
        uint256 totalReturn = returnInfo.returnedAmount; // Get total returned amount
        uint256 totalInvested = projectStorage.totalRaised; // Get total raised

        uint256 share = (investment * totalReturn) / totalInvested; // Calculate proportional share

        investments[msg.sender] = 0; // Clear investment record
        hasWithdrawnReturns[msg.sender] = true; // Mark as withdrawn

        IERC20(paymentToken).safeTransfer(msg.sender, share); // Transfer share to investor

        emit ReturnsWithdrawn(msg.sender, share); // Log withdrawal event
    }

    /**
     * @notice Admin can mark project as defaulted if creator doesn't withdraw funds within 7 days of completion
     * @param reason Reason for marking as defaulted
     */
    function markAsDefaulted(string calldata reason) external onlyAdmin {
        require(projectStorage.status == CrowdfundStructs.ProjectStatus.Active, CrowdfundErrors.PROJECT_NOT_ACTIVE);
        require(block.timestamp > projectInfo.endDate, CrowdfundErrors.INVESTMENT_ENDED);
        require(!hasCreatorWithdrawnFunds, CrowdfundErrors.ALREADY_WITHDRAWN);

        // Check if 7 days have passed since project completion
        require(
            block.timestamp >= projectInfo.endDate + CREATOR_WITHDRAWAL_DEADLINE,
            CrowdfundErrors.DEADLINE_NOT_REACHED
        );

        projectStorage.status = CrowdfundStructs.ProjectStatus.Deferred;
        emit ProjectMarkedAsDefaulted(msg.sender, reason);
    }

    /**
     * @notice Check if creator withdrawal deadline has passed
     * @return bool True if deadline has passed
     */
    function isCreatorWithdrawalDeadlinePassed() external view returns (bool) {
        if (projectStorage.status != CrowdfundStructs.ProjectStatus.Active) return false;
        if (block.timestamp <= projectInfo.endDate) return false;
        if (hasCreatorWithdrawnFunds) return false;

        return block.timestamp >= projectInfo.endDate + CREATOR_WITHDRAWAL_DEADLINE;
    }

    /**
     * @notice Get the deadline timestamp for creator withdrawal
     * @return uint256 Timestamp when creator must withdraw by
     */
    function getCreatorWithdrawalDeadline() external view returns (uint256) {
        return projectInfo.endDate + CREATOR_WITHDRAWAL_DEADLINE;
    }

    /**
   * @dev Modifier that restricts function access to admin addresses only.
 * Checks admin status through the main crowdfund admin contract.
 * Reverts if the caller is not an admin.
 */
    modifier onlyAdmin() {
        require(ICrowdfundAdmin(admin).checkAdmin(msg.sender), CrowdfundErrors.NOT_ADMIN);
        _;
    }

/**
 * @dev Modifier that restricts function access to the project creator only.
 * Reverts if the caller is not the project creator.
 */
    modifier onlyCreator() {
        require(msg.sender == creator, CrowdfundErrors.NOT_CREATOR);
        _;
    }

/**
 * @dev Modifier that restricts function access to when the project is in Active status.
 * Reverts if the project status is not Active.
 */
    modifier onlyActive() {
        require(projectStorage.status == CrowdfundStructs.ProjectStatus.Active, CrowdfundErrors.PROJECT_NOT_ACTIVE);
        _;
    }

/**
 * @dev Returns a list of all investors who have made investments in this project.
 * Uses inline assembly to optimize the array size to match actual investor count.
 * @return address[] Array of investor addresses who have invested in this project
 */
    function getMyInvestments() external view override returns (address[] memory) {
        // Initialize array with maximum possible size (all investors)
        address[] memory myInvestments = new address[](investors.length);
        uint256 count = 0;

        // Iterate through all known investors and filter those with investments
        for (uint256 i = 0; i < investors.length; i++) {
            if (investments[investors[i]] > 0) {
                myInvestments[count] = investors[i]; // Add investor to result array
                count++;                           // Increment valid investor counter
            }
        }

        // Use assembly to resize the array to the actual number of investing investors
        assembly {
            mstore(myInvestments, count)
        }

        return myInvestments;
    }
}