//SPDX-License-Identifier: Unlicense
pragma solidity 0.7.3;

interface ICToken {
    function balanceOfUnderlying(address owner) external returns (uint);
    function mint(uint mintAmount) external returns (uint);
    function redeemUnderlying(uint redeemAmount) external returns (uint);
    function underlying() external returns (address);
}