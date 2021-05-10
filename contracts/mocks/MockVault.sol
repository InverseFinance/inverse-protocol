pragma solidity ^0.8.3;

import "OZ4/token/ERC20/IERC20.sol";
import "OZ4/token/ERC20/utils/SafeERC20.sol";

/**
 * @title Mock token vault
 * @notice Allows users to retrieve whatever token is available.
 */
contract MockVault {
    using SafeERC20 for IERC20;

    IERC20 public token;

    constructor(IERC20 token_) {
        token = token_;
    }

    function deposit(uint256 amount) external {
        token.safeTransferFrom(msg.sender, address(this), amount);
    }

    function withdraw(uint256 amount) external {
        token.safeTransfer(msg.sender, amount);
    }
}
