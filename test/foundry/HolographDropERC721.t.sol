// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {Test, Vm} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

import {DeploymentConfig} from "../../src/struct/DeploymentConfig.sol";
import {Verification} from "../../src/struct/Verification.sol";
import {DropsInitializerV2} from "../../src/drops/struct/DropsInitializerV2.sol";
import {SalesConfiguration} from "../../src/drops/struct/SalesConfiguration.sol";
import {SaleDetails} from "../../src/drops/struct/SaleDetails.sol";

import {HolographFactory} from "../../src/HolographFactory.sol";
import {HolographTreasury} from "../../src/HolographTreasury.sol";

import {MockUser} from "./utils/MockUser.sol";
import {Constants} from "./utils/Constants.sol";
import {Utils} from "./utils/Utils.sol";
import {HolographerInterface} from "../../src/interface/HolographerInterface.sol";
import {IHolographDropERC721V2} from "../../src/drops/interface/IHolographDropERC721V2.sol";

import {HolographERC721} from "../../src/enforcer/HolographERC721.sol";
import {HolographDropERC721V2} from "../../src/drops/token/HolographDropERC721V2.sol";
import {HolographDropERC721Proxy} from "../../src/drops/proxy/HolographDropERC721Proxy.sol";

import {IMetadataRenderer} from "../../src/drops/interface/IMetadataRenderer.sol";
import {DummyMetadataRenderer} from "./utils/DummyMetadataRenderer.sol";
import {DropsMetadataRenderer} from "../../src/drops/metadata/DropsMetadataRenderer.sol";
import {EditionsMetadataRenderer} from "../../src/drops/metadata/EditionsMetadataRenderer.sol";

import {DropsPriceOracleProxy} from "../../src/drops/proxy/DropsPriceOracleProxy.sol";
import {DummyDropsPriceOracle} from "../../src/drops/oracle/DummyDropsPriceOracle.sol";
import {IHolographERC721Errors} from "src/interface/IHolographERC721Errors.sol";

contract HolographDropERC721Test is Test, IHolographERC721Errors {
  /// @notice Event emitted when the funds are withdrawn from the minting contract
  /// @param withdrawnBy address that issued the withdraw
  /// @param withdrawnTo address that the funds were withdrawn to
  /// @param amount amount that was withdrawn
  event FundsWithdrawn(address indexed withdrawnBy, address indexed withdrawnTo, uint256 amount);

  address public alice;
  MockUser public mockUser;

  HolographDropERC721V2 public holographDropERC721;
  HolographTreasury public treasury;

  DummyMetadataRenderer public dummyRenderer = new DummyMetadataRenderer();
  EditionsMetadataRenderer public editionsMetadataRenderer;
  DropsMetadataRenderer public dropsMetadataRenderer;
  DummyDropsPriceOracle public dummyPriceOracle;

  uint104 constant usd10 = 10 * (10 ** 6); // 10 USD (6 decimal places)
  uint104 constant usd100 = 100 * (10 ** 6); // 100 USD (6 decimal places)
  uint104 constant usd1000 = 1000 * (10 ** 6); // 1000 USD (6 decimal places)

  address public constant DEFAULT_OWNER_ADDRESS = address(0x1);
  address payable public constant DEFAULT_FUNDS_RECIPIENT_ADDRESS = payable(address(0x2));
  address payable public constant HOLOGRAPH_TREASURY_ADDRESS = payable(address(0x3));
  address payable constant TEST_ACCOUNT = payable(address(0x888));
  address public constant MEDIA_CONTRACT = address(0x666);

  uint256 public constant FIRST_TOKEN_ID =
    115792089183396302089269705419353877679230723318366275194376439045705909141505; // large 256 bit number due to chain id prefix

  struct Configuration {
    IMetadataRenderer metadataRenderer;
    uint64 editionSize;
    uint16 royaltyBPS;
    address payable fundsRecipient;
  }

  modifier setupTestDrop(uint64 editionSize) {
    // Wrap in brackets to remove from stack in functions that use this modifier
    // Avoids stack to deep errors
    {
      // Setup sale config for edition
      SalesConfiguration memory saleConfig = SalesConfiguration({
        publicSaleStart: 0, // starts now
        publicSaleEnd: type(uint64).max, // never ends
        presaleStart: 0, // never starts
        presaleEnd: 0, // never ends
        publicSalePrice: usd100,
        maxSalePurchasePerAddress: 0, // no limit
        presaleMerkleRoot: bytes32(0) // no presale
      });

      dummyRenderer = new DummyMetadataRenderer();
      DropsInitializerV2 memory initializer = DropsInitializerV2({
        initialOwner: DEFAULT_OWNER_ADDRESS,
        fundsRecipient: payable(DEFAULT_FUNDS_RECIPIENT_ADDRESS),
        editionSize: editionSize,
        royaltyBPS: 800,
        salesConfiguration: saleConfig,
        metadataRenderer: address(dummyRenderer),
        metadataRendererInit: ""
      });

      // Get deployment config, hash it, and then sign it
      DeploymentConfig memory config = getDeploymentConfig(
        "Test NFT", // contractName
        "TNFT", // contractSymbol
        1000, // contractBps
        Constants.getDropsEventConfig(), // eventConfig
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

      HolographFactory factory = HolographFactory(payable(Constants.getHolographFactoryProxy()));

      // Deploy the drop / edition
      vm.recordLogs();
      factory.deployHolographableContract(config, signature, alice); // Pass the payload hash, with the signature, and signer's address
      Vm.Log[] memory entries = vm.getRecordedLogs();

      // Extract the new drop address from the correct log entry and topic
      address newDropAddress = address(uint160(uint256(entries[2].topics[1])));

      // Connect the drop implementation to the drop proxy address
      holographDropERC721 = HolographDropERC721V2(payable(newDropAddress));
    }

    _;
  }

  function setUp() public {
    // Setup VM
    // NOTE: These tests rely on the Holograph protocol being deployed to the local chain
    //       At the moment, the deploy pipeline is still managed by Hardhat, so we need to
    //       first run it via `npx hardhat deploy --network localhost` or `pnpm deploy:localhost` if you need two local chains before running the tests.
    uint256 forkId = vm.createFork("http://localhost:8545");
    vm.selectFork(forkId);

    // Setup signer wallet
    // NOTE: This is the address that will be used to sign transactions
    //       A signature is required to deploy Holographable contracts via the HolographFactory
    alice = vm.addr(1);

    vm.prank(HOLOGRAPH_TREASURY_ADDRESS);

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

    dropsMetadataRenderer = new DropsMetadataRenderer();
  }

  function test_DeployHolographDrop() public {
    // Setup sale config for edition
    SalesConfiguration memory saleConfig = SalesConfiguration({
      publicSaleStart: 0, // starts now
      publicSaleEnd: type(uint64).max, // never ends
      presaleStart: 0, // never starts
      presaleEnd: 0, // never ends
      publicSalePrice: usd100,
      maxSalePurchasePerAddress: 0, // no limit
      presaleMerkleRoot: bytes32(0) // no presale
    });

    // Create initializer
    DropsInitializerV2 memory initializer = DropsInitializerV2({
      initialOwner: payable(DEFAULT_OWNER_ADDRESS),
      fundsRecipient: payable(DEFAULT_FUNDS_RECIPIENT_ADDRESS),
      editionSize: 100,
      royaltyBPS: 1000,
      salesConfiguration: saleConfig,
      metadataRenderer: address(dropsMetadataRenderer),
      metadataRendererInit: abi.encode("description", "imageURI", "animationURI")
    });

    // Get deployment config, hash it, and then sign it
    DeploymentConfig memory config = getDeploymentConfig(
      "Testing Init", // contractName
      "BOO", // contractSymbol
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
    address newDropAddress = address(uint160(uint256(entries[0].topics[1])));

    // Connect the drop implementation to the drop proxy address
    holographDropERC721 = HolographDropERC721V2(payable(newDropAddress));

    // Verify the version
    assertEq(holographDropERC721.version(), 2);
  }

  function test_Init() public setupTestDrop(10) {
    require(holographDropERC721.owner() == DEFAULT_OWNER_ADDRESS, "Default owner set wrong");
    (
      IMetadataRenderer renderer,
      uint64 editionSize,
      uint16 royaltyBPS,
      address payable fundsRecipient
    ) = holographDropERC721.config();
    require(address(renderer) == address(dummyRenderer), "Renderer is wrong");
    require(editionSize == 10, "EditionSize is wrong");

    require(royaltyBPS == 800, "RoyaltyBPS is wrong");
    require(fundsRecipient == payable(DEFAULT_FUNDS_RECIPIENT_ADDRESS), "FundsRecipient is wrong");

    // Setup sale config
    SalesConfiguration memory salesConfig = SalesConfiguration({
      publicSaleStart: 0, // starts now
      publicSaleEnd: type(uint64).max, // never ends
      presaleStart: 0, // never starts
      presaleEnd: 0, // never ends
      publicSalePrice: 0, // 0 USD
      maxSalePurchasePerAddress: 0, // no limit
      presaleMerkleRoot: bytes32(0) // no presale
    });

    HolographERC721 holographDropERC721 = HolographERC721(payable(address(holographDropERC721)));

    string memory name = holographDropERC721.name();
    string memory symbol = holographDropERC721.symbol();
    require(keccak256(bytes(name)) == keccak256(bytes("Test NFT")));
    require(keccak256(bytes(symbol)) == keccak256(bytes("TNFT")));

    string memory contractName = "";
    string memory contractSymbol = "";
    uint16 contractBps = 1000;
    uint256 eventConfig = Constants.getDropsEventConfig();
    bool skipInit = false;

    vm.expectRevert("HOLOGRAPHER: already initialized");
    DropsInitializerV2 memory initializer = DropsInitializerV2({
      initialOwner: DEFAULT_OWNER_ADDRESS,
      fundsRecipient: payable(DEFAULT_FUNDS_RECIPIENT_ADDRESS),
      editionSize: editionSize,
      royaltyBPS: 800,
      salesConfiguration: salesConfig,
      metadataRenderer: address(dummyRenderer),
      metadataRendererInit: ""
    });

    bytes memory initCode = abi.encode(
      bytes32(0x0000000000000000000000486f6c6f677261706844726f704552433732315632), // Source contract type HolographDropERC721V2
      address(Constants.getHolographRegistryProxy()), // address of registry (to get source contract address from)
      abi.encode(initializer) // actual init code for source contract (HolographDropERC721V2)
    );

    holographDropERC721.init(abi.encode(contractName, contractSymbol, contractBps, eventConfig, skipInit, initCode));
  }

  function test_HolographMintFeeCanBeSet(uint256 fee) public {
    vm.prank(DEFAULT_OWNER_ADDRESS);
    treasury = HolographTreasury(payable(Constants.getHolographTreasuryProxy()));

    // Get the treasury admins to set the mint fee
    address treasuryAdmin = treasury.getAdmin();

    // Check that the treasury admin can set the mint fee
    uint256 mintFeeBefore = treasury.getHolographMintFee();

    // Check that non-admins cannot set the mint fee
    vm.expectRevert("HOLOGRAPH: admin only function");
    treasury.setHolographMintFee(fee);

    // Check that the treasury admin can set the mint fee
    vm.startPrank(treasuryAdmin);
    assertEq(mintFeeBefore, 1000000);
    treasury.setHolographMintFee(fee);
    assertEq(treasury.holographMintFee(), fee);
  }

  function test_HolographMintFeeCannotBeSetByNonAdmin(uint256 fee) public {
    vm.prank(DEFAULT_OWNER_ADDRESS);
    treasury = HolographTreasury(payable(Constants.getHolographTreasuryProxy()));

    // Get the treasury admins to set the mint fee
    address treasuryAdmin = treasury.getAdmin();

    // Check that the treasury admin can set the mint fee
    uint256 mintFeeBefore = treasury.getHolographMintFee();

    // Check that non-admins cannot set the mint fee
    vm.expectRevert("HOLOGRAPH: admin only function");
    treasury.setHolographMintFee(fee);

    // Check that the mint fee is the same
    treasuryAdmin = treasury.getAdmin();
    vm.startPrank(treasuryAdmin);
    assertEq(mintFeeBefore, treasury.getHolographMintFee());
  }

  function test_Purchase(uint64 amount) public setupTestDrop(10) {
    // We assume that the amount is at least one and less than or equal to the edition size given in modifier
    vm.assume(amount > 0 && amount <= 10);
    vm.prank(DEFAULT_OWNER_ADDRESS);

    HolographerInterface holographerInterface = HolographerInterface(address(holographDropERC721));
    address sourceContractAddress = holographerInterface.getSourceContract();
    HolographERC721 erc721Enforcer = HolographERC721(payable(address(holographDropERC721)));

    uint104 price = usd100;
    uint256 nativePrice = dummyPriceOracle.convertUsdToWei(price);
    uint256 holographFee = holographDropERC721.getHolographFeeUsd(amount);
    uint256 nativeFee = dummyPriceOracle.convertUsdToWei(holographFee);

    vm.prank(DEFAULT_OWNER_ADDRESS);

    HolographDropERC721V2(payable(sourceContractAddress)).setSaleConfiguration({
      publicSaleStart: 0,
      publicSaleEnd: type(uint64).max,
      presaleStart: 0,
      presaleEnd: 0,
      publicSalePrice: price,
      maxSalePurchasePerAddress: uint32(amount),
      presaleMerkleRoot: bytes32(0)
    });

    uint256 totalCost = amount * (nativePrice + nativeFee);

    vm.prank(address(TEST_ACCOUNT));
    vm.deal(address(TEST_ACCOUNT), totalCost);
    holographDropERC721.purchase{value: totalCost}(amount);

    assertEq(holographDropERC721.saleDetails().maxSupply, 10);
    assertEq(holographDropERC721.saleDetails().totalMinted, amount);

    // First token ID is this long number due to the chain id prefix
    require(erc721Enforcer.ownerOf(FIRST_TOKEN_ID) == address(TEST_ACCOUNT), "Owner is wrong for new minted token");
    assertEq(address(sourceContractAddress).balance, amount * nativePrice - nativeFee);

    // Check that the fee was sent to the treasury
    treasury = HolographTreasury(payable(Constants.getHolographTreasuryProxy()));
    console.log("treasury balance", address(treasury).balance);
    assertEq(address(treasury).balance, nativeFee);

    // Get the treasury admin and keep track of what their balance is
    address treasuryAdmin = treasury.getAdmin();
    uint256 treasuryBalanceBefore = address(treasuryAdmin).balance;
    vm.prank(treasuryAdmin);

    // Check that the treasury admin can withdraw the fee
    treasury.withdraw();

    // Is the fee we withdrew equal to the fee we expected?
    // We subtract the balance before from the balance after to get the fee that should have been transferred during the withdraw
    uint256 treasuryBalanceAfter = address(treasuryAdmin).balance;
    assertEq(treasuryBalanceAfter - treasuryBalanceBefore, nativeFee);
  }

  function test_PurchaseFree(uint64 amount) public setupTestDrop(10) {
    // We assume that the amount is at least one and less than or equal to the edition size given in modifier
    vm.assume(amount > 0 && amount <= 10);
    vm.prank(DEFAULT_OWNER_ADDRESS);

    HolographerInterface holographerInterface = HolographerInterface(address(holographDropERC721));
    address sourceContractAddress = holographerInterface.getSourceContract();
    HolographERC721 erc721Enforcer = HolographERC721(payable(address(holographDropERC721)));

    uint104 price = 0; // Set the price to zero
    uint256 nativePrice = 0; // Set the price to zero
    uint256 holographFee = holographDropERC721.getHolographFeeUsd(amount);
    uint256 nativeFee = dummyPriceOracle.convertUsdToWei(holographFee);

    vm.prank(DEFAULT_OWNER_ADDRESS);

    HolographDropERC721V2(payable(sourceContractAddress)).setSaleConfiguration({
      publicSaleStart: 0,
      publicSaleEnd: type(uint64).max,
      presaleStart: 0,
      presaleEnd: 0,
      publicSalePrice: price,
      maxSalePurchasePerAddress: uint32(amount),
      presaleMerkleRoot: bytes32(0)
    });

    uint256 totalCost = amount * nativeFee; // This will be equal to the holographFee as the nativePrice is 0

    vm.prank(address(TEST_ACCOUNT));
    vm.deal(address(TEST_ACCOUNT), totalCost);
    holographDropERC721.purchase{value: totalCost}(amount);

    assertEq(holographDropERC721.saleDetails().maxSupply, 10);
    assertEq(holographDropERC721.saleDetails().totalMinted, amount);

    // First token ID is this long number due to the chain id prefix
    require(erc721Enforcer.ownerOf(FIRST_TOKEN_ID) == address(TEST_ACCOUNT), "Owner is wrong for new minted token");
    assertEq(address(sourceContractAddress).balance, totalCost - nativeFee); // Expect the balance to be equal to the fee received
  }

  function test_PurchaseTime() public setupTestDrop(10) {
    uint256 amount = 1;
    uint104 price = usd100;
    uint256 nativePrice = dummyPriceOracle.convertUsdToWei(price);
    uint256 holographFee = holographDropERC721.getHolographFeeUsd(amount);
    uint256 nativeFee = dummyPriceOracle.convertUsdToWei(holographFee);
    uint256 totalCost = amount * (nativePrice + nativeFee);

    vm.prank(DEFAULT_OWNER_ADDRESS);
    holographDropERC721.setSaleConfiguration({
      publicSaleStart: 0,
      publicSaleEnd: 0,
      presaleStart: 0,
      presaleEnd: 0,
      publicSalePrice: price,
      maxSalePurchasePerAddress: 2,
      presaleMerkleRoot: bytes32(0)
    });

    assertTrue(!holographDropERC721.saleDetails().publicSaleActive);

    vm.deal(address(TEST_ACCOUNT), totalCost);
    vm.prank(address(TEST_ACCOUNT));
    vm.expectRevert(IHolographDropERC721V2.Sale_Inactive.selector);
    holographDropERC721.purchase{value: totalCost}(1);

    assertEq(holographDropERC721.saleDetails().maxSupply, 10);
    assertEq(holographDropERC721.saleDetails().totalMinted, 0);

    vm.prank(DEFAULT_OWNER_ADDRESS);
    holographDropERC721.setSaleConfiguration({
      publicSaleStart: 9 * 3600,
      publicSaleEnd: 11 * 3600,
      presaleStart: 0,
      presaleEnd: 0,
      maxSalePurchasePerAddress: 20,
      publicSalePrice: price,
      presaleMerkleRoot: bytes32(0)
    });

    assertTrue(!holographDropERC721.saleDetails().publicSaleActive);
    // jan 1st 1980
    vm.warp(10 * 3600);
    assertTrue(holographDropERC721.saleDetails().publicSaleActive);
    assertTrue(!holographDropERC721.saleDetails().presaleActive);

    vm.prank(address(TEST_ACCOUNT));
    holographDropERC721.purchase{value: totalCost}(1);

    HolographERC721 erc721Enforcer = HolographERC721(payable(address(holographDropERC721)));

    assertEq(holographDropERC721.saleDetails().totalMinted, 1);
    assertEq(erc721Enforcer.ownerOf(FIRST_TOKEN_ID), address(TEST_ACCOUNT));
  }

  function test_OnlyAdminCanWithdrawFromTreasury() public {
    treasury = HolographTreasury(payable(Constants.getHolographTreasuryProxy()));
    vm.startPrank(address(0xcafe));
    vm.expectRevert("HOLOGRAPH: admin only function");
    treasury.withdraw();
    vm.stopPrank();
  }

  function test_MintAdmin() public setupTestDrop(10) {
    vm.prank(DEFAULT_OWNER_ADDRESS);
    holographDropERC721.adminMint(DEFAULT_OWNER_ADDRESS, 1);
    assertEq(holographDropERC721.saleDetails().maxSupply, 10);
    assertEq(holographDropERC721.saleDetails().totalMinted, 1);

    HolographERC721 erc721Enforcer = HolographERC721(payable(address(holographDropERC721)));
    require(erc721Enforcer.ownerOf(FIRST_TOKEN_ID) == DEFAULT_OWNER_ADDRESS, "Owner is wrong for new minted token");
  }

  function test_MintMulticall() public setupTestDrop(10) {
    vm.startPrank(DEFAULT_OWNER_ADDRESS);
    bytes[] memory calls = new bytes[](3);
    calls[0] = abi.encodeWithSelector(IHolographDropERC721V2.adminMint.selector, DEFAULT_OWNER_ADDRESS, 5);
    calls[1] = abi.encodeWithSelector(IHolographDropERC721V2.adminMint.selector, address(0x123), 3);
    calls[2] = abi.encodeWithSelector(IHolographDropERC721V2.saleDetails.selector);
    bytes[] memory results = holographDropERC721.multicall(calls);

    (bool saleActive, bool presaleActive, uint256 publicSalePrice, , , , , , , , ) = abi.decode(
      results[2],
      (bool, bool, uint256, uint64, uint64, uint64, uint64, bytes32, uint256, uint256, uint256)
    );
    assertTrue(saleActive);
    assertTrue(!presaleActive);
    assertEq(publicSalePrice, usd100);
    uint256 firstMintedId = abi.decode(results[0], (uint256));
    uint256 secondMintedId = abi.decode(results[1], (uint256));

    assertEq(firstMintedId, 5);
    assertEq(secondMintedId, 8);
  }

  function test_UpdatePriceMulticall() public setupTestDrop(10) {
    uint256 amount = 2;
    uint104 price = usd100;
    uint256 nativePrice = dummyPriceOracle.convertUsdToWei(price);
    uint256 holographFee = holographDropERC721.getHolographFeeUsd(amount);
    uint256 nativeFee = dummyPriceOracle.convertUsdToWei(holographFee);
    uint256 totalCost = amount * (nativePrice + nativeFee);

    vm.startPrank(DEFAULT_OWNER_ADDRESS);
    bytes[] memory calls = new bytes[](3);
    calls[0] = abi.encodeWithSelector(
      IHolographDropERC721V2.setSaleConfiguration.selector,
      price,
      2,
      0,
      type(uint64).max,
      0,
      0,
      bytes32(0)
    );
    calls[1] = abi.encodeWithSelector(IHolographDropERC721V2.adminMint.selector, address(0x999), 3);
    calls[2] = abi.encodeWithSelector(IHolographDropERC721V2.adminMint.selector, address(0x123), 3);
    bytes[] memory results = holographDropERC721.multicall(calls);

    SaleDetails memory saleDetails = holographDropERC721.saleDetails();

    assertTrue(saleDetails.publicSaleActive);
    assertTrue(!saleDetails.presaleActive);
    assertEq(saleDetails.publicSalePrice, price);
    uint256 firstMintedId = abi.decode(results[1], (uint256));
    uint256 secondMintedId = abi.decode(results[2], (uint256));
    assertEq(firstMintedId, 3);
    assertEq(secondMintedId, 6);
    vm.stopPrank();
    vm.startPrank(address(0x111));
    vm.deal(address(0x111), totalCost);
    holographDropERC721.purchase{value: totalCost}(2);

    HolographERC721 erc721Enforcer = HolographERC721(payable(address(holographDropERC721)));
    assertEq(erc721Enforcer.balanceOf(address(0x111)), 2);
    vm.stopPrank();
  }

  function test_MintWrongValue() public setupTestDrop(10) {
    uint256 amount = 1;
    uint104 price = usd10;
    uint256 nativePrice = dummyPriceOracle.convertUsdToWei(price);
    uint256 holographFee = holographDropERC721.getHolographFeeUsd(amount);
    uint256 nativeFee = dummyPriceOracle.convertUsdToWei(holographFee);
    uint256 totalCost = amount * (nativePrice + nativeFee);

    vm.deal(address(TEST_ACCOUNT), dummyPriceOracle.convertUsdToWei(usd1000));

    // First configure sale to make it inactive
    vm.prank(DEFAULT_OWNER_ADDRESS);
    holographDropERC721.setSaleConfiguration({
      publicSaleStart: type(uint64).max,
      publicSaleEnd: type(uint64).max,
      presaleStart: 0,
      presaleEnd: 0,
      publicSalePrice: price,
      maxSalePurchasePerAddress: 2,
      presaleMerkleRoot: bytes32(0)
    });
    vm.prank(address(TEST_ACCOUNT));
    vm.expectRevert(IHolographDropERC721V2.Sale_Inactive.selector);
    holographDropERC721.purchase{value: nativePrice}(1);

    // Then configure sale to make it active but with wrong price
    vm.prank(DEFAULT_OWNER_ADDRESS);
    holographDropERC721.setSaleConfiguration({
      publicSaleStart: 0,
      publicSaleEnd: type(uint64).max,
      presaleStart: 0,
      presaleEnd: 0,
      publicSalePrice: price,
      maxSalePurchasePerAddress: 2,
      presaleMerkleRoot: bytes32(0)
    });
    vm.startPrank(address(TEST_ACCOUNT));
    vm.expectRevert(
      abi.encodeWithSelector(IHolographDropERC721V2.Purchase_WrongPrice.selector, uint256(price + holographFee))
    );
    holographDropERC721.purchase{value: totalCost / 2}(amount);
    vm.stopPrank();
  }

  function test_Withdraw(uint128 amount) public setupTestDrop(10) {
    vm.assume(amount > 0.01 ether);
    vm.deal(address(holographDropERC721), amount);
    vm.prank(DEFAULT_OWNER_ADDRESS);

    // withdrawnBy and withdrawnTo are indexed in the first two positions
    vm.expectEmit(true, true, false, false);
    uint256 leftoverFunds = amount - (amount * 1) / 20;
    emit FundsWithdrawn(DEFAULT_OWNER_ADDRESS, DEFAULT_FUNDS_RECIPIENT_ADDRESS, leftoverFunds);
    holographDropERC721.withdraw();

    assertTrue(
      HOLOGRAPH_TREASURY_ADDRESS.balance < ((uint256(amount) * 1_000 * 5) / 100000) + 2 ||
        HOLOGRAPH_TREASURY_ADDRESS.balance > ((uint256(amount) * 1_000 * 5) / 100000) + 2
    );
    assertTrue(
      DEFAULT_FUNDS_RECIPIENT_ADDRESS.balance > ((uint256(amount) * 1_000 * 95) / 100000) - 2 ||
        DEFAULT_FUNDS_RECIPIENT_ADDRESS.balance < ((uint256(amount) * 1_000 * 95) / 100000) + 2
    );
  }

  function test_MintLimit(uint8 limit) public setupTestDrop(5000) {
    uint104 price = usd10;
    uint256 nativePrice = dummyPriceOracle.convertUsdToWei(price);
    uint256 holographFee = holographDropERC721.getHolographFeeUsd(limit);
    uint256 nativeFee = dummyPriceOracle.convertUsdToWei(holographFee);
    uint256 totalCost = limit * (nativePrice + nativeFee);

    // set limit to speed up tests
    vm.assume(limit > 0 && limit < 50);
    vm.prank(DEFAULT_OWNER_ADDRESS);
    holographDropERC721.setSaleConfiguration({
      publicSaleStart: 0,
      publicSaleEnd: type(uint64).max,
      presaleStart: 0,
      presaleEnd: 0,
      publicSalePrice: price,
      maxSalePurchasePerAddress: limit,
      presaleMerkleRoot: bytes32(0)
    });

    // First check that we can mint up to the limit
    vm.deal(address(TEST_ACCOUNT), 1_000_000 ether);
    vm.prank(address(TEST_ACCOUNT));
    holographDropERC721.purchase{value: totalCost}(limit);

    assertEq(holographDropERC721.saleDetails().totalMinted, limit);

    // Then check that we can't mint more than the limit
    uint256 overTheLimit = limit + 1;
    holographFee = holographDropERC721.getHolographFeeUsd(overTheLimit);
    nativeFee = dummyPriceOracle.convertUsdToWei(holographFee);
    totalCost = overTheLimit * (nativePrice + nativeFee);

    vm.deal(address(0x444), 1_000_000 ether);
    vm.prank(address(0x444));

    vm.expectRevert(IHolographDropERC721V2.Purchase_TooManyForAddress.selector); // 0x220ae94c
    holographDropERC721.purchase{value: totalCost}(overTheLimit);

    // Make sure that no extra tokens were minted
    assertEq(holographDropERC721.saleDetails().totalMinted, limit);
  }

  function testSetSalesConfiguration() public setupTestDrop(10) {
    uint104 price = usd10;
    uint256 nativePrice = dummyPriceOracle.convertUsdToWei(price);
    vm.prank(DEFAULT_OWNER_ADDRESS);
    holographDropERC721.setSaleConfiguration({
      publicSaleStart: 0,
      publicSaleEnd: type(uint64).max,
      presaleStart: 0,
      presaleEnd: 100,
      publicSalePrice: price,
      maxSalePurchasePerAddress: 10,
      presaleMerkleRoot: bytes32(0)
    });

    (, , , , , uint64 presaleEndLookup, ) = holographDropERC721.salesConfig();
    assertEq(presaleEndLookup, 100);

    vm.startPrank(DEFAULT_OWNER_ADDRESS);
    holographDropERC721.setSaleConfiguration({
      publicSaleStart: 0,
      publicSaleEnd: type(uint64).max,
      presaleStart: 100,
      presaleEnd: 0,
      publicSalePrice: price,
      maxSalePurchasePerAddress: 1003,
      presaleMerkleRoot: bytes32(0)
    });

    (, , , , uint64 presaleStartLookup2, uint64 presaleEndLookup2, ) = holographDropERC721.salesConfig();
    assertEq(presaleEndLookup2, 0);
    assertEq(presaleStartLookup2, 100);
  }

  function test_GlobalLimit(uint16 limit) public setupTestDrop(uint64(limit)) {
    // Set assume to a more reasonable number to speed up tests
    vm.assume(limit > 0 && limit < 10);
    vm.startPrank(DEFAULT_OWNER_ADDRESS);
    holographDropERC721.adminMint(DEFAULT_OWNER_ADDRESS, limit);
    vm.expectRevert(IHolographDropERC721V2.Mint_SoldOut.selector);
    holographDropERC721.adminMint(DEFAULT_OWNER_ADDRESS, 1);
  }

  function test_WithdrawNotAllowed() public setupTestDrop(10) {
    vm.expectRevert(IHolographDropERC721V2.Access_WithdrawNotAllowed.selector);
    holographDropERC721.withdraw();
  }

  function test_InvalidFinalizeOpenEdition() public setupTestDrop(5) {
    uint amount = 3;
    uint104 price = usd10;
    uint256 nativePrice = dummyPriceOracle.convertUsdToWei(price);
    uint256 holographFee = holographDropERC721.getHolographFeeUsd(amount);
    uint256 nativeFee = dummyPriceOracle.convertUsdToWei(holographFee);
    uint256 totalCost = amount * (nativePrice + nativeFee);

    vm.prank(DEFAULT_OWNER_ADDRESS);
    holographDropERC721.setSaleConfiguration({
      publicSaleStart: 0,
      publicSaleEnd: type(uint64).max,
      presaleStart: 0,
      presaleEnd: 0,
      publicSalePrice: price,
      presaleMerkleRoot: bytes32(0),
      maxSalePurchasePerAddress: 5
    });
    holographDropERC721.purchase{value: totalCost}(3);
    vm.prank(DEFAULT_OWNER_ADDRESS);
    holographDropERC721.adminMint(address(0x1234), 2);
    vm.prank(DEFAULT_OWNER_ADDRESS);
    vm.expectRevert(IHolographDropERC721V2.Admin_UnableToFinalizeNotOpenEdition.selector);
    holographDropERC721.finalizeOpenEdition();
  }

  function test_ValidFinalizeOpenEdition() public setupTestDrop(type(uint64).max) {
    uint amount = 3;
    uint104 price = usd10;
    uint256 nativePrice = dummyPriceOracle.convertUsdToWei(price);
    uint256 holographFee = holographDropERC721.getHolographFeeUsd(amount);
    uint256 nativeFee = dummyPriceOracle.convertUsdToWei(holographFee);
    uint256 totalCost = amount * (nativePrice + nativeFee);

    vm.prank(DEFAULT_OWNER_ADDRESS);
    holographDropERC721.setSaleConfiguration({
      publicSaleStart: 0,
      publicSaleEnd: type(uint64).max,
      presaleStart: 0,
      presaleEnd: 0,
      publicSalePrice: price,
      presaleMerkleRoot: bytes32(0),
      maxSalePurchasePerAddress: 10
    });

    holographDropERC721.purchase{value: totalCost}(3);
    vm.prank(DEFAULT_OWNER_ADDRESS);
    holographDropERC721.adminMint(address(0x1234), 2);
    vm.prank(DEFAULT_OWNER_ADDRESS);
    holographDropERC721.finalizeOpenEdition();
    vm.expectRevert(IHolographDropERC721V2.Mint_SoldOut.selector);
    vm.prank(DEFAULT_OWNER_ADDRESS);
    holographDropERC721.adminMint(address(0x1234), 2);
    vm.expectRevert(IHolographDropERC721V2.Mint_SoldOut.selector);
    holographDropERC721.purchase{value: nativePrice * 3}(3);
  }

  function test_AdminMint() public setupTestDrop(10) {
    address minter = address(0x32402);
    vm.startPrank(DEFAULT_OWNER_ADDRESS);
    holographDropERC721.adminMint(DEFAULT_OWNER_ADDRESS, 1);
    HolographERC721 erc721Enforcer = HolographERC721(payable(address(holographDropERC721)));
    require(erc721Enforcer.balanceOf(DEFAULT_OWNER_ADDRESS) == 1, "Wrong balance");
    holographDropERC721.adminMint(minter, 1);
    require(erc721Enforcer.balanceOf(minter) == 1, "Wrong balance");
    assertEq(holographDropERC721.saleDetails().totalMinted, 2);
  }

  // NOTE: This test functions differently than previously because change
  //       to allow zero edition size in canMintTokens modifier
  //       This test is now testing that tokens can be minted when edition size is zero
  function test_EditionSizeZero() public setupTestDrop(0) {
    uint256 amount = 2;
    uint104 price = usd100;
    uint256 nativePrice = dummyPriceOracle.convertUsdToWei(price);
    uint256 holographFee = holographDropERC721.getHolographFeeUsd(amount);
    uint256 nativeFee = dummyPriceOracle.convertUsdToWei(holographFee);
    uint256 totalCost = amount * (nativePrice + nativeFee);

    vm.startPrank(DEFAULT_OWNER_ADDRESS);
    address minter = address(0x32402);
    holographDropERC721.adminMint(DEFAULT_OWNER_ADDRESS, 1);
    holographDropERC721.adminMint(minter, 1);

    holographDropERC721.setSaleConfiguration({
      publicSaleStart: 0,
      publicSaleEnd: type(uint64).max,
      presaleStart: 0,
      presaleEnd: 0,
      publicSalePrice: price,
      maxSalePurchasePerAddress: 2,
      presaleMerkleRoot: bytes32(0)
    });

    vm.stopPrank();
    vm.deal(address(TEST_ACCOUNT), totalCost);
    vm.prank(address(TEST_ACCOUNT));
    holographDropERC721.purchase{value: totalCost}(2);
  }

  function test_SoldOut() public setupTestDrop(1) {
    uint104 price = usd10;
    uint256 nativePrice = dummyPriceOracle.convertUsdToWei(price);
    vm.prank(DEFAULT_OWNER_ADDRESS);
    holographDropERC721.adminMint(DEFAULT_OWNER_ADDRESS, 1);

    vm.deal(address(TEST_ACCOUNT), nativePrice * 2);
    vm.prank(address(TEST_ACCOUNT));
    vm.expectRevert(IHolographDropERC721V2.Mint_SoldOut.selector);
    holographDropERC721.purchase{value: nativePrice}(1);
  }

  // test Admin airdrop
  function test_AdminMintAirdrop() public setupTestDrop(1000) {
    vm.startPrank(DEFAULT_OWNER_ADDRESS);
    address[] memory toMint = new address[](4);
    toMint[0] = address(0x10);
    toMint[1] = address(0x11);
    toMint[2] = address(0x12);
    toMint[3] = address(0x13);
    holographDropERC721.adminMintAirdrop(toMint);

    HolographERC721 erc721Enforcer = HolographERC721(payable(address(holographDropERC721)));
    assertEq(holographDropERC721.saleDetails().totalMinted, 4);
    assertEq(erc721Enforcer.balanceOf(address(0x10)), 1);
    assertEq(erc721Enforcer.balanceOf(address(0x11)), 1);
    assertEq(erc721Enforcer.balanceOf(address(0x12)), 1);
    assertEq(erc721Enforcer.balanceOf(address(0x13)), 1);
  }

  function test_AdminMintAirdropFails() public setupTestDrop(1000) {
    vm.startPrank(address(0x10));
    address[] memory toMint = new address[](4);
    toMint[0] = address(0x10);
    toMint[1] = address(0x11);
    toMint[2] = address(0x12);
    toMint[3] = address(0x13);
    vm.expectRevert("ERC721: owner only function");
    holographDropERC721.adminMintAirdrop(toMint);
  }

  // test admin mint non-admin permissions
  function test_AdminMintBatch() public setupTestDrop(1000) {
    vm.startPrank(DEFAULT_OWNER_ADDRESS);
    holographDropERC721.adminMint(DEFAULT_OWNER_ADDRESS, 100);

    HolographERC721 erc721Enforcer = HolographERC721(payable(address(holographDropERC721)));
    assertEq(holographDropERC721.saleDetails().totalMinted, 100);
    assertEq(erc721Enforcer.balanceOf(DEFAULT_OWNER_ADDRESS), 100);
  }

  function test_AdminMintBatchFails() public setupTestDrop(1000) {
    vm.startPrank(address(0x10));
    vm.expectRevert("ERC721: owner only function");
    holographDropERC721.adminMint(address(0x10), 100);
  }

  function test_Burn() public setupTestDrop(10) {
    vm.startPrank(DEFAULT_OWNER_ADDRESS);
    address minter = address(0x32402);

    address[] memory airdrop = new address[](1);
    airdrop[0] = minter;

    holographDropERC721.adminMintAirdrop(airdrop);
    vm.stopPrank();

    vm.startPrank(minter);
    HolographERC721 erc721Enforcer = HolographERC721(payable(address(holographDropERC721)));
    erc721Enforcer.burn(FIRST_TOKEN_ID);
    vm.stopPrank();
  }

  function test_BurnNonOwner() public setupTestDrop(10) {
    address minter = address(0x32402);
    vm.startPrank(DEFAULT_OWNER_ADDRESS);
    address[] memory airdrop = new address[](1);
    airdrop[0] = minter;
    holographDropERC721.adminMintAirdrop(airdrop);
    vm.stopPrank();

    vm.prank(address(0x1));
    HolographERC721 erc721Enforcer = HolographERC721(payable(address(holographDropERC721)));
    vm.expectRevert(abi.encodeWithSelector(ERC721_NotApprovedSender.selector, address(0x1), FIRST_TOKEN_ID));
    erc721Enforcer.burn(FIRST_TOKEN_ID);
  }

  // TODO: Add test burn failure state for users that don't own the token

  function test_EIP165() public setupTestDrop(10) {
    require(holographDropERC721.supportsInterface(0x01ffc9a7), "supports 165");
    require(holographDropERC721.supportsInterface(0x80ac58cd), "supports 721");
    require(holographDropERC721.supportsInterface(0x5b5e139f), "supports 721-metdata");
    require(holographDropERC721.supportsInterface(0x2a55205a), "supports 2981");
    require(!holographDropERC721.supportsInterface(0x0000000), "doesnt allow non-interface");
  }

  function test_Fallback() public setupTestDrop(10) {
    bytes4 functionSignature = bytes4(keccak256("nonExistentFunction()"));
    (bool success, bytes memory result) = address(holographDropERC721).call(abi.encodeWithSelector(functionSignature));

    require(!success, "Function call should fail");
    console.log(string(result));
  }

  // TEST HELPERS
  function getDeploymentConfig(
    string memory contractName,
    string memory contractSymbol,
    uint16 contractBps,
    uint256 eventConfig,
    bool skipInit,
    DropsInitializerV2 memory initializer
  ) public returns (DeploymentConfig memory) {
    bytes memory bytecode = abi.encodePacked(vm.getCode("HolographDropERC721Proxy.sol:HolographDropERC721Proxy"));
    bytes memory initCode = abi.encode(
      bytes32(0x0000000000000000000000486f6c6f677261706844726f704552433732315632), // Source contract type HolographDropERC721V2
      address(Constants.getHolographRegistryProxy()), // address of registry (to get source contract address from)
      abi.encode(initializer) // actual init code for source contract (HolographDropERC721V2)
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
}
