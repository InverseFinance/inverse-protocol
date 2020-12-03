//SPDX-License-Identifier: Unlicense
pragma solidity 0.7.3;

interface IVault {
    function harvest(uint amount) external returns (uint afterFee);
    function distribute(uint amount) external;
}