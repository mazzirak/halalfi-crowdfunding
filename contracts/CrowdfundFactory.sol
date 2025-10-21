// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {CrowdfundProject} from "./CrowdfundProject.sol";
import {ICrowdfundProject} from "./interfaces/ICrowdfundProject.sol";
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

    address public constant USDT_TOKEN = 0x55d398326f99059fF775485246999027B3197955;

    mapping(address => address[]) public creatorProjects;
    mapping(address => bool) public isProject;
    mapping(address => bool) public returnRequested;

    event ProjectCreated(address indexed creator, address project);
    event ReturnRequested(address indexed project, address indexed investor);

    constructor() {
        admin = msg.sender;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can call this function");
        _;
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
            USDT_TOKEN
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

    function getAdmin() external view returns (address) {
        return admin;
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


    function getInvestorProjectsWithAmounts(address investor)
    external
    view
    returns (CrowdfundStructs.ProjectDetail[] memory, uint256[] memory)
    {
        uint256 totalInvestedProjects = 0;

        for (uint256 i = 0; i < allProjects.length; i++) {
            if (ICrowdfundProject(allProjects[i]).getInvestment(investor) > 0) {
                totalInvestedProjects++;
            }
        }

        CrowdfundStructs.ProjectDetail[] memory projectDetails =
                    new CrowdfundStructs.ProjectDetail[](totalInvestedProjects);
        uint256[] memory amounts = new uint256[](totalInvestedProjects);

        uint256 index = 0;
        for (uint256 i = 0; i < allProjects.length; i++) {
            address projectAddress = allProjects[i];
            ICrowdfundProject project = ICrowdfundProject(projectAddress);
            uint256 investment = project.getInvestment(investor);

            if (investment > 0) {
                CrowdfundStructs.ProjectInfo memory info = project.getProjectInfo();

                projectDetails[index] = CrowdfundStructs.ProjectDetail({
                    projectAddress: projectAddress,
                    creator: info.creator,
                    title: info.title,
                    description: info.description,
                    documents: info.documents,
                    startDate: info.startDate,
                    endDate: info.endDate,
                    returnNotifyDate: info.returnNotifyDate,
                    raiseAmount: info.raiseAmount,
                    minInvestment: info.minInvestment,
                    maxInvestment: info.maxInvestment,
                    totalRaised: project.getTotalRaised(),
                    status: project.getStatus(),
                    paymentToken: project.getPaymentToken(),
                    returnInfo: project.getReturnInfo(),
                    rejectionReason: project.getRejectionReason()
                });

                amounts[index] = investment;
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
}