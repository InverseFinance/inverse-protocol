const { ethers } = require('hardhat')
const prompt = require('async-prompt')

async function main () {
  const vault = await prompt('Enter vault address: ')
  const fToken = await prompt('Enter fToken token address: ')
  const rewardpool = await prompt('Enter rewardpool contract address: ')

  const Strat = await ethers.getContractFactory('FTokenStrat')
  const strat = await Strat.deploy(
    vault,
    fToken,
    rewardpool
  )
  await strat.deployed()

  console.log('FTokenStrat deployed to:', strat.address)
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error)
    process.exit(1)
  })
