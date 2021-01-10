//SPDX-License-Identifier: Unlicense
pragma solidity 0.7.3;

import "../vault/IVault.sol";
import "./IUniswapRouter.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IPair {
    function sync() external;
}

contract LpUniswapHarvester is Ownable {

    IUniswapRouter public router;
    IPair public pair;

    constructor(IUniswapRouter router_, IPair _pair) {
        router = router_;
        pair = _pair;
    }

    function harvestVault(IVault vault, uint amount, uint outMin, address[] calldata path, uint deadline) public onlyOwner {
        uint afterFee = vault.harvest(amount);
        IERC20Detailed from = vault.underlying();
        IERC20 to = vault.target();
        from.approve(address(router), afterFee);
        uint received = router.swapExactTokensForTokens(afterFee, outMin, path, address(this), deadline)[1];
        to.approve(address(vault), received);
        vault.distribute(received);
        vault.claimOnBehalf(address(pair));
        pair.sync();
    }

    // no tokens should ever be stored on this contract. Any tokens that are sent here by mistake are recoverable by the owner
    function sweep(address _token) external onlyOwner {
        IERC20(_token).transfer(owner(), IERC20(_token).balanceOf(address(this)));
    }

}