async function main() {
    const Payroll = await ethers.getContractFactory("DolaPayroll");
    const payroll = await Payroll.deploy();
    await payroll.deployed();
    console.log("DolaPayroll deployed to:", payroll.address);
}
  
main().then(
    () => process.exit(0)
).catch(
    error => {
        console.error(error);
        process.exit(1);
    }
);