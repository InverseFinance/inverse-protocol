// SPDX-License-Identifier: MIT
pragma solidity ^0.8.3;

import "./IVoteAdapter.sol";

/**
 * @title Fixed rate adapter interface
 * @notice The fixed rate adapter calculates a user's voting power by
 * multiplying the number of tokens they own by a fixed number. This number can
 * only be changed through governance proposals.
 */
interface IFixedRateAdapter is IVoteAdapter {
    /**
     * @dev This should only be callable by the governing contract.
     * @param newWeight The new voting weight for this token.
     */
    function setVotingWeight(uint256 newWeight) external;

    /// @notice Emitted when the voting weight of the associated token is
    /// updated.
    event VotingWeightUpdated(uint256 oldWeight, uint256 newWeight);
}
