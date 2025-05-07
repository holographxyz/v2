// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {Test, Vm} from "forge-std/Test.sol";

import {IHolographDropERC721V2} from "src/drops/interface/IHolographDropERC721V2.sol";
import {HolographDropERC721V2} from "src/drops/token/HolographDropERC721V2.sol";

/**
 * @title HolographDropERC721Test
 * @notice The goal of this test is to reproduce the exact transaction made at block 6031723 one time, and
 *         then to reproduce the same transaction but with the new version of the contract to confirm that
 *         the new version fixed the whole issue.
 * @dev To run this test you need to use a fork of sepolia at the block 6031724 and to use -vvvv flag to see
 *      the logs. The fixes should fix one of the ETH transfer that was made to the contract and that was
 *      reverting with an EvmError: OutOfFunds
 */
contract HolographDropERC721Test is Test {
  string OP_RPC_URL = vm.envString("OP_RPC_URL");
  string SEPOLIA_RPC_URL = vm.envString("SEPOLIA_RPC_URL");
  string OP_SEPOLIA_RPC_URL = vm.envString("OP_SEPOLIA_RPC_URL");
  string BASE_SEPOLIA_RPC_URL = vm.envString("BASE_SEPOLIA_RPC_URL");
  string ZORA_SEPOLIA_RPC_URL = vm.envString("ZORA_SEPOLIA_RPC_URL");
  string ARB_SEPOLIA_RPC_URL = vm.envString("ARB_SEPOLIA_RPC_URL");
  string BNB_TESTNET_RPC_URL = vm.envString("BNB_TESTNET_RPC_URL");
  string FUJI_RPC_URL = vm.envString("FUJI_RPC_URL");

  uint256 optimismFork;
  uint256 sepoliaFork;
  uint256 opSepoliaFork;
  uint256 baseSepoliaFork;
  uint256 zoraSepoliaFork;
  uint256 arbSepoliaFork;
  uint256 bnbTestnetFork;
  uint256 fujiFork;

  function setUp() public {
    optimismFork = vm.createFork(OP_RPC_URL);
    sepoliaFork = vm.createFork(SEPOLIA_RPC_URL);
    opSepoliaFork = vm.createFork(OP_SEPOLIA_RPC_URL);
    baseSepoliaFork = vm.createFork(BASE_SEPOLIA_RPC_URL);
    zoraSepoliaFork = vm.createFork(ZORA_SEPOLIA_RPC_URL);
    arbSepoliaFork = vm.createFork(ARB_SEPOLIA_RPC_URL);
    bnbTestnetFork = vm.createFork(BNB_TESTNET_RPC_URL);
    fujiFork = vm.createFork(FUJI_RPC_URL);
  }

  /* -------------------------------------------------------------------------- */
  /*                                   SEPOLIA                                  */
  /* -------------------------------------------------------------------------- */

  /* ------------------------- Reproduced transaction ------------------------- */

  /**
   * @dev This test reproduce the exact transaction made at block 6031723
   *      => https://sepolia.etherscan.io/tx/0xb8dcf96afafb93d9148c1c469712ec37be17b8913a68f2c1a1d371a18d1194fb
   *      => https://dashboard.tenderly.co/tx/sepolia/0xb8dcf96afafb93d9148c1c469712ec37be17b8913a68f2c1a1d371a18d1194fb/debugger?trace=0.4.3.3.23
   * @dev To run this test you need to use a fork of sepolia at the block 6031724 and to use -vvvv flag to see
   *      the logs. You should see the transfer to 0xa57106357F9A487F6AfBaA3758e7fCcB787113c4 with a value of 609888904007765 wei
   *      failing with an EvmError: OutOfFunds
   */
  function test_Sepolia_V2PurchaseFreeMoeWithOldVersion() public {
    vm.selectFork(sepoliaFork);

    /// @dev To run this test you need to use a fork of sepolia at the block 6031724
    ///      You can create a fork like that using tenderly and creating a new fork at block 6031723
    assertEq(block.number, 6031724);
    assertEq(block.chainid, 11155111);

    // Doing the exact same call as the target transaction
    vm.prank(0xa57106357F9A487F6AfBaA3758e7fCcB787113c4);
    (bool success, bytes memory data) = address(0x731F5129F241edAc48fA088c5DE3b3149dF822FD).call{value: 609888904007765}(
      abi.encodeWithSelector(
        IHolographDropERC721V2.purchase.selector,
        1
      )
    );

    assertTrue(success);
  }

  /* ---------------------------- Fixed transaction --------------------------- */

  /**
   * @dev This test reproduce the exact transaction made at block 6031723 BUT with the fixed version of the HolographDropERC721V2
   *      The HolographDropERC721V2 is at the address 0xf43953DDE38d03F3feA00DD76685857E57Af49C8, and its bytecode is replaced
   *      with the new version of the contract.
   *      => https://sepolia.etherscan.io/tx/0xb8dcf96afafb93d9148c1c469712ec37be17b8913a68f2c1a1d371a18d1194fb
   *      => https://dashboard.tenderly.co/tx/sepolia/0xb8dcf96afafb93d9148c1c469712ec37be17b8913a68f2c1a1d371a18d1194fb/debugger?trace=0.4.3.3.23
   * @dev To run this test you need to use a fork of sepolia at the block 6031724 and to use -vvvv flag to see
   *      the logs. You should see the transfer to 0xa57106357F9A487F6AfBaA3758e7fCcB787113c4 with a value of 609888904007765 wei
   *      succeeding this time.
   */
  function test_Sepolia_V2PurchaseFreeMoeWithNewVersion() public {
    vm.selectFork(sepoliaFork);
      
    /// @dev To run this test you need to use a fork of sepolia at the block 6031724
    ///      You can create a fork like that using tenderly and creating a new fork at block 6031723
    assertEq(block.number, 6031724);
    assertEq(block.chainid, 11155111);

    // Doing the exact same call as the target transaction
    address holographDropERC721V2Address = 0xf43953DDE38d03F3feA00DD76685857E57Af49C8;
    vm.etch(holographDropERC721V2Address, type(HolographDropERC721V2).runtimeCode);

    // Doing the exact same call as the previous test
    vm.prank(0xa57106357F9A487F6AfBaA3758e7fCcB787113c4);
    (bool success, bytes memory data) = address(0x731F5129F241edAc48fA088c5DE3b3149dF822FD).call{value: 609888904007765}(
      abi.encodeWithSelector(
        IHolographDropERC721V2.purchase.selector,
        1
      )
    );

    assertTrue(success);
  }

  /* -------------------------------------------------------------------------- */
  /*                              Optimism Sepolia                              */
  /* -------------------------------------------------------------------------- */

  /* ------------------------- Reproduced transaction ------------------------- */

  /**
   * @dev This test reproduce the exact transaction made at block 12809571
   *      => https://sepolia-optimism.etherscan.io/tx/0x5b66e38dffc7afeb57ad88af3eb18f545f6ed376710f266ef4c6c65320ac200b
   *      => https://dashboard.tenderly.co/tx/optimistic-sepolia/0x5b66e38dffc7afeb57ad88af3eb18f545f6ed376710f266ef4c6c65320ac200b
   * @dev To run this test you need to use a fork of optimism sepolia at the block 12809571 and to use -vvvv flag to see
   *     the logs. You should see the transfer to 0xa57106357F9A487F6AfBaA3758e7fCcB787113c4 with a value of 609888904007765 wei
   *    failing with an EvmError: OutOfFunds
   */
  function test_OptimismSepolia_V2PurchaseFreeMoeWithOldVersion() public {
    vm.selectFork(opSepoliaFork);

    /// @dev To run this test you need to use a fork of sepolia at the block 12809572
    ///      You can create a fork like that using tenderly and creating a new fork at block 12809571
    assertEq(block.number, 12809572);
    assertEq(block.chainid, 11155420);

    // Doing the exact same call as the target transaction
    vm.prank(0xa57106357F9A487F6AfBaA3758e7fCcB787113c4);
    (bool success, bytes memory data) = address(0x731F5129F241edAc48fA088c5DE3b3149dF822FD).call{value: 609888904007765}(
      abi.encodeWithSelector(
        IHolographDropERC721V2.purchase.selector,
        1
      )
    );

    assertTrue(success);
  }

  /* -------------------------------------------------------------------------- */
  /*                                Base Sepolia                                */
  /* -------------------------------------------------------------------------- */

  /* ------------------------- Reproduced transaction ------------------------- */

  /**
   * @dev This test reproduce the exact transaction made at block 10826672
   *      => https://sepolia.basescan.org/tx/0xafbd520ca736fb210a7e7c954ed128a0104ac6e4ee920e7c5bee3766f5b47fd5
   * @dev To run this test you need to use a fork of base sepolia at the block 10826672 and to use -vvvv flag to see
   *     the logs. You should see the transfer to 0xa57106357F9A487F6AfBaA3758e7fCcB787113c4 with a value of 787500000000001 wei
   *    failing with an EvmError: OutOfFunds
   */
  function test_BaseSepolia_V2PurchaseFreeMoeWithOldVersion() public {
    vm.selectFork(baseSepoliaFork);

    /// @dev To run this test you need to use a fork of base sepolia at the block 10826673
    ///      You can create a fork like that using tenderly and creating a new fork at block 10826672
    assertEq(block.number, 10826673);
    assertEq(block.chainid, 84532);

    // Doing the exact same call as the target transaction
    vm.prank(0xa57106357F9A487F6AfBaA3758e7fCcB787113c4);
    (bool success, bytes memory data) = address(0x731F5129F241edAc48fA088c5DE3b3149dF822FD).call{value: 787500000000001}(
      abi.encodeWithSelector(
        IHolographDropERC721V2.purchase.selector,
        1
      )
    );

    assertTrue(success);
  }

  /* -------------------------------------------------------------------------- */
  /*                                Zora Sepolia                                */
  /* -------------------------------------------------------------------------- */

  /* ------------------------- Reproduced transaction ------------------------- */

  /**
   * @dev This test reproduce the exact transaction made at block 9671960
   *      => https://sepolia.explorer.zora.energy/tx/0x13cbd3f94c33d48b6107bb87e6f27aa87ee2af86d19e59dc5d2dcfa7e731cbc3
   * @dev To run this test you need to use a fork of zora sepolia at the block 9671960 and to use -vvvv flag to see
   *      the logs. You should see the transfer to 0xa57106357F9A487F6AfBaA3758e7fCcB787113c4 with a value of 938188474351665877 wei
   *      failing with an EvmError: OutOfFunds
   */
  function test_ZoraSepolia_V2PurchaseFreeMoeWithOldVersion() public {
    vm.selectFork(zoraSepoliaFork);

    /// @dev To run this test you need to use a fork of zora sepolia at the block 9671961
    ///      You can create a fork like that using tenderly and creating a new fork at block 9671960
    assertEq(block.number, 9671961);
    assertEq(block.chainid, 999999999);

    vm.deal(address(0xa57106357F9A487F6AfBaA3758e7fCcB787113c4), 1000 ether);

    // Doing the exact same call as the target transaction
    vm.prank(0xa57106357F9A487F6AfBaA3758e7fCcB787113c4);
    (bool success, bytes memory data) = address(0x731F5129F241edAc48fA088c5DE3b3149dF822FD).call{value: 938188474351665877}(
      abi.encodeWithSelector(
        IHolographDropERC721V2.purchase.selector,
        1
      )
    );

    assertTrue(success);
  }

  /* -------------------------------------------------------------------------- */
  /*                                Arb Sepolia                                 */
  /* -------------------------------------------------------------------------- */

  /* ------------------------- Reproduced transaction ------------------------- */

  /**
   * @dev This test reproduce the exact transaction made at block 50820655
   *      => https://sepolia.arbiscan.io/tx/0xc827f4b7fa301723a7c8dd5441adb6bf8b697603d91ba18602e8f1af0e329a4b
   * @dev To run this test you need to use a fork of arb sepolia at the block 50820655 and to use -vvvv flag to see
   *      the logs. You should see the transfer to 0xa57106357F9A487F6AfBaA3758e7fCcB787113c4 with a value of 1829666914927551 wei
   *      failing with an EvmError: OutOfFunds
   */
  function test_ArbSepolia_V2PurchaseFreeMoeWithOldVersion() public {
    vm.selectFork(arbSepoliaFork);

    /// @dev To run this test you need to use a fork of arb sepolia at the block 50820656
    ///      You can create a fork like that using tenderly and creating a new fork at block 50820655
    assertEq(block.number, 50820656);
    assertEq(block.chainid, 421614);

    // Doing the exact same call as the target transaction
    vm.prank(0xa57106357F9A487F6AfBaA3758e7fCcB787113c4);
    (bool success, bytes memory data) = address(0x731F5129F241edAc48fA088c5DE3b3149dF822FD).call{value: 1829666914927551}(
      abi.encodeWithSelector(
        IHolographDropERC721V2.purchase.selector,
        1
      )
    );

    assertTrue(success);
  }

  /* -------------------------------------------------------------------------- */
  /*                                 BNB Testnet                                */
  /* -------------------------------------------------------------------------- */

  /* ------------------------- Reproduced transaction ------------------------- */

  /**
   * @dev This test reproduce the exact transaction made at block 40901114
   *      => https://testnet.bscscan.com/tx/0xfc081c94a3b0c5d2ae81b1a4008d407b0668f7ed2cd55f6fa69a69137d102413
   * @dev To run this test you need to use a fork of bnb testnet at the block 40901114 and to use -vvvv flag to see
   *      the logs. You should see the transfer to 0xa57106357F9A487F6AfBaA3758e7fCcB787113c4 with a value of 3292778604457348 wei
   *      failing with an EvmError: OutOfFunds
   */
  function test_BNBTestnet_V2PurchaseFreeMoeWithOldVersion() public {
    vm.selectFork(bnbTestnetFork);

    /// @dev To run this test you need to use a fork of bnb testnet at the block 40901115
    ///      You can create a fork like that using tenderly and creating a new fork at block 40901114
    assertEq(block.number, 40901115);
    assertEq(block.chainid, 97);

    // Doing the exact same call as the target transaction
    vm.prank(0xa57106357F9A487F6AfBaA3758e7fCcB787113c4);
    (bool success, bytes memory data) = address(0x731F5129F241edAc48fA088c5DE3b3149dF822FD).call{value: 3292778604457348}(
      abi.encodeWithSelector(
        IHolographDropERC721V2.purchase.selector,
        1
      )
    );

    assertTrue(success);
  }

  /* -------------------------------------------------------------------------- */
  /*                                    Fuji                                    */
  /* -------------------------------------------------------------------------- */

  /* ------------------------- Reproduced transaction ------------------------- */

  /**
   * @dev This test reproduce the exact transaction made at block 33702307
   *      => https://testnet.avascan.info/blockchain/c/tx/0xc52733b39e6994f029ebde5ebd093d3c03983326ed7741b33deee5c4ef3ca5ab
   * @dev To run this test you need to use a fork of fuji at the block 33702307 and to use -vvvv flag to see
   *      the logs. You should see the transfer to 0xa57106357F9A487F6AfBaA3758e7fCcB787113c4 with a value of 191136596600000000 wei
   *      failing with an EvmError: OutOfFunds
   */
  function test_Fuji_V2PurchaseFreeMoeWithOldVersion() public {
    vm.selectFork(fujiFork);

    /// @dev To run this test you need to use a fork of fuji at the block 33702308
    ///      You can create a fork like that using tenderly and creating a new fork at block 33702307
    assertEq(block.number, 33702308);
    assertEq(block.chainid, 43113);

    // Doing the exact same call as the target transaction
    vm.prank(0xa57106357F9A487F6AfBaA3758e7fCcB787113c4);
    (bool success, bytes memory data) = address(0x731F5129F241edAc48fA088c5DE3b3149dF822FD).call{value: 191136596600000000}(
      abi.encodeWithSelector(
        IHolographDropERC721V2.purchase.selector,
        1
      )
    );

    assertTrue(success);
  }


  /* -------------------------------------------------------------------------- */
  /*                              Optimism Mainnet                              */
  /* -------------------------------------------------------------------------- */
  
  /* ------------------------- Reproduced transaction ------------------------- */

  /**
   * @dev This test reproduce the exact transaction made at block 118904615
   *      => https://optimistic.etherscan.io/tx/0xd0d76dc3ca15a2906009b2932a6dea1ddb1e1ab6f81117fd7eab3ca47b8e1f9a
   * @dev To run this test you need to use a fork of optimism at the block 118904615 and to use -vvvv flag to see
   *     the logs. You should see the transfer to 0x0030c8bB598997Da40626eA01BC70350a8f33f25 with a value of 353262998514953 wei
   *    failing with an EvmError: OutOfFunds
   */
  function test_OptimismMainnet_V2PurchaseFreeMoeWithOldVersion() public {
    vm.selectFork(optimismFork);

    /// @dev To run this test you need to use a fork of optimism at the block 118904616
    ///      You can create a fork like that using tenderly and creating a new fork at block 118904615
    assertEq(block.number, 118904616);
    assertEq(block.chainid, 10);

    // Doing the exact same call as the target transaction
    vm.prank(0x0030c8bB598997Da40626eA01BC70350a8f33f25);
    (bool success, bytes memory data) = address(0xc0C0a215bCC25E617ecA4674833A3Df1bc66A6A6).call{value: 353262998514953}(
      abi.encodeWithSelector(
        IHolographDropERC721V2.purchase.selector,
        1
      )
    );

    assertTrue(success);
  }
}
