const prompt = require('async-prompt');

async function main() {

    const inv = await prompt('Enter inv token address: ');
    const root = "0xa678988106221a80f9068c764518e2ae53dc22d736d461294145b682bb0ab7e6"
    const Distributor = await ethers.getContractFactory("MerkleDistributor");
    const distributor = await Distributor.deploy(inv, root);
    await distributor.deployed();
    console.log("Distributor deployed to:", distributor.address);
  }
  
  main()
    .then(() => process.exit(0))
    .catch(error => {
      console.error(error);
      process.exit(1);
    });