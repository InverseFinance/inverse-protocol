const hre = require('hardhat')
const { describe, it } = require('mocha')
const { ethers } = require('hardhat')
const { expect } = require('chai')

const VAULT = '0x41d079ce7282d49bf4888c71b5d9e4a02c371f9b'
const INVERSE_DEPLOYER = '0x3FcB35a1CbFB6007f9BC638D388958Bc4550cB28'
const FTOKEN = '0xab7fa2b2985bccfc13c6d86b1d5a17486ab1e04c'
const DAI = '0x6b175474e89094c44da98b954eedeac495271d0f'

const HARVESTER = '0x7F058B17648a257ADD341aB76FeBC21794c6e118'
const YFI_ADDRESS = '0x0bc529c00C6401aEF6D220BE8C6Ea1667F6Ad93e'
const DAI_BAGS = '0x079667f4f7a0B440Ad35ebd780eFd216751f0758'

const INVDAO_TIMELOCK = '0xD93AC1B3D1a465e1D5ef841c141C8090f2716A16'
const FARMPOOL = '0x15d3A64B2d5ab9E152F16593Cdebc4bB165B5B4A'

const overrides = {
  gasPrice: ethers.utils.parseUnits('0', 'gwei')
}

describe('harvest finance strategy experiments', function () {
  let strat, vault, dai, weth

  it('Should deploy DAI -> YFI Vault', async function () {
    await hre.network.provider.request({
      method: 'hardhat_impersonateAccount',
      params: [INVERSE_DEPLOYER]
    }
    )
    const signer = await ethers.provider.getSigner(INVERSE_DEPLOYER)
    let Vault = await ethers.getContractFactory('Vault')
    Vault = Vault.connect(signer)
    vault = await Vault.deploy(DAI, YFI_ADDRESS, HARVESTER, 'HARVESTFI: DAI to YFI Vault', 'testDAI>ETH')

    await vault.deployed()
  })

  it('Should deploy fToken strat and connect to Vault', async function () {
    await hre.network.provider.request({
      method: 'hardhat_impersonateAccount',
      params: [INVERSE_DEPLOYER]
    }
    )

    const signer = await ethers.provider.getSigner(INVERSE_DEPLOYER)
    let Strat = await ethers.getContractFactory('FTokenStrat')
    Strat = Strat.connect(signer)
    strat = await Strat.deploy(vault.address, FTOKEN, FARMPOOL, overrides)

    await strat.deployed()
    await vault.setStrat(strat.address, false)

    expect(await vault.strat()).to.equal(strat.address)
    expect(await vault.paused()).to.equal(false)
  })

  it('Should should set strategist and set buffer', async function () {
    await strat.setStrategist(INVERSE_DEPLOYER)
    await strat.setBuffer(ethers.utils.parseEther('5000'))

    expect(await strat.buffer()).to.equal(ethers.utils.parseEther('5000'))
    expect(await strat.strategist()).to.equal(INVERSE_DEPLOYER)
  })

  it('Should deposit (DAI)', async function () {
    await hre.network.provider.request({
      method: 'hardhat_impersonateAccount',
      params: [DAI_BAGS]
    }
    )
    const signer = await ethers.provider.getSigner(DAI_BAGS)
    vault = vault.connect(signer)
    dai = (await ethers.getContractAt('IERC20', DAI)).connect(signer)
    await dai.approve(vault.address, ethers.utils.parseEther('11000000'))

    const vaultBalanceBefore = await vault.balanceOf(DAI_BAGS)
    await vault.deposit(ethers.utils.parseEther('20000'))
    const vaultBalanceAfter = await vault.balanceOf(DAI_BAGS)

    expect(vaultBalanceAfter - ethers.utils.parseEther('20000')).to.equal(vaultBalanceBefore)
  })

  it('Should only update timelock from timelock', async function () {
    await hre.network.provider.request({
      method: 'hardhat_impersonateAccount',
      params: [INVERSE_DEPLOYER]
    }
    )

    const signer = await ethers.provider.getSigner(INVERSE_DEPLOYER)
    attempt = strat.connect(signer)

    await expect(
      attempt.changeTimelock(INVDAO_TIMELOCK)
    ).to.be.revertedWith("CAN ONLY BE CALLED BY TIMELOCK");

    const timelockAddress = await strat.timelock()

    timelock = await ethers.getContractAt('contracts/Timelock.sol:Timelock', timelockAddress)
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
    }
    )

    tx = await admin.executeTransaction(stratAddress, 0, "changeTimelock(address)", payload, timestamp)

    expect(await strat.timelock()).to.equal(INVDAO_TIMELOCK)
  })

  it('Should withdraw (DAI)', async function () {
    await hre.network.provider.request({
      method: 'hardhat_impersonateAccount',
      params: [DAI_BAGS]
    }
    )
    const signer = await ethers.provider.getSigner(DAI_BAGS)
    strat = strat.connect(signer)

    vault = vault.connect(signer)
    dai = (await ethers.getContractAt('IERC20', DAI)).connect(signer)

    const oldBalance = await dai.balanceOf(DAI_BAGS)

    rewardTokenAddress = await strat.rewardtoken()
    farm = (await ethers.getContractAt('IERC20', rewardTokenAddress)).connect(signer)

    expect(await farm.balanceOf(strat.address)).to.equal(0)

    const tx = await vault.withdraw(ethers.utils.parseEther('1000'))

    const newBalance = await dai.balanceOf(DAI_BAGS)

    expect(newBalance.sub(oldBalance)).to.equal(ethers.utils.parseEther('1000'))
  })

  it('Should should yield FARM tokens', async function () {
    rewardTokenAddress = await strat.rewardtoken()
    const signer = await ethers.provider.getSigner(DAI_BAGS)
    farm = (await ethers.getContractAt('IERC20', rewardTokenAddress)).connect(signer)
    const farmBalance = await farm.balanceOf(strat.address)
    expect(farmBalance).to.gt(0)
  })
})
