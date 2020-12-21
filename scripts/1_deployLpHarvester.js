const prompt = require('async-prompt')

async function main () {
  // same address for all networks
  const UNISWAP_ROUTER = '0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D'
  const pair = await prompt('Enter Pair address: ')
  const Harvester = await ethers.getContractFactory('LpUniswapHarvester')
  const harvester = await Harvester.deploy(UNISWAP_ROUTER, pair)
  await harvester.deployed()
  console.log('harvester deployed to:', harvester.address)
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error)
    process.exit(1)
  })
