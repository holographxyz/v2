// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {Test, Vm, console} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";

import {Holograph} from "src/Holograph.sol";
import {HolographGenesis} from "src/HolographGenesis.sol";
import {HolographBridge} from "src/HolographBridge.sol";
import {HolographInterfaces} from "src/HolographInterfaces.sol";
import {HolographFactory} from "src/HolographFactory.sol";
import {HolographOperator} from "src/HolographOperator.sol";
import {HolographRegistry} from "src/HolographRegistry.sol";
import {HolographTreasury} from "src/HolographTreasury.sol";
import {LayerZeroModuleProxyV2} from "src/module/LayerZeroModuleProxyV2.sol";
import {LayerZeroModuleV2} from "src/module/LayerZeroModuleV2.sol";
import {GasParameters} from "src/struct/GasParameters.sol";
import {EndpointPeer} from "src/interface/ILayerZeroEndpointV2.sol";
import {ChainIdType} from "src/enum/ChainIdType.sol";

import {ChainGasParameters} from "scripts/foundry/utils/ChainGasParameters.sol";
import {ForkHelper} from "scripts/foundry/utils/ForkHelper.sol";
import {DeploymentHelper} from "scripts/foundry/utils/DeploymentHelper.sol";

import {Utils} from "../utils/Utils.sol";

contract LayerZeroV2ModuleFixture is Test {
  // Admin address
  address admin;
  // Approved genesis deployer
  address approvedGenesisDeployer = address(0xfFc178694Ea206E10F2314A3a9661fdA41FE486D);

  // Optimism sepolia chain id
  uint256 opSepoliaChainId = 11155420;
  // Arbitrum sepolia chain id
  uint256 arbSepoliaChainId = 421614;
  // Arbitrum sepolia endpoint id
  uint256 arbSepoliaEndpointId = 40231;

  // Default source chain
  uint256 defaultSourceChain = opSepoliaChainId;
  // Default destination chain
  uint256 defaultDestinationChain = arbSepoliaChainId;

  // Layer zero endpoint v2
  address lzEndpoint = address(0x6EDCE65403992e310A62460808c4b910D972f10f);
  // Layer zero executor
  address lzExecutor = address(0xDc0D68899405673b932F0DB7f8A49191491A5bcB);

  // Deployed Cxip ERC721
  address erc721 = address(0x73e4d61F5C2b325EbE0ef33a0fd7089898556B83);
  // An owner of a Cxip ERC721 token
  address erc721Owner = address(0x983DD3402BF68Da001dd08c955D33A824CF22cB0);
  // A Cxip ERC721 token id owned by erc721Owner
  uint256 erc721TokenId = uint256(0xee6b284a00000000000000000000000000000000000000000000000000000001);

  // Holograph proxy
  Holograph holograph = Holograph(payable(0xE149661040a4aFc91936258c7487ACC90725Cb7B));
  // HolographGenesis proxy
  HolographGenesis holographGenesis = HolographGenesis(payable(0x531790b827d7CD803B32A077bEE437Ce2c094C11));
  // holographBridge proxy
  HolographBridge holographBridge = HolographBridge(payable(0xbe2B3b95927a4260CAc28Ec78a3EE33150F6eae9));
  // holographBridge proxy
  HolographInterfaces holographInterfaces = HolographInterfaces(payable(0x5d8Ec7806cF835628935b659fE046Be7b5d7b60C));
  // holographFactory proxy
  HolographFactory holographFactory = HolographFactory(payable(0x1dB08CabD0aE756D473052361d0706F5030E1Fa2));
  // holographOperator proxy
  HolographOperator holographOperator = HolographOperator(payable(0x9f411c719DCBD22716ff1B78f0dDFbd8C214f11B));
  // holographRegistry proxy
  HolographRegistry holographRegistry = HolographRegistry(payable(0xb41F36CA99BC7cfd7681b969c6E29EB5949A49a6));
  // holographTreasury proxy
  HolographTreasury holographTreasury = HolographTreasury(payable(0x0CFA0c4ADC6deA2e03C118C46293b62aDF0cAfD5));
  // Current layerZeroModule
  LayerZeroModuleV2 currentLayerZeroModuleV2 = LayerZeroModuleV2(payable(0x64d76c3c8c5D14080ffbDfD947b5bC08e06926e1));
  // Optimism gas price oracle
  address gasPriceOracle = address(0xbc246E7F89d3964bFC1dAd24060333AC1705b701);

  // LayerZeroV2Module
  LayerZeroModuleV2 layerZeroV2ModuleImplementation;
  // LayerZeroV2Module
  LayerZeroModuleV2 layerZeroV2Module;

  // Deployment 
  bytes32 deploymentSalt = keccak256(abi.encodePacked("Salt"));

  mapping(uint256 => uint256) forks;

  constructor() {}

  function setUp() public virtual {
    string memory forkUrl = vm.envString("OPTIMISM_TESTNET_SEPOLIA_RPC_URL");
    uint256 forkId = vm.createFork(forkUrl);
    vm.selectFork(forkId);

    admin = holographOperator.admin();
    vm.deal(admin, 10000 ether);
    vm.startPrank(admin);

    // Deploy layerZeroV2Module implementation contract
    layerZeroV2ModuleImplementation = new LayerZeroModuleV2();

    uint256[] memory chainIds = new uint256[](2);
    chainIds[0] = opSepoliaChainId;
    chainIds[1] = arbSepoliaChainId;

    for (uint256 i = 0; i < chainIds.length; i++) {
      forkByChainId(chainIds[i]);

      // Deploy layerZeroV2Module implementation contract
      layerZeroV2ModuleImplementation = new LayerZeroModuleV2();

      // Chains ids
      uint32[] memory supportedChains = new uint32[](chainIds.length);
      for (uint256 j = 0; j < chainIds.length; j++) supportedChains[j] = uint32(chainIds[j]);

      // Gas parameters
      GasParameters[] memory gasParameters = new GasParameters[](chainIds.length);
      for (uint256 j = 0; j < chainIds.length; j++) gasParameters[j] = ChainGasParameters.getGasParameters(chainIds[j]);

      // Whiteliste the new layerZeroV2Module for all chains
      EndpointPeer[] memory peers = new EndpointPeer[](chainIds.length);
      address futurLayerZeroModule = DeploymentHelper.computeGenesisDeploymentAddress(
        deploymentSalt,
        type(LayerZeroModuleProxyV2).creationCode,
        address(holographGenesis)
      );
      for (uint256 j = 0; j < chainIds.length; j++) {
        peers[j] = EndpointPeer({peer: futurLayerZeroModule, eid: DeploymentHelper.getEndpointId(chainIds[j])});
      }

      // Encode Layer zero module proxy init code
      bytes memory initCode = abi.encode(
        address(layerZeroV2ModuleImplementation),
        abi.encode(
          address(holographBridge),
          address(holographInterfaces),
          address(holographOperator),
          address(gasPriceOracle),
          DeploymentHelper.getLzEndpoint(chainIds[i]),
          DeploymentHelper.getLzExecutor(chainIds[i]),
          address(holograph),
          supportedChains,
          gasParameters,
          peers
        )
      );

      // Deploy layerZeroV2Module
      bytes32 salt = deploymentSalt;

      // Divide the salt into saltHash (bytes12) and secret (bytes20)
      bytes20 secret = bytes20(salt); // Extract the first 20 bytes
      bytes12 saltHash = bytes12(salt << 160); // Extract the first 12 bytes

      // Start recording emitted events
      vm.recordLogs();

      // Deploy the new layerZeroV2Module using the holographGenesis contract
      vm.stopPrank();
      vm.prank(approvedGenesisDeployer);
      holographGenesis.deploy(block.chainid, saltHash, secret, type(LayerZeroModuleProxyV2).creationCode, initCode);
      vm.startPrank(admin);

      // Retrive the deployed layerZeroV2Module address from the emitted events
      Vm.Log[] memory entries = vm.getRecordedLogs();
      address _layerZeroV2Module = abi.decode(entries[0].data, (address));
      layerZeroV2Module = LayerZeroModuleV2(payable(address(_layerZeroV2Module)));

      // Compare the deployed layerZeroV2Module with the expected one
      if (_layerZeroV2Module != futurLayerZeroModule)
        revert(
          string(
            abi.encodePacked(
              "The deployed layerZeroV2Module address is different from the expected one: ",
              vm.toString(_layerZeroV2Module),
              " != ",
              vm.toString(futurLayerZeroModule)
            )
          )
        );

      // Set operator's messaging module to the new LayerZeroModuleV2
      holographOperator.setMessagingModule(address(layerZeroV2Module));

      for (uint256 j = 0; j < chainIds.length; j++) {
        if (chainIds[j] == block.chainid) continue;

        // Update holographInterface chainId map
        holographInterfaces.updateChainIdMap(
          ChainIdType.HOLOGRAPH,
          chainIds[j],
          ChainIdType.LAYERZEROV2,
          DeploymentHelper.getEndpointId(chainIds[j])
        );
      }

      vm.stopPrank();
    }

    // Fork back to OP sepolia chain as default
    forkByChainId(opSepoliaChainId);

    /* -------------------------------------------------------------------------- */
    /*                               Label addresses                              */
    /* -------------------------------------------------------------------------- */

    // Label layerZeroV2ModuleImplementation
    vm.label(
      address(layerZeroV2ModuleImplementation),
      string(
        abi.encodePacked("layerZeroV2ModuleImplementation(", vm.toString(address(layerZeroV2ModuleImplementation)), ")")
      )
    );

    // Label layerZeroV2Module
    vm.label(
      address(layerZeroV2Module),
      string(abi.encodePacked("layerZeroV2Module(", vm.toString(address(layerZeroV2Module)), ")"))
    );

    // Label holographBridge
    vm.label(
      address(holographBridge),
      string(abi.encodePacked("holographBridge(", vm.toString(address(holographBridge)), ")"))
    );

    // Label holographInterfaces
    vm.label(
      address(holographInterfaces),
      string(abi.encodePacked("holographInterfaces(", vm.toString(address(holographInterfaces)), ")"))
    );

    // Label holographFactory
    vm.label(
      address(holographFactory),
      string(abi.encodePacked("holographFactory(", vm.toString(address(holographFactory)), ")"))
    );

    // Label holographOperator
    vm.label(
      address(holographOperator),
      string(abi.encodePacked("holographOperator(", vm.toString(address(holographOperator)), ")"))
    );

    // Label holographRegistry
    vm.label(
      address(holographRegistry),
      string(abi.encodePacked("holographRegistry(", vm.toString(address(holographRegistry)), ")"))
    );

    // Label holographTreasury
    vm.label(
      address(holographTreasury),
      string(abi.encodePacked("holographTreasury(", vm.toString(address(holographTreasury)), ")"))
    );

    // Label currentLayerZeroModuleV2
    vm.label(
      address(currentLayerZeroModuleV2),
      string(abi.encodePacked("currentLayerZeroModuleV2(", vm.toString(address(currentLayerZeroModuleV2)), ")"))
    );

    // Label admin
    vm.label(admin, string(abi.encodePacked("admin(", vm.toString(address(admin)), ")")));

    // Label erc721
    vm.label(erc721, string(abi.encodePacked("erc721(", vm.toString(address(erc721)), ")")));

    // Label erc721Owner
    vm.label(erc721Owner, string(abi.encodePacked("erc721Owner(", vm.toString(address(erc721Owner)), ")")));

    // Label lzEndpoint
    vm.label(lzEndpoint, string(abi.encodePacked("lzEndpoint(", vm.toString(address(lzEndpoint)), ")")));
  }

  /* -------------------------------------------------------------------------- */
  /*                             Internal functions                             */
  /* -------------------------------------------------------------------------- */

  function forkByChainId(uint256 chainId) internal {
    uint256 forkId;
    if (forks[chainId] != 0) {
      forkId = forks[chainId];
    } else {
      string memory forkUrl = ForkHelper.getRpcUrl(chainId);
      forkId = vm.createFork(forkUrl);
      forks[chainId] = forkId;
    }
    vm.selectFork(forkId);
  }
}
