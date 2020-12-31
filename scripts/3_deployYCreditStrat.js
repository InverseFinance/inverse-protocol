const { ethers } = require('hardhat')
const prompt = require('async-prompt')

async function main () {
  const vault = await prompt('Enter vault address: ')
  const timelock = await prompt('Enter Timelock address: ')

  const Strat = await ethers.getContractFactory('YCreditStrat')
  const strat = await Strat.deploy(
    vault,
    timelock
  )
  await strat.deployed()

  console.log('YCreditStrat deployed to:', strat.address)
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error)
    process.exit(1)
  })
