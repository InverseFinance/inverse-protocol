// SPDX-License-Identifier: MIT
pragma solidity ^0.8.3;

import "OZ4/access/Ownable.sol";
import "OZ4/token/ERC20/IERC20.sol";
import "OZ4/token/ERC20/utils/SafeERC20.sol";

/**
 * @title User Proxy
 * @notice Acts as proxy for users that interact with a WrapperGovernanceToken
 * contract.
 * @dev This contract does no validity checks on function signatures. This is
 * expected of DAO members before and during the proposal that allowed the
 * function to be added to the related WrappedGovernanceToken contract.
 */
contract UserProxy is Ownable {
    using SafeERC20 for IERC20;

    /**
     * @notice Withdraw token from this contract.
     */
    function withdrawToken(
        IERC20 token
    )
        external
        onlyOwner
        returns (uint256)
    {
        uint256 tokenBalance = token.balanceOf(address(this));

        token.safeTransfer(owner(), tokenBalance);

        return tokenBalance;
    }

    /**
     * @notice Call function on external contract
     * @param target Address of the external contract.
     * @param callData Data to send with the call.
     * @param token Address of the token to approve for use by the external
     * contract.
     * @param amount The number of tokens the external contract should be
     * approved for.
     */
    function callFunction(
        address target,
        bytes memory callData,
        IERC20 token,
        uint256 amount
    )
        external
        onlyOwner
    {
        if (amount > 0) {
            token.approve(target, amount);
        }

        (bool success, bytes memory returnData) = target.call(callData);

        // Silence warnings about unused variables.
        returnData;

        require(
            success,
            "UserProxy::callFunction: Transaction execution reverted"
        );
    }
}
