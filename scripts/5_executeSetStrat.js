const prompt = require('async-prompt');

async function main() {

    const vault = await prompt('Enter vault address: ');
    const strat = await prompt('Enter (new) strategy address: ');
    const eta = await prompt('Enter ETA: ');
    let force = await prompt('Force strategy transition without checks? (y/N) ');

    force = force.toLowerCase()

    if(force === "y") force = true
    else if(force === "n") force = false
    else if(force === "") force = false
    else throw new Error("Invalid force choice")

    const vaultContract = await ethers.getContractAt("Vault", vault);
    const timelockAddress = await vaultContract.timelock();
    const timelock = await ethers.getContractAt("Timelock", timelockAddress);
    const signature = "setStrat(address,bool)"
    const abiCoder = new ethers.utils.AbiCoder();
    const data = abiCoder.encode(["address", "bool"], [strat, force]);
    const tx = await timelock.executeTransaction(vault, 0, signature, data, eta);
    console.log("Transaction submitted:", tx.hash);
  }
  
  main()
    .then(() => process.exit(0))
    .catch(error => {
      console.error(error);
      process.exit(1);
    });