const { ethers } = require("hardhat")
const { expect } = require("chai");

const VAULT = "0x2dCdCA085af2E258654e47204e483127E0D8b277"
const GUEST_LIST = "0xcB16133a37Ef19F90C570B426292BDcca185BF47"
const INVERSE_DEPLOYER = "0x3FcB35a1CbFB6007f9BC638D388958Bc4550cB28"
const YDAI = "0xBFa4D8AA6d8a379aBFe7793399D3DdaCC5bBECBB"
const DEPOSITOR = "0x7a22e7a4d912231f9c0fb6760c59ab560188360b" // has over 21k tokens
const TIMELOCK = "0x446Ce1FcFF45F2A9066B7E2B4198db48e79e1bf0"
const CTOKEN_STRAT = "0x42bE0F4FA30980f8261325E9C8Fc9CBd08dE9D6C"
const DAI = "0x6b175474e89094c44da98b954eedeac495271d0f"

const overrides = {
    gasPrice:ethers.utils.parseUnits("0", "gwei")
}

describe("yearn v2 migration", function() {

    let strat, vault, dai;

    it("Should deploy new strategy", async function() {
        await hre.network.provider.request({
            method: "hardhat_impersonateAccount",
            params: [INVERSE_DEPLOYER]}
        )
        const signer = await ethers.provider.getSigner(INVERSE_DEPLOYER);
        let Strat = await ethers.getContractFactory("YTokenStrat");
        Strat = Strat.connect(signer)
        strat = await Strat.deploy(VAULT, YDAI, overrides);

        await strat.deployed();
    })

    it("Should whitelist strategy", async function() {
        const signer = await ethers.provider.getSigner(INVERSE_DEPLOYER);
        let guestList = await ethers.getContractAt("GuestList", GUEST_LIST);
        guestList = guestList.connect(signer);
        const tx = await guestList.invite_guest(strat.address, overrides);
        await tx.wait()
        expect(await guestList.authorized(strat.address, ethers.utils.parseEther("250000"))).to.equal(true);
    })

    it("Should set strategy", async function() {
        await hre.network.provider.request({
            method: "hardhat_impersonateAccount",
            params: [TIMELOCK]}
        )
        const cTokenStrat = await ethers.getContractAt("IStrat", CTOKEN_STRAT);
        const totalValue = await cTokenStrat.callStatic.calcTotalValue()
        const timelock = await ethers.provider.getSigner(TIMELOCK);
        vault = await ethers.getContractAt("EthVault", VAULT);
        vault = vault.connect(timelock)
        const tx = await vault.setStrat(strat.address, true, overrides);
        await tx.wait()
        const oldStratValue = await cTokenStrat.callStatic.calcTotalValue()
        expect(oldStratValue).to.lt(ethers.utils.parseEther("1"));
        const newStratValue = await strat.calcTotalValue()
        expect(totalValue.sub(newStratValue)).to.lt(ethers.utils.parseEther("1"))
    })

    it("Should withdraw", async function() {
        const amount = ethers.utils.parseEther("1435.000000000000000009")
        await hre.network.provider.request({
            method: "hardhat_impersonateAccount",
            params: [DEPOSITOR]}
        )
        const signer = await ethers.provider.getSigner(DEPOSITOR);
        vault = vault.connect(signer)
        dai = await ethers.getContractAt("IERC20", DAI);
        dai = dai.connect(signer);
        const oldBalance = await dai.balanceOf(DEPOSITOR);
        const tx = await vault.withdraw(amount);
        await tx.wait()
        const newBalance = await dai.balanceOf(DEPOSITOR)
        expect(newBalance.sub(oldBalance)).to.equal(amount)
    })

})