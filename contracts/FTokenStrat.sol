//SPDX-License-Identifier: Unlicense
/*
harvest finance strategy
prox:         0xab7fa2b2985bccfc13c6d86b1d5a17486ab1e04c
current_imp:  0x9b3be0cc5dd26fd0254088d03d8206792715588b
fDAI:         0xe85c8581e60d7cd32bbfd86303d2a4fa6a951dac

*/

pragma solidity 0.7.3;

import "./IStrat.sol";
import "./IFToken.sol";
import "./IVault.sol";
import "./IRewardPool.sol";
import "./Timelock.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/Math.sol";

contract FTokenStrat is IStrat {

    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using SafeERC20 for IERC20Detailed;
    using SafeERC20 for IRewardPool;
    IVault public vault;
    IFToken public fToken;
    IERC20Detailed public underlying;
    IRewardPool public rewardpool;
    IERC20Detailed public rewardtoken;
    Timelock public timelock;
    address public strategist;  //strategy administrator
    uint public immutable minWithdrawalCap; // prevents the owner from completely blocking withdrawals
    uint public withdrawalCap = uint(-1); // max uint
    uint public buffer = uint(-1); // buffer of underlying to keep in the strat
    string public name = "Harvest Finance"; // for display purposes only

    modifier onlyVault {
        require(msg.sender == address(vault), "CAN ONLY BE CALLED BY VAULT");
        _;
    }

    modifier onlyOwner {
        require(msg.sender == vault.owner(), "CAN ONLY BE CALLED BY OWNER"); // vault owner is strat owner
        _;
    }

    modifier onlyStrategist {
        require(msg.sender == strategist || msg.sender == vault.owner(), "CAN ONLY BE CALLED BY STRATEGIST");
        _;
    }

    modifier onlyTimelock {
        require(msg.sender == address(timelock), "CAN ONLY BE CALLED BY TIMELOCK");
        _;
    }

    constructor(IVault vault_, IFToken fToken_, IRewardPool rewardpool_) {
        require(address(vault_.underlying()) == fToken_.underlying(),"VAULT / TOKEN UNDERLYING MISMATCH");
        vault = vault_;
        fToken = fToken_;
        rewardpool = rewardpool_;
        rewardtoken = IERC20Detailed(rewardpool.rewardToken());
        timelock = Timelock(vault.timelock()); // use the same timelock from the vault
        underlying = IERC20Detailed(fToken_.underlying());
        underlying.safeApprove(address(fToken), uint(-1)); // intentional underflow
        fToken.approve(address(rewardpool), uint(-1));

        minWithdrawalCap = 1000 * (10 ** underlying.decimals()); // 10k min withdrawal cap
    }

    function invest() external override onlyVault {
        uint balance = underlying.balanceOf(address(this));

        if(balance > buffer) {
            fToken.deposit(balance - buffer);

            uint ftokenBalance = fToken.underlyingBalanceWithInvestmentForHolder(address(this));
            rewardpool.stake(ftokenBalance - buffer);

        }

    }

    function divest(uint amount) external override onlyVault {
        uint balance = underlying.balanceOf(address(this));
        if(balance < amount) {
            uint missingAmount = amount - balance; // can't underflow because of above it statement
            require(missingAmount <= withdrawalCap, "Reached withdrawal cap"); // Big withdrawals can cause slippage. Users must split into multiple txs
            fToken.withdraw(
                Math.min(
                    sharesForAmount(missingAmount)+1, // +1 is a fix for a rounding issue
                    fToken.balanceOf(address(this))
                )
            );
        }

        rewardpool.exit();

        underlying.safeTransfer(address(vault), amount);
    }

    function totalFTokenDeposits() public view returns (uint) {
        return fToken.balanceOf(address(this))
                .mul(fToken.getPricePerFullShare())
                .div(10**fToken.decimals());
    }

    function totalRewardTokenPending() public returns (uint) {
        return rewardpool.rewards(address(this));
    }

    function calcTotalValue() external view override returns (uint) {
        return Math.max(totalFTokenDeposits(), 1) // cannot be lower than 1 because we subtract 1 after
        .sub(1) // account for dust
        .add(underlying.balanceOf(address(this)));
    }

    // IMPORTANT: This function can only be called by the timelock to recover any token amount including deposited fToken and underlying
    // However, the owner of the timelock must first submit their request and wait 2 days before confirming.
    // This gives depositors a good window to withdraw before a potentially malicious rescue
    // The intent is for the owner to be able to rescue funds in the case they become stuck after launch
    // However, users should not trust the owner and watch the timelock contract least once a week on Etherscan
    // In the future, the timelock contract will be destroyed and the functionality will be removed after the code gets audited
    function rescue(address _token, address _to, uint _amount) external {
        require(msg.sender == address(timelock));
        IERC20(_token).safeTransfer(_to, _amount);
    }

    // Any tokens (other than the fToken and underlying) that are sent here by mistake are recoverable by the vault owner
    function sweep(address _token, address _to) public onlyOwner {
        require(_token != address(fToken) && _token != address(underlying));
        IERC20(_token).safeTransfer(_to, IERC20(_token).balanceOf(address(this)));
    }

    // Bypasses withdrawal cap. Should be used with care. Can cause slippage with large amounts.
    function withdrawShares(uint shares) public onlyStrategist {
        fToken.withdraw(shares);
    }

    // Bypasses withdrawal cap. Should be used with care. Can cause slippage with large amounts.
    function withdrawUnderlying(uint amount) public onlyStrategist {
        fToken.withdraw(sharesForAmount(amount));
    }

    // Bypasses withdrawal cap. Should be used with care. Can cause slippage with large amounts.
    function withdrawAll() public onlyStrategist {
        fToken.withdrawAll();
    }

    function depositUnderlying(uint amount) public onlyStrategist {
        fToken.deposit(amount);
    }

    function depositAll() public onlyStrategist {
        fToken.deposit(underlying.balanceOf(address(this)));
    }

    // set buffer to -1 to pause deposits. 0 to remove buffer.
    function setBuffer(uint _buffer) public onlyStrategist {
        buffer = _buffer;
    }

    // set to -1 for no cap
    function setWithdrawalCap(uint underlyingCap) public onlyStrategist {
        require(underlyingCap >= minWithdrawalCap);
        withdrawalCap = underlyingCap;
    }

    function sharesForAmount(uint amount) internal view returns (uint) {
        return amount.mul(fToken.totalSupply()).div(fToken.underlyingBalanceInVault());
    }

    function setStrategist(address _newStrategist) public onlyOwner {
        strategist = _newStrategist;
    }

    function changeTimelock(Timelock _newTimelock) public onlyTimelock {
        timelock = Timelock(_newTimelock);
    }

    function changeRewardPool(IRewardPool _newRewardPool ) public onlyStrategist {
        rewardpool = _newRewardPool;
        rewardtoken = IERC20Detailed(rewardpool.rewardToken());
    }

}
