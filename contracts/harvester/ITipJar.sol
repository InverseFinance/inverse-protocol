// SPDX-License-Identifier: MIT
pragma solidity 0.7.3;

interface ITipJar {
    function tip() external payable;
    function updateMinerSplit(address minerAddress, address splitTo, uint32 splitPct) external;
    function setFeeCollector(address newCollector) external;
    function setFee(uint32 newFee) external;
    function changeAdmin(address newAdmin) external;
    function upgradeTo(address newImplementation) external;
    function upgradeToAndCall(address newImplementation, bytes calldata data) external payable; 
}