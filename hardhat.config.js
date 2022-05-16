const { task } = require('hardhat/config')
const { submitArcherTransaction, getTip } = require('./src/utils')

require('@nomiclabs/hardhat-etherscan')
require('@nomiclabs/hardhat-waffle')
require('dotenv').config()

task('user-info', 'Check vault user info')
  .addParam('vault', 'vault address')
  .addParam('user', 'user address')
  .setAction(async args => {
    const vault = await ethers.getContractAt('Vault', args.vault)
    const vaultBalance = await vault.balanceOf(args.user)
    const vaultSymbol = await vault.symbol()
    const vaultDecimals = await vault.decimals()
    const underlying = await ethers.getContractAt('ERC20', await vault.underlying())
    const underlyingBalance = await underlying.balanceOf(args.user)
    const underlyingSymbol = await underlying.symbol()
    const underlyingDecimals = await underlying.decimals()
    const target = await ethers.getContractAt('ERC20', await vault.target())
    const targetBalance = await target.balanceOf(args.user)
    const targetSymbol = await target.symbol()
    const targetDecimals = await target.decimals()
    const unclaimedProfit = await vault.unclaimedProfit(args.user)
    console.log('Vault Balance:', ethers.utils.formatUnits(vaultBalance, vaultDecimals), vaultSymbol)
    console.log('Underlying Balance:', ethers.utils.formatUnits(underlyingBalance, underlyingDecimals), underlyingSymbol)
    console.log('Target Balance:', ethers.utils.formatUnits(targetBalance, targetDecimals), targetSymbol)
    console.log('Claimable Profit:', ethers.utils.formatUnits(unclaimedProfit, targetDecimals), targetSymbol)
  })

task('deposit', 'Deposit underlying to a vault')
  .addParam('vault', 'vault address')
  .addParam('amount', 'underlying token amount')
  .setAction(async args => {
    const vault = await ethers.getContractAt('Vault', args.vault)
    const underlying = await ethers.getContractAt('IERC20Detailed', await vault.underlying())
    const decimals = await underlying.decimals()
    const approveTx = await underlying.approve(vault.address, ethers.utils.parseUnits(args.amount, decimals))
    console.log('Waiting for approve:', approveTx.hash)
    await approveTx.wait(3)
    const tx = await vault.deposit(ethers.utils.parseUnits(args.amount, decimals))
    console.log('Deposit tx:', tx.hash)
  })

task('claim', 'Claim profit from a vault')
  .addParam('vault', 'vault address')
  .setAction(async args => {
    const vault = await ethers.getContractAt('Vault', args.vault)
    const userAddress = await (await ethers.getSigners())[0].getAddress()
    const unclaimedProfit = await vault.unclaimedProfit(userAddress)
    const target = await ethers.getContractAt('ERC20', await vault.target())
    const decimals = await target.decimals()
    const symbol = await target.symbol()
    console.log('Claiming', ethers.utils.formatUnits(unclaimedProfit, decimals), symbol)
    const tx = await vault.claim()
    console.log('Claim tx:', tx.hash)
  })

task('harvest', 'Harvest a vault')
  .addParam('vault', 'vault address')
  .addOptionalParam('amount', 'amount to harvest')
  .setAction(async args => {
    const vault = await ethers.getContractAt('Vault', args.vault)
    const underlyingAddress = await vault.underlying()
    const targetAddress = await vault.target()
    const decimals = await vault.decimals()
    const tipHarvester = await ethers.getContractAt('TipHarvester', await vault.harvester())
    if (!args.amount) {
      args.amount = await vault.callStatic.underlyingYield()
    } else {
      args.amount = ethers.utils.parseUnits(args.amount, decimals)
    }
    if(args.amount.gt(0)) {
      console.log("Harvesting", ethers.utils.formatUnits(args.amount, decimals))
      const deadline = Math.ceil(Date.now()/1000) + 3600 // 1 hour from now
      let path = [underlyingAddress, targetAddress]
      // TODO: Find best path dynamically
      const weth = "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2"
      if(targetAddress.toLowerCase() !== weth.toLowerCase()) {
        path = [underlyingAddress, weth, targetAddress]
      }
      const provider = ethers.getDefaultProvider()
      const estimate = await provider.estimateGas({
        to: tipHarvester.address,
        data: (await tipHarvester.populateTransaction.harvestVault(args.vault, args.amount, 0, path, deadline))['data']
      })
      
      const tip = await getTip('standard')
      // creating wallet as etherssigner.signTransaction not supported
      const privateKey = (await provider.getNetwork()).chainId == 1 ? process.env.MAINNET_PRIVKEY : process.env.RINKEBY_PRIVKEY
      const deployer = new ethers.Wallet(privateKey, provider)
      const nonce = await deployer.getTransactionCount()
      const unsignedTx = await tipHarvester.populateTransaction.harvestVault(args.vault, args.amount, 0, path, deadline, {
        gasLimit: Math.max(estimate, 1000000),
        nonce: nonce,
        value: tip
      })
      
      // sign transaction and send to Archer DAO relay server
      const signedTx = await deployer.signTransaction(unsignedTx)
      const response = await submitArcherTransaction(signedTx, deadline)
      const data = response.data;
      console.log(`Response from Archer DAO relay, status: ${response.status}, data: ${JSON.stringify(data)}`)
    } else {
      console.log("Nothing to Harvest. Skipping.")
    }
  })

task('changeHarvester', 'Change a vault harvester')
  .addParam('vault', 'vault address')
  .addParam('harvester', 'harvester address')
  .setAction(async args => {
    const vault = await ethers.getContractAt('Vault', args.vault)
    const tx = await vault.changeHarvester(args.harvester)
    console.log(tx.hash)
  })

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  networks: {
    hardhat: {
      forking: {
        url: `https://eth-mainnet.alchemyapi.io/v2/${process.env.ALCHEMY_KEY}`,
        blockNumber: 11589707	
      }
    },
    rinkeby: {
      url: `https://eth-rinkeby.alchemyapi.io/v2/${process.env.ALCHEMY_KEY}`,
      accounts: [process.env.RINKEBY_PRIVKEY]
    },
    live: {
      url: `https://eth-mainnet.alchemyapi.io/v2/${process.env.ALCHEMY_KEY}`,
      accounts: [process.env.MAINNET_PRIVKEY]
    }
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY
  },
  solidity: {
    compilers: [
      {
        version: '0.7.3'
      },
      {
        version: '0.5.16'
      },
      {
        version: '0.6.11'
      }
    ]
  },
  namedAccounts: {
    tipJar: {
      1: '0x5312B0d160E16feeeec13437a0053009e7564287',
      4: '0x914528335B5d031c93Ac86e6F6A6C67052Eb44f0'
    },
    deployer: {
      defualt: 0
    }
  }
}
