//SPDX-License-Identifier: Unlicense
pragma solidity 0.7.3;

interface IDelayMinter {
    function announceMint(address target, uint256 amount) external;
    function executeMint(uint256 id) external;
}

interface INotifyHelper {
    function notifyPoolsIncludingProfitShare(uint256[] memory amounts, address[] memory pools, uint256 profitShareIncentiveForWeek, uint256 firstProfitShareTimestamp, uint256 sum) external;
}
