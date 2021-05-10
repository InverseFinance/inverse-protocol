// SPDX-License-Identifier: MIT
pragma solidity ^0.8.3;

/**
 * @title Inverse Token vote retrieval interface
 * @dev Used to easily retrieve the vote counts for users on INV and xINV.
 */
interface IInverseToken {
    /**
     * @notice Determine the prior number of votes for an account as of a block
     * number.
     * @dev Block number must be a finalized block or else this function will
     * revert to prevent misinformation.
     * @param account The address of the account to check.
     * @param blockNumber The block number to get the vote balance at.
     * @return The number of votes the account had as of the given block.
     */
    function getPriorVotes(
        address account,
        uint256 blockNumber
    ) external view returns (uint96);
}
