const hre = require('hardhat')
const { describe, it } = require('mocha')
const { ethers } = require('hardhat')
const { expect } = require('chai')

const VAULT = '0x41d079ce7282d49bf4888c71b5d9e4a02c371f9b'
const INVERSE_DEPLOYER = '0x3FcB35a1CbFB6007f9BC638D388958Bc4550cB28'
const FDAI = '0xe85c8581e60d7cd32bbfd86303d2a4fa6a951dac'
const DAI = '0x6b175474e89094c44da98b954eedeac495271d0f'

const HARVESTER = '0x7F058B17648a257ADD341aB76FeBC21794c6e118'
const YFI_ADDRESS = '0x0bc529c00C6401aEF6D220BE8C6Ea1667F6Ad93e'
const DAI_BAGS = '0x079667f4f7a0B440Ad35ebd780eFd216751f0758'

const overrides = {
  gasPrice: ethers.utils.parseUnits('0', 'gwei')
}

describe('harvest finance strategy experiments', function () {
  let strat, vault, dai, weth

  it('Should deploy DAI -> YFI Vault', async function () {
    const Vault = await ethers.getContractFactory('Vault')
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
    strat = await Strat.deploy(vault.address, FDAI, overrides)

    await strat.deployed()
    await vault.setStrat(strat.address, false)

    expect(await vault.strat()).to.equal(strat.address)
    expect(await vault.paused()).to.equal(false)
  })

  it('Should deposit (DAI)', async function () {
    await hre.network.provider.request({
      method: 'hardhat_impersonateAccount',
      params: [DAI_BAGS]
    }
    )
    const signer = await ethers.provider.getSigner(DAI_BAGS)
    strat = strat.connect(signer)

    vault = vault.connect(signer)
    dai = (await ethers.getContractAt('IERC20', DAI)).connect(signer)

    await dai.approve(vault.address, ethers.utils.parseEther('1000'))
    await vault.deposit(ethers.utils.parseEther('1000'))

    expect(await vault.balanceOf(await signer.getAddress())).to.equal(ethers.utils.parseUnits('1000'))
  })
})
