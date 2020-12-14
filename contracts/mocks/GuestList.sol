//SPDX-License-Identifier: Unlicense
pragma solidity 0.7.3;

interface GuestList {
    function invite_guest(address) external;
    function authorized(address, uint) external view returns (bool);
}