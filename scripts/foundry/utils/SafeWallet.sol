// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Vm} from "forge-std/Vm.sol";
import {console} from "forge-std/console.sol";
import {ForkHelper} from "../utils/ForkHelper.sol";

library SafeWallet {
  function createTransaction(
    address safeWallet,
    bytes32 safeSignerPrivateKey,
    address to,
    bytes memory data
  ) internal returns (bytes memory res) {
    createTransactionOnChain(safeWallet, safeSignerPrivateKey, block.chainid, to, data);
  }

  function createTransactionOnChain(
    address safeWallet,
    bytes32 safeSignerPrivateKey,
    uint256 chainId,
    address to,
    bytes memory data
  ) internal returns (bytes memory res) {
    Vm vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    string[] memory inputs = new string[](16);
    inputs[0] = "node";
    inputs[1] = "./scripts/utils/safeCLI/targets/cli.js";
    inputs[2] = "safeTx";
    inputs[3] = "--chain";
    inputs[4] = vm.toString(chainId);
    inputs[5] = "--calldata";
    inputs[6] = vm.toString(data);
    inputs[7] = "--safe";
    inputs[8] = vm.toString(safeWallet);
    inputs[9] = "--to";
    inputs[10] = vm.toString(to);
    inputs[11] = "--rpc";
    inputs[12] = ForkHelper.getRpcUrl(chainId);
    inputs[13] = "--private-key";
    inputs[14] = vm.toString(safeSignerPrivateKey);
    inputs[15] = "--silent";

    res = vm.ffi(inputs);
  }

  function createTransactionWithALedgerSafeSigner(
    address safeWallet,
    address ledgerSafeSigner,
    address to,
    bytes memory data
  ) internal returns (bytes memory res) {
    createTransactionWithASoftwareSafeSigner(safeWallet, ledgerSafeSigner, block.chainid, to, data);
  }

  function createTransactionWithASoftwareSafeSigner(
    address safeWallet,
    address ledgerSafeSigner,
    uint256 chainId,
    address to,
    bytes memory data
  ) internal returns (bytes memory res) {
    Vm vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));
    console.log("data length: ", data.length);

    string[] memory inputs = new string[](16);
    inputs[0] = "node";
    inputs[1] = "./scripts/utils/safeCLI/targets/cli.js";
    inputs[2] = "safeTx";
    inputs[3] = "--chain";
    inputs[4] = vm.toString(chainId);
    inputs[5] = "--calldata";
    inputs[6] = vm.toString(data);
    inputs[7] = "--safe";
    inputs[8] = vm.toString(safeWallet);
    inputs[9] = "--to";
    inputs[10] = vm.toString(to);
    inputs[11] = "--ledger";
    inputs[12] = vm.toString(ledgerSafeSigner);
    inputs[13] = "--rpc";
    inputs[14] = ForkHelper.getRpcUrl(chainId);
    inputs[15] = "--silent";

    for (uint256 i = 0; i < inputs.length; i++) {
      console.log(inputs[i], " ");
    }

    res = vm.ffi(inputs);
  }

  /**
   * @notice Get the name of the ts-utils-cli file for the current machine
   * @dev Does not work on windows
   * @dev Possible values: ts-utils-cli-linux-x64, ts-utils-cli-macos-arm64, ts-utils-cli-macos-x64
   * @return fileName The name of the ts-utils-cli file for the current machine
   */
  function getTsUtilsCliFileName() internal returns (string memory fileName) {
    string memory arch = getArch();
    string memory kernel = getKernel();

    if (keccak256(abi.encodePacked(arch)) == keccak256(abi.encodePacked("Linux"))) {
      fileName = "ts-utils-cli-linux-x64";
    } else if (keccak256(abi.encodePacked(arch)) == keccak256(abi.encodePacked("Darwin"))) {
      if (keccak256(abi.encodePacked(kernel)) == keccak256(abi.encodePacked("arm64"))) {
        fileName = "ts-utils-cli-macos-arm64";
      } else {
        fileName = "ts-utils-cli-macos-x64";
      }
    }
  }

  /**
   * @notice Get the architecture of the current machine
   * @dev Does not work on windows
   */
  function getArch() internal returns (string memory) {
    Vm vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    string[] memory inputs = new string[](2);
    inputs[0] = "uname";
    inputs[1] = "-s";

    return string(vm.ffi(inputs));
  }

  /**
   * @notice Get the kernel of the current machine
   * @dev Does not work on windows
   */
  function getKernel() internal returns (string memory) {
    Vm vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    string[] memory inputs = new string[](2);
    inputs[0] = "uname";
    inputs[1] = "-m";

    return string(vm.ffi(inputs));
  }
}
