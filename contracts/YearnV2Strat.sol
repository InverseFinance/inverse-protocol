//SPDX-License-Identifier: Unlicense
pragma solidity 0.7.3;

import "./IStrat.sol";
import "./IYToken.sol";
import "./IVault.sol";
import "./Timelock.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/Math.sol";

contract YTokenStrat is IStrat {
    
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    IVault public vault;
    IYToken public yToken;
    IERC20 public underlying;
    Timelock public timelock;
    bool public depositsPaused; // pausing only applies to Yearn deposits. Not strategy
    uint public withdrawalCap; // 0 implies no cap
    uint public unutilized; // similar to Uniswap reserves. Discrepancies are dangerous
    string public name = "Yearn V2"; // for display purposes only

    modifier onlyVault {
        require(msg.sender == address(vault));
        _;
    }

    modifier onlyOwner {
        require(msg.sender == vault.owner()); // vault owner is strat owner
        _;
    }

    constructor(IVault vault_, IYToken yToken_) {
        vault = vault_;
        yToken = yToken_;
        timelock = Timelock(vault.timelock()); // use the same timelock from the vault
        underlying = IERC20(yToken_.token());
        underlying.safeApprove(address(yToken), uint(-1)); // intentional underflow
    }

    function invest() external override onlyVault {
        uint amount = underlying.balanceOf(address(this)).sub(unutilized); // unutilized reserves do not count for incoming investment
        require(amount > 0, "Nothing to invest");
        if(!depositsPaused) {
            uint max = yToken.availableDepositLimit();
            yToken.deposit(Math.min(amount, max), address(this)); // respect Yearn's limits and leave the remainder here
            if(max < amount) { // some funds are left unutilized
                syncUntilized();
            }
        } else {
            syncUntilized(); // just keep the entire amount here
        }
    }

    function divest(uint amount) external override onlyVault {
        require(amount > 0, "Nothing to divest"); // this fails when migrating away but there are no deposits. But in that case, what are we even migrating?
        bool zeroUnutilized = unutilized == 0; // to save on SSTOREs
        if(unutilized < amount) {
            uint missingAmount = amount.sub(unutilized);
            if(withdrawalCap > 0) { // 0 implies no cap
                require(missingAmount <= withdrawalCap, "Reached withdrawal cap"); // Big withdrawals can cause slippage on Yearn's side. Users must split into multiple txs
            }
            yToken.withdraw(sharesForAmount(missingAmount) + 1, address(this));  // +1 is a fix for a rounding issue
        }
        underlying.transfer(address(vault), amount);
        if(!zeroUnutilized) syncUntilized(); // unutilized can only go down when withdrawing.
    }

    function totalYearnDeposits() public view returns (uint) {
        return yToken.balanceOf(address(this))
                .mul(yToken.pricePerShare())
                .div(10**18); // TODO: Dynamic precision
    }

    function calcTotalValue() external view override returns (uint) {
        return Math.max(totalYearnDeposits(), 1) // cannot be lower than 1 because we subtract 1 after
        .sub(1) // account for dust
        .add(underlying.balanceOf(address(this)));
    }

    // IMPORTANT: This function can only be called by the timelock to recover any token amount including deposited yToken and underlying
    // However, the owner of the timelock must first submit their request and wait 2 days before confirming.
    // This gives depositors a good window to withdraw before a potentially malicious rescue
    // The intent is for the owner to be able to rescue funds in the case they become stuck after launch
    // However, users should not trust the owner and watch the timelock contract least once a week on Etherscan
    // In the future, the timelock contract will be destroyed and the functionality will be removed after the code gets audited
    function rescue(address _token, address _to, uint _amount) external {
        require(msg.sender == address(timelock));
        IERC20(_token).transfer(_to, _amount);
    }

    // Any tokens (other than the yToken and underlying) that are sent here by mistake are recoverable by the vault owner
    function sweep(address _token, address _to) public onlyOwner {
        require(_token != address(yToken) && _token != address(underlying));
        IERC20(_token).transfer(_to, IERC20(_token).balanceOf(address(this)));
    }

    function pauseDeposits(bool value) public onlyOwner {
        depositsPaused = value;
    }

    // Bypasses withdrawal cap. Should be used with care. Can cause Yearn slippage with large amounts.
    function withdrawShares(uint shares) public onlyOwner {
        yToken.withdraw(shares, address(this));
        syncUntilized();
    }

    // Bypasses withdrawal cap. Should be used with care. Can cause Yearn slippage with large amounts.
    function withdrawUnderlying(uint amount) public onlyOwner {
        yToken.withdraw(sharesForAmount(amount), address(this));
        syncUntilized();
    }

    // Bypasses withdrawal cap. Should be used with care. Can cause Yearn slippage with large amounts.
    function withdrawAll() public onlyOwner {
        yToken.withdraw(yToken.balanceOf(address(this)), address(this));
        syncUntilized();
    }

    function depositUnderlying(uint amount) public onlyOwner {
        yToken.deposit(amount, address(this));
        syncUntilized();
    }

    function depositAll() public onlyOwner {
        yToken.deposit(underlying.balanceOf(address(this)), address(this));
        syncUntilized();
    }

    // 0 implies no cap
    function setWithdrawalCap(uint underlyingCap) public onlyOwner {
        withdrawalCap = underlyingCap;
    }

    function sharesForAmount(uint amount) internal view returns (uint) {
        return amount.mul(yToken.totalSupply()).div(yToken.totalAssets());
    }

    function syncUntilized() internal {
        unutilized = underlying.balanceOf(address(this));
    }

}