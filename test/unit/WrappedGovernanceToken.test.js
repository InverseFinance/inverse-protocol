const hre = require('hardhat');
const { expect } = require('chai')

describe('WrappedGovernanceToken unit tests', () => {
  const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000';
  const wallet = {};

  // Contract artifacts
  let ERC20Artifact;
  let VaultArtifact;
  let WGTArtifact;

  // Contract instances
  let tokenA;
  let tokenB;
  let vaultA;
  let vaultB;
  let wgt;

  // Contract parameters
  const tokenAName = 'MockToken A';
  const tokenASymbol = 'MTA';
  const tokenASupply = hre.ethers.utils.parseUnits('100', 18);
  const tokenBName = 'MockToken B';
  const tokenBSymbol = 'MTB';
  const tokenBSupply = hre.ethers.utils.parseUnits('500', 18);
  const wgtName = `WGT ${tokenAName}`;
  const wgtSymbol = `w${tokenASymbol}`;

  // Helper functions
  const getTokenBalance = async (token, account) => {
    return await token.balanceOf(account.address);
  }

  const getVotes = async (account, blockNumber) => {
    return await wgt.getPriorVotes(account.address, blockNumber)
  }

  before(async () => {
    // Set up test accounts
    const signers = await hre.ethers.getSigners();
    wallet.deployer = signers[0];
    wallet.delegate = signers[1];
    wallet.receiver = signers[2];

    // Set up contract artifacts
    ERC20Artifact = await hre.artifacts.readArtifact('MockToken');
    WGTArtifact = await hre.artifacts.readArtifact('WrappedGovernanceToken');
    VaultArtifact = await hre.artifacts.readArtifact('MockVault');
  });

  beforeEach(async() => {
    tokenA = await hre.waffle.deployContract(
      wallet.deployer,
      ERC20Artifact,
      [tokenAName, tokenASymbol, tokenASupply],
    );
    wgt = await hre.waffle.deployContract(
      wallet.deployer,
      WGTArtifact,
      [
        tokenA.address,
        wgtName,
        wgtSymbol,
      ],
    );
  });

  it('should deploy', async () => {
    expect(wgt.address.toString()).to.not.equal(ZERO_ADDRESS);
  });

  describe('metadata', () => {
    it('should have the name prefix', async () => {
      expect(await wgt.name()).to.equal(wgtName);
    });

    it('should have the symbol prefix', async () => {
      expect(await wgt.symbol()).to.equal(wgtSymbol);
    });

    it('should have the same number of decimals', async () => {
      expect(await tokenA.decimals()).to.equal(18);
      expect(await wgt.decimals()).to.equal(await tokenA.decimals());
    });
  });

  describe('minting and burning', () => {
    it('should deploy with zero token balance', async () => {
      expect(await getTokenBalance(wgt, wallet.deployer)).to.equal(0);
    });

    it('should deploy with user proxies set to the zero address', async () => {
      expect(await wgt.proxies(wallet.deployer.address)).to.equal(ZERO_ADDRESS);
    });

    it('should mint tokens on deposit', async () => {
      await tokenA.connect(wallet.deployer).approve(wgt.address, tokenASupply);
      await wgt.connect(wallet.deployer).deposit(tokenASupply);

      expect(await getTokenBalance(wgt, wallet.deployer)).to.equal(tokenASupply);
    });

    it('should deploy a UserProxy contract if user had none', async () => {
      await tokenA.connect(wallet.deployer).approve(wgt.address, tokenASupply);
      await wgt.connect(wallet.deployer).deposit(tokenASupply);

      expect(await wgt.proxies(wallet.deployer.address)).to.not.equal(ZERO_ADDRESS);
    });

    it('should allow partial withdrawals', async () => {
      await tokenA.connect(wallet.deployer).approve(wgt.address, tokenASupply);
      await wgt.connect(wallet.deployer).deposit(tokenASupply);

      const withdrawAmount = tokenASupply.div(2);
      await wgt.connect(wallet.deployer).withdraw(withdrawAmount);

      expect(await getTokenBalance(tokenA, wallet.deployer)).to.equal(withdrawAmount);
      expect(await getTokenBalance(wgt, wallet.deployer)).to.equal(tokenASupply.sub(withdrawAmount));
    });

    it('should allow full withdrawals', async() => {
      await tokenA.connect(wallet.deployer).approve(wgt.address, tokenASupply);
      await wgt.connect(wallet.deployer).deposit(tokenASupply);
      await wgt.connect(wallet.deployer).withdraw(tokenASupply);

      expect(await getTokenBalance(tokenA, wallet.deployer)).to.equal(tokenASupply);
      expect(await getTokenBalance(wgt, wallet.deployer)).to.equal(0);
    });
  });

  describe('delegation', () => {
    it('should deploy with no delegate set', async () => {
      expect(await wgt.delegates(wallet.deployer.address)).to.equal(ZERO_ADDRESS);
    });

    it('should return 0 votes if no delegate is set', async () => {
      const previousBlock = (await hre.waffle.provider.getBlockNumber()) - 1;

      expect(await getVotes(wallet.deployer, previousBlock)).to.equal(0);
    });

    it('should allow self-delegation', async () => {
      await wgt.connect(wallet.deployer).delegate(wallet.deployer.address);

      expect(await wgt.delegates(wallet.deployer.address)).to.equal(wallet.deployer.address);
    });

    it('should allow delegating to another address', async () => {
      await wgt.connect(wallet.deployer).delegate(wallet.delegate.address);

      expect(await wgt.delegates(wallet.deployer.address)).to.equal(wallet.delegate.address);
    });

    it('should allow delegation by signature', async () => {
      // TODO
    });

    it('should allow batch delegation by signatures', async () => {
      // TODO
    });
  });

  describe('utilization', () => {
    // Utilization specific parameters
    const functionSignature = 'mint(address,uint256)';
    const encodedHash = hre.ethers.utils.keccak256(
      hre.ethers.utils.defaultAbiCoder.encode(
        ['string'],
        [functionSignature],
      ),
    );

    it('should not have registered function from the start', async () => {
      // This does not guarantee that no other functions have been set, but does
      // allow the rest of the tests to assume that this specific function was
      // not set at construction.
      expect(await wgt.functionsPerContract(tokenA.address, encodedHash)).to.equal(false);
    });

    it('should allow adding contract functions', async () => {
      expect(await wgt.functionsPerContract(tokenA.address, encodedHash)).to.equal(false);

      await wgt.addContractFunction(tokenA.address, functionSignature);
      expect(await wgt.functionsPerContract(tokenA.address, encodedHash)).to.equal(true);
    });

    it('should allow removal of contract functions', async () => {
      await wgt.addContractFunction(tokenA.address, functionSignature);
      expect(await wgt.functionsPerContract(tokenA.address, encodedHash)).to.equal(true);

      await wgt.removeContractFunction(tokenA.address, functionSignature);
      expect(await wgt.functionsPerContract(tokenA.address, encodedHash)).to.equal(false);
    });

    describe('external contract calls', () => {
      beforeEach(async () => {
        // Deposit tokens to deploy UserProxy contract
        await tokenA.connect(wallet.deployer).approve(wgt.address, tokenASupply);
        await wgt.connect(wallet.deployer).deposit(tokenASupply);

        // Deploy extra token to test calling external contracts without using
        // the underlying functionality
        tokenB = await hre.waffle.deployContract(
          wallet.deployer,
          ERC20Artifact,
          [tokenBName, tokenBSymbol, tokenBSupply],
        );

        // Deploy vaults to test calling external contracts that return tokens
        vaultA = await hre.waffle.deployContract(
          wallet.deployer,
          VaultArtifact,
          [tokenA.address],
        );
        vaultB = await hre.waffle.deployContract(
          wallet.deployer,
          VaultArtifact,
          [tokenB.address],
        );

        // Mint tokens to deposit into their respective vaults
        await tokenA.connect(wallet.deployer).mint(
          vaultA.address,
          tokenASupply,
        );
        await tokenB.connect(wallet.deployer).mint(
          vaultB.address,
          tokenBSupply,
        );
      });

      it('should allow registered contract function calls', async () => {
        await wgt.connect(wallet.deployer).addContractFunction(
          tokenB.address,
          functionSignature,
        );

        const mintCallData = hre.ethers.utils.defaultAbiCoder.encode(
          ['address', 'uint256'],
          [wallet.receiver.address, tokenBSupply],
        );

        // Transfer ownership to user's UserProxy instance to allow mint call.
        const userProxy = await wgt.proxies(wallet.deployer.address);
        await tokenB.connect(wallet.deployer).transferOwnership(userProxy);

        // Note that no underlying tokens are sent along with this function call,
        // nor do we expect any tokens to be returned from the call. That part of
        // this function's functionality is out of scope for this specific test,
        // and will be tested in a different test.
        await wgt.connect(wallet.deployer).callContractFunction(
          tokenB.address,
          functionSignature,
          mintCallData,
          0,
          [],
        );

        expect(await getTokenBalance(tokenB, wallet.receiver)).to.equal(tokenBSupply);
      });

      it('should transfer back tokens received from function calls', async () => {
        const withdrawSignature = 'withdraw(uint256)';
        await wgt.connect(wallet.deployer).addContractFunction(
          vaultB.address,
          withdrawSignature,
        );

        const withdrawAmount = tokenBSupply.div(4);
        const withdrawCallData = hre.ethers.utils.defaultAbiCoder.encode(
          ['uint256'],
          [withdrawAmount],
        );

        // We expect tokens to be returned from this address, hence we pass the
        // address of the expected tokens (in this case `tokenB`) as a function
        // argument.
        await wgt.connect(wallet.deployer).callContractFunction(
          vaultB.address,
          withdrawSignature,
          withdrawCallData,
          0,
          [tokenB.address],
        );

        expect(await getTokenBalance(tokenB, wallet.deployer)).to.equal(tokenBSupply.add(withdrawAmount));
      });

      it('should increase WGT balance upon receiving WGT from function calls', async () => {
        const withdrawSignature = 'withdraw(uint256)';
        await wgt.connect(wallet.deployer).addContractFunction(
          vaultA.address,
          withdrawSignature,
        );

        const withdrawAmount = tokenASupply.div(4);
        const withdrawCallData = hre.ethers.utils.defaultAbiCoder.encode(
          ['uint256'],
          [withdrawAmount],
        );

        // Note that no underlying tokens are sent along with this function call,
        // nor do we expect any tokens to be returned from the call. That part of
        // this function's functionality is out of scope for this specific test,
        // and will be tested in a different test.
        await wgt.connect(wallet.deployer).callContractFunction(
          vaultA.address,
          withdrawSignature,
          withdrawCallData,
          0,
          [tokenA.address],
        );

        expect(await getTokenBalance(tokenA, wallet.deployer)).to.equal(0);
        expect(await getTokenBalance(wgt, wallet.deployer)).to.equal(tokenASupply.add(withdrawAmount));
      });

      it('should keep track of locked token balances', async () => {
        const depositSignature = 'deposit(uint256)';
        await wgt.connect(wallet.deployer).addContractFunction(
          vaultA.address,
          depositSignature,
        );

        const depositAmount = tokenASupply.div(4);
        const depositCallData = hre.ethers.utils.defaultAbiCoder.encode(
          ['uint256'],
          [depositAmount],
        );

        await wgt.connect(wallet.deployer).callContractFunction(
          vaultA.address,
          depositSignature,
          depositCallData,
          depositAmount,
          [],
        );

        expect(await wgt.availableBalanceOf(wallet.deployer.address)).to.equal(
          tokenASupply.sub(depositAmount)
        );
      });
    });
  });
});
