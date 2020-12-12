//SPDX-License-Identifier: Unlicense
pragma solidity 0.7.3;

import "./IStrat.sol";
import "./IYToken.sol";
import "./IVault.sol";
import "./Timelock.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

contract YTokenStrat is IStrat {
    
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    IVault public vault;
    IYToken public yToken;
    IERC20 public underlying;
    Timelock public timelock;

    modifier onlyVault {
        require(msg.sender == address(vault));
        _;
    }

    constructor(IVault vault_, IYToken yToken_) {
        vault = vault_;
        yToken = yToken_;
        timelock = new Timelock(msg.sender, 7 days);
        underlying = IERC20(yToken_.token());
        underlying.safeApprove(address(yToken), uint(-1));
    }

    function invest() external override onlyVault {
        uint balance = underlying.balanceOf(address(this));
        require(balance > 0);
        yToken.deposit(balance, address(this));
    }

    function divest(uint amount) external override onlyVault {
        require(yToken.withdraw(amount.mul(yToken.pricePerShare()), address(vault)) == amount);
    }

    function calcTotalValue() external view override returns (uint) {
        return yToken.balanceOf(address(this)).mul(yToken.pricePerShare());
    }

    // IMPORTANT: This function can only be called by the timelock to recover any token amount including deposited yToken
    // However, the owner of the timelock must first submit their request and wait 7 days before confirming.
    // This gives depositors a good window to withdraw before a potentially malicious rescue
    // The intent is for the owner to be able to rescue funds in the case they become stuck after launch
    // However, users should not trust the owner and watch the timelock contract least once a week on Etherscan
    // In the future, the timelock contract will be destroyed and the functionality will be removed after the code gets audited
    function rescue(address _token, address _to, uint _amount) external {
        require(msg.sender == address(timelock));
        IERC20(_token).transfer(_to, _amount);
    }

    // Any tokens (other than the yToken) that are sent here by mistake are recoverable by the vault owner
    function sweep(address _token) external {
        address owner = vault.owner();
        require(msg.sender == owner);
        require(_token != address(yToken));
        IERC20(_token).transfer(owner, IERC20(_token).balanceOf(address(this)));
    }

}