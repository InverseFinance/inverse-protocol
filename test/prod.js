// mainnet forking integration test
const hre = require('hardhat')
const { ethers } = require('hardhat')
const { describe, it } = require('mocha')
const { expect } = require('chai')

const UNISWAP_ROUTER_ADDRESS = '0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D'
const DAI_ADDRESS = '0x6b175474e89094c44da98b954eedeac495271d0f'
const WETH_ADDRESS = '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2'
const CDAI_ADDRESS = '0x5d3a536E4D6DbD6114cc1Ead35777bAB948E3643'
const IMPERSONATED_ADDRESS = '0x079667f4f7a0B440Ad35ebd780eFd216751f0758' // they got lots of DAI to steal ;)

describe('test in prod', function () {
  let harvester, vault, strat, dai, weth

  it('Should deploy harvester', async function () {
    const Harvester = await ethers.getContractFactory('UniswapHarvester')
    harvester = await Harvester.deploy(UNISWAP_ROUTER_ADDRESS)

    await harvester.deployed()
    expect(await harvester.router()).to.equal(UNISWAP_ROUTER_ADDRESS)
  })

  it('Should deploy DAI -> WETH Vault', async function () {
    const Vault = await ethers.getContractFactory('EthVault')
    vault = await Vault.deploy(DAI_ADDRESS, WETH_ADDRESS, harvester.address, 'Test DAI to ETH Vault', 'testDAI>ETH')

    await vault.deployed()
  })

  it('Should deploy cDai Strat', async function () {
    const Strat = await ethers.getContractFactory('CTokenStrat')
    strat = await Strat.deploy(vault.address, CDAI_ADDRESS)

    await strat.deployed()
  })

  it('Should connect Strat to Vault', async function () {
    await vault.setStrat(strat.address, false)
    expect(await vault.strat()).to.equal(strat.address)
    expect(await vault.paused()).to.equal(false)
  })

  it('Should deposit (DAI)', async function () {
    await hre.network.provider.request({
      method: 'hardhat_impersonateAccount',
      params: [IMPERSONATED_ADDRESS]
    }
    )
    const signer = await ethers.provider.getSigner(IMPERSONATED_ADDRESS)
    vault = vault.connect(signer)
    dai = (await ethers.getContractAt('IERC20', DAI_ADDRESS)).connect(signer)
    await dai.approve(vault.address, ethers.utils.parseEther('1000'))
    await vault.deposit(ethers.utils.parseEther('1000'))
    expect(await vault.balanceOf(await signer.getAddress())).to.equal(ethers.utils.parseUnits('1000'))
  })

  it('Should harvest', async function () {
    const currentBlock = await ethers.provider.getBlockNumber()
    const block = await ethers.provider.getBlock(currentBlock)
    const future = block.timestamp + 178800

    await hre.network.provider.request({
      method: 'evm_setNextBlockTimestamp',
      params: [future]
    }
    )
    await vault.underlyingYield() // we send a tx to compound for it to accrue interest
    const uyield = await vault.callStatic.underlyingYield()
    await harvester.harvestVault(
      vault.address,
      uyield,
      0,
      [DAI_ADDRESS, WETH_ADDRESS],
      future + 10)
    weth = (await ethers.getContractAt('IERC20', WETH_ADDRESS))
    expect(await weth.balanceOf(vault.address)).to.gt(0)
  })

  it('Should claim target token (ETH)', async function () {
    const unclaimedProfits = await vault.unclaimedProfit(IMPERSONATED_ADDRESS)
    expect(unclaimedProfits).to.gt(0)
    const balanceBefore = await ethers.provider.getBalance(IMPERSONATED_ADDRESS)
    const tx = await vault.claimETH({ gasPrice: '1' })
    const receipt = await tx.wait()
    const balanceAfter = await ethers.provider.getBalance(IMPERSONATED_ADDRESS)
    expect(balanceAfter.sub(balanceBefore.sub(receipt.cumulativeGasUsed))).to.equal(unclaimedProfits)
  })

  it('Should withdraw principal (ETH)', async function () {
    const daiBeforeBalance = await dai.balanceOf(IMPERSONATED_ADDRESS)
    await vault.withdraw(ethers.utils.parseEther('1000'))
    const daiAfterBalance = await dai.balanceOf(IMPERSONATED_ADDRESS)
    expect(daiAfterBalance.sub(daiBeforeBalance)).to.equal(ethers.utils.parseEther('1000'))
    expect(await vault.balanceOf(IMPERSONATED_ADDRESS)).to.equal(0)
  })
})
