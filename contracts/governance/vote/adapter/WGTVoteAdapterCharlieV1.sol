// SPDX-License-Identifier: MIT
pragma solidity ^0.8.3;

import "OZ4/access/Ownable.sol";

import "./IFixedRateAdapter.sol";
import "../../token/IWrappedGovernanceToken.sol";

/**
 * @title WGT vote adapter CharlieV1 version
 * @notice This CharlieV1 version calculates the number of votes by getting a
 * user's balance of the associated wrapped governance token and multiplying
 * that number by a fixed weight.
 */
contract WGTVoteAdapterCharlieV1 is IFixedRateAdapter, Ownable {
    /// @notice Address of the WGT.
    IWrappedGovernanceToken public token;

    /// @notice The voting weight associated with the WGT.
    uint256 public weight;

    /**
     * @param token_ Address of the associated WGT.
     * @param weight_ Initial weight associated with the token.
     */
    constructor(IWrappedGovernanceToken token_, uint256 weight_) Ownable() {
        token = token_;
        weight = weight_;
    }

    /**
     * @return Address of the token associated with this adapter.
     */
    function getToken() external view override returns (address) {
        return address(token);
    }

    /**
     * @param account The account of which to return the voting power.
     * @param blockNumber The latest block number that is counted.
     * @return The voting power of `account` at block `blockNumber`.
     */
    function getVotingPower(
        address account,
        uint256 blockNumber
    )
        external
        view
        override
        returns (uint256)
    {
        return token.getPriorVotes(account, blockNumber) * weight;
    }

    /**
     * @notice Update the voting weight associated with the WGT.
     * @param newWeight The new voting weight for this token.
     */
    function setVotingWeight(uint256 newWeight) external override onlyOwner {
        emit VotingWeightUpdated(weight, newWeight);

        weight = newWeight;
    }
}
