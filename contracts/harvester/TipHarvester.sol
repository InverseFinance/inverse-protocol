pragma solidity 0.7.3;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "../vault/IVault.sol";
import "./IUniswapRouter.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./ITipJar.sol";

contract TipHarvester is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using Address for address payable;
    
    IUniswapRouter public router;
    ITipJar public immutable tipJar;
    mapping(IVault => uint256) public ratePerToken;


    constructor(IUniswapRouter router_, ITipJar tipJar_) {
        router = router_;
        tipJar = tipJar_;
    }

    fallback() external payable {}
    receive() external payable {}

    /***
    * @notice retrieve tokens sent to contract by mistake
    * @param token_ Token to retrieve
    */
    function collect(address token_) public onlyOwner {
        if (token_ == address(0)) {
            payable(msg.sender).sendValue(address(this).balance);
        } else {
            uint256 balance = IERC20(token_).balanceOf(address(this));
            IERC20(token_).safeTransfer(msg.sender, balance);
        }
    }

    /**
    * @notice approve to spend given amount of given token
    * @param token Approval token
    * @param spender Address to spend token
    * @param amount Allowance of token amount to spend 
    */
    function _approve(IERC20 token, address spender, uint256 amount) internal {
        if (token.allowance(address(this), spender) < amount) {
            token.safeApprove(spender, amount);
        }
    }

    /**
     * @notice swap tokens for tokens
     * @param amountIn Amount to swap
     * @param amountOutMin Minimum amount out
     * @param path Path for swap
     * @param deadline Block timestamp deadline for trade
     */
    function _swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) internal {
        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(amountIn, amountOutMin, path, to, deadline);
    }

    /**
     * @notice Tip specific amount of ETH
     * @param tipAmount Amount to tip
     */
    function _tipAmountETH(uint256 tipAmount) internal {
        tipJar.tip{value: tipAmount}();
    }

    /**
     * @notice set router to IUniswapRouter compatible router
     * @dev ensure router is IUniswapRouter compatible
     * @param router_ IUniswapRouter compatible router
     */
    function setRouter(IUniswapRouter router_) public onlyOwner {
        router = router_;
    }

    /**
    * @notice harvest vault while tipping miner
    *         _swapExactTokensForTokens returns no amounts and therefore received amount has to be calculated
    * @param vault Vault from which to harvest
    * @param amount Amount to harvest
    * @param outMin Minimum amount of tokens out
    * @param path Token swap path
    * @param deadline Block timestamp deadline for trade
    */
    function harvestVault(IVault vault, uint256 amount, uint256 outMin, address[] calldata path, uint256 deadline) public payable onlyOwner {
        require(msg.value > 0, "Tip Harvester: tip must be > 0");
        _tipAmountETH(msg.value);

        uint256 afterFee = vault.harvest(amount);
        uint256 durationSinceLastHarvest = block.timestamp.sub(vault.lastDistribution());
        IERC20Detailed from = vault.underlying();
        ratePerToken[vault] = afterFee.mul(10**(36-from.decimals())).div(vault.totalSupply()).div(durationSinceLastHarvest);
        IERC20 to = vault.target();
        
        _approve(from, address(router), afterFee);
        uint256 toBalanceBefore = IERC20(path[path.length - 1]).balanceOf(address(this));
        _swapExactTokensForTokens(afterFee, outMin, path, address(this), deadline);
        uint256 toBalanceAfter = IERC20(path[path.length - 1]).balanceOf(address(this));

        uint256 received = toBalanceAfter.sub(toBalanceBefore);
        _approve(to, address(vault), received);
        vault.distribute(received);
    }
}
