const prompt = require('async-prompt');

async function main() {

    const inv = await prompt('Enter inv token address: ');
    const MultiDelegator = await ethers.getContractFactory("MultiDelegator");
    const multiDelegator = await MultiDelegator.deploy(inv);
    await multiDelegator.deployed();
    console.log("MultiDelegator deployed to:", multiDelegator.address);
  }
  
  main()
    .then(() => process.exit(0))
    .catch(error => {
      console.error(error);
      process.exit(1);
    });