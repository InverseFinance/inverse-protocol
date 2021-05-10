// SPDX-License-Identifier: MIT
pragma solidity ^0.8.3;

import "OZ4/access/Ownable.sol";
import "OZ4/utils/structs/EnumerableSet.sol";
import "OZ4/token/ERC20/ERC20.sol";
import "OZ4/token/ERC20/IERC20.sol";
import "OZ4/token/ERC20/utils/SafeERC20.sol";

import "../UserProxy.sol";
import "./IWrappedGovernanceToken.sol";


/**
 * @title Wrapped Governance Token
 * @notice Wraps an ERC20 token to be used for governance actions.
 * @dev This contract has no generic transfer functions, i.e. wrapped governance
 * tokens are non-transferable. Wrapped governance tokens get minted when the
 * underlying token is deposited, and burned when that token is retrieved.
 */
contract WrappedGovernanceToken is IWrappedGovernanceToken, Ownable {
    using EnumerableSet for EnumerableSet.AddressSet;
    using SafeERC20 for IERC20;

    /// @dev Name of the wrapped governance token.
    string private _name;

    /// @dev Symbol of the wrapped governance token
    string private _symbol;

    /// @dev Registry of account balance per address.
    mapping (address => uint256) private _balances;

    /// @dev Total supply of wrapped tokens.
    uint256 private _totalSupply;

    /// @notice The token to wrap.
    IERC20 public immutable underlying;

    /// @notice The number of decimals of the WGT. Equal to the decimals of the
    /// underlying token.
    uint8 public immutable _decimals;

    /// @notice The number of tokens currently utilized in some form per address.
    mapping (address => uint256) public lockedBalance;

    /// @notice Hash of registered functions per contract.
    mapping (address => mapping (bytes32 => bool)) public functionsPerContract;

    /// @notice The UserProxy contract that performs actions delegated to it by
    /// by the user.
    mapping (address => UserProxy) public proxies;

    /// @notice A record of each account's delegate.
    mapping (address => address) public delegates;

    /// @notice The EIP-712 typehash for the contract's domain.
    bytes32 public constant DOMAIN_TYPEHASH = keccak256("EIP712Domain(string name,uint256 chainId,address verifyingContract)");

    /// @notice The EIP-712 typehash for the delegation struct used by the contract.
    bytes32 public constant DELEGATION_TYPEHASH = keccak256("Delegation(address delegatee,uint256 nonce,uint256 expiry)");

    /// @notice A record of states for signing / validating signatures.
    mapping (address => uint256) public nonces;

    /// @notice A record of votes checkpoint for each account, by index.
    mapping (address => mapping (uint256 => Checkpoint)) public checkpoints;

    /// @notice The number of checkpoints for each account.
    mapping (address => uint256) public numCheckpoints;

    /**
     * @notice Checks whether an address has an associated proxy.
     * @param account The address to check.
     */
    modifier hasProxy(address account) {
        require(
            address(proxies[account]) != address(0),
            "WGT::hasProxy: Given account has no proxy"
        );
        _;
    }

    /**
     * @notice Checks whether a signature is available for use on a contract.
     * @param contract_ Address of the contract.
     * @param signature Function signature to check.
     */
    modifier isValidFunction(address contract_, string memory signature) {
        require(
            functionsPerContract[contract_][keccak256(abi.encode(signature))],
            "WGT::isValidFunction: Invalid contract/function combination."
        );
        _;
    }

    /**
     * @dev ERC20 is used for `token` instead of `IERC20` to support calling the
     * `decimals` function as it's not part of the IERC20 specification.
     * @param token_ Address of token to wrap.
     * @param name_ Name of this WGT.
     * @param symbol_ Symbol of this WGT.
     */
    constructor(ERC20 token_, string memory name_, string memory symbol_) {
        underlying = token_;

        _name = name_;
        _symbol = symbol_;
        _decimals = token_.decimals();
    }

    /**
     * @return Name of the wrapped governance token.
     */
    function name() external view returns (string memory) {
        return _name;
    }

    /**
     * @return Symbol of the wrapped governance token.
     */
    function symbol() external view returns (string memory) {
        return _symbol;
    }

    /**
     * @dev The number of decimals is set at construction time and is equal to
     * the underlying token's decimals, provided that the underlying token does
     * not change that value.
     * @return Decimals used by the wrapped governance token.
     */
    function decimals() external view override returns (uint8) {
        return _decimals;
    }

    /**
     * @param account Address to check the balance of.
     * @return Balance of given account.
     */
    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    /**
     * @return Total supply of the wrapped governance token.
     */
    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     */
    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _totalSupply += amount;
        _balances[account] += amount;

        _moveDelegates(address(0), account, amount);

        emit Transfer(address(0), account, amount);
    }

    /**
     * @dev Destroys `amount` tokens from `account`, reducing the total supply.
     */
    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");

        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        _balances[account] = accountBalance - amount;
        _totalSupply -= amount;

        _moveDelegates(account, address(0), amount);

        emit Transfer(account, address(0), amount);
    }

    /**
     * @notice Deposit governance tokens.
     * @param amount Number of governance tokens to deposit.
     */
    function deposit(uint256 amount) external override {
        underlying.safeTransferFrom(msg.sender, address(this), amount);

        UserProxy proxy = proxies[msg.sender];

        // Deploy new user proxy if user does not have one.
        if (address(proxy) == address(0)) {
            proxy = new UserProxy();
            proxies[msg.sender] = proxy;

            emit UserProxyCreated(msg.sender, address(proxy));
        }

        // Mint same number of WGT tokens for user
        _mint(msg.sender, amount);
    }

    /**
     * @notice Withdraw governance tokens.
     * @param amount Number of governance tokens to withdraw
     */
    function withdraw(uint256 amount) external override {
        require(
            availableBalanceOf(msg.sender) >= amount,
            "WGT::withdraw: Insufficient balance"
        );

        underlying.safeTransfer(msg.sender, amount);

        // Burn the same number of WGT tokens from user
        _burn(msg.sender, amount);
    }

    /**
     * @notice Delegate votes to an account.
     * @dev If users want to vote themselves, they have to delegate to their own
     * address first.
     * @param delegatee Address to delegate votes to.
     */
    function delegate(address delegatee) external override {
        _delegate(msg.sender, delegatee);
    }

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
    )
        public
        override
    {
        bytes32 domainSeparator = keccak256(
            abi.encode(
                DOMAIN_TYPEHASH,
                keccak256(bytes(_name)),
                block.chainid,
                address(this)
            )
        );
        bytes32 structHash = keccak256(
            abi.encode(DELEGATION_TYPEHASH, delegatee, nonce, expiry)
        );
        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", domainSeparator, structHash)
        );
        address signatory = ecrecover(digest, v, r, s);

        require(
            signatory != address(0),
            "WGT::delegateBySig: invalid signature"
        );
        require(
            nonce == nonces[signatory]++,
            "WGT::delegateBySig: invalid nonce"
        );
        require(
            block.timestamp <= expiry,
            "WGT::delegateBySig: signature expired"
        );

        _delegate(signatory, delegatee);
    }

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
    )
        external
        override
    {
        require(
            nonce.length == expiry.length
            && nonce.length == v.length
            && nonce.length == r.length
            && nonce.length == s.length,
            "WGT::delegateBySig: Mismatched array lengths"
        );

        for (uint256 i = 0; i < nonce.length; i++) {
            delegateBySig(delegatee, nonce[i], expiry[i], v[i], r[i], s[i]);
        }
    }

    /**
     * @dev Delegates votes from one address to another.
     * @param delegator Address delegating their votes.
     * @param delegatee Address votes are delegated to.
     */
    function _delegate(address delegator, address delegatee) internal {
        address currentDelegate = delegates[delegator];
        uint256 delegatorBalance = balanceOf(delegator);
        delegates[delegator] = delegatee;

        emit DelegateChanged(delegator, currentDelegate, delegatee);

        _moveDelegates(currentDelegate, delegatee, delegatorBalance);
    }

    /**
     * @dev Moves votes from one account to another.
     * @param srcRep Address of account to move votes from.
     * @param dstRep Address of account to move votes to.
     * @param amount Number of votes to move.
     */
    function _moveDelegates(
        address srcRep,
        address dstRep,
        uint256 amount
    )
        internal
    {
        if (srcRep != dstRep && amount > 0) {
            if (srcRep != address(0)) {
                uint256 srcRepNum = numCheckpoints[srcRep];
                uint256 srcRepOld = srcRepNum > 0 ? checkpoints[srcRep][srcRepNum - 1].votes : 0;
                uint256 srcRepNew = srcRepOld - amount;

                _writeCheckpoint(srcRep, srcRepNum, srcRepOld, srcRepNew);
            }

            if (dstRep != address(0)) {
                uint256 dstRepNum = numCheckpoints[dstRep];
                uint256 dstRepOld = dstRepNum > 0 ? checkpoints[dstRep][dstRepNum - 1].votes : 0;
                uint256 dstRepNew = dstRepOld + amount;

                _writeCheckpoint(dstRep, dstRepNum, dstRepOld, dstRepNew);
            }
        }
    }

    function _writeCheckpoint(
        address delegatee,
        uint256 nCheckpoints,
        uint256 oldVotes,
        uint256 newVotes
    )
        internal
    {
        uint256 blockNumber = block.number;

        if (nCheckpoints > 0 && checkpoints[delegatee][nCheckpoints - 1].fromBlock == blockNumber) {
            checkpoints[delegatee][nCheckpoints - 1].votes = newVotes;
        } else {
            checkpoints[delegatee][nCheckpoints] = Checkpoint(blockNumber, newVotes);
            numCheckpoints[delegatee] = nCheckpoints + 1;
        }

        emit DelegateVotesChanged(delegatee, oldVotes, newVotes);
    }

    /**
     * @param account Address of account to get available balance of.
     * @return The number of underlying tokens available to utilize.
     */
    function availableBalanceOf(
        address account
    )
        public
        view
        override
        returns (uint256)
    {
        // `lockedBalance[account]` can never exceed `_balances[account]`. It's
        // always checked whenever the number is incremented.
        return balanceOf(account) - lockedBalance[account];
    }

    /**
     * @notice Determine the prior number of votes for an account as of a block
     * number
     * @dev Block number must be a finalized block or else this function will
     * revert to prevent misinformation.
     * @param account The address of the account to check
     * @param blockNumber The block number to get the vote balance at
     * @return The number of votes the account had as of the given block
     */
    function getPriorVotes(
        address account,
        uint256 blockNumber
    )
        public
        view
        override
        returns (uint256)
    {
        require(blockNumber < block.number, "WGT::getPriorVotes: not yet determined");

        uint256 nCheckpoints = numCheckpoints[account];
        if (nCheckpoints == 0) {
            return 0;
        }

        // First check most recent balance
        if (checkpoints[account][nCheckpoints - 1].fromBlock <= blockNumber) {
            return checkpoints[account][nCheckpoints - 1].votes;
        }

        // Next check implicit zero balance
        if (checkpoints[account][0].fromBlock > blockNumber) {
            return 0;
        }

        uint256 lower = 0;
        uint256 upper = nCheckpoints - 1;
        while (upper > lower) {
            uint256 center = upper - (upper - lower) / 2; // ceil, avoiding overflow
            Checkpoint memory cp = checkpoints[account][center];
            if (cp.fromBlock == blockNumber) {
                return cp.votes;
            } else if (cp.fromBlock < blockNumber) {
                lower = center;
            } else {
                upper = center - 1;
            }
        }

        return checkpoints[account][lower].votes;
    }

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
    )
        external
        override
        hasProxy(msg.sender)
        isValidFunction(contract_, signature)
    {
        UserProxy proxy = proxies[msg.sender];

        if (amount > 0) {
            require(
                availableBalanceOf(msg.sender) >= amount,
                "WGT::callContractFunction: Insufficient balance"
            );

            // Lock up user's token balance for `amount`, because this is now
            // utilized by the user's proxy contract.
            lockedBalance[msg.sender] += amount;
            underlying.safeTransfer(address(proxy), amount);
        }

        bytes memory callData;

        if (bytes(signature).length == 0) {
            callData = data;
        } else {
            callData = abi.encodePacked(bytes4(keccak256(bytes(signature))), data);
        }

        proxy.callFunction(contract_, callData, underlying, amount);

        for (uint256 i = 0; i < tokens.length; i++) {
            uint256 withdrawnAmount = proxy.withdrawToken(tokens[i]);

            // The governance token is kept in the wrapper. If the user receives
            // more governance tokens then additional WGT is minted to keep
            // track.
            if (address(tokens[i]) == address(underlying)) {
                uint256 accountLockedBalance = lockedBalance[msg.sender];

                // It's possible that more governance tokens have accumulated
                // during their utilized period. In this case we have to prevent
                // `lockedBalance` from reverting due to underflow.
                if (accountLockedBalance >= withdrawnAmount) {
                    accountLockedBalance -= withdrawnAmount;
                } else {
                    uint256 difference = withdrawnAmount - accountLockedBalance;

                    lockedBalance[msg.sender] = 0;
                    _mint(msg.sender, difference);
                }
            } else {
                // In the case where tokens are withdrawn that aren't the
                // wrapped governance token, they are immediately sent to the
                // user.
                tokens[i].safeTransfer(msg.sender, withdrawnAmount);
            }
        }
    }

    /**
     * @notice Register callable function signature of a contract.
     * @param contract_ Address of contract to call.
     * @param signature Function signature of the call.
     */
    function addContractFunction(
        address contract_,
        string memory signature
    )
        external
        override
        onlyOwner
    {
        functionsPerContract[contract_][keccak256(abi.encode(signature))] = true;
    }

    /**
     * @notice Unregister callable function signature of a contract.
     * @param contract_ Address of contract to call.
     * @param signature Function signature of the call.
     */
    function removeContractFunction(
        address contract_,
        string memory signature
    )
        external
        override
        onlyOwner
    {
        functionsPerContract[contract_][keccak256(abi.encode(signature))] = false;
    }
}
