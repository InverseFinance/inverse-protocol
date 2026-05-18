// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.5.16;

interface IGovernorMills {
    function cancel(uint256 proposalId) external;
    function __queueSetTimelockPendingAdmin(address newPendingAdmin, uint256 eta) external;
    function __executeSetTimelockPendingAdmin(address newPendingAdmin, uint256 eta) external;
}

contract Guardian {
    IGovernorMills public governorMills;
    address public constant oldGovernor = 0x926dF14a23BE491164dCF93f4c468A50ef659D5B;
    uint256 public revertDeadline;
    address public deployer;
    address public pendingDeployer;
    address public rwg = 0xE3eD95e130ad9E15643f5A5f232a3daE980784cd;
    address public pendingRwg;
    mapping(uint256 => bool) public cancellableProposals;

    event GovernanceRevertQueued(uint256 indexed eta);
    event GovernanceReverted(uint256 indexed eta);
    event AllowCancel(uint256 indexed proposalId, bool decision);
    event ExecuteCancel(uint256 indexed proposalId);
    event PendingRwgSet(address indexed newPendingRwg);
    event RwgSet(address indexed oldRwg, address indexed newRwg);
    event PendingDeployerSet(address indexed newPendingDeployer);
    event DeployerSet(address indexed oldDeployer, address indexed newDeployer);

    constructor(address _deployer) public {
        revertDeadline = block.timestamp + 180 days; //6 month rollback window
        governorMills = IGovernorMills(msg.sender);
        deployer = _deployer;
    }

    function queueRevertToPreviousGovernance(uint256 eta) external {
        require(msg.sender == deployer || msg.sender == rwg, "Guardian: not deployer or rwg");
        require(block.timestamp <= revertDeadline, "Guardian: revert deadline exceeded");
        governorMills.__queueSetTimelockPendingAdmin(oldGovernor, eta);
        emit GovernanceRevertQueued(eta);
    }

    function executeRevertToPreviousGovernance(uint256 eta) external {
        require(msg.sender == deployer || msg.sender == rwg, "Guardian: not deployer or rwg");
        governorMills.__executeSetTimelockPendingAdmin(oldGovernor, eta);
        emit GovernanceReverted(eta);
    }

    function allowCancel(uint256 proposalId, bool decision) external {
        require(msg.sender == deployer, "Guardian: not deployer");
        cancellableProposals[proposalId] = decision;
        emit AllowCancel(proposalId, decision);
    }

    function executeCancel(uint256 proposalId) external {
        require(msg.sender == rwg, "Guardian: not rwg");
        require(cancellableProposals[proposalId], "Guardian: not cancellable");
        governorMills.cancel(proposalId);
        cancellableProposals[proposalId] = false;
        emit ExecuteCancel(proposalId);
    }

    function setPendingRwg(address _rwg) external {
        require(msg.sender == rwg, "Guardian: not rwg");
        emit PendingRwgSet(_rwg);
        pendingRwg = _rwg;
    }

    function claimRwg() external {
        require(msg.sender == pendingRwg, "Guardian: not pending rwg");
        emit RwgSet(rwg, pendingRwg);
        rwg = pendingRwg;
        pendingRwg = address(0);
    }

    function setPendingDeployer(address _deployer) external {
        require(msg.sender == deployer, "Guardian: not deployer");
        emit PendingDeployerSet(_deployer);
        pendingDeployer = _deployer;
    }

    function claimDeployer() external {
        require(msg.sender == pendingDeployer, "Guardian: not pending deployer");
        emit DeployerSet(deployer, pendingDeployer);
        deployer = pendingDeployer;
        pendingDeployer = address(0);
    }
}
