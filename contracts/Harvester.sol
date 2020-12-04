//SPDX-License-Identifier: Unlicense
pragma solidity 0.7.3;

import "./IVault.sol";
import "./IUniswapRouter.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract UniswapHarvester is Ownable {

    IUniswapRouter public router;

    constructor(IUniswapRouter router_) {
        router = router_;
    }

    function harvestVault(IVault vault, uint amount, uint outMin, address[] calldata path, uint deadline) public onlyOwner {
        uint afterFee = vault.harvest(amount);
        IERC20Detailed from = vault.underlying();
        IERC20 to = vault.cash();
        from.approve(address(router), afterFee);
        uint received = router.swapExactTokensForTokens(afterFee, outMin, path, address(this), deadline)[1];
        to.approve(address(vault), received);
        vault.distribute(received);
    }

}