// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./interfaces/ICrowdfundAdmin.sol";
import "./interfaces/ICrowdfundProject.sol";
import "./libraries/CrowdfundStructs.sol";
import "./libraries/CrowdfundErrors.sol";

contract CrowdfundAdmin is ICrowdfundAdmin {
    address public admin;
    address[] public allProjects;
    mapping(address => bool) public isAdmin;
    event ProjectApproved(address indexed project, address indexed approver, string reason);
    event ProjectRejected(address indexed project, address indexed rejector, string reason);
    event AdminAdded(address indexed admin);
    event AdminRemoved(address indexed admin);

    constructor() {
        admin = msg.sender;
        isAdmin[msg.sender] = true;
    }

    modifier onlyAdmin() {
        require(isAdmin[msg.sender], CrowdfundErrors.NOT_ADMIN);
        _;
    }
    function checkAdmin(address adminAddress) external view override returns (bool) {
        return isAdmin[adminAddress];
    }
    function addAdmin(address newAdmin) external override onlyAdmin {
        require(!isAdmin[newAdmin], "Address is already an admin");
        isAdmin[newAdmin] = true;
        emit AdminAdded(newAdmin);
    }


    function removeAdmin(address adminToRemove) external override onlyAdmin {
        require(adminToRemove != admin, "Cannot remove primary admin");
        require(isAdmin[adminToRemove], "Address is not an admin");
        isAdmin[adminToRemove] = false;
        emit AdminRemoved(adminToRemove);
    }

    function approveProject(address project, string calldata reason) external override onlyAdmin {
        ICrowdfundProject(project).approveProject();
        allProjects.push(project);
        emit ProjectApproved(project, msg.sender, reason);
    }

    function rejectProject(address project, string calldata reason) external override onlyAdmin {
        ICrowdfundProject(project).rejectProject(reason);
        emit ProjectRejected(project, msg.sender, reason);
    }
  
    function getAdminProjects() external view override returns (address[] memory) {
        return allProjects;
    }
}