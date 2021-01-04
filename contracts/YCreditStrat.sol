//SPDX-License-Identifier: Unlicense
pragma solidity 0.7.3;

import "./IStrat.sol";
import "./IYCredit.sol";
import "./IVault.sol";
import "./Timelock.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

contract YCreditStrat is IStrat {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    IVault public vault;
    IYCredit public yCredit;
    Timelock public timelock;
    string public name = "yCredit Compounded Staking";

    modifier onlyVault {
        require(msg.sender == address(vault));
        _;
    }

    constructor(IVault vault_, Timelock timelock_) {
        vault = vault_;
        timelock = timelock_;
        yCredit = IYCredit(address(vault_.underlying())); // vault underlying must be yCredit
    }

    function invest() external override onlyVault {
        reinvest();
    }

    function divest(uint amount) external override onlyVault {
        reinvest();
        yCredit.unstake(amount);
        yCredit.transfer(address(vault), amount);
    }

    function calcTotalValue() external view override returns (uint) {
        return yCredit.stakes(address(this)).add(yCredit.earned(address(this)));
    }

    function reinvest() public {
        yCredit.getReward();
        uint balance = yCredit.balanceOf(address(this));
        if(balance > 0) {
            yCredit.stake(balance);
        }
    }

    // IMPORTANT: This function can only be called by the timelock to recover any token amount including deposited yCredit
    // However, the owner of the timelock must first submit their request and wait 7 days before confirming.
    // This gives depositors a good window to withdraw before a potentially malicious escape
    // The intent is for the owner to be able to rescue funds in the case they become stuck after launch
    // However, users should not trust the owner and watch the timelock contract least once a week on Etherscan
    // In the future, the timelock contract will be destroyed and the functionality will be removed after the code gets audited
    function rescue(address _token, address _to, uint _amount) external {
        require(msg.sender == address(timelock));
        IERC20(_token).transfer(_to, _amount);
    }

    // Any tokens (other than yCredit) that are sent here by mistake are recoverable by the vault owner
    function sweep(address _token) external {
        address owner = vault.owner();
        require(msg.sender == owner);
        require(_token != address(yCredit));
        IERC20(_token).transfer(owner, IERC20(_token).balanceOf(address(this)));
    }

    function changeTimelock(Timelock timelock_) external {
        require(msg.sender == address(timelock));
        timelock = timelock_;
    }

}