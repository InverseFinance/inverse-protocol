//SPDX-License-Identifier: Unlicense
pragma solidity 0.7.3;

import "../IStrat.sol";
import "./IYToken.sol";
import "../../vault/IVault.sol";
import "../../misc/Timelock.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/Math.sol";

contract YTokenStrat is IStrat {
    
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using SafeERC20 for IERC20Detailed;
    IVault public vault;
    IYToken public yToken;
    IERC20Detailed public underlying;
    Timelock public timelock;
    uint public immutable minWithdrawalCap; // prevents the owner from completely blocking withdrawals
    uint public withdrawalCap = uint(-1); // max uint
    uint public buffer; // buffer of underlying to keep in the strat
    string public name = "Yearn V2"; // for display purposes only
    address public strategist;

    modifier onlyVault {
        require(msg.sender == address(vault));
        _;
    }

    modifier onlyTimelock {
        require(msg.sender == address(timelock));
        _;
    }

    modifier onlyStrategist {
        require(msg.sender == strategist || msg.sender == address(timelock));
        _;
    }

    constructor(IVault vault_, IYToken yToken_, Timelock timelock_) {
        strategist = msg.sender;
        vault = vault_;
        yToken = yToken_;
        timelock = timelock_;
        underlying = IERC20Detailed(yToken_.token());
        underlying.safeApprove(address(yToken), uint(-1)); // intentional underflow
        minWithdrawalCap = 1000 * (10 ** underlying.decimals()); // 10k min withdrawal cap
    }

    function invest() external override onlyVault {
        uint balance = underlying.balanceOf(address(this));
        if(balance > buffer) {
            uint max = yToken.availableDepositLimit();
            if(max > 0) {
                yToken.deposit(Math.min(balance - buffer, max)); // can't underflow because of above if statement
            }
        }
    }

    function divest(uint amount) external override onlyVault {
        uint balance = underlying.balanceOf(address(this));
        if(balance < amount) {
            uint missingAmount = amount - balance; // can't underflow because of above it statement
            require(missingAmount <= withdrawalCap, "Reached withdrawal cap"); // Big withdrawals can cause slippage on Yearn's side. Users must split into multiple txs
            yToken.withdraw(
                Math.min(
                    sharesForAmount(missingAmount)+1, // +1 is a fix for a rounding issue
                    yToken.balanceOf(address(this))
                )
            );
        }
        underlying.safeTransfer(address(vault), amount);
    }

    function totalYearnDeposits() public view returns (uint) {
        return yToken.balanceOf(address(this))
                .mul(yToken.pricePerShare())
                .div(10**yToken.decimals());
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
    function rescue(address _token, address _to, uint _amount) external onlyTimelock {
        IERC20(_token).safeTransfer(_to, _amount);
    }

    // Bypasses withdrawal cap. Should be used with care. Can cause Yearn slippage with large amounts.
    function withdrawShares(uint shares) public onlyStrategist {
        yToken.withdraw(shares);
    }

    // Bypasses withdrawal cap. Should be used with care. Can cause Yearn slippage with large amounts.
    function withdrawUnderlying(uint amount) public onlyStrategist {
        yToken.withdraw(sharesForAmount(amount));
    }

    // Bypasses withdrawal cap. Should be used with care. Can cause Yearn slippage with large amounts.
    function withdrawAll() public onlyStrategist {
        yToken.withdraw();
    }

    function depositUnderlying(uint amount) public onlyStrategist {
        yToken.deposit(amount);
    }

    function depositAll() public onlyStrategist {
        yToken.deposit(underlying.balanceOf(address(this)));
    }

    // set buffer to -1 to pause deposits to yearn. 0 to remove buffer.
    function setBuffer(uint _buffer) public onlyStrategist {
        buffer = _buffer;
    }

    // set to -1 for no cap
    function setWithdrawalCap(uint underlyingCap) public onlyStrategist {
        require(underlyingCap >= minWithdrawalCap);
        withdrawalCap = underlyingCap;
    }

    function sharesForAmount(uint amount) internal view returns (uint) {
        return amount.mul(yToken.totalSupply()).div(yToken.totalAssets());
    }

    function setStrategist(address _strategist) public onlyTimelock {
        strategist = _strategist;
    }

}