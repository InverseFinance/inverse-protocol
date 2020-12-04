//SPDX-License-Identifier: Unlicense
pragma solidity 0.7.3;

import "./IStrat.sol";
import "./IVault.sol";
import "./DividendToken.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

contract Vault is Ownable, Pausable, DividendToken {
    using SafeMath for uint256;
    using SafeERC20 for IERC20Detailed;

    IERC20Detailed public underlying;
    IStrat public strat;
    address public harvester;
    uint constant MAX_FEE = 10000;
    uint public performanceFee = 1000; // 10% of profit

    modifier onlyHarvester {
        require(msg.sender == harvester);
        _;
    }

    constructor(IERC20Detailed underlying_, IERC20 reward_, address harvester_, string memory name_, string memory symbol_)
    DividendToken(reward_, name_, symbol_, underlying_.decimals())
    {
        underlying = underlying_;
        harvester = harvester_;
        _pause(); // paused until a strategy is connected
    }

    function calcTotalValue() public returns (uint underlyingAmount) {
        return strat.calcTotalValue();
    }

    function deposit(uint amount) public whenNotPaused {
        underlying.safeTransferFrom(msg.sender, address(strat), amount);
        strat.invest();
        _mint(msg.sender, amount);
    }

    function withdraw(uint amount) public {
        _burn(msg.sender, amount);
        strat.divest(amount);
        underlying.safeTransfer(msg.sender, amount);
    }

    function underlyingYield() public returns (uint) {
        return calcTotalValue().sub(totalSupply());
    }

    function unclaimedProfit(address user) public view returns (uint256) {
        return withdrawableDividendOf(user);
    }

    function claimProfit() public {
        withdrawDividend(msg.sender);
    }

    function pauseDeposits(bool trigger) public onlyOwner {
        if(trigger) _pause();
        else _unpause();
    }

    function changeHarvester(address harvester_) public onlyOwner {
        harvester = harvester_;
    }

    function changePerformanceFee(uint fee_) public onlyOwner {
        require(fee_ <= MAX_FEE);
        performanceFee = fee_;
    }

    function setStrat(IStrat strat_, bool force) public onlyOwner {
        if(address(strat) != address(0)) {
            uint prevTotalValue = strat.calcTotalValue();
            strat.divest(prevTotalValue);
            underlying.safeTransfer(address(strat_), underlying.balanceOf(address(this)));
            strat_.invest();
            if(!force) {
                require(strat_.calcTotalValue() >= prevTotalValue);
                require(strat.calcTotalValue() == 0);
            }
        } else {
            _unpause();
        }
        strat = strat_;
    }

    function harvest(uint amount) public onlyHarvester returns (uint afterFee) {
        require(amount <= underlyingYield(), "Amount larger than generated yield");
        strat.divest(amount);
        if(performanceFee > 0) {
            uint fee = amount.mul(performanceFee).div(MAX_FEE);
            afterFee = amount.sub(fee);
            underlying.safeTransfer(owner(), fee);
        } else {
            afterFee = amount;
        }
        underlying.safeTransfer(harvester, afterFee);
    }

    function distribute(uint amount) public onlyHarvester {
        distributeDividends(amount);
    }

}