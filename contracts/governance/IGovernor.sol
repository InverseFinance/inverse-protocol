// SPDX-License-Identifier: MIT
pragma solidity ^0.8.3;

import "./proposal/IProposalMaster.sol";
import "./vote/IVoteMaster.sol";

/**
 * @title Governor Charlie
 * @custom:experimental This is an unaudited, experimental series of contracts.
 */
interface IGovernor {
    /// <-- Governance ---
    /// @notice Data structure containing proposal metadata.
    /// @dev Its attributes don't have a natspec due to it not being allowed on
    /// struct attributes.
    struct Proposal {
        // Creator of the proposal.
        address proposer;

        // The block at which voting begins: token holders must delegate their
        // votes prior to the block associated with this value.
        uint256 startBlock;

        // The block at which voting ends: votes must be cast prior to this
        // block.
        uint256 endBlock;

        // The timestamp that the proposal will be available for execution, set
        // once the vote succeeds.
        uint256 eta;

        // Flag marking whether the proposal has been canceled.
        bool canceled;

        // Flag marking whether the proposal has been executed.
        bool executed;

        // Current number of votes abstaining from this proposal
        uint256 votesAbstain;

        // Current number of votes in opposition to this proposal
        uint256 votesAgainst;

        // Current number of votes in favor of this proposal
        uint256 votesFor;

        // The hashed value of the ordered list of target addresses, values,
        // function signatures and the associated call data.
        bytes32 hash;
    }

    /// @notice Possible states that a proposal may be in
    enum ProposalState {
        Pending,
        Active,
        Canceled,
        Defeated,
        Succeeded,
        Queued,
        Expired,
        Executed
    }

    /// @notice Types of supported votes.
    enum VoteType {
        Abstain,
        Against,
        For
    }

    /// @notice Emitted when a new proposal is created.
    event ProposalCreated(
        uint256 proposalId,
        address proposer,
        address[] targets,
        uint256[] values,
        string[] signatures,
        bytes[] calldatas,
        uint256 startTimestamp,
        uint256 endTimestamp,
        string description
    );

    /// @notice Emitted when a proposal is canceled.
    event ProposalCanceled(uint256 proposalId);

    /// @notice Emitted when a proposal has succeeded and is is queued.
    event ProposalQueued(uint256 proposalId, uint256 eta);

    /// @notice Emitted when a proposal is executed.
    event ProposalExecuted(uint256 proposalId);

    /// @notice Emitted when an account casts a vote.
    event VoteCast(
        address voter,
        uint256 proposalId,
        VoteType support,
        uint256 votes,
        string reason
    );

    /**
     * @notice Create new proposal. Can only be called by accepted governance
     * contracts.
     * @dev The values pertaining to the contract calls are not stored in this
     * governance contract. Instead, only a hash is stored to preserve gas. At
     * the time of queueing and execution, the exact same call data must be sent
     * for verification purposes.
     * @param targets Array of contract addresses to interact with.
     * @param values Array of ETH values to send along with the contract calls.
     * @param signatures Array of function signatures.
     * @param calldatas Array of bytes-encoded function parameters.
     * @param description Proposal title and description.
     * @return `true` if proposal is accepted, will otherwise revert.
     */
    function propose(
        address[] memory targets,
        uint256[] memory values,
        string[] memory signatures,
        bytes[] memory calldatas,
        string memory description
    ) external returns (bool);

    /**
     * @notice Queue proposal content for execution. Can only be called after a
     * proposal passes.
     * @dev This function must receive the exact same proposal contents as when
     * it was proposed. These values will be verified against the stored hash of
     * those values.
     * @param proposalId Identifier of the proposal to queue.
     * @param targets Array of contract addresses to interact with.
     * @param values Array of ETH values to send along with the contract calls.
     * @param signatures Array of function signatures.
     * @param calldatas Array of bytes-encoded function parameters.
     * @return `true` if proposal is queued, will otherwise revert.
     */
    function queue(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        string[] memory signatures,
        bytes[] memory calldatas
    ) external returns (bool);

    /**
     * @notice Execute proposal content. Can only be called after a proposal
     * has been queued and the queue period has expired.
     * @dev This function must receive the exact same proposal contents as when
     * it was proposed. These values will be verified against the stored hash of
     * those values.
     * @param proposalId Identifier of the proposal to execute.
     * @param targets Array of contract addresses to interact with.
     * @param values Array of ETH values to send along with the contract calls.
     * @param signatures Array of function signatures.
     * @param calldatas Array of bytes-encoded function parameters.
     * @return `true` if proposal is executed, will otherwise revert.
     */
    function execute(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        string[] memory signatures,
        bytes[] memory calldatas
    ) external returns (bool);

    /**
     * @notice Cancel a proposal. Can only be called when a proposal is queued.
     * @dev This function must receive the exact same proposal contents as when
     * it was proposed. These values will be verified against the stored hash of
     * those values.
     * @param proposalId Identifier of the proposal to execute.
     * @param targets Array of contract addresses to interact with.
     * @param values Array of ETH values to send along with the contract calls.
     * @param signatures Array of function signatures.
     * @param calldatas Array of bytes-encoded function parameters.
     * @return `true` if proposal is canceled, will otherwise revert.
     */
    function cancel(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        string[] memory signatures,
        bytes[] memory calldatas
    ) external returns (bool);

    /**
     * @notice Cast vote for given proposal.
     * @param proposalId Identifier of the proposal to cast vote for.
     * @param support The type of vote to cast. The function will revert if an
     * out-of-bounds value is received.
     * @param reason Reason behind the vote. Can be an empty string.
     */
    function castVote(
        uint256 proposalId,
        VoteType support,
        string memory reason
    ) external;

    /**
     * @notice Cast vote by signature
     * @param proposalId Identifier of the proposal to cast vote for.
     * @param support The type of vote to cast. The function will revert if an
     * out-of-bounds value is received.
     * @param reason Reason behind the vote. Can be an empty string.
     * @param v Recovery ID of the transaction signature.
     * @param r "r" output value of the ECDSA signature.
     * @param s "s" output value of the ECDSA signature.
     */
    function castVoteBySig(
        uint256 proposalId,
        VoteType support,
        string memory reason,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    /**
     * @notice Cast votes for multiple proposals.
     * @param proposalIds Array of proposal identifiers to cast vote for.
     * @param support The type of votes to cast. The function will revert if an
     * out-of-bounds value is received.
     * @param reasons Reasoning behind each vote. Can be an array of empty
     * strings.
     */
    function castVotes(
        uint256[] memory proposalIds,
        VoteType[] memory support,
        string[] memory reasons
    ) external;

    function getVotingPower(
        uint256 proposalId,
        address account,
        uint256 blockNumber
    ) external view returns (uint256);

    /**
     * @notice Get state of given proposal.
     * @param proposalId Identifier of the proposal to get the state of.
     * @return State of given proposal.
     */
    function getState(uint256 proposalId) external view returns (ProposalState);
    // --- Governance -->

    // <-- Meta governance ---
    /// @notice Emitted when a new proposal master is set.
    event ProposalMasterUpdated(address oldMaster, address newMaster);

    /// @notice Emitted when a new vote master is set.
    event VoteMasterUpdated(address oldMaster, address newMaster);

    /**
     * @notice Set new proposal master contract.
     * @param newMaster Address of new proposal master.
     */
    function setProposalMaster(address newMaster) external;

    /**
     * @notice Set new vote master contract.
     * @param newMaster Address of new proposal master.
     */
    function setVoteMaster(address newMaster) external;

    /**
     * @notice Set pending timelock.
     * @param newTimelock Address of new timelock contract.
     */
    function setPendingTimelock(address newTimelock) external;

    /**
     * @notice Accept new timelock.
     */
    function acceptTimelock() external;
    // --- Meta governance -->

    // <-- Rescue ---
    /// @notice Emitted when a rescue attempt is made.
    event RescueAttempted(address rescuer);

    /**
     * @notice Attempt to transfer ownership of timelock.
     * @dev This function auto-sets the number of "for" votes for this proposal
     * to 10% of the INV supply. If either of Charlie's proposal or voting
     * systems are irreversibly broken, then the rescue functions can be used to
     * take back ownership of the timelock contract.
     */
    function attemptRescue() external;

    /**
     * @notice Queue rescue proposal transaction
     * @dev This function cannot make use of functions that reside in external
     * contracts, as those contracts and/or functions may be compromised.
     */
    function queueRescue() external;

    /**
     * @notice Execute rescue proposal transaction
     * @dev This function cannot make use of functions that reside in external
     * contracts other than timelock, as those contracts and/or functions may be
     * compromised.
     */
    function executeRescue() external;
    // --- Rescue -->
}
