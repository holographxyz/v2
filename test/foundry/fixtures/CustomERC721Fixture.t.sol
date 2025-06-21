// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {Test, Vm} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";

import {HolographTreasury} from "src/HolographTreasury.sol";
import {DummyDropsPriceOracle} from "src/drops/oracle/DummyDropsPriceOracle.sol";
import {CustomERC721Initializer} from "src/struct/CustomERC721Initializer.sol";
import {DeploymentConfig} from "src/struct/DeploymentConfig.sol";
import {CustomERC721SalesConfiguration} from "src/struct/CustomERC721SalesConfiguration.sol";
import {LazyMintConfiguration} from "src/struct/LazyMintConfiguration.sol";
import {Verification} from "src/struct/Verification.sol";
import {HolographFactory} from "src/HolographFactory.sol";
import {HolographerInterface} from "src/interface/HolographerInterface.sol";
import {HolographERC721} from "src/enforcer/HolographERC721.sol";
import {CustomERC721} from "src/token/CustomERC721.sol";

import {MockUser} from "../utils/MockUser.sol";
import {Utils} from "../utils/Utils.sol";
import {CustomERC721Helper} from "test/foundry/CustomERC721/utils/Helper.sol";

import {Constants} from "test/foundry/utils/Constants.sol";
import {DEFAULT_BASE_URI, DEFAULT_BASE_URI_2, DEFAULT_PLACEHOLDER_URI, DEFAULT_PLACEHOLDER_URI_2, DEFAULT_ENCRYPT_DECRYPT_KEY, DEFAULT_ENCRYPT_DECRYPT_KEY_2, DEFAULT_MAX_SUPPLY, DEFAULT_MINT_INTERVAL, DEFAULT_START_DATE} from "test/foundry/CustomERC721/utils/Constants.sol";

contract CustomERC721Fixture is Test {
  /// @notice Event emitted when the funds are withdrawn from the minting contract
  /// @param withdrawnBy address that issued the withdraw
  /// @param withdrawnTo address that the funds were withdrawn to
  /// @param amount amount that was withdrawn
  event FundsWithdrawn(address indexed withdrawnBy, address indexed withdrawnTo, uint256 amount);

  /* -------------------------------- Addresses ------------------------------- */
  address sourceContractAddress;
  address public constant DEFAULT_OWNER_ADDRESS = address(0x1);
  address public constant DEFAULT_MINTER_ADDRESS = address(0x11);
  address payable public constant DEFAULT_FUNDS_RECIPIENT_ADDRESS = payable(address(0x2));
  address payable public constant HOLOGRAPH_TREASURY_ADDRESS = payable(address(0x3));
  address payable constant TEST_ACCOUNT = payable(address(0x888));
  address public constant MEDIA_CONTRACT = address(0x666);
  address public alice;
  address public initialOwner = address(uint160(uint256(keccak256("initialOwner"))));
  address public fundsRecipient = address(uint160(uint256(keccak256("fundsRecipient"))));

  /* -------------------------------- Contracts ------------------------------- */
  HolographERC721 erc721Enforcer;
  MockUser public mockUser;
  CustomERC721 public customErc721;
  HolographTreasury public treasury;
  DummyDropsPriceOracle public dummyPriceOracle;

  /* ---------------------------- Test environment ---------------------------- */
  uint256 nativePrice;
  uint256 public chainPrepend;
  uint256 totalCost;
  uint104 constant usd10 = 10 * (10 ** 6); // 10 USD (6 decimal places)
  uint104 constant usd100 = 100 * (10 ** 6); // 100 USD (6 decimal places)
  uint104 constant usd1000 = 1000 * (10 ** 6); // 1000 USD (6 decimal places)
  uint256 internal fuzzingMaxSupply;
  LazyMintConfiguration[] public defaultLazyMintConfigurations;

  uint256 public constant FIRST_TOKEN_ID =
    115792089183396302089269705419353877679230723318366275194376439045705909141505; // large 256 bit number due to chain id prefix

  constructor() {
    // Create the first batch configuration
    bytes memory encryptedUri = CustomERC721Helper.encryptDecrypt(
      abi.encodePacked(DEFAULT_BASE_URI),
      DEFAULT_ENCRYPT_DECRYPT_KEY
    );
    bytes32 provenanceHash = keccak256(abi.encodePacked(DEFAULT_BASE_URI, DEFAULT_ENCRYPT_DECRYPT_KEY, block.chainid));
    defaultLazyMintConfigurations.push(
      LazyMintConfiguration({
        _amount: DEFAULT_MAX_SUPPLY / 2,
        _baseURIForTokens: DEFAULT_PLACEHOLDER_URI,
        _data: abi.encode(encryptedUri, provenanceHash)
      })
    );

    // Create the second batch configuration
    bytes memory encryptedUri2 = CustomERC721Helper.encryptDecrypt(
      abi.encodePacked(DEFAULT_BASE_URI_2),
      DEFAULT_ENCRYPT_DECRYPT_KEY_2
    );
    bytes32 provenanceHash2 = keccak256(
      abi.encodePacked(DEFAULT_BASE_URI_2, DEFAULT_ENCRYPT_DECRYPT_KEY_2, block.chainid)
    );
    defaultLazyMintConfigurations.push(
      LazyMintConfiguration({
        _amount: DEFAULT_MAX_SUPPLY / 2,
        _baseURIForTokens: DEFAULT_PLACEHOLDER_URI_2,
        _data: abi.encode(encryptedUri2, provenanceHash2)
      })
    );
  }

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

  modifier setupTestCustomERC21(uint32 maxSupply) {
    chainPrepend = deployAndSetupProtocol(maxSupply, false);

    _;
  }

  modifier setupTestCustomERC21WithoutLazyMintSync(uint32 maxSupply) {
    chainPrepend = deployAndSetupProtocol(maxSupply, true);

    _;
  }

  modifier setupTestCustomERC21WithLazyMint(uint32 maxSupply) {
    chainPrepend = deployAndSetupProtocol(maxSupply, true, defaultLazyMintConfigurations);

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
    CustomERC721Initializer memory initializer
  ) public returns (DeploymentConfig memory) {
    bytes memory bytecode = abi.encodePacked(vm.getCode("CustomERC721Proxy.sol:CustomERC721Proxy"));
    bytes memory initCode = abi.encode(
      bytes32(0x0000000000000000000000000000000000000000437573746F6D455243373231), // Source contract type CustomERC721
      address(Constants.getHolographRegistryProxy()), // address of registry (to get source contract address from)
      abi.encode(initializer) // actual init code for source contract (CustomERC721)
    );

    return
      DeploymentConfig({
        contractType: Utils.stringToBytes32("HolographERC721"), // HolographERC721
        chainType: 1338, // holograph.getChainId(),
        salt: 0x0000000000000000000000000000000000000000000000000000000000000001, // random salt from user
        byteCode: bytecode, // custom contract bytecode
        initCode: abi.encode(contractName, contractSymbol, contractBps, eventConfig, skipInit, initCode) // init code is used to initialize the HolographERC721 enforcer
      });
  }

  function _setUpPurchase() private {
    // We assume that the amount is at least one and less than or equal to the edition size given in modifier
    vm.prank(DEFAULT_OWNER_ADDRESS);

    HolographerInterface holographerInterface = HolographerInterface(address(customErc721));
    sourceContractAddress = holographerInterface.getSourceContract();
    erc721Enforcer = HolographERC721(payable(address(customErc721)));

    uint104 price = usd100;
    nativePrice = dummyPriceOracle.convertUsdToWei(price);

    totalCost = (nativePrice);

    vm.warp(customErc721.START_DATE());
  }

  function deployAndSetupProtocol(
    uint32 maxSupply,
    bool skipLazyMintSync,
    LazyMintConfiguration[] memory lazyMintsConfigurations
  ) internal returns (uint256) {
    _deployAndSetupProtocol(maxSupply, skipLazyMintSync, lazyMintsConfigurations);

    return chainPrepend;
  }

  function deployAndSetupProtocol(uint32 maxSupply, bool skipLazyMintSync) internal returns (uint256) {
    _deployAndSetupProtocol(maxSupply, skipLazyMintSync, new LazyMintConfiguration[](0));

    return chainPrepend;
  }

  function _purchaseAllSupply() internal {
    for (uint256 i = 0; i < customErc721.currentTheoricalMaxSupply(); i++) {
      address user = address(uint160(uint256(keccak256(abi.encodePacked(i)))));
      vm.startPrank(address(user));
      vm.deal(address(user), totalCost);
      customErc721.purchase{value: totalCost}(1);
      vm.stopPrank();
    }
  }

  function _deployAndSetupProtocol(
    uint32 maxSupply,
    bool skipLazyMintSync,
    LazyMintConfiguration[] memory lazyMintsConfigurations
  ) private {
    // Setup sale config for edition
    CustomERC721SalesConfiguration memory saleConfig = CustomERC721SalesConfiguration({
      publicSalePrice: usd100,
      maxSalePurchasePerAddress: 0 // no limit
    });

    // Create initializer
    CustomERC721Initializer memory initializer = CustomERC721Initializer({
      startDate: DEFAULT_START_DATE,
      initialMaxSupply: maxSupply,
      mintInterval: DEFAULT_MINT_INTERVAL,
      initialOwner: payable(DEFAULT_OWNER_ADDRESS),
      initialMinter: payable(DEFAULT_MINTER_ADDRESS),
      fundsRecipient: payable(DEFAULT_FUNDS_RECIPIENT_ADDRESS),
      contractURI: "https://example.com/metadata.json",
      salesConfiguration: saleConfig,
      lazyMintsConfigurations: lazyMintsConfigurations
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

    address newCustomERC721Address;
    if (lazyMintsConfigurations.length > 0) {
      newCustomERC721Address = address(uint160(uint256(entries[3 + lazyMintsConfigurations.length].topics[1])));
    } else {
      newCustomERC721Address = address(uint160(uint256(entries[3].topics[1])));
    }

    // Connect the drop implementation to the drop proxy address
    customErc721 = CustomERC721(payable(newCustomERC721Address));

    if (!skipLazyMintSync) {
      vm.prank(DEFAULT_OWNER_ADDRESS);
      customErc721.syncLazyMint();
    }
  }
}
