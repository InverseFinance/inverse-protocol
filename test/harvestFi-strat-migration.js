const hre = require('hardhat')
const { describe, it } = require('mocha')
const { ethers } = require('hardhat')
const { expect } = require('chai')

const INVERSE_DEPLOYER = '0x3FcB35a1CbFB6007f9BC638D388958Bc4550cB28'
const FTOKEN = '0xab7fa2b2985bccfc13c6d86b1d5a17486ab1e04c'
const DAI = '0x6b175474e89094c44da98b954eedeac495271d0f'

const HARVESTER = '0x7F058B17648a257ADD341aB76FeBC21794c6e118'
const YFI_ADDRESS = '0x0bc529c00C6401aEF6D220BE8C6Ea1667F6Ad93e'
const DAI_BAGS = '0x648148a0063b9d43859d9801f2bf9bb768e22142'

const INVDAO_TIMELOCK = '0xD93AC1B3D1a465e1D5ef841c141C8090f2716A16'
const FARMPOOL = '0x15d3A64B2d5ab9E152F16593Cdebc4bB165B5B4A'
const UNISWAP_ROUTER = '0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D'

const overrides = {
  gasPrice: ethers.utils.parseUnits('0', 'gwei')
}

describe('harvest finance strategy experiments', function () {
  let strat, vault, dai, weth

  it('Should deploy DAI -> YFI Vault', async function () {
    await hre.network.provider.request({
      method: 'hardhat_impersonateAccount',
      params: [INVERSE_DEPLOYER]
    })
    const signer = await ethers.provider.getSigner(INVERSE_DEPLOYER)
    let Vault = await ethers.getContractFactory('Vault')
    Vault = Vault.connect(signer)
    vault = await Vault.deploy(DAI, YFI_ADDRESS, HARVESTER, 'HARVESTFI: DAI to YFI Vault', 'testDAI>YFI')

    await vault.deployed()
  })

  it('Should deploy fToken strat', async function () {
    await hre.network.provider.request({
      method: 'hardhat_impersonateAccount',
      params: [INVERSE_DEPLOYER]
    })

    const signer = await ethers.provider.getSigner(INVERSE_DEPLOYER)
    let Strat = await ethers.getContractFactory('FTokenStrat')
    Strat = Strat.connect(signer)
    strat = await Strat.deploy(vault.address, FTOKEN, FARMPOOL, UNISWAP_ROUTER, overrides)

    await strat.deployed()
  })

  it('Should connect strat to Vault', async function () {
    await vault.setStrat(strat.address, false)
    expect(await vault.strat()).to.equal(strat.address)
    expect(await vault.paused()).to.equal(false)
  })

  it('Should set strategist', async function () {
    strat.setStrategist(INVERSE_DEPLOYER)
    expect(await strat.strategist()).to.equal(INVERSE_DEPLOYER)
  })

  it('Should set buffer', async function () {
    await strat.setBuffer(ethers.utils.parseEther('5000'))
    expect(await strat.buffer()).to.equal(ethers.utils.parseEther('5000'))
  })

  it('Should revert unauthorized call to changeTimelock', async function () {
    await expect(
      strat.changeTimelock(INVDAO_TIMELOCK)
    ).to.be.revertedWith("CAN ONLY BE CALLED BY TIMELOCK");
  })

  it('Should only update timelock from timelock', async function () {
    const signer = await ethers.provider.getSigner(INVERSE_DEPLOYER)
    const timelockAddress = await strat.timelock()
    const timelock = await ethers.getContractAt('contracts/Timelock.sol:Timelock', timelockAddress)
    admin = timelock.connect(signer)

    const currentBlock = await ethers.provider.getBlockNumber()
    const block = await ethers.provider.getBlock(currentBlock)
    const timestamp = block.timestamp + 178800
    const payload = ethers.utils.hexZeroPad(INVDAO_TIMELOCK, 32)
    const stratAddress = await vault.strat()
    await admin.queueTransaction(stratAddress, 0, "changeTimelock(address)", payload, timestamp)
    const future = timestamp + 1000
    await hre.network.provider.request({
      method: 'evm_setNextBlockTimestamp',
      params: [future]
    })
    await admin.executeTransaction(stratAddress, 0, "changeTimelock(address)", payload, timestamp)
    expect(await strat.timelock()).to.equal(INVDAO_TIMELOCK)
  })

  it('Should deposit (DAI)', async function () {
    await hre.network.provider.request({
      method: 'hardhat_impersonateAccount',
      params: [DAI_BAGS]
    })
    const signer = await ethers.provider.getSigner(DAI_BAGS)
    vault = vault.connect(signer)
    const dai = (await ethers.getContractAt('IERC20', DAI)).connect(signer)
    await dai.approve(vault.address, ethers.utils.parseEther('11000000'))
    const vaultBalanceBefore = await vault.balanceOf(DAI_BAGS)
    await vault.deposit(ethers.utils.parseEther('10000'))
    const vaultBalanceAfter = await vault.balanceOf(DAI_BAGS)
    expect(vaultBalanceAfter - ethers.utils.parseEther('10000')).to.equal(vaultBalanceBefore)
  })

  it('Should withdraw (DAI)', async function () {
    const currentBlock = await ethers.provider.getBlockNumber()
    const block = await ethers.provider.getBlock(currentBlock)
    const timestamp = block.timestamp + 178800
    await hre.network.provider.request({
      method: 'evm_setNextBlockTimestamp',
      params: [timestamp]
    })

    await hre.network.provider.request({
      method: 'hardhat_impersonateAccount',
      params: [DAI_BAGS]
    })
    const signer = await ethers.provider.getSigner(DAI_BAGS)
    strat = strat.connect(signer)
    vault = vault.connect(signer)
    dai = (await ethers.getContractAt('IERC20Detailed', DAI)).connect(signer)

    const oldBalance = await dai.balanceOf(DAI_BAGS)
    const rewardTokenAddress = await strat.rewardtoken()
    const farm = (await ethers.getContractAt('IERC20', rewardTokenAddress)).connect(signer)
    await farm.approve(strat.address, ethers.utils.parseEther('10000'))
    expect(await farm.balanceOf(strat.address)).to.equal(0)

    await vault.withdraw(ethers.utils.parseEther('100'))
    const newBalance = await dai.balanceOf(DAI_BAGS)
    expect(newBalance.sub(oldBalance)).to.equal(ethers.utils.parseEther('100'))
  })

  it('Should yield greater than 0 FARM tokens', async function () {
    const signer = await ethers.provider.getSigner(DAI_BAGS)
    const rewardTokenAddress = await strat.rewardtoken()
    const farm = (await ethers.getContractAt('IERC20', rewardTokenAddress)).connect(signer)
    const farmBalance = await farm.balanceOf(strat.address)
    expect(farmBalance).to.gt(0)
  })


  it('Should harvest FARM tokens from strat', async function () {
    const signer = await ethers.provider.getSigner(INVERSE_DEPLOYER)
    strat = strat.connect(signer)

    const outmin = 1
    path = [ await strat.rewardtoken(), DAI]
    const currentBlock = await ethers.provider.getBlockNumber()
    const block = await ethers.provider.getBlock(currentBlock)
    const deadline = block.timestamp + 1000

    const oldBalance = await dai.balanceOf(strat.address)
    const harvested = await strat.harvestRewardToken(outmin, path, deadline, overrides)
    const newBalance = await dai.balanceOf(strat.address)
    const balanceDelta = newBalance - oldBalance
    expect(balanceDelta).to.gt(0)

    //const balanceDeltaDec = balanceDelta / 10 ** (await dai.decimals())
    //console.log("ADDED DAI FROM FARM HARVEST", balanceDeltaDec)

  })

})
