// SPDX-License-Identifier: MIT
pragma solidity ^0.8.3;

/**
 * @title Vote master interface
 * @dev It's up to the developer how to implement the specifics of the vote
 * master. It is able to set up connections to other contracts, including the
 * governance contract to read specific proposal data.
 */
interface IVoteMaster {
    /**
     * @notice Get voting power of an account at a given block for a proposal.
     * @param proposalId Identifier of the proposal to vote for.
     * @param account Account to get total voting number of.
     * @param blockNumber Block number at which to get voting power.
     * @return The total voting power of `account` at block `blockNumber`.
     */
    function getVotingPower(
        uint256 proposalId,
        address account,
        uint256 blockNumber
    ) external view returns (uint256);
}
