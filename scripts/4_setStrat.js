const prompt = require('async-prompt');

async function main() {

    const vault = await prompt('Enter vault address: ');
    const strat = await prompt('Enter (new) strategy address: ');
    let force = await prompt('Force strategy transition without checks? (y/N) ');

    force = force.toLowerCase()

    if(force === "y") force = true
    else if(force === "n") force = false
    else if(force === "") force = false
    else throw new Error("Invalid force choice")

    const vaultContract = await ethers.getContractAt("Vault", vault);
    const tx = await vaultContract.setStrat(strat, force)
    console.log("Transaction submitted:", tx.hash);
  }
  
  main()
    .then(() => process.exit(0))
    .catch(error => {
      console.error(error);
      process.exit(1);
    });