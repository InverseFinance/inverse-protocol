pragma solidity ^0.8.3;

import "OZ4/access/Ownable.sol";
import "OZ4/token/ERC20/ERC20.sol";


/**
 * @title Mock ERC-20 token
 */
contract MockToken is ERC20, Ownable {
    constructor(
        string memory name_,
        string memory symbol_,
        uint256 initialSupply
    )
        ERC20(name_, symbol_)
    {
        _mint(msg.sender, initialSupply);
    }

    function mint(address receiver, uint256 amount) external onlyOwner {
        _mint(receiver, amount);
    }
}
