const prompt = require('async-prompt');

async function main() {

    const inv = await prompt('Enter inv token address: ');
    const Governor = await ethers.getContractFactory("GovernorAlpha");
    const governor = await Governor.deploy(inv);
    await governor.deployed();
    console.log("Governor deployed to:", governor.address);
  }
  
  main()
    .then(() => process.exit(0))
    .catch(error => {
      console.error(error);
      process.exit(1);
    });