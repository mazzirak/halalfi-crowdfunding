// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {CrowdfundProject} from "./CrowdfundProject.sol";
import {ICrowdfundProject} from "./interfaces/ICrowdfundProject.sol";
import {ICrowdfundAdmin} from "./interfaces/ICrowdfundAdmin.sol";
import {CrowdfundErrors} from "./libraries/CrowdfundErrors.sol";
import {CrowdfundStructs} from "./libraries/CrowdfundStructs.sol";

/**
 * @title CrowdfundFactory
 * @author Mazyar Zirak <mazyarzirak1@gmail.com>
 * @notice Factory contract for deploying new crowdfunding projects.
 * @dev This contract enables users to create instances of CrowdfundProject contracts.
 *      It keeps track of all deployed projects and their creators.
 */
contract CrowdfundFactory {
    address public admin;
    address[] public allProjects;

    address public immutable paymentToken;

    mapping(address => address[]) public creatorProjects;
    mapping(address => bool) public isProject;
    mapping(address => bool) public returnRequested;

    event ProjectCreated(address indexed creator, address project);
    event ReturnRequested(address indexed project, address indexed investor);

    constructor(address _paymentToken, address _adminContract) {
        require(_paymentToken != address(0), CrowdfundErrors.INVALID_PAYMENT_TOKEN);
        require(_adminContract != address(0), CrowdfundErrors.INVALID_ADDRESS);
        require(_adminContract.code.length > 0, CrowdfundErrors.ADMIN_MUST_BE_CONTRACT);
        admin = _adminContract;
        paymentToken = _paymentToken;
    }

    /**
     * @notice Creates a new crowdfunding project.
     * @param title The title of the crowdfunding project.
     * @param description A brief description of the project.
     * @param documents An array of document hashes associated with the project.
     * @param startDate Timestamp when contributions can begin.
     * @param endDate Timestamp when contributions end.
     * @param returnNotifyDate Timestamp for when investors will be notified of returns.
     * @param raiseAmount Target funding amount in wei.
     * @param minInvestment Minimum investment allowed from a single contributor.
     * @param maxInvestment Maximum investment allowed from a single contributor.
     * @return projectAddress The address of the newly created CrowdfundProject.
     */
    function createProject(
        string memory title,
        string memory description,
        CrowdfundStructs.Document[] memory documents,
        uint256 startDate,
        uint256 endDate,
        uint256 returnNotifyDate,
        uint256 raiseAmount,
        uint256 minInvestment,
        uint256 maxInvestment
    ) external returns (address) {
        require(startDate >= block.timestamp, CrowdfundErrors.INVALID_DATE);
        require(raiseAmount > 0, CrowdfundErrors.INVALID_AMOUNT);
        require(minInvestment > 0, CrowdfundErrors.INVALID_AMOUNT);
        require(endDate > startDate, CrowdfundErrors.INVALID_DATE);
        require(returnNotifyDate > endDate, CrowdfundErrors.INVALID_DATE);
        require(minInvestment <= maxInvestment, CrowdfundErrors.INVALID_AMOUNT);
        require(maxInvestment <= raiseAmount, CrowdfundErrors.INVALID_AMOUNT);

        CrowdfundStructs.ProjectInfo memory init = CrowdfundStructs.ProjectInfo({
            creator: msg.sender,
            title: title,
            description: description,
            documents: documents,
            startDate: startDate,
            endDate: endDate,
            returnNotifyDate: returnNotifyDate,
            raiseAmount: raiseAmount,
            minInvestment: minInvestment,
            maxInvestment: maxInvestment
        });

        CrowdfundProject project = new CrowdfundProject(
            admin,
            init,
            paymentToken
        );

        address projectAddress = address(project);
        allProjects.push(projectAddress);
        creatorProjects[msg.sender].push(projectAddress);
        isProject[projectAddress] = true;

        emit ProjectCreated(msg.sender, projectAddress);
        return projectAddress;
    }

    /**
     * @notice Retrieves an array of all deployed crowdfunding project addresses.
     * @return An array containing addresses of all projects.
     */
    function getAllProjects() external view returns (address[] memory) {
        return allProjects;
    }

    /**
     * @notice Retrieves all crowdfunding projects created by a specific address.
     * @param creator The address of the project creator.
     * @return An array of project addresses created by the given address.
     */
    function getCreatorProjects(address creator) external view returns (address[] memory) {
        return creatorProjects[creator];
    }

    /**
     * @notice Gets detailed info about a specific project.
     * @param project The address of the CrowdfundProject contract.
     * @return info Struct containing all project metadata.
     */
    function getProjectDetails(address project) external view returns (CrowdfundStructs.ProjectInfo memory) {
        require(isProject[project], CrowdfundErrors.NOT_PROJECT);
        return ICrowdfundProject(project).getProjectInfo();
    }

    /**
    * @dev Public view function to retrieve the primary admin address.
 * @return address The primary admin address for the contract
 */
    function getAdmin() external view returns (address) {
        return admin;
    }

/**
 * @dev Retrieves all projects an investor has invested in along with their investment amounts.
 * Iterates through all approved projects to find those where the investor has made investments.
 * @param investor The address of the investor to query
 * @return CrowdfundStructs.ProjectDetail[] Array of project details for invested projects
 * @return uint256[] Array of investment amounts corresponding to each project
 */
    function getInvestorProjectsWithAmounts(address investor)
    external
    view
    returns (CrowdfundStructs.ProjectDetail[] memory, uint256[] memory)
    {
        // First pass: Count how many projects the investor has invested in
        uint256 totalInvestedProjects = 0;
        for (uint256 i = 0; i < allProjects.length; i++) {
            if (ICrowdfundProject(allProjects[i]).getInvestment(investor) > 0) {
                totalInvestedProjects++;
            }
        }

        // Initialize return arrays with the exact size needed
        CrowdfundStructs.ProjectDetail[] memory projectDetails =
                    new CrowdfundStructs.ProjectDetail[](totalInvestedProjects);
        uint256[] memory amounts = new uint256[](totalInvestedProjects);

        // Second pass: Populate the arrays with project details and investment amounts
        uint256 index = 0;
        for (uint256 i = 0; i < allProjects.length; i++) {
            address projectAddress = allProjects[i];
            ICrowdfundProject project = ICrowdfundProject(projectAddress);
            uint256 investment = project.getInvestment(investor);

            if (investment > 0) {

                CrowdfundStructs.ProjectInfo memory info = project.getProjectInfo();

                // Construct detailed project information
                projectDetails[index] = CrowdfundStructs.ProjectDetail({
                    projectAddress: projectAddress,           // Address of the project contract
                    creator: info.creator,                    // Project creator address
                    title: info.title,                        // Project title
                    description: info.description,            // Project description
                    documents: info.documents,                // Project documents
                    startDate: info.startDate,                // Project start date
                    endDate: info.endDate,                    // Project end date
                    returnNotifyDate: info.returnNotifyDate,  // Return notification date
                    raiseAmount: info.raiseAmount,            // Target funding amount
                    minInvestment: info.minInvestment,        // Minimum investment allowed
                    maxInvestment: info.maxInvestment,        // Maximum investment allowed
                    totalRaised: project.getTotalRaised(),    // Total amount raised by the project
                    status: project.getStatus(),              // Current project status
                    paymentToken: project.getPaymentToken(),  // Token used for payments
                    returnInfo: project.getReturnInfo(),      // Investment return information
                    rejectionReason: project.getRejectionReason() // Reason if project was rejected
                });

                amounts[index] = investment; // Store the investment amount
                index++;
            }
        }

        return (projectDetails, amounts);
    }

    /**
     * @notice Investor signals that they expect returns to be processed.
     * @param project The project address to mark as needing returns.
     */
    function requestReturn(address project) external {
        require(isProject[project], CrowdfundErrors.NOT_PROJECT);
        require(ICrowdfundProject(project).getInvestment(msg.sender) > 0, CrowdfundErrors.NOT_INVESTOR);
        returnRequested[project] = true;
        emit ReturnRequested(project, msg.sender);
    }

    /**
     * @notice Retrieves detailed info about all crowdfunding projects.
     * @return An array of ProjectDetail structs containing full project information.
     */
    function getAllProjectsDetails() external view returns (CrowdfundStructs.ProjectDetail[] memory) {
        address[] memory projects = this.getAllProjects();
        uint256 projectCount = projects.length;
        CrowdfundStructs.ProjectDetail[] memory projectDetails = new CrowdfundStructs.ProjectDetail[](projectCount);

        for (uint256 i = 0; i < projectCount; i++) {
            address projectAddress = projects[i];
            ICrowdfundProject project = ICrowdfundProject(projectAddress);

            CrowdfundStructs.ProjectInfo memory projectInfo = this.getProjectDetails(projectAddress);

            projectDetails[i] = CrowdfundStructs.ProjectDetail({
                projectAddress: projectAddress,
                creator: projectInfo.creator,
                title: projectInfo.title,
                description: projectInfo.description,
                documents: projectInfo.documents,
                startDate: projectInfo.startDate,
                endDate: projectInfo.endDate,
                returnNotifyDate: projectInfo.returnNotifyDate,
                raiseAmount: projectInfo.raiseAmount,
                minInvestment: projectInfo.minInvestment,
                maxInvestment: projectInfo.maxInvestment,
                totalRaised: project.getTotalRaised(),
                status: project.getStatus(),
                paymentToken: project.getPaymentToken(),
                returnInfo: project.getReturnInfo(),
                rejectionReason: project.getRejectionReason()
            });
        }

        return projectDetails;
    }

    /**
     * @notice Update admin contract address (only callable by current admin)
     * @param newAdminContract New admin contract address
     */
    function updateAdmin(address newAdminContract) external {
        require(ICrowdfundAdmin(admin).checkAdmin(msg.sender), CrowdfundErrors.NOT_ADMIN);
        require(newAdminContract != address(0), CrowdfundErrors.INVALID_ADDRESS);
        require(newAdminContract.code.length > 0, CrowdfundErrors.ADMIN_MUST_BE_CONTRACT);
        admin = newAdminContract;
    }
}