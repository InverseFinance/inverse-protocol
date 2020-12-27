//SPDX-License-Identifier: Unlicense
pragma solidity 0.7.3;

interface IFToken {
    function balanceOf(address user) external view returns (uint);
    function getPricePerFullShare() external view returns (uint);
    function deposit(uint amount) external returns (uint);
    function withdraw(uint shares) external returns (uint);
    function withdrawAll() external returns (uint);
    function underlying() external returns (address);
    function underlyingBalanceInVault() external view returns (uint);
    function totalSupply() external view returns (uint);
    function availableToInvestOut() external view returns (uint);
    function decimals() external view returns (uint8);
}
