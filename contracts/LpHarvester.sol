
pragma solidity 0.7.3;
// Experimental ABIEncoderV2 required for compilation and use of KP3R interfaces. This could be written in Solidity 0.8 instead, which uses ABIEncoderV2 by default.

import "./IVault.sol";
import "./IUniswapRouter.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IPair {
    function sync() external;
}

interface IKeep3rV1 {
    function isMinKeeper(address keeper, uint minBond, uint earned, uint age) external returns (bool);
    function receipt(address credit, address keeper, uint amount) external;
    function unbond(address bonding, uint amount) external;
    function withdraw(address bonding) external;
    function bonds(address keeper, address credit) external view returns (uint);
    function unbondings(address keeper, address credit) external view returns (uint);
    function approve(address spender, uint amount) external returns (bool);
    function jobs(address job) external view returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function worked(address keeper) external;
    function KPRH() external view returns (IKeep3rV1Helper);
}

interface IKeep3rV1Helper {
    function getQuoteLimit(uint gasUsed) external view returns (uint);
}

contract LpUniswapHarvester is Ownable {

    IUniswapRouter public router;
    IPair public pair;
    
    uint public minKeep = 50e18; // Keepers must bond at least 50 KP3R

    modifier keeper() {
        require(KP3R.isMinKeeper(msg.sender, minKeep, 0, 0), "::isKeeper: keeper is not registered");
        _;
    }
    
    modifier upkeep() {
        uint _gasUsed = gasleft();
        require(KP3R.isMinKeeper(msg.sender, minKeep, 0, 0), "::isKeeper: keeper is not registered");
        _;
        uint _received = KP3R.KPRH().getQuoteLimit(_gasUsed.sub(gasleft()));
        KP3R.receipt(address(KP3R), address(this), _received);
        _received = _swap(_received);
        msg.sender.transfer(_received);
    }

    /* Harvester can be managed by a seperate governance Contract or EOA */
    
    address public governance;
    address public pendingGovernance;
    
     /**
     * @notice Allows governance to change governance (for future upgradability)
     * @param _governance new governance address to set
     */
    function setGovernance(address _governance) external {
        require(msg.sender == governance, "setGovernance: !gov");
        pendingGovernance = _governance;
    }

    /**
     * @notice Allows pendingGovernance to accept their role as governance (protection pattern)
     */
    function acceptGovernance() external {
        require(msg.sender == pendingGovernance, "acceptGovernance: !pendingGov");
        governance = pendingGovernance;
    }
    
    IKeep3rV1 public constant KP3R = IKeep3rV1(0x1cEB5cB57C4D4E2b2433641b95Dd330A33185A44);
    WETH9 public constant WETH = WETH9(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IUniswapV2Router public constant UNI = IUniswapV2Router(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
     
    /* You can set Min Keep3r bond requirements to ensure we have trusted Keepers of the Harvester */
    function setMinKeep(uint _keep) external {
        require(msg.sender == governance, "setGovernance: !gov");
        minKeep = _keep;
    }


    constructor(IUniswapRouter router_, IPair _pair) {
        router = router_;
        pair = _pair;
    }

    function harvestVault(IVault vault, uint amount, uint outMin, address[] calldata path, uint deadline) public keeper {
        uint afterFee = vault.harvest(amount);
        IERC20Detailed from = vault.underlying();
        IERC20 to = vault.target();
        from.approve(address(router), afterFee);
        uint received = router.swapExactTokensForTokens(afterFee, outMin, path, address(this), deadline)[1];
        to.approve(address(vault), received);
        vault.distribute(received);
        vault.claimOnBehalf(address(pair));
        pair.sync();
    }

    // no tokens should ever be stored on this contract. Any tokens that are sent here by mistake are recoverable by the owner
    function sweep(address _token) external onlyOwner {
        IERC20(_token).transfer(owner(), IERC20(_token).balanceOf(address(this))); }
        
        function work() public upkeep {
        bool worked = harvestVault();
        require(worked, "INVUniswapHarvester: !work");
    }

    function workForFree() public keeper {
        bool worked = harvestVault();
        require(worked, "INVUniswapHarvester: !work");
    }
    
   
 /* Needs logic to check if the Vault rewards can be harvested else return false  */
    function workable(address harvester) public view returns (bool) {
       for () { 
            if () { 
                return true;
            }
       }
        return false; 
        
    }
    
    //Pays Keeper in ETH
    
    receive() external payable {}
    
    function _swap(uint _amount) internal returns (uint) {
        KP3R.approve(address(UNI), _amount);
        
        address[] memory path = new address[](2);
        path[0] = address(KP3R);
        path[1] = address(WETH);

        uint[] memory amounts = UNI.swapExactTokensForTokens(_amount, uint256(0), path, address(this), now.add(1800));
        WETH.withdraw(amounts[1]);
        return amounts[1];
    }

}
