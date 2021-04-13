// SPDX-License-Identifier: MIT
pragma solidity ^0.8.3;

import "OZ4/access/Ownable.sol";
import "OZ4/utils/structs/EnumerableSet.sol";

import "./IVoteMaster.sol";
import "./adapter/IVoteAdapter.sol";

/**
 * @title Vote master Charlie V1
 * @notice Calculates the number of votes an account is privy to at a certain
 * block number. This simple version sums up the values returned by the vote
 * adapters associated with approved governance tokens.
 */
contract VoteMasterCharlieV1 is IVoteMaster, Ownable {
    using EnumerableSet for EnumerableSet.AddressSet;

    /// @dev The set of all active vote adapters.
    EnumerableSet.AddressSet private adapters;

    /// @notice Emitted when an adapter is added for a governance token.
    event AdapterAdded(address adapter);

    /// @notice Emitted when a token adapter is removed.
    event AdapterRemoved(address adapter);

    /**
     * @param adapters_ Array of vote adapters to initialize vote master with.
     * @param timelock Address of the timelock that owns this vote master.
     */
    constructor(address[] memory adapters_, address timelock) {
        for (uint256 i = 0; i < adapters_.length; i++) {
            adapters.add(adapters_[i]);
        }

        transferOwnership(timelock);
    }

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
    )
        external
        view
        override
        returns (uint256)
    {
        // Called here separately to avoid bytecode and prevent unused variable
        // warning from showing up.
        proposalId;

        uint256 totalVotes = 0;

        for (uint256 i = 0; i < adapters.length(); i++) {
            IVoteAdapter adapter = IVoteAdapter(adapters.at(i));
            totalVotes += adapter.getVotingPower(account, blockNumber);
        }

        return totalVotes;
    }

    /**
     * @notice Get all supported governance tokens.
     * @dev This array may contain duplicates.
     * @return Array of token addresses.
     */
    function getTokens() external view returns (address[] memory) {
        uint256 adapterCount = adapters.length();
        address[] memory tokens = new address[](adapterCount);

        for (uint256 i = 0; i < adapterCount; i++) {
            IVoteAdapter adapter = IVoteAdapter(adapters.at(i));
            tokens[i] = adapter.getToken();
        }

        return tokens;
    }

    /**
     * @notice Add vote adapter contract.
     * @param adapter Address of vote adapter to add.
     */
    function addAdapter(address adapter) external onlyOwner {
        if (adapters.add(adapter)) {
            emit AdapterAdded(adapter);
        }
    }

    /**
     * @notice Remove vote adapter contract.
     * @param adapter Address of vote adapter to remove.
     */
    function removeAdapter(address adapter) external onlyOwner {
        if (adapters.remove(adapter)) {
            emit AdapterRemoved(adapter);
        }
    }

    /**
     * @notice Get all vote adapters associated with a supported token.
     * @return Array of adapter addresses.
     */
    function getAdapters() external view returns (address[] memory) {
        uint256 adapterCount = adapters.length();
        address[] memory adapterArray = new address[](adapterCount);

        for (uint256 i = 0; i < adapterCount; i++) {
            adapterArray[i] = adapters.at(i);
        }

        return adapterArray;
    }

}
