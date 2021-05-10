// SPDX-License-Identifier: MIT
pragma solidity ^0.8.3;

/**
 * @title Vote adapter interface
 */
interface IVoteAdapter {
    /**
     * @return Address of the token associated with this adapter.
     */
    function getToken() external view returns (address);

    /**
     * @param account The account of which to return the voting power.
     * @param blockNumber The latest block number that is counted.
     * @return The voting power of `account` at block `blockNumber`.
     */
    function getVotingPower(
        address account,
        uint256 blockNumber
    ) external view returns (uint256);
}
