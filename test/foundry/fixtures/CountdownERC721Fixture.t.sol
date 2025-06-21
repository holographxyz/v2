// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {Test, Vm} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";

import {HolographTreasury} from "src/HolographTreasury.sol";
import {DummyDropsPriceOracle} from "src/drops/oracle/DummyDropsPriceOracle.sol";
import {CountdownERC721Initializer} from "src/struct/CountdownERC721Initializer.sol";
import {DeploymentConfig} from "src/struct/DeploymentConfig.sol";
import {CustomERC721SalesConfiguration} from "src/struct/CustomERC721SalesConfiguration.sol";
import {Verification} from "src/struct/Verification.sol";
import {HolographFactory} from "src/HolographFactory.sol";
import {HolographerInterface} from "src/interface/HolographerInterface.sol";
import {HolographERC721} from "src/enforcer/HolographERC721.sol";
import {CountdownERC721} from "src/token/CountdownERC721.sol";

import {MockUser} from "../utils/MockUser.sol";
import {Utils} from "../utils/Utils.sol";

import {Constants} from "test/foundry/utils/Constants.sol";
import {DEFAULT_MINT_INTERVAL, DEFAULT_START_DATE} from "test/foundry/CountdownERC721/utils/Constants.sol";

contract CountdownERC721Fixture is Test {
  /// @notice Event emitted when the funds are withdrawn from the minting contract
  /// @param withdrawnBy address that issued the withdraw
  /// @param withdrawnTo address that the funds were withdrawn to
  /// @param amount amount that was withdrawn
  event FundsWithdrawn(address indexed withdrawnBy, address indexed withdrawnTo, uint256 amount);

  /* ----------------------------- Default values ----------------------------- */
  address public constant DEFAULT_OWNER_ADDRESS = address(0x1);
  address public constant DEFAULT_MINTER_ADDRESS = address(0x11);
  address payable public constant DEFAULT_FUNDS_RECIPIENT_ADDRESS = payable(address(0x2));
  string public DEFAULT_DESCRIPTION = "Description of the token";
  string public DEFAULT_IMAGE_URI = "ar://o8eyC27OuSZF0z-zIen5NTjJOKTzOQzKJzIe3F7Lmg0/1.png";
  string public DEFAULT_EXTERNAL_LINK = "https://example.com";
  string public DEFAULT_ENCRYPTED_MEDIA_URI = "xxx";
  string public DEFAULT_CONTRACT_URI = "https://example.com/metadata.json";

  /* -------------------------------- Addresses ------------------------------- */
  address sourceContractAddress;
  address payable public constant HOLOGRAPH_TREASURY_ADDRESS = payable(address(0x3));
  address payable constant TEST_ACCOUNT = payable(address(0x888));
  address public constant MEDIA_CONTRACT = address(0x666);
  address public alice;
  address public initialOwner = address(uint160(uint256(keccak256("initialOwner"))));
  address public fundsRecipient = address(uint160(uint256(keccak256("fundsRecipient"))));

  /* -------------------------------- Contracts ------------------------------- */
  HolographERC721 erc721Enforcer;
  MockUser public mockUser;
  CountdownERC721 public countdownErc721;
  HolographTreasury public treasury;
  DummyDropsPriceOracle public dummyPriceOracle;

  /* ---------------------------- Test environment ---------------------------- */
  uint104 mintEthPrice = 0.1 ether;
  uint256 public chainPrepend;
  uint256 internal fuzzingMaxSupply;

  uint256 public constant FIRST_TOKEN_ID =
    115792089183396302089269705419353877679230723318366275194376439045705909141505; // large 256 bit number due to chain id prefix

  constructor() {}

  function setUp() public virtual {
    // Setup VM
    // NOTE: These tests rely on the Holograph protocol being deployed to the local chain
    //       At the moment, the deploy pipeline is still managed by Hardhat, so we need to
    //       first run it via `npx hardhat deploy --network localhost` or `yarn deploy:localhost` if you need two local chains before running the tests.
    uint256 forkId = vm.createFork("http://localhost:8545");
    vm.selectFork(forkId);

    // Setup signer wallet
    // NOTE: This is the address that will be used to sign transactions
    //       A signature is required to deploy Holographable contracts via the HolographFactory
    alice = vm.addr(1);
    // vm.prank(HOLOGRAPH_TREASURY_ADDRESS);
    dummyPriceOracle = DummyDropsPriceOracle(Constants.getDummyDropsPriceOracle());

    // NOTE: This needs to be uncommented to inject the DropsPriceOracleProxy contract into the VM if it isn't done by the deploy script
    //       At the moment we have hardhat configured to deploy and inject the code approrpriately to match the hardcoded address in the HolographDropERC721V2 contract
    // We deploy DropsPriceOracleProxy at specific address
    // vm.etch(address(Constants.getDropsPriceOracleProxy()), address(new DropsPriceOracleProxy()).code);
    // We set storage slot to point to actual drop implementation
    // vm.store(
    //   address(Constants.getDropsPriceOracleProxy()),
    //   bytes32(uint256(keccak256("eip1967.Holograph.dropsPriceOracle")) - 1),
    //   bytes32(abi.encode(Constants.getDummyDropsPriceOracle()))
    // );

    try vm.envUint("FUZZING_MAX_SUPPLY") returns (uint256 result) {
      fuzzingMaxSupply = result;
    } catch {
      fuzzingMaxSupply = 100;
    }
  }

  modifier setupTestCountdownErc721(uint32 maxSupply) {
    chainPrepend = deployAndSetupProtocol(maxSupply);

    _;
  }

  modifier setUpPurchase() {
    _setUpPurchase();

    _;
  }

  /* -------------------------------------------------------------------------- */
  /*                                Test helpers                                */
  /* -------------------------------------------------------------------------- */

  function getDeploymentConfig(
    string memory contractName,
    string memory contractSymbol,
    uint16 contractBps,
    uint256 eventConfig,
    bool skipInit,
    CountdownERC721Initializer memory initializer
  ) public returns (DeploymentConfig memory) {
    bytes memory bytecode = abi.encodePacked(vm.getCode("CountdownERC721Proxy.sol:CountdownERC721Proxy"));
    bytes memory initCode = abi.encode(
      bytes32(0x0000000000000000000000000000000000436f756e74646f776e455243373231), // Source contract type CountdownERC721
      address(Constants.getHolographRegistryProxy()), // address of registry (to get source contract address from)
      abi.encode(initializer) // actual init code for source contract (CountdownERC721)
    );

    return
      DeploymentConfig({
        contractType: Utils.stringToBytes32("HolographERC721"), // HolographERC721
        chainType: 1338, // holograph.getChainId(),
        salt: 0x0000000000000000000000000000000000000000000000000000000000000001, // random salt from user
        byteCode: bytecode, // countdown contract bytecode
        initCode: abi.encode(contractName, contractSymbol, contractBps, eventConfig, skipInit, initCode) // init code is used to initialize the HolographERC721 enforcer
      });
  }

  function _setUpPurchase() internal {
    // We assume that the amount is at least one and less than or equal to the edition size given in modifier
    vm.prank(DEFAULT_OWNER_ADDRESS);

    HolographerInterface holographerInterface = HolographerInterface(address(countdownErc721));
    sourceContractAddress = holographerInterface.getSourceContract();
    erc721Enforcer = HolographERC721(payable(address(countdownErc721)));

    vm.warp(countdownErc721.START_DATE());
  }

  function deployAndSetupProtocol(uint32 maxSupply) internal returns (uint256) {
    _deployAndSetupProtocol(maxSupply);

    return chainPrepend;
  }

  function _purchaseAllSupply() internal {
    for (uint256 i = 0; i < countdownErc721.currentTheoricalMaxSupply(); i++) {
      address user = address(uint160(uint256(keccak256(abi.encodePacked(i)))));
      vm.startPrank(address(user));
      vm.deal(address(user), mintEthPrice);
      countdownErc721.purchase{value: mintEthPrice}(1);
      vm.stopPrank();
    }
  }

  function _deployAndSetupProtocol(uint32 maxSupply) private {
    // Setup sale config for edition
    CustomERC721SalesConfiguration memory saleConfig = CustomERC721SalesConfiguration({
      publicSalePrice: uint104(mintEthPrice),
      maxSalePurchasePerAddress: 0 // no limit
    });

    // Create initializer
    CountdownERC721Initializer memory initializer = CountdownERC721Initializer({
      description: DEFAULT_DESCRIPTION,
      imageURI: DEFAULT_IMAGE_URI,
      animationURI: "",
      externalLink: DEFAULT_EXTERNAL_LINK,
      encryptedMediaURI: DEFAULT_ENCRYPTED_MEDIA_URI,
      startDate: DEFAULT_START_DATE,
      initialMaxSupply: maxSupply,
      mintInterval: DEFAULT_MINT_INTERVAL,
      initialOwner: payable(DEFAULT_OWNER_ADDRESS),
      initialMinter: payable(DEFAULT_MINTER_ADDRESS),
      fundsRecipient: payable(DEFAULT_FUNDS_RECIPIENT_ADDRESS),
      contractURI: DEFAULT_CONTRACT_URI,
      salesConfiguration: saleConfig
    });

    // Get deployment config, hash it, and then sign it
    DeploymentConfig memory config = getDeploymentConfig(
      "Contract Name", // contractName
      "SYM", // contractSymbol
      1000, // contractBps
      type(uint256).max, // eventConfig
      false, // skipInit
      initializer
    );
    bytes32 hash = keccak256(
      abi.encodePacked(
        config.contractType,
        config.chainType,
        config.salt,
        keccak256(config.byteCode),
        keccak256(config.initCode),
        alice
      )
    );

    (uint8 v, bytes32 r, bytes32 s) = vm.sign(1, hash);
    Verification memory signature = Verification(r, s, v);
    address signer = ecrecover(hash, v, r, s);
    require(signer == alice, "Invalid signature");

    HolographFactory factory = HolographFactory(payable(Constants.getHolographFactoryProxy()));

    // Deploy the drop / edition
    vm.recordLogs();
    factory.deployHolographableContract(config, signature, alice); // Pass the payload hash, with the signature, and signer's address
    Vm.Log[] memory entries = vm.getRecordedLogs();

    address newCountdownERC721Address = address(uint160(uint256(entries[3].topics[1])));

    // Connect the drop implementation to the drop proxy address
    countdownErc721 = CountdownERC721(payable(newCountdownERC721Address));
  }
}