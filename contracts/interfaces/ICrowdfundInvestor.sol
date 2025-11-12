// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface ICrowdfundInvestor {
    function invest(uint256 amount) external payable;

    function withdrawReturns() external;

    function getMyInvestments() external view returns (address[] memory);

    function claimRefund() external;

    function getInvestorProjectsWithAmounts(address investor) external view returns (address[] memory, uint256[] memory);
}