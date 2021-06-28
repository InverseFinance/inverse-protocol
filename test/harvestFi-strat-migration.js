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

const HARVEST_DEPLOYER = '0xf00dd244228f51547f0563e60bca65a30fbf5f7f'
const NOTIFY_HELPER = '0xe20c31e3d08027f5aface84a3a46b7b3b165053c'
const DELAY_MINTER = '0x284D7200a0Dabb05ee6De698da10d00df164f61d'

const overrides = {
  gasPrice: ethers.utils.parseUnits('0', 'gwei')
}

describe('harvest finance strategy experiments', function () {
  let strat, vault, dai, weth

  it('Deploys DAI -> YFI Vault', async function () {
    await hre.network.provider.request({
      method: 'hardhat_impersonateAccount',
      params: [INVERSE_DEPLOYER]
    })
    const signer = await ethers.provider.getSigner(INVERSE_DEPLOYER)
    let Vault = await ethers.getContractFactory('Vault')
    Vault = Vault.connect(signer)
    vault = await Vault.deploy(DAI, YFI_ADDRESS, HARVESTER, INVDAO_TIMELOCK, 'HARVESTFI: DAI to YFI Vault', 'testDAI>YFI')

    await vault.deployed()
  })

  it('Deploys fToken strat', async function () {
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

  it('Connects strat to Vault', async function () {
    await vault.setStrat(strat.address, false)
    expect(await vault.strat()).to.equal(strat.address)
    expect(await vault.paused()).to.equal(false)
  })

  it('Sets strategist', async function () {
    strat.setStrategist(INVERSE_DEPLOYER)
    expect(await strat.strategist()).to.equal(INVERSE_DEPLOYER)
  })

  it('Sets buffer', async function () {
    await strat.setBuffer(ethers.utils.parseEther('1000'))
    expect(await strat.buffer()).to.equal(ethers.utils.parseEther('1000'))
  })

  it('Reverts unauthorized call to changeTimelock', async function () {
    await expect(
      strat.changeTimelock(INVDAO_TIMELOCK)
    ).to.be.revertedWith("CAN ONLY BE CALLED BY TIMELOCK");
  })

  it('Only updates timelock from timelock', async function () {
    const signer = await ethers.provider.getSigner(INVERSE_DEPLOYER)
    const timelockAddress = await strat.timelock()
    const timelock = await ethers.getContractAt('contracts/misc/Timelock.sol:Timelock', timelockAddress)
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

  it('[Setup harvest deployer and notify reward pools]', async function () {
    await hre.network.provider.request({
      method: 'hardhat_impersonateAccount',
      params: [HARVEST_DEPLOYER]
    })
    const signer = await ethers.provider.getSigner(HARVEST_DEPLOYER)
    const minter = await ethers.getContractAt('IDelayMinter', DELAY_MINTER)
    mint = minter.connect(signer)
    await mint.announceMint(HARVEST_DEPLOYER, ethers.utils.parseEther('12462'))

    const currentBlock = await ethers.provider.getBlockNumber()
    const block = await ethers.provider.getBlock(currentBlock)
    const timestamp = block.timestamp + 178800

    await hre.network.provider.request({
      method: 'evm_setNextBlockTimestamp',
      params: [timestamp]
    })
    const farm = (await ethers.getContractAt('@openzeppelin/contracts/token/ERC20/IERC20.sol:IERC20', await strat.rewardtoken())).connect(signer)
    await farm.approve(DELAY_MINTER, ethers.utils.parseEther('10000'))
    await farm.approve(NOTIFY_HELPER, ethers.utils.parseEther('10000'))

    await mint.executeMint(17)

    const notify = await ethers.getContractAt('INotifyHelper', NOTIFY_HELPER)
    gov = notify.connect(signer)
    await gov.notifyPoolsIncludingProfitShare([ethers.utils.parseEther('6000')],[FARMPOOL], ethers.utils.parseEther('1425'), 1608663600, ethers.utils.parseEther('7425'))
  })

  it('Deposits (DAI)', async function () {
    await hre.network.provider.request({
      method: 'hardhat_impersonateAccount',
      params: [DAI_BAGS]
    })
    const signer = await ethers.provider.getSigner(DAI_BAGS)
    vault = vault.connect(signer)
    const supply = await vault.totalSupply()
    const totalVal = await strat.calcTotalValue()
    const dai = (await ethers.getContractAt('@openzeppelin/contracts/token/ERC20/IERC20.sol:IERC20', DAI)).connect(signer)
    await dai.approve(vault.address, ethers.utils.parseEther('11000000'))
    const vaultBalanceBefore = await vault.balanceOf(DAI_BAGS)
    await vault.deposit(ethers.utils.parseEther('20000'))
    const vaultBalanceAfter = await vault.balanceOf(DAI_BAGS)
    expect(vaultBalanceAfter - ethers.utils.parseEther('20000')).to.equal(vaultBalanceBefore)
  })

  it('[FFW]', async function () {
    const currentBlock = await ethers.provider.getBlockNumber()
    const block = await ethers.provider.getBlock(currentBlock)
    const timestamp = block.timestamp + 1178800

    await hre.network.provider.request({
      method: 'evm_setNextBlockTimestamp',
      params: [timestamp]
    })
  })

  it('Withdraws (DAI)', async function () {
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
    const farm = (await ethers.getContractAt('@openzeppelin/contracts/token/ERC20/IERC20.sol:IERC20', rewardTokenAddress)).connect(signer)
    await farm.approve(strat.address, ethers.utils.parseEther('10000'))
    expect(await farm.balanceOf(strat.address)).to.equal(0)

    const balance = await vault.balanceOf(DAI_BAGS)
    const buffer = await strat.buffer()
    const delta = balance.sub(buffer)

    await vault.withdraw(delta)
    const newBalance = await dai.balanceOf(DAI_BAGS)
    expect(newBalance.sub(oldBalance)).to.equal(ethers.utils.parseEther('19000'))  // -1000 for the buffer
  })

  it('Harvests FARM tokens from strat', async function () {
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

    const balanceDeltaDec = balanceDelta / 10 ** (await dai.decimals())
    console.log("ADDED DAI FROM FARM HARVEST", balanceDeltaDec)
  })

})
