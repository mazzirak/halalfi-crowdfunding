// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "../libraries/CrowdfundStructs.sol";

interface ICrowdfundProject {
    function approveProject() external;
    function rejectProject(string memory reason) external;
    function getProjectInfo() external view returns (CrowdfundStructs.ProjectInfo memory);
    function getStatus() external view returns (CrowdfundStructs.ProjectStatus);
    function getTotalRaised() external view returns (uint256);
    function getInvestors() external view returns (address[] memory);
    function getInvestment(address investor) external view returns (uint256);
    function getReturnInfo() external view returns (CrowdfundStructs.ProjectReturn memory);
    function getPaymentToken() external view returns (address);
    function getRejectionReason() external view returns (string memory);
    function updateAdmin(address newAdmin) external; 
    function getAdmin() external view returns (address); 
}