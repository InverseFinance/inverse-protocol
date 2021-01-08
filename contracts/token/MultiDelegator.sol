pragma solidity ^0.5.16;

pragma experimental ABIEncoderV2;

interface InvInterface {
    function delegateBySig(address delegatee, uint nonce, uint expiry, uint8 v, bytes32 r, bytes32 s) external;
}

contract MultiDelegator {

    InvInterface public inv;

    constructor (InvInterface _inv) public {
        inv = _inv;
    }

    function delegateBySig(address delegatee, uint[] memory nonce, uint[] memory expiry, uint8[] memory v, bytes32[] memory r, bytes32[] memory s) public {
        for (uint256 i = 0; i < nonce.length; i++) {
            inv.delegateBySig(delegatee, nonce[i], expiry[i], v[i], r[i], s[i]);
        }
    }
}