//SPDX-License-Identifier: Unlicense
pragma solidity 0.7.3;

import "./IStrat.sol";
import "./ICToken.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

contract CTokenStrat is IStrat {
    
    using SafeERC20 for IERC20;
    address public vault;
    ICToken public cToken;
    IERC20 public underlying;

    modifier onlyVault {
        require(msg.sender == vault);
        _;
    }

    constructor(address vault_, ICToken cToken_) {
        vault = vault_;
        cToken = cToken_;
        underlying = IERC20(cToken_.underlying());
        underlying.safeApprove(address(cToken), uint(-1));
    }

    function invest() external override onlyVault {
        uint balance = underlying.balanceOf(address(this));
        require(balance > 0);
        require(cToken.mint(balance) == 0);
    }

    function divest(uint amount) external override onlyVault {
        require(cToken.redeemUnderlying(amount) == 0);
        underlying.safeTransfer(vault, amount);
    }

    function calcTotalValue() external override returns (uint) {
        return cToken.balanceOfUnderlying(address(this));
    }

}