// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./interfaces/ICrowdfundAdmin.sol";
import "./interfaces/ICrowdfundProject.sol";
import "./libraries/CrowdfundStructs.sol";
import "./libraries/CrowdfundErrors.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract CrowdfundAdmin is ICrowdfundAdmin {
    using SafeERC20 for IERC20;

    address public admin;
    address[] public allProjects;
    mapping(address => bool) public isAdmin;

    event ProjectApproved(address indexed project, address indexed approver, string reason);
    event ProjectRejected(address indexed project, address indexed rejector, string reason);
    event AdminAdded(address indexed admin);
    event AdminRemoved(address indexed admin);
    event FeesWithdrawn(address indexed token, address indexed to, uint256 amount);

    constructor() {
        admin = msg.sender;
        isAdmin[msg.sender] = true;
    }

    /**
  * @dev Modifier that restricts function access to admin addresses only.
 * Reverts if the caller is not an admin, ensuring only authorized users can execute the function.
 */
    modifier onlyAdmin() {
        require(isAdmin[msg.sender], CrowdfundErrors.NOT_ADMIN);
        _;
    }

/**
 * @dev Public view function to check if an address has admin privileges.
 * @param adminAddress The address to check for admin status
 * @return bool Returns true if the address is an admin, false otherwise
 */
    function checkAdmin(address adminAddress) external view override returns (bool) {
        return isAdmin[adminAddress];
    }

/**
 * @dev Adds a new admin to the system.
 * Can only be called by an existing admin (enforced by onlyAdmin modifier).
 * @param newAdmin The address to grant admin privileges to
 */
    function addAdmin(address newAdmin) external override onlyAdmin {
        require(newAdmin != address(0), CrowdfundErrors.INVALID_ADDRESS); // Prevent zero address
        require(!isAdmin[newAdmin], CrowdfundErrors.ALREADY_EXISTS);     // Prevent duplicate admins
        isAdmin[newAdmin] = true;                                       // Grant admin status
        emit AdminAdded(newAdmin);                                      // Log the event
    }

/**
 * @dev Removes admin privileges from an existing admin.
 * Cannot remove the primary admin (admin variable) to maintain system integrity.
 * @param adminToRemove The address to revoke admin privileges from
 */
    function removeAdmin(address adminToRemove) external override onlyAdmin {
        require(adminToRemove != admin, CrowdfundErrors.CANNOT_REMOVE_PRIMARY); // Protect primary admin
        require(isAdmin[adminToRemove], CrowdfundErrors.DOES_NOT_EXIST);        // Verify admin exists
        isAdmin[adminToRemove] = false;                                         // Revoke admin status
        emit AdminRemoved(adminToRemove);                                       // Log the event
    }

/**
 * @dev Approves a crowdfund project by calling its approval function and adding it to the registry.
 * Only admins can call this function to maintain project quality control.
 * @param project The address of the project contract to approve
 * @param reason Optional explanation for the approval decision
 */
    function approveProject(address project, string calldata reason) external override onlyAdmin {
        ICrowdfundProject(project).approveProject(); // Call the project's internal approval function
        allProjects.push(project);                   // Add to the list of approved projects
        emit ProjectApproved(project, msg.sender, reason); // Log the approval event
    }

/**
 * @dev Rejects a crowdfund project by calling its rejection function.
 * Only admins can call this function to maintain project quality control.
 * @param project The address of the project contract to reject
 * @param reason Explanation for the rejection decision
 */
    function rejectProject(address project, string calldata reason) external override onlyAdmin {
        ICrowdfundProject(project).rejectProject(reason); // Call the project's internal rejection function
        emit ProjectRejected(project, msg.sender, reason); // Log the rejection event
    }

/**
 * @dev Returns the list of all approved projects.
 * Public view function for external access to the approved project registry.
 * @return address[] Array of approved project contract addresses
 */
    function getAdminProjects() external view override returns (address[] memory) {
        return allProjects;
    }
    /**
     * @notice Withdraw collected platform fees
     * @param token Token contract address
     * @param to Recipient address
     * @param amount Amount to withdraw
     */
    function withdrawFees(address token, address to, uint256 amount) external onlyAdmin {
        require(token != address(0), CrowdfundErrors.INVALID_ADDRESS);
        require(to != address(0), CrowdfundErrors.INVALID_ADDRESS);
        require(amount > 0, CrowdfundErrors.INVALID_AMOUNT);

        uint256 balance = IERC20(token).balanceOf(address(this));
        require(amount <= balance, CrowdfundErrors.NOT_ENOUGH_BALANCE);

        IERC20(token).safeTransfer(to, amount);
        emit FeesWithdrawn(token, to, amount);
    }

    /**
     * @notice Get the current balance of a token held by this contract
     * @param token Token contract address
     * @return balance Current balance
     */
    function getTokenBalance(address token) external view returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }

    /**
     * @notice Transfer primary admin role
     * @param newAdmin New primary admin address
     */
    function transferPrimaryAdmin(address newAdmin) external {
        require(msg.sender == admin, CrowdfundErrors.ONLY_PRIMARY_ADMIN);
        require(newAdmin != address(0), CrowdfundErrors.INVALID_ADDRESS);
        require(newAdmin != admin, CrowdfundErrors.ALREADY_EXISTS);

        // Add new admin if not already an admin
        if (!isAdmin[newAdmin]) {
            isAdmin[newAdmin] = true;
            emit AdminAdded(newAdmin);
        }

        admin = newAdmin;
    }
}