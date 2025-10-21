// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./interfaces/ICrowdfundProject.sol";
import "./interfaces/ICrowdfundInvestor.sol";
import "./interfaces/ICrowdfundAdmin.sol";
import "./libraries/CrowdfundErrors.sol";
import "./libraries/CrowdfundStructs.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

/**
 * @title CrowdfundProject
 * @author Mazyar Zirak <mazyarzirak1@gmail.com>
 */
contract CrowdfundProject is ICrowdfundProject, ICrowdfundInvestor, ReentrancyGuard {
    using SafeMath for uint256;

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

    bool public hasCreatorWithdrawnFunds;
    uint256 public constant PLATFORM_FEE_PERCENT = 1; // 1% platform fee

    constructor(
        address _admin,
        CrowdfundStructs.ProjectInfo memory init,
        address _paymentToken
    ) {
        require(init.endDate > init.startDate, CrowdfundErrors.INVALID_DATE);
        require(init.returnNotifyDate > init.endDate, CrowdfundErrors.INVALID_DATE);
        require(init.minInvestment <= init.maxInvestment, CrowdfundErrors.INVALID_AMOUNT);
        require(init.maxInvestment <= init.raiseAmount, CrowdfundErrors.INVALID_AMOUNT);
        require(_paymentToken != address(0), "Payment token cannot be zero address");

        admin = _admin;
        factory = msg.sender;
        creator = init.creator;
        paymentToken = _paymentToken;

        _initProjectInfo(init);

        projectStorage = ProjectStorage({
            status: CrowdfundStructs.ProjectStatus.Pending,
            totalRaised: 0,
            raiseAmount: uint128(init.raiseAmount),
            rejectionReason: ""
        });
        hasCreatorWithdrawnFunds = false;
    }

    function hasUserClaimedRefund(address user) external view returns (bool) {
        return hasClaimedRefund[user];
    }

    function hasUserWithdrawnReturns(address user) external view returns (bool) {
        return hasWithdrawnReturns[user];
    }

    function hasCreatorRepaid() external view returns (bool) {
        return returnInfo.isReturned;
    }

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

    function invest(uint256 amount) external payable override nonReentrant {
        ProjectStorage storage ps = projectStorage;

        // Reject any ETH/BNB sent
        require(msg.value == 0, "ETH/BNB not accepted, use USDT only");
        require(amount > 0, "Amount must be greater than 0");
        require(ps.status == CrowdfundStructs.ProjectStatus.Waiting || ps.status == CrowdfundStructs.ProjectStatus.Active, "Project not available for investment");
        require(block.timestamp >= projectInfo.startDate, "Investment not started");
        require(block.timestamp <= projectInfo.endDate, "Investment period ended");
        require(amount >= projectInfo.minInvestment, "Below minimum investment");
        require(amount <= projectInfo.maxInvestment, "Above maximum investment");
        require(ps.totalRaised + amount <= projectInfo.raiseAmount, "Exceeds funding goal");

        // Transfer USDT from investor to this contract
        require(
            IERC20(paymentToken).transferFrom(msg.sender, address(this), amount),
            "USDT transfer failed"
        );

        if (investments[msg.sender] == 0) investors.push(msg.sender);
        investments[msg.sender] += amount;
        ps.totalRaised += uint128(amount);

        if (ps.totalRaised == ps.raiseAmount) {
            ps.status = CrowdfundStructs.ProjectStatus.Active;
        }

        emit FundsInvested(msg.sender, amount);
    }
    

    function approveProject() external override {
        ProjectStorage storage ps = projectStorage;
        require(ps.status == CrowdfundStructs.ProjectStatus.Pending, CrowdfundErrors.INVALID_STATUS);
        ps.status = CrowdfundStructs.ProjectStatus.Waiting;
        emit ProjectApproved(msg.sender);
    }

    function rejectProject(string memory reason) external override {
        ProjectStorage storage ps = projectStorage;
        require(ps.status == CrowdfundStructs.ProjectStatus.Pending, CrowdfundErrors.INVALID_STATUS);
        ps.status = CrowdfundStructs.ProjectStatus.Rejected;
        ps.rejectionReason = reason;
        emit ProjectRejected(msg.sender, reason);
    }

    function getRejectionReason() external view override returns (string memory) {
        return projectStorage.rejectionReason;
    }

    function getProjectInfo() external view override returns (CrowdfundStructs.ProjectInfo memory) {
        return projectInfo;
    }

    function _determineStatus() internal view returns (CrowdfundStructs.ProjectStatus) {
        ProjectStorage storage ps = projectStorage;

        if (ps.status == CrowdfundStructs.ProjectStatus.Pending) return CrowdfundStructs.ProjectStatus.Pending;
        if (ps.status == CrowdfundStructs.ProjectStatus.Rejected) return CrowdfundStructs.ProjectStatus.Rejected;

        if (ps.status == CrowdfundStructs.ProjectStatus.Waiting) {
            if (block.timestamp < projectInfo.startDate) {
                return CrowdfundStructs.ProjectStatus.Waiting;
            } else if (block.timestamp <= projectInfo.endDate) {
                return CrowdfundStructs.ProjectStatus.Active;
            } else {
                if (ps.totalRaised >= ps.raiseAmount) {
                    return CrowdfundStructs.ProjectStatus.Completed;
                } else {
                    return CrowdfundStructs.ProjectStatus.Deferred;
                }
            }
        }

        return ps.status;
    }

    function getInvestorProjectsWithAmounts(address investor) external view override returns (address[] memory, uint256[] memory) {
        uint256 count = 0;
        for (uint256 i = 0; i < investors.length; i++) {
            if (investments[investors[i]] > 0) {
                count++;
            }
        }

        address[] memory projectList = new address[](count);
        uint256[] memory amountList = new uint256[](count);

        uint256 index = 0;
        for (uint256 i = 0; i < investors.length; i++) {
            if (investments[investors[i]] > 0) {
                projectList[index] = address(this);
                amountList[index] = investments[investors[i]];
                index++;
            }
        }

        return (projectList, amountList);
    }

    function claimRefund() external nonReentrant override {
        require(_determineStatus() == CrowdfundStructs.ProjectStatus.Deferred, "Project is not deferred");
        require(investments[msg.sender] > 0, "No investment to refund");
        require(!hasClaimedRefund[msg.sender], "Already claimed refund");

        uint256 amount = investments[msg.sender];
        investments[msg.sender] = 0;
        hasClaimedRefund[msg.sender] = true;

        require(IERC20(paymentToken).transfer(msg.sender, amount), "USDT transfer failed");
    }
    

    function getStatus() external view override returns (CrowdfundStructs.ProjectStatus) {
        return _determineStatus();
    }

    function getTotalRaised() external view override returns (uint256) {
        return projectStorage.totalRaised;
    }

    function getInvestors() external view override returns (address[] memory) {
        return investors;
    }

    function getInvestment(address investor) external view override returns (uint256) {
        return investments[investor];
    }

    function getReturnInfo() external view override returns (CrowdfundStructs.ProjectReturn memory) {
        return returnInfo;
    }

    function getPaymentToken() external view override returns (address) {
        return paymentToken;
    }
    
    function withdrawFunds() external nonReentrant onlyCreator {
        require(projectStorage.status == CrowdfundStructs.ProjectStatus.Active, CrowdfundErrors.PROJECT_NOT_ACTIVE);
        require(block.timestamp >= projectInfo.endDate, CrowdfundErrors.INVALID_DATE);
        require(!hasCreatorWithdrawnFunds, "Funds already withdrawn");

        uint256 balance = IERC20(paymentToken).balanceOf(address(this));
        require(balance > 0, CrowdfundErrors.NOT_ENOUGH_BALANCE);

      
        uint256 feeAmount = (projectStorage.totalRaised * PLATFORM_FEE_PERCENT) / 100;
        uint256 creatorAmount = balance - feeAmount;

        hasCreatorWithdrawnFunds = true;

        // Transfer fee to admin
        require(IERC20(paymentToken).transfer(admin, feeAmount), CrowdfundErrors.TRANSFER_FAILED);
        // Transfer remaining to creator
        require(IERC20(paymentToken).transfer(creator, creatorAmount), CrowdfundErrors.TRANSFER_FAILED);

        emit FundsWithdrawn(creator, creatorAmount);
        emit PlatformFeeTransferred(admin, feeAmount);
    }

    function returnFunds(uint256 amount) external payable nonReentrant onlyCreator onlyActive {
        require(msg.value == 0, "ETH/BNB not accepted, use USDT only");
        require(!returnInfo.isReturned, CrowdfundErrors.ALREADY_RETURNED);

        uint256 totalRaised = projectStorage.totalRaised;
        require(amount >= totalRaised, "Must repay at least the raised amount");

        require(
            IERC20(paymentToken).transferFrom(msg.sender, address(this), amount),
            "USDT transfer failed"
        );

        uint256 profit = amount - totalRaised;
        uint256 profitPercentage = (profit * 100) / totalRaised;

        returnInfo = CrowdfundStructs.ProjectReturn({
            returnedAmount: amount,
            profitPercentage: profitPercentage,
            returnDate: block.timestamp,
            isReturned: true
        });

        projectStorage.status = CrowdfundStructs.ProjectStatus.Completed;

        emit FundsReturned(returnInfo.returnedAmount, profitPercentage);
    }

    function withdrawReturns() external nonReentrant override {
        require(returnInfo.isReturned, "Returns not available yet");
        require(investments[msg.sender] > 0, "No investment found");
        require(!hasWithdrawnReturns[msg.sender], "Already withdrawn returns");

        uint256 investment = investments[msg.sender];
        uint256 totalReturn = returnInfo.returnedAmount;
        uint256 totalInvested = projectStorage.totalRaised;

        uint256 share = (investment * totalReturn) / totalInvested;

        investments[msg.sender] = 0;
        hasWithdrawnReturns[msg.sender] = true;
        
        require(IERC20(paymentToken).transfer(msg.sender, share), "USDT transfer failed");

        emit ReturnsWithdrawn(msg.sender, share);
    }

    function markAsDefaulted() external onlyAdmin {
        require(block.timestamp > projectInfo.returnNotifyDate);
        require(projectStorage.status == CrowdfundStructs.ProjectStatus.Active, CrowdfundErrors.INVALID_STATUS);
        projectStorage.status = CrowdfundStructs.ProjectStatus.Deferred;
    }

    modifier onlyAdmin() {
        require(ICrowdfundAdmin(admin).checkAdmin(msg.sender), CrowdfundErrors.NOT_ADMIN);
        _;
    }

    modifier onlyCreator() {
        require(msg.sender == creator, CrowdfundErrors.NOT_CREATOR);
        _;
    }

    modifier onlyActive() {
        require(projectStorage.status == CrowdfundStructs.ProjectStatus.Active, CrowdfundErrors.PROJECT_NOT_ACTIVE);
        _;
    }

    function getMyInvestments() external view override returns (address[] memory) {
        address[] memory myInvestments = new address[](investors.length);
        uint256 count = 0;

        for (uint256 i = 0; i < investors.length; i++) {
            if (investments[investors[i]] > 0) {
                myInvestments[count] = investors[i];
                count++;
            }
        }
        assembly {
            mstore(myInvestments, count)
        }

        return myInvestments;
    }
}