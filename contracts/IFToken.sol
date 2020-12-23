//SPDX-License-Identifier: Unlicense
pragma solidity 0.7.3;

interface IFToken {
    function balanceOf(address user) external view returns (uint);
    function getPricePerFullShare() external view returns (uint);
    //function deposit(uint amount, address recipient) external returns (uint);  // not used
    function deposit(uint amount) external returns (uint);
    //function deposit() external returns (uint);
    //function withdraw(uint shares, address recipient) external returns (uint); // not used
    function withdraw(uint shares) external returns (uint);
    function withdraw() external returns (uint);
    function token() external returns (address);
    function underlying() external returns (address);
    function underlyingBalanceInVault() external view returns (uint);
    function totalSupply() external view returns (uint);
    function availableToInvestOut() external view returns (uint);
    function decimals() external view returns (uint8);
}
