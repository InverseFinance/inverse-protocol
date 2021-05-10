const hre = require('hardhat');
const { expect } = require('chai')

describe('INVVoteAdapterCharlieV1 unit tests', () => {
  const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000';
  const wallet = {};

  // Contract artifacts
  let INVArtifact;
  let VoteAdapterArtifact;

  // Contract instances
  let inv;
  let voteAdapter;

  // Contract parameters
  const weight = 5;

  // Helper functions
  const getVotes = async (account, blockNumber) => {
    return await inv.getPriorVotes(account.address, blockNumber)
  }

  before(async () => {
    // Set up test accounts
    const signers = await hre.ethers.getSigners();
    wallet.deployer = signers[0];
    wallet.receiver = signers[1];

    // Set up contract artifacts
    INVArtifact = await hre.artifacts.readArtifact('INV');
    VoteAdapterArtifact = await hre.artifacts.readArtifact('INVVoteAdapterCharlieV1');
  });

  beforeEach(async() => {
    inv = await hre.waffle.deployContract(
      wallet.deployer,
      INVArtifact,
      [wallet.deployer.address],
    );
    voteAdapter = await hre.waffle.deployContract(
      wallet.deployer,
      VoteAdapterArtifact,
      [inv.address, weight],
    );

    // Ensure that INV is transferable
    await inv.openTheGates();
  });

  it('should deploy', async () => {
    expect(voteAdapter.address.toString()).to.not.equal(ZERO_ADDRESS);
  });

  describe('metadata', () => {
    it('should have the correct token address', async () => {
      expect(await voteAdapter.getToken()).to.equal(inv.address);
    });

    it('should have the initial weight factor', async () => {
      expect(await voteAdapter.weight()).to.equal(weight);
    });
  });

  describe('voting power', () => {
    it('should allow voting weight changes', async () => {
      const newWeight = 10;
      await voteAdapter.setVotingWeight(newWeight);

      expect(await voteAdapter.weight()).to.equal(newWeight);
    });

    it('should return zero for undelegated voters', async () => {
      const previousBlockNumber = (await hre.waffle.provider.getBlockNumber()) - 1;
      const votingPower = await voteAdapter.getVotingPower(
        wallet.deployer.address,
        previousBlockNumber,
      );

      expect(votingPower).to.equal(0);
    });

    it('should return the correct voting power after delegating', async () => {
      const invSupply = hre.ethers.utils.parseUnits('100000', 18);
      await inv.connect(wallet.deployer).delegate(wallet.deployer.address);

      // Votes are stored by checkpointing block numbers. Here we mine a new
      // block to ensure that the transaction containing the `getVotingPower`
      // call is in a separate block.
      await hre.network.provider.send("evm_mine");

      const previousBlockNumber = (await hre.waffle.provider.getBlockNumber()) - 1;
      const votingPower = await voteAdapter.getVotingPower(
        wallet.deployer.address,
        previousBlockNumber,
      );

      expect(votingPower).to.equal(invSupply.mul(weight));
    });
  });
});
