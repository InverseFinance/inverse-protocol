const hre = require('hardhat');
const { expect } = require('chai')

describe('UserProxy unit tests', () => {
  const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000';
  const wallet = {};

  // Contract artifacts
  let UserProxyArtifact;
  let ERC20Artifact;
  let VaultArtifact;

  // Contract instances
  let userProxy;
  let token;
  let vault;

  // Contract parameters
  const tokenName = 'MockToken A';
  const tokenSymbol = 'MTA';
  const tokenSupply = hre.ethers.utils.parseUnits('100', 18);

  before(async () => {
    // Set up test accounts
    const signers = await hre.ethers.getSigners();
    wallet.deployer = signers[0];
    wallet.receiver = signers[1];

    // Set up contract artifacts
    UserProxyArtifact = await hre.artifacts.readArtifact('UserProxy');
    ERC20Artifact = await hre.artifacts.readArtifact('MockToken');
    VaultArtifact = await hre.artifacts.readArtifact('MockVault');
  });

  beforeEach(async() => {
    userProxy = await hre.waffle.deployContract(
      wallet.deployer,
      UserProxyArtifact,
      [],
    );
    token = await hre.waffle.deployContract(
      wallet.deployer,
      ERC20Artifact,
      [tokenName, tokenSymbol, tokenSupply],
    );
    vault = await hre.waffle.deployContract(
      wallet.deployer,
      VaultArtifact,
      [token.address],
    );
  });

  it('should deploy', async () => {
    expect(userProxy.address.toString()).to.not.equal(ZERO_ADDRESS);
  });

  describe('external contract calls', () => {
    it('should call external contract', async () => {
      const getReceiverBalance = async () => {
        return await token.balanceOf(wallet.receiver.address);
      };

      // Balance should be zero at the start
      expect(await getReceiverBalance()).to.equal(0);

      // transfer ownership to allow mint call
      await token.connect(wallet.deployer).transferOwnership(userProxy.address);

      // Calls the `mint(address receiver, uint256 amount)` functions on the mock
      // token contract. For this specific test both the `token` and `amount`
      // parameters are unused.
      const tokenInterface = new hre.ethers.utils.Interface(ERC20Artifact.abi);
      await userProxy.callFunction(
        token.address,
        tokenInterface.encodeFunctionData(
          'mint',
          [wallet.receiver.address, tokenSupply],
        ),
        ZERO_ADDRESS,
        0,
      );

      expect(await getReceiverBalance()).to.equal(tokenSupply);
    });

    it('should call external contract and transfer tokens', async () => {
      const getVaultBalance = async () => {
        return await token.balanceOf(vault.address);
      };

      // Balance should be zero at the start
      expect(await getVaultBalance()).to.equal(0);

      // Transfer funds to proxy. In practice, this should always be done by a
      // managing contract instead of an externally owned address.
      await token.connect(wallet.deployer).transfer(
        userProxy.address,
        tokenSupply,
      );

      const vaultInterface = new hre.ethers.utils.Interface(VaultArtifact.abi);
      await userProxy.callFunction(
        vault.address,
        vaultInterface.encodeFunctionData(
          'deposit',
          [tokenSupply],
        ),
        token.address,
        tokenSupply,
      );

      expect(await getVaultBalance()).to.equal(tokenSupply);
    });
  });
});
