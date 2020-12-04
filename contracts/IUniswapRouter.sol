//SPDX-License-Identifier: Unlicense
pragma solidity 0.7.3;

interface IUniswapRouter {
    function swapExactTokensForTokens(
    uint amountIn,
    uint amountOutMin,
    address[] calldata path,
    address to,
    uint deadline
    ) external returns (uint[] memory amounts);

}