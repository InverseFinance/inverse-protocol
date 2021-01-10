//SPDX-License-Identifier: Unlicense
pragma solidity 0.7.3;

interface IYCredit {
    function balanceOf(address account) external view returns (uint);
    function transfer(address dst, uint amount) external returns (bool);
    function stake(uint256 amount) external;
    function unstake(uint amount) external;
    function getReward() external;
    function earned(address account) external view returns (uint);
    function stakes(address) external view returns (uint);
}