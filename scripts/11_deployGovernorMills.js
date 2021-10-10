async function main() {

    const Governor = await ethers.getContractFactory("GovernorMills");
    const governor = await Governor.deploy();
    await governor.deployed();
    console.log("Governor Mills deployed to:", governor.address);
  }
  
  main()
    .then(() => process.exit(0))
    .catch(error => {
      console.error(error);
      process.exit(1);
    });