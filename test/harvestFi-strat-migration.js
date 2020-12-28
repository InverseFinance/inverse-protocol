const hre = require('hardhat')
const { describe, it, beforeEach } = require('mocha')
const { ethers } = require('hardhat')
const { expect } = require('chai')

const VAULT = '0x41d079ce7282d49bf4888c71b5d9e4a02c371f9b'
const INVERSE_DEPLOYER = '0x3FcB35a1CbFB6007f9BC638D388958Bc4550cB28'
const FDAI = '0xe85c8581e60d7cd32bbfd86303d2a4fa6a951dac'
const DAI = '0x6b175474e89094c44da98b954eedeac495271d0f'

const HARVESTER = '0x7F058B17648a257ADD341aB76FeBC21794c6e118'
const YFI_ADDRESS = '0x0bc529c00C6401aEF6D220BE8C6Ea1667F6Ad93e'
const DAI_BAGS = '0x079667f4f7a0B440Ad35ebd780eFd216751f0758'

const INVDAO_TIMELOCK = '0xD93AC1B3D1a465e1D5ef841c141C8090f2716A16';

const overrides = { gasPrice: ethers.utils.parseUnits('0', 'gwei') }
describe('harvest finance setup', () => {
  let vault, strat;

  it('Should deploy DAI -> YFI Vault', async () => {
    await hre.network.provider.request({
      method: 'hardhat_impersonateAccount',
      params: [INVERSE_DEPLOYER]
    })
    const signer = await ethers.provider.getSigner(INVERSE_DEPLOYER)
    const Vault = (await ethers.getContractFactory('Vault')).connect(signer)
    vault = await Vault.deploy(DAI, YFI_ADDRESS, HARVESTER, 'HARVESTFI: DAI to YFI Vault', 'testDAI>ETH')
    await vault.deployed()
  })

  it('Should deploy fToken strat and connect to Vault', async () => {
    await hre.network.provider.request({
      method: 'hardhat_impersonateAccount',
      params: [INVERSE_DEPLOYER]
    })
    const signer = await ethers.provider.getSigner(INVERSE_DEPLOYER)
    const Strat = (await ethers.getContractFactory('FTokenStrat')).connect(signer)
    strat = await Strat.deploy(vault.address, FDAI, overrides)
    await strat.deployed()
    await vault.setStrat(strat.address, false)
    expect(await vault.strat()).to.equal(strat.address)
    expect(await vault.paused()).to.equal(false)
  })
})

describe('harvest finance strategy experiments', () => {
  let vault, strat;

  beforeEach(async () => {
    await hre.network.provider.request({
      method: 'hardhat_impersonateAccount',
      params: [INVERSE_DEPLOYER]
    })

    const signer = await ethers.provider.getSigner(INVERSE_DEPLOYER)

    const Vault = (await ethers.getContractFactory('Vault')).connect(signer)
    vault = await Vault.deploy(DAI, YFI_ADDRESS, HARVESTER, 'HARVESTFI: DAI to YFI Vault', 'testDAI>ETH')
    await vault.deployed()

    const Strat = (await ethers.getContractFactory('FTokenStrat')).connect(signer)
    strat = await Strat.deploy(vault.address, FDAI, overrides)
    await strat.deployed()
    await vault.setStrat(strat.address, false)
  })

  it('Should deposit (DAI)', async () => {
    await hre.network.provider.request({
      method: 'hardhat_impersonateAccount',
      params: [DAI_BAGS]
    })
    const amount = ethers.utils.parseEther('1000')
    const signer = await ethers.provider.getSigner(DAI_BAGS)
    const dai = (await ethers.getContractAt('IERC20', DAI)).connect(signer)
    const signedVault = vault.connect(signer)

    await dai.approve(signedVault.address, amount)
    await signedVault.deposit(amount)
    expect(await signedVault.balanceOf(await signer.getAddress())).to.equal(amount)
  })

  it('Should deposit then withdraw (DAI)', async () => {
    await hre.network.provider.request({
      method: 'hardhat_impersonateAccount',
      params: [DAI_BAGS]
    })
    const amount = ethers.utils.parseEther('1000')
    const signer = await ethers.provider.getSigner(DAI_BAGS)
    const dai = (await ethers.getContractAt('IERC20', DAI)).connect(signer)
    const signedVault = vault.connect(signer)

    await dai.approve(signedVault.address, amount)
    await signedVault.deposit(amount)
    expect(await signedVault.balanceOf(await signer.getAddress())).to.equal(amount)

    const balance = await signedVault.balanceOf(await signer.getAddress())
    const oldBalance = await dai.balanceOf(DAI_BAGS)
    const tx = await signedVault.withdraw(amount)
    const newBalance = await dai.balanceOf(DAI_BAGS)
    expect(newBalance.sub(oldBalance)).to.equal(balance)
  })

  it('Should only update timelock from timelock', async () => {
    await hre.network.provider.request({
      method: 'hardhat_impersonateAccount',
      params: [INVERSE_DEPLOYER]
    })
    const TIMELOCK_THRESHOLD = 178800 // ~2 days to satifiy timelock
    const signer = await ethers.provider.getSigner(INVERSE_DEPLOYER)
    const attempt = strat.connect(signer)

    await expect(
      attempt.changeTimelock(INVDAO_TIMELOCK)
    ).to.be.revertedWith("CAN ONLY BE CALLED BY TIMELOCK");

    const timelockAddress = await strat.timelock()
    const timelock = await ethers.getContractAt('contracts/Timelock.sol:Timelock', timelockAddress)
    const admin = timelock.connect(signer)

    const currentBlock = await ethers.provider.getBlockNumber()
    const block = await ethers.provider.getBlock(currentBlock)

    const timestamp = block.timestamp + TIMELOCK_THRESHOLD
    const payload = ethers.utils.hexZeroPad(INVDAO_TIMELOCK, 32)
    const stratAddress = await vault.strat()

    await admin.queueTransaction(stratAddress, 0, "changeTimelock(address)", payload, timestamp)

    const future = timestamp + 1000
    await hre.network.provider.request({
      method: 'evm_setNextBlockTimestamp',
      params: [future]
    })

    const tx = await admin.executeTransaction(stratAddress, 0, "changeTimelock(address)", payload, timestamp)
    expect(await strat.timelock()).to.equal(INVDAO_TIMELOCK)
  })
})
