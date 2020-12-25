const hre = require('hardhat')
const { describe, it } = require('mocha')
const { ethers } = require('hardhat')
const { expect } = require('chai')

const INVERSE_DEPLOYER = '0x3FcB35a1CbFB6007f9BC638D388958Bc4550cB28'
const DEPOSITOR = '0x8A2F5d6D822611BDab08D306aA8F3E3942177417' // has lots of tokens
const WBTC_VAULT = '0xc8f2E91dC9d198edEd1b2778F6f2a7fd5bBeac34'
const CDAI = '0x5d3a536e4d6dbd6114cc1ead35777bab948e3643'
const DAI = '0x6b175474e89094c44da98b954eedeac495271d0f'

const overrides = { gasPrice: ethers.utils.parseUnits('0', 'gwei') }

describe('wbtc vault', () => {
  it('Should deploy new strategy', async () => {
    await hre.network.provider.request({
      method: 'hardhat_impersonateAccount',
      params: [INVERSE_DEPLOYER]
    })
    const signer = await ethers.provider.getSigner(INVERSE_DEPLOYER)
    const Strat = (await ethers.getContractFactory('CTokenStrat')).connect(signer)
    const strat = await Strat.deploy(WBTC_VAULT, CDAI, overrides)
    await strat.deployed()
  })

  it('Should get balance', async () => {
    const vault = await ethers.getContractAt('Vault', WBTC_VAULT)
    const dai = await ethers.getContractAt('IERC20', DAI)
    const vaultBal = await vault.balanceOf(DEPOSITOR)
    const daiBal = await dai.balanceOf(DEPOSITOR)
    expect(String(vaultBal.toString() / 1E18)).to.equal('494506.9802010616')
    expect(String(daiBal.toString() / 1E18)).to.equal('2471.7230865602073')
  })

  it('Should deposit', async () => {
    const amount = ethers.utils.parseEther('2')
    await hre.network.provider.request({
      method: 'hardhat_impersonateAccount',
      params: [DEPOSITOR]
    })
    const signer = await ethers.provider.getSigner(DEPOSITOR)
    const vault = (await ethers.getContractAt('Vault', WBTC_VAULT)).connect(signer)
    const dai = (await ethers.getContractAt('IERC20', DAI)).connect(signer)
    const userBal = await dai.balanceOf(DEPOSITOR)
    const vaultBal = await vault.balanceOf(DEPOSITOR)
    await dai.approve(vault.address, amount)
    const tx = await vault.deposit(amount)
    await tx.wait()
    const newUserBal = await dai.balanceOf(DEPOSITOR)
    const newVaultBal = await vault.balanceOf(DEPOSITOR)
    expect(userBal.sub(newUserBal)).to.equal(amount)
    expect(newVaultBal.sub(vaultBal)).to.equal(amount)
  })

  it('Should withdraw', async () => {
    const amount = ethers.utils.parseEther('2')
    await hre.network.provider.request({
      method: 'hardhat_impersonateAccount',
      params: [DEPOSITOR]
    })
    const signer = await ethers.provider.getSigner(DEPOSITOR)
    const vault = (await ethers.getContractAt('Vault', WBTC_VAULT)).connect(signer)
    const dai = (await ethers.getContractAt('IERC20', DAI)).connect(signer)
    const bal = await dai.balanceOf(DEPOSITOR)
    const tx = await vault.withdraw(amount)
    await tx.wait()
    const newBal = await dai.balanceOf(DEPOSITOR)
    expect(newBal.sub(bal)).to.equal(amount)
  })
})
