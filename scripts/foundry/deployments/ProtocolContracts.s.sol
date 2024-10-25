// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {Vm} from "forge-std/Vm.sol";
import {stdJson} from "forge-std/StdJson.sol";

import {Holograph} from "src/Holograph.sol";
import {HolographBridge} from "src/HolographBridge.sol";
import {HolographFactory} from "src/HolographFactory.sol";
import {HolographOperator} from "src/HolographOperator.sol";
import {HolographInterfaces} from "src/HolographInterfaces.sol";
import {HolographRegistry} from "src/HolographRegistry.sol";
import {HolographGenesis} from "src/HolographGenesis.sol";

import {Logger} from "../utils/Logger.sol";
import {ForkHelper} from "../utils/ForkHelper.sol";
import {EnvHelper} from "../utils/EnvHelper.sol";
import {SafeWallet} from "../utils/SafeWallet.sol";

contract ProtocolContractsDeployScript is Script, Logger {
  using stdJson for string;

  HolographGenesis holographGenesis;

  address currentWallet;

  string constant HOLOGRAPH = "Holograph";
  string constant HOLOGRAPH_BRIDGE = "HolographBridge";
  string constant HOLOGRAPH_FACTORY = "HolographFactory";
  string constant HOLOGRAPH_OPERATOR = "HolographOperator";
  string constant HOLOGRAPH_INTERFACES = "HolographInterfaces";
  string constant HOLOGRAPH_REGISTERY = "HolographRegistry";

  function deploy(
    bytes32 _deployerPrivateKey,
    address hardwareWallet,
    address safeWallet,
    address ledgerSafeSigner,
    bytes32 safeSignerPrivateKey,
    string memory contractName,
    bytes memory bytecode,
    bytes memory initcode,
    uint256[] calldata chainIds
  ) public {
    uint256 deployerPrivateKey = uint256(_deployerPrivateKey);

    if (safeWallet != address(0)) {
      currentWallet = safeWallet;
    } else if (hardwareWallet != address(0)) {
      currentWallet = hardwareWallet;
    } else {
      currentWallet = vm.addr(deployerPrivateKey);
    }

    if (ledgerSafeSigner == address(0) && safeSignerPrivateKey == bytes32(0)) {
      revert("Either ledgerSafeSigner or safeSignerPrivateKey must be set");
    }

    bool isSafeSignerLedger = ledgerSafeSigner != address(0);

    loadProtocolContracts();

    // TODO: set it based on the HOLOGRAPH_ENVIRONMENT
    bytes32 deploymentSalt = vm.envOr("DEPLOYMENT_SALT", bytes32(0));

    for (uint256 i = 0; i < chainIds.length; i++) {
      ForkHelper.forkByChainId(chainIds[i]);

      // Broadcast transaction with deployer private key
      if (safeWallet == address(0)) {
        vm.startBroadcast(hardwareWallet);
      } else if (safeWallet == address(0)) {
        vm.startBroadcast(deployerPrivateKey);
      }

      if (safeWallet == address(0)) {
        logHlgDeployerMessage(
          string(
            abi.encodePacked(
              "Simulating ",
              contractName,
              " deployment on ",
              magenta(ForkHelper.getChainName(chainIds[i]))
            )
          )
        );
      }

      // Deploy implementation contract
      address implem = deployImplementation(contractName);

      // Divide the salt into saltHash (bytes12) and secret (bytes20)
      bytes20 secret = bytes20(deploymentSalt); // Extract the first 20 bytes
      bytes12 saltHash = bytes12(deploymentSalt << 160); // Extract the first 12 bytes

      // Deploy the new layerZeroV2Module using the holographGenesis contract
      if (safeWallet != address(0)) {
        if (isSafeSignerLedger) {
          bytes memory res = SafeWallet.createTransactionWithALedgerSafeSigner(
            safeWallet,
            ledgerSafeSigner,
            address(holographGenesis),
            abi.encodeWithSignature(
              "deploy(uint256,bytes12,bytes20,bytes,bytes)",
              block.chainid,
              saltHash,
              secret,
              bytecode,
              initcode
            )
          );
          console.log(string(res));
        } else {
          bytes memory res = SafeWallet.createTransaction(
            safeWallet,
            safeSignerPrivateKey,
            address(holographGenesis),
            abi.encodeWithSignature(
              "deploy(uint256,bytes12,bytes20,bytes,bytes)",
              block.chainid,
              saltHash,
              secret,
              bytecode,
              initcode
            )
          );
        }
      } else {
        // Start recording emitted events
        vm.recordLogs();

        holographGenesis.deploy(block.chainid, saltHash, secret, bytecode, initcode);

        // Retrive the deployed contract address from the emitted events
        Vm.Log[] memory entries = vm.getRecordedLogs();
        address _deployedContract = abi.decode(entries[0].data, (address));
        logHlgDeployerMessage(
          string(
            abi.encodePacked(
              contractName,
              " deployment simulation succeed on ",
              magenta(ForkHelper.getChainName(chainIds[i]))
            )
          )
        );
        vm.stopBroadcast();
      }
    }
  }

  function getHolographGenesisCalldata(bytes memory bytecode, bytes memory initcode) public returns (address) {
    loadProtocolContracts();

    logHlgDeployerMessage(
      string(abi.encodePacked("Holograph genesis address: ", (vm.toString(address(holographGenesis)))))
    );

    // TODO: set it based on the HOLOGRAPH_ENVIRONMENT
    bytes32 deploymentSalt = vm.envOr("DEPLOYMENT_SALT", bytes32(0));
    // Divide the salt into saltHash (bytes12) and secret (bytes20)
    bytes20 secret = bytes20(deploymentSalt); // Extract the first 20 bytes
    bytes12 saltHash = bytes12(deploymentSalt << 160); // Extract the first 12 bytes

    logHlgDeployerMessage(
      string(
        abi.encodePacked(
          "calldata: ",
          vm.toString(abi.encodeWithSignature(
            "deploy(uint256,bytes12,bytes20,bytes,bytes)",
            block.chainid,
            saltHash,
            secret,
            bytecode,
            initcode
          ))
        )
      )
    );

    return address(holographGenesis);
  }

  /**
   * Load the protocol contracts addresses from the environment
   * @dev This function reads the json files from the deployments folder based on
   *      the HOLOGRAPH_ENVIRONMENT env variable.
   */
  function loadProtocolContracts() private {
    string memory currentEnv;
    try vm.envString("HOLOGRAPH_ENVIRONMENT") returns (string memory _currentEnv) {
      currentEnv = _currentEnv;
    } catch {
      revert("HOLOGRAPH_ENVIRONMENT env variable is not set");
    }

    if (
      keccak256(abi.encodePacked(currentEnv)) != keccak256(abi.encodePacked("develop")) &&
      keccak256(abi.encodePacked(currentEnv)) != keccak256(abi.encodePacked("testnet")) &&
      keccak256(abi.encodePacked(currentEnv)) != keccak256(abi.encodePacked("mainnet"))
    ) {
      revert("Invalid HOLOGRAPH_ENVIRONMENT. Possible values are: develop, testnet, mainnet");
    }

    /* ---------------------------- Protocol contracts ---------------------------- */

    // Construct the path where the protocol contracts deployments json files are stored
    string memory deployPath = string(abi.encodePacked("deployments/", currentEnv, "/"));
    VmSafe.DirEntry[] memory dirs = vm.readDir(deployPath);

    // Read the protocol contracts deployment json files
    string memory holographJson = vm.readFile(string(abi.encodePacked(dirs[0].path, "/Holograph.json")));

    address forcedHolographGenesisAddress = vm.envOr("HOLOGRAPH_GENESIS_ADDRESS", address(0));
    if (forcedHolographGenesisAddress != address(0)) {
      holographGenesis = HolographGenesis(payable(forcedHolographGenesisAddress));
    } else {
      holographGenesis = HolographGenesis(payable(holographJson.readAddress(".receipt.to")));
    }
  }

  function deployImplementation(string memory contractName) private returns (address) {
    if (keccak256(bytes(contractName)) == keccak256(bytes(HOLOGRAPH))) {
      return address(new Holograph());
    } else if (keccak256(bytes(contractName)) == keccak256(bytes(HOLOGRAPH_BRIDGE))) {
      return address(new HolographBridge());
    } else if (keccak256(bytes(contractName)) == keccak256(bytes(HOLOGRAPH_FACTORY))) {
      return address(new HolographFactory());
    } else if (keccak256(bytes(contractName)) == keccak256(bytes(HOLOGRAPH_OPERATOR))) {
      return address(new HolographOperator());
    } else if (keccak256(bytes(contractName)) == keccak256(bytes(HOLOGRAPH_INTERFACES))) {
      // No proxy implementation for interfaces
      return address(0);
    } else if (keccak256(bytes(contractName)) == keccak256(bytes(HOLOGRAPH_REGISTERY))) {
      // No proxy implementation for registry
      return address(0);
    } else {
      revert(string(abi.encodePacked("Foundry unsupported contract: ", contractName)));
    }
  }
}
