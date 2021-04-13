// SPDX-License-Identifier: MIT
pragma solidity ^0.8.3;

import "OZ4/access/Ownable.sol";
import "OZ4/token/ERC20/IERC20.sol";
import "OZ4/token/ERC20/utils/SafeERC20.sol";
import "OZ4/utils/structs/EnumerableSet.sol";

import "./IGovernor.sol";
import "./ITimelock.sol";
import "./proposal/IProposalMaster.sol";
import "./vote/IVoteMaster.sol";

/**
 * @title Governor Charlie
 * @custom:experimental This is an unaudited, experimental series of contracts.
 */
contract GovernorCharlie is Ownable, IGovernor {
    using EnumerableSet for EnumerableSet.AddressSet;
    using SafeERC20 for IERC20;

    /// @notice The name of this contract
    string public constant name = "Inverse Governor Charlie";

    /**
     * @param timelock_ The timelock address and owner of this contract.
     * @param rescueAddress_ Address to transfer ownership to in the event of a
     * emergency rescue attempt of the timelock contract.
     * @param rescueStakingToken_ Address of the token used to initiate an
     * emergency rescue attempt of the timelock contract.
     * @param rescueStakingAmount_ The number of tokens required to initiate an
     * emergency rescue attempt.
     */
    constructor(
        ITimelock timelock_,
        address rescueAddress_,
        IERC20 rescueStakingToken_,
        uint256 rescueStakingAmount_
    ) {
        timelock = timelock_;
        rescueAddress = rescueAddress_;
        rescueStakingToken = rescueStakingToken_;
        rescueStakingAmount = rescueStakingAmount_;

        transferOwnership(address(timelock_));
    }

    /// <-- [Governance] ---
    /// @notice The EIP-712 typehash for the contract's domain
    bytes32 public constant DOMAIN_TYPEHASH = keccak256("EIP712Domain(string name,uint256 chainId,address verifyingContract)");

    /// @notice The EIP-712 typehash for the ballot struct used by the contract
    bytes32 public constant BALLOT_TYPEHASH = keccak256("Ballot(uint256 proposalId,uint8 support,string reason)");

    /// @notice The registry of all proposals.
    mapping (uint256 => Proposal) public proposals;

    /// @notice The registry of proposals made per account.
    mapping (address => uint256[]) public proposalsByUser;

    /// @notice Mapping that tracks which addresses already voted for proposals.
    /// @dev Hashed using "keccak256(voterAddress, proposalId)".
    mapping (bytes32 => bool) public alreadyVoted;

    /// @notice The number of proposals.
    uint256 public proposalCount;

    /// @notice The contract responsible for determining the validity of an
    /// address's actions (e.g. creating, executing, cancelling etc.) pertaining
    /// to proposals.
    IProposalMaster public proposalMaster;

    /// @notice The contract responsible for determining the number of votes an
    /// account has at any given block number.
    IVoteMaster public voteMaster;

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
    )
        external
        override
        returns (bool)
    {
        uint256 startBlock;
        uint256 endBlock;
        // The proposer's eligibility to create a new proposal is checked by a
        // proposal master contract.
        {
            bool canPropose;
            (canPropose, startBlock, endBlock) =
                proposalMaster.canPropose(
                    msg.sender,
                    block.number,
                    targets,
                    values,
                    signatures,
                    calldatas
                );

            require(canPropose, "GovernorCharlie::propose: Ineligible to propose");
        }

        // To prevent storage of needless amounts of data, only a hash of the
        // function call data is stored.
        bytes32 contentHash = _hash(targets, values, signatures, calldatas);

        // The proposal counter is incremented before a new proposal is stored
        // to ensure that the number of proposals is correct before and after
        // creation.
        proposals[++proposalCount] = Proposal({
            proposer: msg.sender,
            startBlock: startBlock,
            endBlock: endBlock,
            eta: 0,
            canceled: false,
            executed: false,
            votesAbstain: 0,
            votesAgainst: 0,
            votesFor: 0,
            hash: contentHash
        });
        proposalsByUser[msg.sender].push(proposalCount);

        emit ProposalCreated(
            proposalCount,
            msg.sender,
            targets,
            values,
            signatures,
            calldatas,
            startBlock,
            endBlock,
            description
        );

        return true;
    }

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
    )
        external
        override
        returns (bool)
    {
        require(
            proposalMaster.canQueue(
                msg.sender,
                block.number - 1,
                proposalId,
                targets,
                values,
                signatures,
                calldatas
            ),
            "GovernorCharlie::queue: Unauthorized to queue"
        );

        Proposal storage proposal = proposals[proposalId];
        bytes32 contentHash = _hash(targets, values, signatures, calldatas);
        require(
            contentHash == proposal.hash,
            "GovernorCharlie::queue: Mismatching function call data"
        );

        uint256 eta = block.timestamp + timelock.delay();

        for (uint256 i = 0; i < targets.length; i++) {
            timelock.queueTransaction(
                targets[i],
                values[i],
                signatures[i],
                calldatas[i],
                eta
            );
        }

        proposal.eta = eta;
        emit ProposalQueued(proposalId, eta);

        return true;
    }

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
    )
        external
        override
        returns (bool)
    {
        require(
            proposalMaster.canExecute(
                msg.sender,
                block.number - 1,
                proposalId,
                targets,
                values,
                signatures,
                calldatas
            ),
            "GovernorCharlie::execute: Unauthorized to execute"
        );

        Proposal storage proposal = proposals[proposalId];
        bytes32 contentHash = _hash(targets, values, signatures, calldatas);
        require(
            contentHash == proposal.hash,
            "GovernorCharlie::execute: Mismatching function call data"
        );

        for (uint256 i = 0; i < targets.length; i++) {
            timelock.executeTransaction(
                targets[i],
                values[i],
                signatures[i],
                calldatas[i],
                proposal.eta
            );
        }

        proposal.executed = true;
        emit ProposalExecuted(proposalId);

        return true;
    }

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
    )
        external
        override
        returns (bool)
    {
        require(
            proposalMaster.canCancel(
                msg.sender,
                block.number - 1,
                proposalId,
                targets,
                values,
                signatures,
                calldatas
            ),
            "GovernorCharlie::queue: Unauthorized to cancel"
        );

        Proposal storage proposal = proposals[proposalId];
        bytes32 contentHash = _hash(targets, values, signatures, calldatas);
        require(
            contentHash == proposal.hash,
            "GovernorCharlie::queue: Mismatching function call data"
        );

        for (uint256 i = 0; i < targets.length; i++) {
            timelock.cancelTransaction(
                targets[i],
                values[i],
                signatures[i],
                calldatas[i],
                proposal.eta
            );
        }

        proposal.canceled = true;
        emit ProposalCanceled(proposalId);

        return true;
    }

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
    )
        external
        override
    {
        _castVote(msg.sender, proposalId, support, reason);
    }

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
    )
        external
        override
    {
        bytes32 domainSeparator = keccak256(
            abi.encode(
                DOMAIN_TYPEHASH,
                keccak256(bytes(name)),
                block.chainid,
                address(this)
            )
        );
        bytes32 structHash = keccak256(
            abi.encode(
                BALLOT_TYPEHASH,
                proposalId,
                support
            )
        );
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                domainSeparator,
                structHash
            )
        );

        address signatory = ecrecover(digest, v, r, s);

        require(
            signatory != address(0),
            "GovernorCharlie::castVoteBySig: invalid signature"
        );

        return _castVote(signatory, proposalId, support, reason);
    }

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
    )
        external
        override
    {
        require(
            proposalIds.length == support.length
            && support.length == reasons.length,
            "GovernorCharlie::castVotes: mismatched array lengths"
        );

        for (uint256 i = 0; i < proposalIds.length; i++) {
            _castVote(
                msg.sender,
                proposalIds[i],
                support[i],
                reasons[i]
            );
        }
    }

    /**
     * @notice Cast votes for given proposal.
     * @param voter The account casting their vote(s).
     * @param proposalId Identifier of the proposal to cast vote for.
     * @param support The type of vote to cast. The function will revert if an
     * out-of-bounds value is received.
     * @param reason Reason behind the vote. Can be an empty string.
     */
    function _castVote(
        address voter,
        uint256 proposalId,
        VoteType support,
        string memory reason
    )
        internal
    {
        Proposal storage proposal = proposals[proposalId];

        require(
            proposal.startBlock <= block.timestamp
            && block.number <= proposal.endBlock,
            "GovernorCharlie::_castVote: Voting inactive"
        );

        uint256 votingPower = getVotingPower(
            proposalId,
            voter,
            proposal.startBlock
        );

        require(
            votingPower > 0,
            "GovernorCharlie::_castVote: Voting power must be above 0"
        );

        // Hash to prevent storage of multiple values.
        bytes32 voteHash = keccak256(abi.encode(proposalId, voter));

        require(
            !alreadyVoted[voteHash],
            "GovernorCharlie::_castVote: Already voted"
        );

        if (support == VoteType.Abstain) {
            proposal.votesAbstain += votingPower;
        } else if (support == VoteType.Against) {
            proposal.votesAbstain += votingPower;
        } else {
            proposal.votesFor += votingPower;
        }

        alreadyVoted[voteHash] = true;

        emit VoteCast(voter, proposalId, support, votingPower, reason);
    }

    function getVotingPower(
        uint256 proposalId,
        address account,
        uint256 blockNumber
    )
        public
        view
        override
        returns (uint256)
    {
        return voteMaster.getVotingPower(proposalId, account, blockNumber);
    }

    /**
     * @notice Get state of given proposal.
     * @param proposalId Identifier of the proposal to get the state of.
     * @return State of given proposal.
     */
    function getState(
        uint256 proposalId
    )
        public
        view
        override
        returns (ProposalState)
    {
        require(
            proposalCount >= proposalId && proposalId > 0,
            "GovernorCharlie::getState: invalid proposal id"
        );

        Proposal memory proposal = proposals[proposalId];

        if (proposal.canceled) {
            return ProposalState.Canceled;
        } else if (block.number <= proposal.startBlock) {
            return ProposalState.Pending;
        } else if (block.number <= proposal.endBlock) {
            return ProposalState.Active;
        } else if (proposal.votesFor <= proposal.votesAgainst) {
            return ProposalState.Defeated;
        }

        uint256 totalVotes =
            proposal.votesAbstain + proposal.votesAgainst + proposal.votesFor;
        if (totalVotes < proposalMaster.getQuorum(proposal.startBlock)) {
            return ProposalState.Defeated;
        } else if (proposal.eta == 0) {
            return ProposalState.Succeeded;
        } else if (proposal.executed) {
            return ProposalState.Executed;
        } else if (block.timestamp >= proposal.eta + timelock.GRACE_PERIOD()) {
            return ProposalState.Expired;
        } else {
            return ProposalState.Queued;
        }
    }

    /**
     * @notice Generate hash of function call data.
     * @param targets Array of contract addresses to interact with.
     * @param values Array of ETH values to send along with the contract calls.
     * @param signatures Array of function signatures.
     * @param calldatas Array of bytes-encoded function parameters.
     * @return bytes32-encoded hash of given parameters.
     */
    function _hash(
        address[] memory targets,
        uint256[] memory values,
        string[] memory signatures,
        bytes[] memory calldatas
    )
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(targets, values, signatures, calldatas));
    }
    // --- Governance -->

    // <-- Meta governance ---
    /// @notice The active timelock (and owner) of the governance master.
    ITimelock public timelock;

    /// @notice The new owner, pending an acceptance call.
    address public pendingTimelock;

    /**
     * @notice Set new proposal master contract.
     * @param newMaster Address of new proposal master.
     */
    function setProposalMaster(address newMaster) external override onlyOwner {
        require(
            newMaster != address(0) && newMaster != address(proposalMaster),
            "GovernorCharlie::setProposalMaster: Invalid address"
        );

        emit ProposalMasterUpdated(address(proposalMaster), newMaster);

        proposalMaster = IProposalMaster(newMaster);
    }

    /**
     * @notice Set new vote master contract.
     * @param newMaster Address of new proposal master.
     */
    function setVoteMaster(address newMaster) external override onlyOwner {
        require(
            newMaster != address(0) && newMaster != address(voteMaster),
            "GovernorCharlie::setVoteMaster: Invalid address"
        );

        emit VoteMasterUpdated(address(voteMaster), newMaster);

        voteMaster = IVoteMaster(newMaster);
    }

    /**
     * @notice Set pending timelock.
     * @param newTimelock Address of new timelock contract.
     */
    function setPendingTimelock(
        address newTimelock
    )
        external
        override
        onlyOwner
    {
        pendingTimelock = newTimelock;
    }

    /**
     * @notice Accept new timelock.
     */
    function acceptTimelock() external override {
        require(
            msg.sender == pendingTimelock,
            "GovernorCharlie::acceptTimelock: Must be pending timelock"
        );
        timelock = ITimelock(pendingTimelock);
        transferOwnership(pendingTimelock);

        // Ownership is transferred. Reset pending timelock to zero address.
        pendingTimelock = address(0);
    }
    // --- Meta governance -->

    // <-- Rescue ---
    /// @notice Address to swap timelock owner with in rescue attempt. It is
    /// recommended to set this to a proven governance contract.
    address public immutable rescueAddress;

    /// @notice Token to use for rescue purposes. Users of this contract are
    /// recommended to set this to their main governance if available.
    IERC20 public immutable rescueStakingToken;

    /// @notice The number of rescue tokens to temporarily stake for rescue
    /// purposes.
    uint256 public immutable rescueStakingAmount;

    /// @notice The minimum number of days required between rescue attempts.
    uint256 public constant rescueResetPeriod = 30 days;

    /// @notice Timestamp of the last rescue attempt.
    uint256 public lastRescueAttempt;

    /// @notice Identifier of the last rescue proposal.
    uint256 public rescueProposalId;

    /**
     * @notice Attempt to transfer ownership of timelock.
     * @dev This function auto-sets the number of "for" votes for this proposal
     * to 10% of the INV supply. If either of Charlie's proposal or voting
     * systems are irreversibly broken, then the rescue functions can be used to
     * take back ownership of the timelock contract.
     */
    function attemptRescue() external override {
        require(
            lastRescueAttempt + rescueResetPeriod < block.timestamp,
            "GovernorCharlie::rescue: Too soon"
        );
        rescueStakingToken.safeTransferFrom(
            msg.sender,
            address(this),
            rescueStakingAmount
        );

        lastRescueAttempt = block.timestamp;

        // Create rescue proposal with hard-coded parameters.
        uint256 startBlock = block.timestamp + 1;
        uint256 endBlock = startBlock + 17280;

        // Initialize dynamically-sized arrays due to restriction in Solidity
        // not allowing statically-sized arrays to be passed into functions that
        // expect a dynamically-sized array.
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        string[] memory signatures = new string[](1);
        bytes[] memory data = new bytes[](1);
        targets[0] = address(timelock);
        values[0] = 0;
        signatures[0] = "setPendingAdmin(address)";
        data[0] = abi.encodePacked(rescueAddress);

        proposals[++proposalCount] = Proposal({
            proposer: msg.sender,
            startBlock: startBlock,
            endBlock: endBlock,
            eta: 0,
            canceled: false,
            executed: false,
            votesAbstain: 0,
            votesAgainst: 0,
            votesFor: 10000e18,
            hash: _hash(targets, values, signatures, data)
        });
        rescueProposalId = proposalCount;

        rescueStakingToken.safeTransfer(msg.sender, rescueStakingAmount);

        emit ProposalCreated(
            proposalCount,
            msg.sender,
            targets,
            values,
            signatures,
            data,
            startBlock,
            endBlock,
            "#Rescue Attempt"
        );
        emit RescueAttempted(msg.sender);
    }
    /**
     * @notice Queue rescue proposal transaction
     * @dev This function cannot make use of functions that reside in external
     * contracts, as those contracts and/or functions may be compromised.
     */
    function queueRescue() external override {
        Proposal storage proposal = proposals[rescueProposalId];

        // Only check that the voting period has expired and that the number of
        // "for" votes are  outnumbered by "against" votes. There is no quorum
        // for a rescue vote as that would require interacting with a contract
        // that could be compromised.
        require(
            block.timestamp > proposal.endBlock &&
            proposal.votesFor > proposal.votesAgainst,
            "GovernorCharlie::queueRescue: Proposal not succeeded"
        );

        uint256 eta = block.timestamp + timelock.delay();

        timelock.queueTransaction(
            address(timelock),
            0,
            "setPendingAdmin(address)",
            abi.encodePacked(rescueAddress),
            eta
        );

        proposal.eta = eta;
        emit ProposalQueued(rescueProposalId, eta);
    }

    /**
     * @notice Execute rescue proposal transaction
     * @dev This function cannot make use of functions that reside in external
     * contracts other than timelock, as those contracts and/or functions may be
     * compromised.
     */
    function executeRescue() external override {
        Proposal storage proposal = proposals[rescueProposalId];

        // If the rescue transaction was successfully queued on the timelock
        // contract, that means rescue is a go.
        require(
            timelock.queuedTransactions(
                keccak256(
                    abi.encode(
                        address(timelock),
                        0,
                        "setPendingAdmin(address)",
                        abi.encodePacked(rescueAddress),
                        proposal.eta
                    )
                )
            ),
            "GovernorCharlie::executeRescue: Proposal not queued"
        );

        timelock.executeTransaction(
            address(timelock),
            0,
            "setPendingAdmin(address)",
            abi.encodePacked(rescueAddress),
            proposal.eta
        );

        proposal.executed = true;

        emit ProposalExecuted(rescueProposalId);
    }
    // --- Rescue -->
}
