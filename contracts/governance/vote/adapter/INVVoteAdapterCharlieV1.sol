// SPDX-License-Identifier: MIT
pragma solidity ^0.8.3;

import "OZ4/access/Ownable.sol";

import "./IFixedRateAdapter.sol";
import "../../token/IInverseToken.sol";

/**
 * @title Inverse vote adapter CharlieV1 version
 * @notice This CharlieV1 version calculates the number of votes by getting a
 * user's balance and multiplying that number by a fixed weight.
 */
contract INVVoteAdapterCharlieV1 is IFixedRateAdapter, Ownable {
    /// @notice Address of the `INV` or `xINV` token.
    IInverseToken public token;

    /// @notice The voting weight associated with one `INV` or `xINV` token.
    uint256 public weight;

    /**
     * @param token_ Address of the associated Inverse token.
     * @param weight_ Initial weight associated with the token.
     */
    constructor(IInverseToken token_, uint256 weight_) Ownable() {
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
     * @dev The Inverse tokens return the number of votes as a `uint96` value,
     * hence the need for a `uint256` cast.
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
        return uint256(token.getPriorVotes(account, blockNumber)) * weight;
    }

    /**
     * @notice Update the voting weight associated with the `INV`/`xINV` token.
     * @param newWeight The new voting weight for this token.
     */
    function setVotingWeight(uint256 newWeight) external override onlyOwner {
        emit VotingWeightUpdated(weight, newWeight);

        weight = newWeight;
    }
}
