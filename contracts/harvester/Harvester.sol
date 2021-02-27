//SPDX-License-Identifier: Unlicense
pragma solidity 0.7.3;
import "@openzeppelin/contracts/math/SafeMath.sol";
import "../vault/IVault.sol";
import "./IUniswapRouter.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract UniswapHarvester is Ownable {
    using SafeMath for uint256;
    IUniswapRouter public router;
    mapping (IVault => uint) public ratePerToken;

    constructor(IUniswapRouter router_) {
        router = router_;
    }

    function harvestVault(IVault vault, uint amount, uint outMin, address[] calldata path, uint deadline) public onlyOwner {
        uint afterFee = vault.harvest(amount);
        uint durationSinceLastHarvest = block.timestamp.sub(vault.lastDistribution());
        IERC20Detailed from = vault.underlying();
        ratePerToken[vault] = afterFee.mul(10**(36-from.decimals())).div(vault.totalSupply()).div(durationSinceLastHarvest);
        IERC20 to = vault.target();
        from.approve(address(router), afterFee);
        uint received = router.swapExactTokensForTokens(afterFee, outMin, path, address(this), deadline)[path.length-1];
        to.approve(address(vault), received);
        vault.distribute(received);
    }

    // no tokens should ever be stored on this contract. Any tokens that are sent here by mistake are recoverable by the owner
    function sweep(address _token) external onlyOwner {
        IERC20(_token).transfer(owner(), IERC20(_token).balanceOf(address(this)));
    }

}