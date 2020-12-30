//SPDX-License-Identifier: Unlicense
pragma solidity 0.7.3;

interface IRewardPool {
    function stake(uint amount) external;
    function exit() external;
    function withdraw(uint amount) external;
    function balanceOf(address user) external view returns (uint);
    function earned(address user) external view returns (uint);
    function rewardToken() external returns (address);
    function rewards(address user) external returns (uint);
}
