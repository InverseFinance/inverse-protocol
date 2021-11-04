const prompt = require('async-prompt');

async function main() {
  const timelock = await prompt('Enter Timelock address: ');
  const inv = await prompt('Enter INV address: ');
  const xinv = await prompt('Enter XINV address: ');
  const Governor = await ethers.getContractFactory("GovernorMills");
    const governor = await Governor.deploy(
      timelock,
      inv,
      xinv
    );
    await governor.deployed();
    console.log("Governor Mills deployed to:", governor.address);
  }
  
  main()
    .then(() => process.exit(0))
    .catch(error => {
      console.error(error);
      process.exit(1);
    });