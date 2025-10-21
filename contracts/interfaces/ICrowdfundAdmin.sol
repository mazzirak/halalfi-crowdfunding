// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../libraries/CrowdfundStructs.sol";

interface ICrowdfundAdmin {
    function addAdmin(address newAdmin) external;
    function removeAdmin(address adminToRemove) external;
    function approveProject(address project, string calldata reason) external;
    function rejectProject(address project, string calldata reason) external;
    function getAdminProjects() external view returns (address[] memory);
    function checkAdmin(address adminAddress) external view returns (bool); 
}