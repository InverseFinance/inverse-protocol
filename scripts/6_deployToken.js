const prompt = require('async-prompt');

async function main() {

    const minter = await prompt('Enter minter/initial holder address: ');
    const INV = await ethers.getContractFactory("INV");
    const inv = await INV.deploy(minter);
    await inv.deployed();
    console.log("INV deployed to:", inv.address);
  }
  
  main()
    .then(() => process.exit(0))
    .catch(error => {
      console.error(error);
      process.exit(1);
    });