// SPDX-License-Identifier: MIT
pragma solidity ^0.8.3;

import "OZ4/token/ERC20/IERC20.sol";

/**
 * @title Wrapped governance token interface
 * @notice Wraps an ERC20 token to be used for governance actions.
 * @dev This interface has no defined transfer functions, i.e. wrapped
 * governance tokens are non-transferable. Wrapped governance tokens get minted
 * when the underlying token is deposited, and burned when that token is
 * retrieved. This is not necessarily required, but transfers add a large amount
 * of complexity to the process due to the relationship between the wrapped
 * governance token contract, its `UserProxy` instances, and their interaction
 * with external contracts.
 */
interface IWrappedGovernanceToken {

    /// @notice Data structure to keep track of a holder's balance at a certain
    /// block number.
    struct Checkpoint {
        uint256 fromBlock;
        uint256 votes;
    }

    /**
     * @return The number of decimals the token uses.
     */
    function decimals() external view returns (uint8);

    /**
     * @notice Deposit governance tokens.
     * @param amount Number of governance tokens to deposit.
     */
    function deposit(uint256 amount) external;

    /**
     * @notice Withdraw governance tokens.
     * @param amount Number of governance tokens to withdraw
     */
    function withdraw(uint256 amount) external;

    /**
     * @param account Address of account to get available balance of.
     * @return The number of underlying tokens available to utilize.
     */
    function availableBalanceOf(
        address account
    ) external view returns (uint256);

    /**
     * @notice Delegate votes to an account.
     * @dev If users want to vote themselves, they have to delegate to their own
     * address first.
     * @param delegatee Address to delegate votes to.
     */
    function delegate(address delegatee) external;

    /**
     * @notice Delegate votes via signature.
     * @param delegatee Address to delegate votes to.
     * @param nonce Nonce value of the signature.
     * @param expiry Timestamp at which the signature expires.
     * @param v Recovery ID of the transaction signature.
     * @param r "r" output value of the ECDSA signature.
     * @param s "s" output value of the ECDSA signature.
     */
    function delegateBySig(
        address delegatee,
        uint256 nonce,
        uint256 expiry,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    /**
     * @notice Delegate multiple accounts' votes via signatures.
     * @param delegatee Address to delegate votes to.
     * @param nonce Ordered array of nonce values of the signatures.
     * @param expiry Ordered array of timestamp at which the signatures expire.
     * @param v Ordered array of recovery IDs of the transaction signature.
     * @param r Ordered array of "r" output values of the ECDSA signatures.
     * @param s Ordered array of "s" output values of the ECDSA signatures.
     */
    function delegateBySigs(
        address delegatee,
        uint256[] calldata nonce,
        uint256[] calldata expiry,
        uint8[] calldata v,
        bytes32[] calldata r,
        bytes32[] calldata s
    ) external;

    /**
     * @notice Determine the prior number of votes for an account as of a block number
     * @dev Block number must be a finalized block or else this function will revert to prevent misinformation.
     * @param account The address of the account to check
     * @param blockNumber The block number to get the vote balance at
     * @return The number of votes the account had as of the given block
     */
    function getPriorVotes(
        address account,
        uint256 blockNumber
    ) external view returns (uint256);

    /**
     * @notice Call a registered contract and function combination.
     * @param contract_ Address of contract to call.
     * @param signature Function signature of the call.
     * @param data Call data to send with the function call.
     * @param amount Number of underlying tokens to transfer with the call.
     * @param tokens Array of token addresses that are expected to be claimable
     * during or after the function call.
     */
    function callContractFunction(
        address contract_,
        string memory signature,
        bytes memory data,
        uint256 amount,
        IERC20[] memory tokens
    ) external;

    /**
     * @notice Register callable function signature of a contract.
     * @param contract_ Address of contract to call.
     * @param signature Function signature of the call.
     */
    function addContractFunction(
        address contract_,
        string memory signature
    ) external;

    /**
     * @notice Unregister callable function signature of a contract.
     * @param contract_ Address of contract to call.
     * @param signature Function signature of the call.
     */
    function removeContractFunction(
        address contract_,
        string memory signature
    ) external;

    /// @notice Emitted whenever governance tokens are deposited or withdrawn.
    event Transfer(address indexed from, address indexed to, uint256 value);

    /// @notice Emitted when a new user proxy contract is created.
    event UserProxyCreated(address user, address proxy);

    /// @notice Emitted when a delegate's number of votes change.
    event DelegateVotesChanged(
        address delegatee,
        uint256 oldVotes,
        uint256 newVotes
    );

    /// @notice Emitted when an account delegates to a new account.
    event DelegateChanged(
        address delegator,
        address currentDelegate,
        address delegatee
    );

    /// @notice Emitted when a new combination of contract and function
    /// signature is added to the list of function users can call.
    event ContractFunctionAdded(
        address indexed contract_,
        string signature
    );

    /// @notice Emitted when a contract's function signature is removed from the
    /// list of functions users can call.
    event ContractFunctionRemoved(
        address indexed contract_,
        string signature
    );
}
