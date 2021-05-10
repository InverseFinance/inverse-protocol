// SPDX-License-Identifier: MIT
pragma solidity ^0.8.3;

import "OZ4/access/Ownable.sol";
import "OZ4/token/ERC20/IERC20.sol";
import "OZ4/token/ERC20/utils/SafeERC20.sol";
import "OZ4/utils/structs/EnumerableSet.sol";

import "./IProposalMaster.sol";
import "../IGovernor.sol";

/**
 * @title Proposal master Charlie V1
 * @notice Calculates a predefined (but mutable) percentage of circulating
 * governance tokens and sets that number as proposal threshold. This adapter
 * also supports a list of addresses of which the token balances should not be
 * counted, e.g. burn addresses and treasuries.
 */
contract ProposalMasterCharlieV1 is IProposalMaster, Ownable {
    using EnumerableSet for EnumerableSet.AddressSet;
    using SafeERC20 for IERC20;

    /// @notice The governance master contract to retrieve metadata regarding
    /// other governance aspects such as voting power.
    IGovernor public immutable governance;

    /// @dev The set of tokens used for governance purposes.
    EnumerableSet.AddressSet private tokens;

    mapping (address => EnumerableSet.AddressSet) private tokensByGovernance;

    /// @dev The registry of addresses to exclude for the purpose of counting
    /// actual votes. Examples can be burn addresses and treasuries.
    mapping (address => EnumerableSet.AddressSet) private excluded;

    /// @notice The percentage of circulating tokens to use as threshold for
    /// proposal creation eligibility.
    uint256 public proposalPercentage;

    /// @notice The percentage of circulating tokens to use as threshold for
    /// required quorum to pass a proposal.
    uint256 public quorumPercentage;

    /// @notice The period (expressed in blocks) before voting goes live for a
    /// given proposal.
    uint256 public proposalDelay;

    /// @notice The period (expressed in blocks) in which voters are able to
    /// cast a vote for a given proposal.
    uint256 public proposalVotingPeriod;

    /// @notice Emitted when the proposal threshold percentage is updated.
    event ProposalPercentageUpdated(
        uint256 oldPercentage,
        uint256 newPercentage
    );

    /// @notice Emitted when the quorum threshold percentage is updated.
    event QuorumPercentageUpdated(
        uint256 oldPercentage,
        uint256 newPercentage
    );

    /// @notice Emitted when a new governance token is added.
    event TokenAdded(address token);

    /// @notice Emitted when a governance token is removed.
    event TokenRemoved(address token);

    /// @notice Emitted when an account's balance is excluded from being counted
    /// towards a token's total supply.
    event ExclusionAccountAdded(address token, address account);

    /// @notice Emitted when an account's balance is no longer excluded from
    /// being counted towards a token's total supply.
    event ExclusionAccountRemoved(address token, address account);

    /**
     * @param tokens_ The initial list of governance tokens to support.
     * @param timelock The timelock address associated with governance.
     * @param governance_ The master governance contract address.
     * @param initialProposalPercentage The percentage to use as threshold for
     * checking proposal creation eligibility.
     * @param initialQuorumPercentage The percentage to use for calculating the
     * required quorum for passing a proposal.
     */
    constructor(
        address[] memory tokens_,
        address timelock,
        address governance_,
        uint256 initialProposalPercentage,
        uint256 initialQuorumPercentage
    ) {
        for (uint256 i = 0; i < tokens_.length; i++) {
            addToken(tokens_[i]);
        }

        governance = IGovernor(governance_);
        updateProposalPercentage(initialProposalPercentage);
        updateQuorumPercentage(initialQuorumPercentage);
        transferOwnership(timelock);
    }

    /**
     * @notice Update the percentage value used to calculate the voting power
     * required to create a new proposal.
     * @param percentage The new percentage to use.
     */
    function updateProposalPercentage(uint256 percentage) public onlyOwner {
        require(
            percentage <= 100,
            "ProposalMasterCharlieV1::updateProposalPercentage: Invalid percentage"
        );

        require(
            percentage != proposalPercentage,
            "ProposalMasterCharlieV1::updateProposalPercentage: Value is already in use"
        );

        uint256 oldPercentage = proposalPercentage;
        proposalPercentage = percentage;

        emit ProposalPercentageUpdated(oldPercentage, percentage);
    }

    /**
     * @notice Update the percentage value used to calculate the number of votes
     * required to reach quorum.
     * @param percentage The new percentage to use.
     */
    function updateQuorumPercentage(uint256 percentage) public onlyOwner {
        require(
            percentage <= 100,
            "ProposalMasterCharlieV1::updateQuorumPercentage: Invalid percentage"
        );

        require(
            percentage != quorumPercentage,
            "ProposalMasterCharlieV1::updateQuorumPercentage: Value is already in use"
        );

        uint256 oldPercentage = quorumPercentage;
        quorumPercentage = percentage;

        emit QuorumPercentageUpdated(oldPercentage, percentage);
    }

    /**
     * @notice Add governance token to proposal master.
     * @param token Address of governance token to add.
     */
    function addToken(address token) public onlyOwner {
        if (tokens.add(token)) {
            emit TokenAdded(token);
        }
    }

    /**
     * @notice Remove governance token from proposal master.
     * @param token Address of governance token to remove.
     */
    function removeToken(address token) external onlyOwner {
        if (tokens.remove(token)) {
            emit TokenRemoved(token);
        }
    }

    /**
     * @notice Get all supported governance tokens.
     * @return Array of token addresses.
     */
    function getTokens() external view returns (address[] memory) {
        uint256 tokenCount = tokens.length();
        address[] memory allTokens = new address[](tokenCount);

        for (uint256 i = 0; i < tokenCount; i++) {
            allTokens[i] = tokens.at(i);
        }

        return allTokens;
    }

    /**
     * @notice Add account to excluded addresses list of given token.
     * @dev This function succeeds silently if the address was already excluded.
     * @param token The token of which `account`'s balance will be excluded.
     * @param account The address that will be excluded from counting.
     */
    function addExcludedAccount(
        address token,
        address account
    )
        external
        onlyOwner
    {
        if (excluded[token].add(account)) {
            emit ExclusionAccountAdded(token, account);
        }
    }

    /**
     * @notice Remove account from excluded addresses list of given token.
     * @dev This function succeeds silently if the address wasn't on the list.
     * @param token The token of which `account`'s balance will be re-included.
     * @param account The address that will be re-included to counting.
     */
    function removeExcludedAccount(
        address token,
        address account
    )
        external
        onlyOwner
    {
        if (excluded[token].remove(account)) {
            emit ExclusionAccountRemoved(token, account);
        }
    }

    /**
     * @notice Check whether `account` is able to create a new proposal at block
     * `blockNumber` for given proposal parameters.
     * @param account Account to check eligibility of.
     * @param blockNumber Block number to check eligibility for.
     * @param targets Array of contract addresses to interact with.
     * @param values Array of ETH values to send along with the contract calls.
     * @param signatures Array of function signatures.
     * @param calldatas Array of bytes-encoded function parameters.
     * @return A 3-tuple containing the account's eligibility, as well as the
     * start and end blocks determining the voting period.
     */
    function canPropose(
        address account,
        uint256 blockNumber,
        address[] memory targets,
        uint256[] memory values,
        string[] memory signatures,
        bytes[] memory calldatas
    )
        external
        view
        override
        returns (bool, uint256, uint256)
    {
        require(
            targets.length == values.length
            && targets.length == signatures.length
            && targets.length == calldatas.length,
            "ProposalMasterCharlie::canPropose: mismatched array lengths"
        );

        uint256 votingPower = governance.getVotingPower(
            0,
            account,
            blockNumber
        );
        uint256 startBlock = block.number + proposalDelay;
        uint256 endBlock = startBlock + proposalVotingPeriod;

        return (
            votingPower <= getThreshold(account, blockNumber),
            startBlock,
            endBlock
        );
    }

    /**
     * @notice Check whether `account` is able to queue given proposal at block
     * `blockNumber` for given proposal parameters.
     * @param account Account to check eligibility of.
     * @param blockNumber Block number to check eligibility for.
     * @param proposalId Identifier of proposal to queue.
     * @param targets Array of contract addresses to interact with.
     * @param values Array of ETH values to send along with the contract calls.
     * @param signatures Array of function signatures.
     * @param calldatas Array of bytes-encoded function parameters.
     * @return `true` if eligible, `false` otherwise.
     */
    function canQueue(
        address account,
        uint256 blockNumber,
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        string[] memory signatures,
        bytes[] memory calldatas
    )
        external
        pure
        override
        returns (bool)
    {
        // Ignore all given parameters in this simple threshold adapter. Calling
        // the values here results in no extra bytecode, while silencing the
        // warning regarding unused variables.
        account; blockNumber; proposalId; targets; values; signatures; calldatas;

        return true;
    }

    /**
     * @notice Check whether `account` is able to execute given proposal at
     * block `blockNumber` for given proposal parameters.
     * @param account Account to check eligibility of.
     * @param proposalId Identifier of proposal to execute.
     * @param blockNumber Block number to check eligibility for.
     * @param targets Array of contract addresses to interact with.
     * @param values Array of ETH values to send along with the contract calls.
     * @param signatures Array of function signatures.
     * @param calldatas Array of bytes-encoded function parameters.
     * @return `true` if eligible, `false` otherwise.
     */
    function canExecute(
        address account,
        uint256 blockNumber,
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        string[] memory signatures,
        bytes[] memory calldatas
    )
        external
        pure
        override
        returns (bool)
    {
        // Ignore all given parameters in this simple threshold adapter. Calling
        // the values here results in no extra bytecode, while silencing the
        // warning regarding unused variables.
        account; blockNumber; proposalId; targets; values; signatures; calldatas;

        return true;
    }

    /**
     * @notice Check whether `account` is able to cancel given proposal at block
     * `blockNumber` for given proposal parameters.
     * @param account Account to check eligibility of.
     * @param proposalId Identifier of proposal to cancel.
     * @param blockNumber Block number to check eligibility for.
     * @param targets Array of contract addresses to interact with.
     * @param values Array of ETH values to send along with the contract calls.
     * @param signatures Array of function signatures.
     * @param calldatas Array of bytes-encoded function parameters.
     * @return `true` if eligible, `false` otherwise.
     */
    function canCancel(
        address account,
        uint256 blockNumber,
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        string[] memory signatures,
        bytes[] memory calldatas
    )
        external
        pure
        override
        returns (bool)
    {
        // Ignore all given parameters in this simple threshold adapter. Calling
        // the values here results in no extra bytecode, while silencing the
        // warning regarding unused variables.
        account; blockNumber; proposalId; targets; values; signatures; calldatas;

        // This implementation allows no cancellations.
        return false;
    }

    /**
     * @notice Get vote quorum required for proposal to succeed.
     * @param blockNumber The block number to get quorum at.
     * @return The number of votes required for a proposal to succeed.
     */
    function getQuorum(
        uint256 blockNumber
    )
        external
        view
        override
        returns (uint256)
    {
        return 4 * getThreshold(address(0), blockNumber);
    }

    /**
     * @notice Get proposal threshold by calculating the sum of x percentage of
     * circulating governance tokens minus excluded addresses.
     * @param account The account that wants to create a new proposal.
     * @param blockNumber The block number to use for timestamping purposes.
     * @return The total voting power required to create a new proposal.
     */
    function getThreshold(
        address account,
        uint256 blockNumber
    )
        public
        view
        returns (uint256)
    {
        // Ignore all given parameters in this simple threshold adapter. Calling
        // the values here results in no extra bytecode, while silencing the
        // warning regarding unused variables.
        account; blockNumber;

        return _getTotalTokenSupply() * proposalPercentage / 100;
    }

    /**
     * @notice Get sum of total supply of all associated tokens.
     */
    function _getTotalTokenSupply() internal view returns (uint256) {
        uint256 supply = 0;

        for (uint256 i = 0; i < tokens.length(); i++) {
            IERC20 token = IERC20(tokens.at(i));

            supply += token.totalSupply();

            // Remove balances of excluded addresses.
            for (uint256 j = 0; j < excluded[address(token)].length(); j++) {
                address excludedAddress = excluded[address(token)].at(j);

                // This cannot underflow due to the `totalSupply` of the token
                // already being added.
                supply -= token.balanceOf(excludedAddress);
            }
        }

        return supply;
    }
}
