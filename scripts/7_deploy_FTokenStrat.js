const { ethers } = require('hardhat')
const prompt = require('async-prompt')

async function main () {
  const vault = await prompt('Enter vault address: ')
  const yToken = await prompt('Enter fToken token address: ')

  const Strat = await ethers.getContractFactory('FTokenStrat')
  const strat = await Strat.deploy(
    vault,
    fToken
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
