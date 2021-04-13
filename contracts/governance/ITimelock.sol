// SPDX-License-Identifier: MIT
pragma solidity ^0.8.3;

interface ITimelock {
    event NewAdmin(address indexed newAdmin);
    event NewPendingAdmin(address indexed newPendingAdmin);
    event NewDelay(uint indexed newDelay);
    event CancelTransaction(bytes32 indexed txHash, address indexed target, uint value, string signature,  bytes data, uint eta);
    event ExecuteTransaction(bytes32 indexed txHash, address indexed target, uint value, string signature,  bytes data, uint eta);
    event QueueTransaction(bytes32 indexed txHash, address indexed target, uint value, string signature, bytes data, uint eta);

    function delay() external view returns (uint256);
    function GRACE_PERIOD() external view returns (uint256);
    function queuedTransactions(bytes32 txHash) external view returns (bool);

    function setDelay(uint delay_) external;
    function acceptAdmin() external;
    function setPendingAdmin(address pendingAdmin_) external;

    function queueTransaction(address target, uint value, string memory signature, bytes memory data, uint eta) external returns (bytes32);
    function cancelTransaction(address target, uint value, string memory signature, bytes memory data, uint eta) external;
    function executeTransaction(address target, uint value, string memory signature, bytes memory data, uint eta) external;
}
