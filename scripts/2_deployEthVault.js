const { ethers } = require('hardhat')
const prompt = require('async-prompt')

async function main () {
  const underlying = await prompt('Enter underlying token address: ')
  const target = await prompt('Enter WETH token address: ')
  const harvester = await prompt('Enter Harvester address: ')
  const timelock = await prompt('Enter Timelock address: ')
  const name = await prompt('Enter Vault ERC20 token name: ')
  const symbol = await prompt('Enter Vault ERC20 token symbol: ')

  const Vault = await ethers.getContractFactory('EthVault')
  const vault = await Vault.deploy(
    underlying,
    target,
    harvester,
    timelock,
    name,
    symbol
  )
  await vault.deployed()

  console.log('ETH vault deployed to:', vault.address)
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error)
    process.exit(1)
  })
