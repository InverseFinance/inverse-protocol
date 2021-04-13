// SPDX-License-Identifier: MIT
pragma solidity ^0.8.3;

/**
 * @title Proposal master interface
 * @notice The proposal master is responsible for all calculations and checks
 * pertaining to state changes of proposals on the main governance system. It's
 * up to the developer whether simple or complex calculations and/or checks are
 * implemented.
 */
interface IProposalMaster {
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
    ) external view returns (bool, uint256, uint256);

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
    ) external view returns (bool);

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
    ) external view returns (bool);

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
    ) external view returns (bool);

    /**
     * @notice Get vote quorum required for proposal to succeed.
     * @param blockNumber The block number to get quorum at.
     * @return The number of votes required for a proposal to succeed.
     */
    function getQuorum(uint256 blockNumber) external view returns (uint256);
}
