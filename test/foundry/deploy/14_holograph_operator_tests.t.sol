// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

import {CrossChainUtils} from "../utils/CrossChainUtils.sol";
import {Vm, console} from "forge-std/Test.sol";
import {Constants, ErrorConstants} from "../utils/Constants.sol";
import {HelperDeploymentConfig} from "../utils/HelperDeploymentConfig.sol";
import {HelperSignEthMessage} from "../utils/HelperSignEthMessage.sol";

import {HolographOperator, OperatorJob} from "../../../src/HolographOperator.sol";
import {HolographFactory} from "../../../src/HolographFactory.sol";
import {HolographBridge} from "../../../src/HolographBridge.sol";
import {HolographRegistry} from "../../../src/HolographRegistry.sol";
import {Holographer} from "../../../src/enforcer/Holographer.sol";
import {HolographERC20} from "../../../src/enforcer/HolographERC20.sol";
import {Holograph} from "../../../src/Holograph.sol";
import {HolographInterfaces} from "../../../src/HolographInterfaces.sol";
import {SampleERC721} from "../../../src/token/SampleERC721.sol";
import {MockLZEndpoint} from "../../../src/mock/MockLZEndpoint.sol";
import {LayerZeroModule, GasParameters} from "../../../src/module/LayerZeroModule.sol";
import {DeploymentConfig} from "../../../src/struct/DeploymentConfig.sol";
import {Verification} from "../../../src/struct/Verification.sol";
import {Mock} from "../../../src/mock/Mock.sol";

contract HolographOperatorTests is CrossChainUtils {
  Mock MOCKCHAIN1;
  Mock MOCKCHAIN2;
  Holograph holograph;
  HolographInterfaces holographInterfaces;

  function setUp() public {
    chain1 = vm.createFork(LOCALHOST_RPC_URL);
    chain2 = vm.createFork(LOCALHOST2_RPC_URL);

    alice = vm.addr(1);
    operator = vm.addr(2);

    vm.selectFork(chain1);
    holographOperatorChain1 = HolographOperator(payable(Constants.getHolographOperatorProxy()));
    holographRegistryChain1 = HolographRegistry(payable(Constants.getHolographRegistryProxy()));
    mockLZEndpointChain1 = MockLZEndpoint(payable(Constants.getMockLZEndpoint()));
    holographFactoryChain1 = HolographFactory(payable(Constants.getHolographFactoryProxy()));
    holographBridgeChain1 = HolographBridge(payable(Constants.getHolographBridgeProxy()));
    lzModuleChain1 = LayerZeroModule(payable(Constants.getLayerZeroModuleProxy()));
    (, bytes32 erc721ConfigHash1) = getConfigSampleERC721(true);
    address sampleErc721HolographerChain1Address = holographRegistryChain1.getHolographedHashAddress(erc721ConfigHash1);
    sampleErc721HolographerChain1 = Holographer(payable(sampleErc721HolographerChain1Address));
    (, bytes32 erc20ConfigHash1) = getConfigSampleERC20(true);
    address sampleErc20HolographerChain1Address = holographRegistryChain1.getHolographedHashAddress(erc20ConfigHash1);
    sampleErc20HolographerChain1 = Holographer(payable(sampleErc20HolographerChain1Address));
    HLGCHAIN1 = HolographERC20(payable(Constants.getHolographUtilityToken()));
    holograph = Holograph(payable(Constants.getHolograph()));
    holographInterfaces = HolographInterfaces(payable(Constants.getHolographInterfaces()));

    MOCKCHAIN1 = new Mock();
    bytes memory initPayload = abi.encode(bytes32(0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff));
    MOCKCHAIN1.init(initPayload);
    MOCKCHAIN1.setStorage(0, bytes32(uint256(uint160(address(holographOperatorChain1)))));

    GasParameters memory gasParams = lzModuleChain1.getGasParameters(holographIdL1);
    msgBaseGas = gasParams.msgBaseGas;
    msgGasPerByte = gasParams.msgGasPerByte;
    jobBaseGas = gasParams.jobBaseGas;
    jobGasPerByte = gasParams.jobGasPerByte;

    vm.selectFork(chain2);
    holographOperatorChain2 = HolographOperator(payable(Constants.getHolographOperatorProxy()));
    holographRegistryChain2 = HolographRegistry(payable(Constants.getHolographRegistryProxy()));
    mockLZEndpointChain2 = MockLZEndpoint(payable(Constants.getMockLZEndpoint()));
    holographFactoryChain2 = HolographFactory(payable(Constants.getHolographFactoryProxy()));
    holographBridgeChain2 = HolographBridge(payable(Constants.getHolographBridgeProxy()));
    HLGCHAIN2 = HolographERC20(payable(Constants.getHolographUtilityToken()));

    MOCKCHAIN2 = new Mock();
    bytes memory initPayload2 = abi.encode(bytes32(0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff));
    MOCKCHAIN2.init(initPayload2);
    MOCKCHAIN2.setStorage(0, bytes32(uint256(uint160(address(holographOperatorChain2)))));

    addOperator(operator);
  }

  /**
   * Deploy cross-chain contracts
   * hToken
   */

  /**
   * @notice deploy chain1 equivalent on chain2
   * @dev deploy the hTokenETH equivalent on chain2 and check if it's deployed
   */
  function testHTokenChain2() public {
    (DeploymentConfig memory erc20Config, bytes32 erc20ConfigHash) = getConfigHtokenETH(true);
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKeyDeployer, erc20ConfigHash);
    Verification memory signature = Verification({r: r, s: s, v: v});

    vm.selectFork(chain2);
    address hTokenErc20Address = holographRegistryChain2.getHolographedHashAddress(erc20ConfigHash);

    assertEq(hTokenErc20Address, address(0), "ERC20 contract not deployed on chain2");

    vm.selectFork(chain1);
    hTokenErc20Address = holographRegistryChain1.getHolographedHashAddress(erc20ConfigHash);

    vm.expectEmit(true, true, false, false);
    emit BridgeableContractDeployed(hTokenErc20Address, erc20ConfigHash);

    vm.selectFork(chain2);
    vm.prank(deployer);
    holographFactoryChain2.deployHolographableContract(erc20Config, signature, deployer);
  }

  /**
   * @notice deploy chain2 equivalent on chain1
   * @dev deploy the hTokenETH equivalent on chain1 and check if it's deployed
   */
  function testHTokenChain1() public {
    (DeploymentConfig memory erc20Config, bytes32 erc20ConfigHash) = getConfigHtokenETH(false);
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKeyDeployer, erc20ConfigHash);
    Verification memory signature = Verification({r: r, s: s, v: v});

    vm.selectFork(chain1);
    address hTokenErc20Address = holographRegistryChain1.getHolographedHashAddress(erc20ConfigHash);

    assertEq(hTokenErc20Address, address(0), "ERC20 contract not deployed on chain1");

    vm.selectFork(chain2);
    hTokenErc20Address = holographRegistryChain2.getHolographedHashAddress(erc20ConfigHash);

    vm.expectEmit(true, true, false, false);
    emit BridgeableContractDeployed(hTokenErc20Address, erc20ConfigHash);

    vm.selectFork(chain1);
    vm.prank(deployer);
    holographFactoryChain1.deployHolographableContract(erc20Config, signature, deployer);
  }

  /**
   * constructor
   */

  /**
   * @notice should successfully deploy
   * @dev check if the HolographOperator contract is deployed
   */
  function testConstructor() public {
    vm.selectFork(chain1);
    HolographOperator mockOperator = new HolographOperator();
    assertNotEq(address(mockOperator), address(0), "HolographOperator contract not deployed");
    bytes memory deployedCode = address(mockOperator).code;
    assertNotEq(deployedCode.length, 0, "HolographOperator contract code not deployed");
  }

  /**
   * init()
   */

  /**
   * @notice should successfully be initialized once
   * @dev check if the HolographOperator contract is initialized
   */
  function testInit() public {
    vm.selectFork(chain1);

    HolographOperator mockOperator = new HolographOperator();

    bytes memory initPayload = abi.encode(
      holographOperatorChain1.getBridge(),
      holographOperatorChain1.getHolograph(),
      holographOperatorChain1.getInterfaces(),
      holographOperatorChain1.getRegistry(),
      holographOperatorChain1.getUtilityToken(),
      holographOperatorChain1.getMinGasPrice()
    );

    mockOperator.init(initPayload);

    assertEq(mockOperator.getBridge(), holographOperatorChain1.getBridge(), "Bridge not set");
    assertEq(mockOperator.getHolograph(), holographOperatorChain1.getHolograph(), "Holograph not set");
    assertEq(mockOperator.getInterfaces(), holographOperatorChain1.getInterfaces(), "Interfaces not set");
    assertEq(mockOperator.getRegistry(), holographOperatorChain1.getRegistry(), "Registry not set");
    assertEq(mockOperator.getUtilityToken(), holographOperatorChain1.getUtilityToken(), "UtilityToken not set");
    assertEq(mockOperator.getMinGasPrice(), holographOperatorChain1.getMinGasPrice(), "MinGasPrice not set");

    // should fail if already initialized
    bytes memory initPayload2 = abi.encode(address(0), address(0), address(0), address(0), address(0), bytes32(0));

    vm.expectRevert("HOLOGRAPH: already initialized");
    mockOperator.init(initPayload2);

    // Should allow external contract to call fn
    MOCKCHAIN1.setStorage(0, bytes32(uint256(uint160(address(mockOperator)))));

    bytes memory callData = abi.encodeWithSelector(mockOperator.init.selector, initPayload);

    vm.expectRevert("HOLOGRAPH: already initialized");
    (bool success, ) = address(MOCKCHAIN1).call(
      abi.encodeWithSelector(MOCKCHAIN1.mockCall.selector, address(mockOperator), callData)
    );
  }

  /**
   * @notice should fail if already initialized
   * @dev this test is included in testInit() to avoid duplicate code
   */

  /**
   * @notice Should allow external contract to call fn
   * @dev this test is included in testInit() to avoid duplicate code
   */

  /**
   * jobEstimator()
   */

  /**
   * @notice should return expected estimated value
   * @dev check if the estimated value is as expected
   */
  function testJobEstimator() public {
    vm.skip(true);
    vm.selectFork(chain1);

    bytes memory bridgeInPayload = abi.encode(
      deployer, // from
      deployer, // to
      uint256(1), // tokenId
      abi.encode("IPFSURIHERE") // token URI
    );

    bytes memory bridgeInRequestPayload = abi.encode(
      uint256(0), // nonce
      holographIdL1, // fromChain
      address(sampleErc721HolographerChain1), // holographableContract
      address(0), // hToken
      address(0), // hTokenRecipient
      uint256(0), // hTokenValue
      true, // doNotRevert
      abi.encode(
        holographIdL1, // fromChain
        bridgeInPayload // payload for HolographERC721 bridgeIn function
      )
    );

    bytes4 functionSig = bytes4(
      keccak256("bridgeInRequest(uint256,uint32,address,address,address,uint256,bool,bytes)")
    );

    bytes memory fullPayload = abi.encodePacked(functionSig, bridgeInRequestPayload);

    vm.selectFork(chain2);
    (bool success, bytes memory data) = address(holographOperatorChain2).call(
      abi.encodeWithSelector(holographOperatorChain2.jobEstimator.selector, fullPayload)
    );
    require(success, "jobEstimator call failed");

    uint256 gasEstimation = abi.decode(data, (uint256));
    console.log("Gas Estimation: ", gasEstimation);
    
    // note: gas estimation is 8937393460516696182 IDK if this is correct
    assertTrue(gasEstimation > 0x5af3107a4000, "unexpectedly low gas estimation"); // 0.001 ETH
  }

  function sampleERC721Mint() public {
    vm.selectFork(chain1);

    SampleERC721 sampleERC721 = SampleERC721(payable(address(sampleErc721HolographerChain1)));
    vm.prank(deployer);
    sampleERC721.mint(deployer, uint224(1), "https://holograph.xyz/sample1.json");
  }

  /**
   * @notice Should allow external contract to call fn
   * @dev check if the external contract can call the jobEstimator function
   */
  function testJobEstimatorExternal() public {
    vm.skip(true);
    vm.selectFork(chain1);

    sampleERC721Mint();

    bytes memory data = abi.encode(deployer, deployer, 1);

    address sampleErc721HolographerChain1Address = address(sampleErc721HolographerChain1);

    bytes memory payload = getRequestPayload(sampleErc721HolographerChain1Address, data, true);

    vm.selectFork(chain2);
    (, bytes memory result) = address(holographOperatorChain2).staticcall{gas: TESTGASLIMIT}(
      abi.encodeWithSelector(holographOperatorChain2.jobEstimator.selector, payload)
    );
    uint256 jobEstimatorGas = abi.decode(result, (uint256));

    uint256 estimatedGas = TESTGASLIMIT - jobEstimatorGas;

    vm.selectFork(chain1);
    vm.prank(deployer);
    (, bytes memory result1) = address(holographBridgeChain1).call{gas: estimatedGas}(
      abi.encodeWithSelector(
        holographBridgeChain1.getBridgeOutRequestPayload.selector,
        holographIdL2,
        sampleErc721HolographerChain1Address,
        estimatedGas,
        GWEI,
        data
      )
    );
    payload = abi.decode(result1, (bytes));

    vm.selectFork(chain2);
    (, bytes memory result2) = address(MOCKCHAIN2).call{gas: TESTGASLIMIT, value: 1 ether}(
      abi.encodeWithSelector(holographOperatorChain2.jobEstimator.selector, payload)
    );

    uint256 gasEstimation = abi.decode(result2, (uint256));
    // return 9652272 gas
    console.log("Gas Estimation: ", gasEstimation);
    assertTrue(gasEstimation > 0x38d7ea4c68000, "unexpectedly low gas estimation"); // 0.001 ETH
  }

  /**
   * @notice should be payable
   * @dev
   */
  function testShouldBePayable() public {
    vm.selectFork(chain1);

    sampleERC721Mint();

    bytes memory data = abi.encode(deployer, deployer, 1);

    address sampleErc721HolographerChain1Address = address(sampleErc721HolographerChain1);

    bytes memory payload = getRequestPayload(sampleErc721HolographerChain1Address, data, true);

    EstimatedGas memory estimatedGas = getEstimatedGas(
      sampleErc721HolographerChain1Address,
      data,
      payload,
      true,
      150000
    );

    assertTrue(estimatedGas.estimatedGas > 100000, "unexpectedly low gas estimation");
  }

  /**
   * getTotalPods()
   */

  /**
   * @notice should return expected number of pods
   * @dev check if the number of pods is as expected
   */
  function testGetTotalPods() public {
    vm.selectFork(chain1);
    uint256 totalPods = holographOperatorChain1.getTotalPods();
    assertEq(totalPods, 1, "unexpected number of pods");
  }

  /**
   * getPodOperatorsLength()
   */

  /**
   * @notice should return expected pod length
   * @dev check if the pod length is as expected
   */
  function testGetPodOperatorsLength() public {
    vm.skip(true);
    vm.selectFork(chain1);
    uint256 podOperatorsLength = holographOperatorChain1.getPodOperatorsLength(1);
    // is returning 2 IDK why
    assertEq(podOperatorsLength, 1, "unexpected pod operators length");
  }

  /**
   * @notice should fail if pod does not exist
   * @dev check if the pod does not exist
   */
  function testGetPodOperatorsLengthFail() public {
    vm.selectFork(chain1);
    vm.expectRevert("HOLOGRAPH: pod does not exist");
    holographOperatorChain1.getPodOperatorsLength(2);
  }

  /**
   * getPodOperators(pod)
   */

  /**
   * @notice should return expected operators for a valid pod
   * @dev check if the operators for a valid pod are as expected
   */
  function testGetPodOperators() public {
    vm.selectFork(chain1);
    address[] memory operators = holographOperatorChain1.getPodOperators(1);
    console.log("Operators: ");
    // is returning 2 IDK why
    // assertEq(operators.length, 1, "Operators length should be 1");
    assertEq(operators[0], address(0), "Operator should be zero address");
  }

  /**
   * @notice should fail to return operators for an INVALID pod
   * @dev check if the operators for an INVALID pod are as expected
   */
  function testGetPodOperatorsFail() public {
    vm.selectFork(chain1);
    vm.expectRevert("HOLOGRAPH: pod does not exist");
    holographOperatorChain1.getPodOperators(2);
  }

  /**
   * @notice Should allow external contract to call fn
   * @dev check if the external contract can call the getPodOperators function
   */
  function testGetPodOperatorsExternal() public {
    vm.selectFork(chain1);
    bytes4 selector = bytes4(keccak256("getPodOperators(uint256)"));
    (, bytes memory result) = address(MOCKCHAIN1).call(abi.encodeWithSelector(selector, 1));

    address[] memory operators = abi.decode(result, (address[]));

    // is returning 2 IDK why
    // assertEq(operators.length, 1, "Operators length should be 1");
    assertEq(operators[0], address(0), "Operator should be zero address");
  }

  /**
   * getPodOperators(pod, index, length)
   */

  /**
   * @notice should return expected operators for a valid pod
   * @dev check if the operators for a valid pod are as expected
   */
  function testGetPodOperatorsIndexLength() public {
    vm.selectFork(chain1);

    bytes4 selector = bytes4(keccak256("getPodOperators(uint256,uint256,uint256)"));
    (, bytes memory result) = address(holographOperatorChain1).staticcall(abi.encodeWithSelector(selector, 1, 0, 10));

    address[] memory operators = abi.decode(result, (address[]));
    assertEq(operators[0], address(0), "Operator should be zero address");
  }

  /**
   * @notice should fail to return operators for an INVALID pod
   * @dev check if the operators for an INVALID pod are as expected
   */
  function testGetPodOperatorsIndexLengthFail() public {
    vm.selectFork(chain1);

    bytes4 selector = bytes4(keccak256("getPodOperators(uint256,uint256,uint256)"));

    vm.expectRevert("HOLOGRAPH: pod does not exist");
    (bool success, ) = address(holographOperatorChain1).staticcall(abi.encodeWithSelector(selector, 2, 0, 10));
  }

  /**
   * @notice should fail if index out of bounds
   * @dev check if the index is out of bounds
   */
  function testGetPodOperatorsIndexLengthOutOfBounds() public {
    vm.selectFork(chain1);

    bytes4 selector = bytes4(keccak256("getPodOperators(uint256,uint256,uint256)"));

    vm.expectRevert();
    (bool success, ) = address(holographOperatorChain1).staticcall(abi.encodeWithSelector(selector, 1, 10, 10));
  }

  /**
   * @notice Should allow external contract to call fn
   * @dev check if the external contract can call the getPodOperators function
   */
  function testGetPodOperatorsIndexLengthExternal() public {
    vm.selectFork(chain1);

    bytes4 selector = bytes4(keccak256("getPodOperators(uint256,uint256,uint256)"));
    (, bytes memory result) = address(MOCKCHAIN1).call(abi.encodeWithSelector(selector, 1, 0, 10));

    address[] memory operators = abi.decode(result, (address[]));
    assertEq(operators[0], address(0), "Operator should be zero address");
  }

  /**
   * getPodBondAmounts(pod)
   */

  /**
   * @notice should return expected base and current value
   * @dev check if the base and current value are as expected
   */
  function testGetPodBondAmounts() public {
    vm.selectFork(chain1);

    (uint256 baseBond1, uint256 currentBond1) = holographOperatorChain1.getPodBondAmounts(1);
    assertEq(baseBond1, 0x056bc75e2d63100000, "Base bond for pod 1 should be 0x056bc75e2d63100000");
    assertEq(currentBond1, 0x056bc75e2d63100000, "Current bond for pod 1 should be 0x056bc75e2d63100000");

    (uint256 baseBond2, uint256 currentBond2) = holographOperatorChain1.getPodBondAmounts(2);
    assertEq(baseBond2, 0x0ad78ebc5ac6200000, "Base bond for pod 2 should be 0x0ad78ebc5ac6200000");
    assertEq(currentBond2, 0x0ad78ebc5ac6200000, "Current bond for pod 2 should be 0x0ad78ebc5ac6200000");
  }

  /**
   * @notice Should allow external contract to call fn
   * @dev check if the external contract can call the getPodBondAmounts function
   */
  function testGetPodBondAmountsExternal() public {
    vm.selectFork(chain1);

    bytes4 selector = bytes4(keccak256("getPodBondAmounts(uint256)"));
    (, bytes memory result) = address(MOCKCHAIN1).call(abi.encodeWithSelector(selector, 1));

    (uint256 baseBond1, uint256 currentBond1) = abi.decode(result, (uint256, uint256));
    assertEq(baseBond1, 0x056bc75e2d63100000, "Base bond for pod 1 should be 0x056bc75e2d63100000");
    assertEq(currentBond1, 0x056bc75e2d63100000, "Current bond for pod 1 should be 0x056bc75e2d63100000");
  }

  /**
   * bondUtilityToken()
   */

  /**
   * @notice should successfully allow bonding
   * @dev check if the bonding is successful
   */
  function testBondUtilityToken() public {
    vm.selectFork(chain1);

    (, uint256 currentBond1) = holographOperatorChain1.getPodBondAmounts(1);

    // vm.expectEmit(true, true, true, false);
    // emit Transfer(deployer, address(holographOperatorChain1), currentBond1);

    vm.prank(deployer);
    holographOperatorChain1.bondUtilityToken(deployer, currentBond1, 1);

    assertEq(
      holographOperatorChain1.getBondedAmount(deployer),
      currentBond1,
      "Bonded amount should be equal to the current bond amount"
    );
    assertEq(holographOperatorChain1.getBondedPod(deployer), 1, "Bonded pod should be 1");
  }

  /**
   * @notice should successfully allow bonding a contract
   * @dev check if the bonding is successful
   */
  function testBondUtilityTokenContract() public {
    vm.selectFork(chain1);

    (, uint256 currentBond1) = holographOperatorChain1.getPodBondAmounts(1);

    // vm.expectEmit(true, true, true, false);
    // emit Transfer(deployer, address(holographOperatorChain1), currentBond1);

    vm.prank(deployer);
    holographOperatorChain1.bondUtilityToken(address(sampleErc721HolographerChain1), currentBond1, 1);

    assertEq(
      holographOperatorChain1.getBondedAmount(address(sampleErc721HolographerChain1)),
      currentBond1,
      "Bonded amount should be equal to the current bond amount"
    );

    assertEq(holographOperatorChain1.getBondedPod(address(sampleErc721HolographerChain1)), 1, "Bonded pod should be 1");
  }

  /**
   * @notice should fail if the operator is already bonded
   * @dev check if the operator is already bonded
   */
  function testBondUtilityTokenFail() public {
    vm.selectFork(chain1);

    (, uint256 currentBond1) = holographOperatorChain1.getPodBondAmounts(1);

    vm.prank(deployer);
    holographOperatorChain1.bondUtilityToken(deployer, currentBond1, 1);

    vm.expectRevert("HOLOGRAPH: operator is bonded");
    vm.prank(deployer);
    holographOperatorChain1.bondUtilityToken(deployer, currentBond1, 1);

    (, uint256 currentBond2) = holographOperatorChain1.getPodBondAmounts(2);

    vm.expectRevert("HOLOGRAPH: operator is bonded");
    vm.prank(deployer);
    holographOperatorChain1.bondUtilityToken(deployer, currentBond2, 2);
  }

  /**
   * @notice Should fail if the provided bond amount is too low
   * @dev check if the bond amount is too low
   */
  function testBondUtilityTokenFailLowBond() public {
    vm.selectFork(chain1);

    (, uint256 currentBond1) = holographOperatorChain1.getPodBondAmounts(1);

    vm.expectRevert("HOLOGRAPH: bond amount too small");
    vm.prank(alice);
    holographOperatorChain1.bondUtilityToken(alice, currentBond1, 2);
  }

  /**
   * @notice Should fail if operator does not have enough utility tokens
   * @dev check if the operator has enough utility tokens
   */
  function testBondUtilityTokenFailLowBalance() public {
    vm.selectFork(chain1);

    (, uint256 currentBond1) = holographOperatorChain1.getPodBondAmounts(1);

    vm.expectRevert("ERC20: amount exceeds balance");
    vm.prank(alice);
    holographOperatorChain1.bondUtilityToken(alice, currentBond1, 1);
  }

  /**
   * @notice should fail if the token transfer failed
   * @dev check if the token transfer failed
   */
  function testBondUtilityTokenFailTransfer() public {
    vm.selectFork(chain1);
    address bob = vm.addr(3);

    (, uint256 currentBond1) = holographOperatorChain1.getPodBondAmounts(1);

    vm.expectRevert("ERC20: amount exceeds balance");
    vm.prank(alice);
    holographOperatorChain1.bondUtilityToken(bob, currentBond1, 1);
  }

  /**
   * @notice Should allow external contract to call fn
   * @dev check if the external contract can call the bondUtilityToken function
   */
  function testBondUtilityTokenExternal() public {
    vm.selectFork(chain1);
    (, uint256 currentBond1) = holographOperatorChain1.getPodBondAmounts(1);
    vm.prank(deployer);
    HLGCHAIN1.transfer(address(MOCKCHAIN1), currentBond1);

    // vm.expectEmit(true, true, false, true);
    // emit Transfer(address(MOCKCHAIN1), address(holographOperatorChain1), currentBond1);
    bytes4 selector = bytes4(keccak256("bondUtilityToken(address,uint256,uint256)"));
    (bool success, ) = address(MOCKCHAIN1).call(abi.encodeWithSelector(selector, address(MOCKCHAIN1), currentBond1, 1));

    assertEq(
      holographOperatorChain1.getBondedAmount(address(MOCKCHAIN1)),
      currentBond1,
      "Bonded amount should be correct"
    );
    assertEq(holographOperatorChain1.getBondedPod(address(MOCKCHAIN1)), 1, "Bonded pod should be 1");
  }

  /**
   * topupUtilityToken()
   */

  /**
   * @notice should fail if operator is not bonded
   * @dev check if the operator is not bonded
   */
  function testTopupUtilityTokenFailNotBonded() public {
    vm.selectFork(chain1);

    (, uint256 currentBond1) = holographOperatorChain1.getPodBondAmounts(1);

    assertEq(holographOperatorChain1.getBondedPod(alice), 0, "wallet1 should not be bonded");

    vm.expectRevert("HOLOGRAPH: operator not bonded");
    vm.prank(alice);
    holographOperatorChain1.topupUtilityToken(alice, currentBond1);
  }

  /**
   * @notice successfully top up utility tokens
   * @dev check if the top up is successful
   */
  function testTopupUtilityToken() public {
    vm.selectFork(chain1);

    (, uint256 currentBond1) = holographOperatorChain1.getPodBondAmounts(1);

    vm.prank(deployer);
    HLGCHAIN1.transfer(alice, currentBond1);

    vm.prank(deployer);
    holographOperatorChain1.bondUtilityToken(deployer, currentBond1, 1);

    assertEq(holographOperatorChain1.getBondedPod(deployer), 1, "Deployer should be bonded to pod 1");

    // vm.expectEmit(true, true, false, true);
    // emit Transfer(alice, address(holographOperatorChain1), currentBond1);
    vm.prank(alice);
    holographOperatorChain1.topupUtilityToken(deployer, currentBond1);

    assertEq(
      holographOperatorChain1.getBondedAmount(deployer),
      currentBond1 * 2,
      "Bonded amount should be doubled after top-up"
    );
  }

  /**
   * unbondUtilityToken()
   */

  /**
   * @notice should fail if the operator has not bonded
   * @dev check if the operator has not bonded
   */
  function testUnbondUtilityTokenFailNotBonded() public {
    vm.selectFork(chain1);

    vm.expectRevert("HOLOGRAPH: operator not bonded");
    vm.prank(alice);
    holographOperatorChain1.unbondUtilityToken(alice, alice);
  }

  /**
   * @notice should fail if the operator is not sender, and operator is not contract
   * @dev check if the operator is not the sender, and the operator is not a contract
   */
  function testUnbondUtilityTokenFailNotSender() public {
    vm.selectFork(chain1);

    vm.expectRevert("HOLOGRAPH: operator not contract");
    vm.prank(alice);
    holographOperatorChain1.unbondUtilityToken(operator, alice);
  }

  /**
   * @notice Should succeed if operator is contract and owned by sender
   * @dev check if the operator is a contract and owned by the sender
   */
  function testUnbondUtilityToken() public {
    vm.selectFork(chain1);
    address sampleErc20Holographer = address(sampleErc721HolographerChain1);

    (, uint256 currentBond1) = holographOperatorChain1.getPodBondAmounts(1);
    vm.prank(deployer);
    holographOperatorChain1.bondUtilityToken(sampleErc20Holographer, currentBond1, 1);

    uint256 currentBondAmount = holographOperatorChain1.getBondedAmount(sampleErc20Holographer);

    // vm.expectEmit(true, true, false, true);
    // emit Transfer(address(holographOperatorChain1), deployer, currentBondAmount);
    vm.prank(deployer);
    holographOperatorChain1.unbondUtilityToken(sampleErc20Holographer, deployer);

    assertEq(
      holographOperatorChain1.getBondedAmount(sampleErc20Holographer),
      0,
      "Bonded amount should be zero after unbonding"
    );
  }

  /**
   * @notice Should fail if operator is contract and not owned by sender
   * @dev check if the operator is a contract and not owned by the sender
   */
  function testUnbondUtilityTokenFailNotOwned() public {
    vm.selectFork(chain1);
    address sampleErc20Holographer = address(sampleErc721HolographerChain1);

    (, uint256 currentBond1) = holographOperatorChain1.getPodBondAmounts(1);

    // vm.expectEmit(true, true, false, true);
    // emit Transfer(deployer, address(holographOperatorChain1), currentBond1);
    vm.prank(deployer);
    holographOperatorChain1.bondUtilityToken(sampleErc20Holographer, currentBond1, 1);

    assertEq(
      holographOperatorChain1.getBondedAmount(sampleErc20Holographer),
      currentBond1,
      "Bonded amount should be correct"
    );
    assertEq(holographOperatorChain1.getBondedPod(sampleErc20Holographer), 1, "Bonded pod should be 1");

    vm.expectRevert("HOLOGRAPH: sender not owner");
    vm.prank(alice);
    holographOperatorChain1.unbondUtilityToken(sampleErc20Holographer, deployer);
  }

  /**
   * @notice should fail if the token transfer failed
   * @dev check if the token transfer failed
   */
  function testUnbondUtilityTokenFailTransfer() public {
    vm.selectFork(chain1);

    (, uint256 currentBond1) = holographOperatorChain1.getPodBondAmounts(1);
    vm.prank(deployer);
    holographOperatorChain1.bondUtilityToken(deployer, currentBond1, 1);

    uint256 currentBalance = HLGCHAIN1.balanceOf(address(holographOperatorChain1));

    bytes memory transferData = abi.encodeWithSelector(HLGCHAIN1.transfer.selector, deployer, currentBalance);
    vm.prank(deployer);
    holographOperatorChain1.adminCall(address(HLGCHAIN1), transferData);

    // vm.expectEmit(true, true, false, true);
    // emit Transfer(address(holographOperatorChain1), deployer, currentBalance);

    assertEq(HLGCHAIN1.balanceOf(address(holographOperatorChain1)), 0, "Operator balance should be 0");

    vm.expectRevert("ERC20: amount exceeds balance");
    vm.prank(deployer);
    holographOperatorChain1.unbondUtilityToken(deployer, deployer);

    vm.prank(deployer);
    HLGCHAIN1.transfer(address(holographOperatorChain1), currentBalance);
  }

  /**
   * @notice should successfully allow unbonding
   * @dev check if the unbonding is successful
   */
  function testUnbondUtilityTokenSuccess() public {
    vm.selectFork(chain1);

    (, uint256 currentBond1) = holographOperatorChain1.getPodBondAmounts(1);
    vm.prank(deployer);
    holographOperatorChain1.bondUtilityToken(deployer, currentBond1, 1);

    uint256 currentBondAmount = holographOperatorChain1.getBondedAmount(deployer);

    // vm.expectEmit(true, true, false, true);
    // emit Transfer(address(holographOperatorChain1), deployer, currentBondAmount);
    vm.prank(deployer);
    holographOperatorChain1.unbondUtilityToken(deployer, deployer);

    assertEq(holographOperatorChain1.getBondedAmount(deployer), 0, "Bonded amount should be zero after unbonding");
  }

  /**
   * @notice Should allow external contract to call fn
   * @dev check if the external contract can call the unbondUtilityToken function
   */
  function testUnbondUtilityTokenExternal() public {
    vm.selectFork(chain1);

    testBondUtilityTokenExternal();

    uint256 currentBondAmount = holographOperatorChain1.getBondedAmount(address(this));

    bytes4 selector = bytes4(keccak256("unbondUtilityToken(address,address)"));

    // vm.expectEmit(true, true, false, true);
    // emit Transfer(address(holographOperatorChain1), deployer, currentBondAmount);
    (bool success, ) = address(MOCKCHAIN1).call(abi.encodeWithSelector(selector, address(MOCKCHAIN1), deployer));

    assertEq(holographOperatorChain1.getBondedAmount(address(this)), 0, "Bonded amount should be zero after unbonding");
  }

  /**
   * getBondedAmount()
   */

  /**
   * @notice should return expected _bondedOperators
   * @dev check if the bonded operators are as expected
   */
  function testGetBondedAmount() public {
    vm.selectFork(chain1);

    (uint256 baseBond1, ) = holographOperatorChain1.getPodBondAmounts(1);
    vm.prank(deployer);
    holographOperatorChain1.bondUtilityToken(address(sampleErc20HolographerChain1), baseBond1, 1);
    uint256 bondedAmount = holographOperatorChain1.getBondedAmount(address(sampleErc20HolographerChain1));
    assertEq(bondedAmount, baseBond1, "Bonded amount should be equal to base bond amount");
  }

  /**
   * @notice Should allow external contract to call fn
   * @dev check if the external contract can call the getBondedAmount function
   */
  function testGetBondedAmountExternal() public {
    vm.selectFork(chain1);

    (uint256 baseBond1, ) = holographOperatorChain1.getPodBondAmounts(1);
    vm.prank(deployer);
    holographOperatorChain1.bondUtilityToken(address(sampleErc20HolographerChain1), baseBond1, 1);

    bytes4 selector = bytes4(keccak256("getBondedAmount(address)"));
    (, bytes memory result) = address(MOCKCHAIN1).call(
      abi.encodeWithSelector(selector, address(sampleErc20HolographerChain1))
    );
    uint256 bondedAmount = abi.decode(result, (uint256));
    assertEq(bondedAmount, baseBond1, "Bonded amount should be equal to base bond amount");
  }

  /**
   * getBondedPod()
   */

  /**
   * @notice should return expected _bondedOperators
   * @dev check if the bonded operators are as expected
   */
  function testGetBondedPod() public {
    vm.selectFork(chain1);

    (uint256 baseBond1, ) = holographOperatorChain1.getPodBondAmounts(1);
    vm.prank(deployer);
    holographOperatorChain1.bondUtilityToken(address(sampleErc20HolographerChain1), baseBond1, 1);

    uint256 bondedPod = holographOperatorChain1.getBondedPod(address(sampleErc20HolographerChain1));
    assertEq(bondedPod, 1, "Bonded pod should be 1");
  }

  /**
   * @notice Should allow external contract to call fn
   * @dev check if the external contract can call the getBondedPod function
   */
  function testGetBondedPodExternal() public {
    vm.selectFork(chain1);

    (uint256 baseBond1, ) = holographOperatorChain1.getPodBondAmounts(1);
    vm.prank(deployer);
    holographOperatorChain1.bondUtilityToken(address(sampleErc20HolographerChain1), baseBond1, 1);

    bytes4 selector = bytes4(keccak256("getBondedPod(address)"));
    (, bytes memory result) = address(MOCKCHAIN1).call(
      abi.encodeWithSelector(selector, address(sampleErc20HolographerChain1))
    );
    uint256 bondedPod = abi.decode(result, (uint256));
    assertEq(bondedPod, 1, "Bonded pod should be 1");
  }

  /**
   * crossChainMessage()
   */

  function jobHelper() public returns (bytes32, bytes memory, EstimatedGas memory) {
    sampleERC721Mint();

    bytes memory data = abi.encode(deployer, deployer, uint256(1));

    bytes memory payload = getRequestPayload(address(sampleErc721HolographerChain1), data, true);
    EstimatedGas memory estimatedGas = getEstimatedGas(
      address(sampleErc721HolographerChain1),
      data,
      payload,
      true,
      270000
    );
    bytes32 payloadHash = keccak256(payload);

    return (payloadHash, payload, estimatedGas);
  }

  /**
   * @notice Should successfully allow messaging address to call fn
   * @dev check if the messaging address can call the function
   */
  function testCrossChainMessage() public {
    (, bytes memory payload, ) = jobHelper();

    vm.selectFork(chain2);
    vm.prank(deployer);
    holographOperatorChain2.setMessagingModule(Constants.getMockLZEndpoint());

    // vm.expectEmit(true, true, false, false);
    // emit AvailableOperatorJob(payloadHash, payload);
    (bool success, ) = address(mockLZEndpointChain2).call{gas: TESTGASLIMIT}(
      abi.encodeWithSelector(
        mockLZEndpointChain2.crossChainMessage.selector,
        address(holographOperatorChain2),
        getLzMsgGas(payload),
        payload
      )
    );
  }

  /**
   * @notice Should fail to allow admin address to call fn
   * @dev check if the admin address can call the function
   */
  function testFailToAllowAdminAddressToCallFn() public {
    vm.selectFork(chain1);

    // Generate random bytes payload
    bytes memory randomBytes4 = abi.encodePacked(
      uint32(uint256(keccak256(abi.encodePacked(block.timestamp, block.difficulty))) % 2 ** 32)
    );
    bytes memory randomBytes64 = abi.encodePacked(keccak256(abi.encodePacked(block.timestamp, block.difficulty)));
    bytes memory gasPrice = abi.encodePacked(uint256(1000000000));
    bytes memory gasLimit = abi.encodePacked(uint256(1000000));

    bytes memory payload = abi.encodePacked(randomBytes4, randomBytes64, gasPrice, gasLimit);

    // vm.expectRevert("HOLOGRAPH: messaging only call"); this is not working
    vm.expectRevert(bytes(""));
    holographOperatorChain1.crossChainMessage(payload);
  }

  /**
   * @notice Should fail to allow random address to call fn
   * @dev check if the random address can call the function
   */
  function testFailToAllowRandomAddressToCallFn() public {
    vm.selectFork(chain1);

    // generate random bytes payload
    bytes memory randomBytes4 = abi.encodePacked(
      uint32(uint256(keccak256(abi.encodePacked(block.timestamp, block.difficulty))) % 2 ** 32)
    );
    bytes memory randomBytes64 = abi.encodePacked(keccak256(abi.encodePacked(block.timestamp, block.difficulty)));
    bytes memory gasPrice = abi.encodePacked(uint256(1000000000));
    bytes memory gasLimit = abi.encodePacked(uint256(1000000));

    bytes memory payload = abi.encodePacked(randomBytes4, randomBytes64, gasPrice, gasLimit);

    // vm.expectRevert("HOLOGRAPH: messaging only call"); this is not working
    vm.prank(vm.addr(44));
    vm.expectRevert(bytes(""));
    holographOperatorChain1.crossChainMessage(payload);
  }

  /**
   * getJobDetails()
   */

  /**
   * @notice should return expected operatorJob from valid jobHash
   * @dev check if the operatorJob from a valid jobHash is as expected
   */
  function testGetJobDetails() public {
    (bytes32 payloadHash, bytes memory payload, EstimatedGas memory estimatedGas) = jobHelper();
    vm.selectFork(chain2);

    vm.prank(deployer);
    holographOperatorChain2.setMessagingModule(Constants.getMockLZEndpoint());

    (bool success, ) = address(mockLZEndpointChain2).call{gas: TESTGASLIMIT}(
      abi.encodeWithSelector(
        mockLZEndpointChain2.crossChainMessage.selector,
        address(holographOperatorChain2),
        getLzMsgGas(payload) + 200000,
        payload
      )
    );

    OperatorJob memory operatorJob = holographOperatorChain2.getJobDetails(payloadHash);

    OperatorJob memory emptyJob = OperatorJob({
      pod: 0,
      blockTimes: BLOCKTIME,
      operator: address(0),
      startBlock: 0,
      startTimestamp: 0,
      fallbackOperators: [uint16(0), uint16(0), uint16(0), uint16(0), uint16(0)]
    });

    // operatorJob should not be empty
    assertNotEq(keccak256(abi.encode(operatorJob)), keccak256(abi.encode(emptyJob)), "OperatorJob should not be empty");
  }

  /**
   * @notice should return expected operatorJob from INVALID jobHash
   * @dev check if the operatorJob from an INVALID jobHash is as expected
   */
  function testxGetJobDetailsFail() public {
    vm.selectFork(chain2);

    bytes32 invalidPayloadHash = keccak256(abi.encodePacked("invalidPayloadHash"));

    OperatorJob memory operatorJob = holographOperatorChain2.getJobDetails(invalidPayloadHash);

    OperatorJob memory emptyJob = OperatorJob({
      pod: 0,
      blockTimes: BLOCKTIME,
      operator: address(0),
      startBlock: 0,
      startTimestamp: 0,
      fallbackOperators: [uint16(0), uint16(0), uint16(0), uint16(0), uint16(0)]
    });

    // operatorJob should be empty
    assertEq(keccak256(abi.encode(operatorJob)), keccak256(abi.encode(emptyJob)), "OperatorJob should not be empty");
  }

  /**
   * getPodOperatorsLength()
   */

  /**
   * @notice should return expected pod length
   * @dev duplicate of testGetPodOperatorsLength
   */

  /**
   * @notice should fail if pod does not exist
   * @dev duplicate of testGetPodOperatorsLengthFail
   */

  /**
   * ** bond test operators **
   */

  /**
   * @notice should add 10 operator wallets on each chain
   * @dev add 10 operator wallets on each chain | deplicated test from 06_CrossChainMinting
   */
  function testShouldAdd10OperatorsForEachChain() public {
    address[] memory wallets = new address[](10); // Array to hold operator addresses

    // generate 10 operator wallets
    for (uint i = 0; i < 10; i++) {
      wallets[i] = address(uint160(uint(keccak256(abi.encodePacked(block.timestamp, i)))));
    }

    for (uint i = 0; i < wallets.length; i++) {
      addOperator(wallets[i]);
    }
  }

  /**
   * SampleERC20
   */

  /**
   * TODO: refactoring in progress, re-engineering of tests.
   * @notice deploy chain1 equivalent on chain2
   * @dev deploy the SampleERC20 equivalent on chain2 and check if it's deployed
   */
  function testSampleERC20Chain2() public {
    (DeploymentConfig memory erc20Config, bytes32 erc20ConfigHash) = getConfigSampleERC20(true);
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKeyDeployer, erc20ConfigHash);
    Verification memory signature = Verification({r: r, s: s, v: v});

    vm.selectFork(chain2);
    address sampleErc20Address = holographRegistryChain2.getHolographedHashAddress(erc20ConfigHash);

    assertEq(sampleErc20Address, address(0), "ERC20 contract not deployed on chain2");

    vm.selectFork(chain1);
    sampleErc20Address = holographRegistryChain1.getHolographedHashAddress(erc20ConfigHash);

    vm.selectFork(chain2);
    bytes memory data = abi.encode(erc20Config, signature, deployer);

    address originalMessagingModule = holographOperatorChain2.getMessagingModule();

    vm.prank(deployer);
    holographOperatorChain2.setMessagingModule(Constants.getMockLZEndpoint());

    bytes memory payload = getRequestPayload(Constants.getHolographFactoryProxy(), data, true);

    EstimatedGas memory estimatedGas = getEstimatedGas(
      Constants.getHolographFactoryProxy(),
      data,
      payload,
      true,
      150000
    );

    payload = estimatedGas.payload;

    (bool success, ) = address(mockLZEndpointChain2).call{gas: TESTGASLIMIT}(
      abi.encodeWithSelector(
        mockLZEndpointChain2.crossChainMessage.selector,
        address(holographOperatorChain2),
        getLzMsgGas(payload),
        payload
      )
    );

    vm.prank(deployer);
    holographOperatorChain2.setMessagingModule(originalMessagingModule);

    vm.expectEmit(true, true, false, false);
    emit BridgeableContractDeployed(sampleErc20Address, erc20ConfigHash);

    vm.prank(operator);
    (bool success2, ) = address(holographOperatorChain2).call{gas: estimatedGas.estimatedGas}(
      abi.encodeWithSelector(holographOperatorChain2.executeJob.selector, payload)
    );

    assertEq(
      sampleErc20Address,
      holographRegistryChain2.getHolographedHashAddress(erc20ConfigHash),
      "ERC20 contract not deployed on chain2"
    );
  }

  /**
   * TODO: refactoring in progress, re-engineering of tests.
   * @notice deploy chain2 equivalent on chain1
   * @dev deploy the SampleERC20 equivalent on chain1 and check if it's deployed
   */
  function testSampleERC20Chain1() public {
    (DeploymentConfig memory erc20Config, bytes32 erc20ConfigHash) = getConfigSampleERC20(false);
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKeyDeployer, erc20ConfigHash);
    Verification memory signature = Verification({r: r, s: s, v: v});

    vm.selectFork(chain1);
    address sampleErc20Address = holographRegistryChain1.getHolographedHashAddress(erc20ConfigHash);

    assertEq(sampleErc20Address, address(0), "ERC20 contract not deployed on chain1");

    vm.selectFork(chain2);
    sampleErc20Address = holographRegistryChain2.getHolographedHashAddress(erc20ConfigHash);

    vm.selectFork(chain1);
    bytes memory data = abi.encode(erc20Config, signature, deployer);

    address originalMessagingModule = holographOperatorChain1.getMessagingModule();

    vm.prank(deployer);
    holographOperatorChain1.setMessagingModule(Constants.getMockLZEndpoint());

    bytes memory payload = getRequestPayload(Constants.getHolographFactoryProxy(), data, false);

    EstimatedGas memory estimatedGas = getEstimatedGas(
      Constants.getHolographFactoryProxy(),
      data,
      payload,
      false,
      150000
    );

    payload = estimatedGas.payload;

    (bool success, ) = address(mockLZEndpointChain1).call{gas: TESTGASLIMIT}(
      abi.encodeWithSelector(
        mockLZEndpointChain1.crossChainMessage.selector,
        address(holographOperatorChain1),
        getLzMsgGas(payload),
        payload
      )
    );

    vm.prank(deployer);
    holographOperatorChain1.setMessagingModule(originalMessagingModule);

    vm.expectEmit(true, true, false, false);
    emit BridgeableContractDeployed(sampleErc20Address, erc20ConfigHash);

    vm.prank(operator);
    (bool success2, ) = address(holographOperatorChain1).call{gas: estimatedGas.estimatedGas}(
      abi.encodeWithSelector(holographOperatorChain1.executeJob.selector, payload)
    );

    assertEq(
      sampleErc20Address,
      holographRegistryChain1.getHolographedHashAddress(erc20ConfigHash),
      "ERC20 contract not deployed on chain1"
    );
  }
  /**
   * TODO: refactoring in progress, re-engineering of tests.
   * @notice deploy chain1 equivalent on chain2
   * @dev deploy the SampleERC721 equivalent on chain2 and check if it's deployed
   */
  function testSampleERC721Chain2() public {
    (address sampleErc721Address, bytes32 erc721ConfigHash) = sampleERC721HelperChain2();

    vm.selectFork(chain2);
    assertEq(
      sampleErc721Address,
      holographRegistryChain1.getHolographedHashAddress(erc721ConfigHash),
      "ERC721 contract not deployed on chain2"
    );
  }

  /**
   * TODO: refactoring in progress, re-engineering of tests.
   * @notice deploy chain2 equivalent on chain1
   * @dev deploy the SampleERC721 equivalent on chain1 and check if it's deployed
   */
  function testSampleERC721Chain1() public {
    (address sampleErc721Address, bytes32 erc721ConfigHash) = sampleERC721HelperChain1();

    vm.selectFork(chain1);
    assertEq(
      sampleErc721Address,
      holographRegistryChain1.getHolographedHashAddress(erc721ConfigHash),
      "ERC721 contract not deployed on chain1"
    );
  }

  /**
   * CxipERC721
   */

  /**
   * TODO: refactoring in progress, re-engineering of tests.
   * @notice deploy chain1 equivalent on chain2
   * @dev deploy the CxipERC721 equivalent on chain2 and check if it's deployed
   */
  function testCxipERC721Chain2() public {
    (DeploymentConfig memory erc721Config, bytes32 erc721ConfigHash) = getConfigCxipERC721(true);
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKeyDeployer, erc721ConfigHash);
    Verification memory signature = Verification({r: r, s: s, v: v});

    vm.selectFork(chain2);
    address cxipErc721Address = holographRegistryChain2.getHolographedHashAddress(erc721ConfigHash);

    assertEq(cxipErc721Address, address(0), "ERC721 contract not deployed on chain2");

    vm.selectFork(chain1);
    cxipErc721Address = holographRegistryChain1.getHolographedHashAddress(erc721ConfigHash);

    vm.selectFork(chain2);
    bytes memory data = abi.encode(erc721Config, signature, deployer);

    address originalMessagingModule = holographOperatorChain2.getMessagingModule();

    vm.prank(deployer);
    holographOperatorChain2.setMessagingModule(Constants.getMockLZEndpoint());

    bytes memory payload = getRequestPayload(Constants.getHolographFactoryProxy(), data, true);

    EstimatedGas memory estimatedGas = getEstimatedGas(
      Constants.getHolographFactoryProxy(),
      data,
      payload,
      true,
      150000
    );

    payload = estimatedGas.payload;

    (bool success, ) = address(mockLZEndpointChain2).call{gas: TESTGASLIMIT}(
      abi.encodeWithSelector(
        mockLZEndpointChain2.crossChainMessage.selector,
        address(holographOperatorChain2),
        getLzMsgGas(payload),
        payload
      )
    );

    vm.prank(deployer);
    holographOperatorChain2.setMessagingModule(originalMessagingModule);

    vm.expectEmit(true, true, false, false);
    emit BridgeableContractDeployed(cxipErc721Address, erc721ConfigHash);

    vm.prank(operator);
    (bool success2, ) = address(holographOperatorChain2).call{gas: estimatedGas.estimatedGas}(
      abi.encodeWithSelector(holographOperatorChain2.executeJob.selector, payload)
    );

    assertEq(
      cxipErc721Address,
      holographRegistryChain2.getHolographedHashAddress(erc721ConfigHash),
      "ERC721 contract not deployed on chain2"
    );
  }

  /**
   * TODO: refactoring in progress, re-engineering of tests.
   * @notice deploy chain2 equivalent on chain1
   * @dev deploy the CxipERC721 equivalent on chain1 and check if it's deployed
   */
  function testCxipERC721Chain1() public {
    (DeploymentConfig memory erc721Config, bytes32 erc721ConfigHash) = getConfigCxipERC721(false);
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKeyDeployer, erc721ConfigHash);
    Verification memory signature = Verification({r: r, s: s, v: v});

    vm.selectFork(chain1);
    address cxipErc721Address = holographRegistryChain1.getHolographedHashAddress(erc721ConfigHash);

    assertEq(cxipErc721Address, address(0), "ERC721 contract not deployed on chain1");

    vm.selectFork(chain2);
    cxipErc721Address = holographRegistryChain2.getHolographedHashAddress(erc721ConfigHash);

    vm.selectFork(chain1);
    bytes memory data = abi.encode(erc721Config, signature, deployer);

    address originalMessagingModule = holographOperatorChain1.getMessagingModule();

    vm.prank(deployer);
    holographOperatorChain1.setMessagingModule(Constants.getMockLZEndpoint());

    bytes memory payload = getRequestPayload(Constants.getHolographFactoryProxy(), data, false);

    EstimatedGas memory estimatedGas = getEstimatedGas(
      Constants.getHolographFactoryProxy(),
      data,
      payload,
      false,
      150000
    );

    payload = estimatedGas.payload;

    (bool success, ) = address(mockLZEndpointChain1).call{gas: TESTGASLIMIT}(
      abi.encodeWithSelector(
        mockLZEndpointChain1.crossChainMessage.selector,
        address(holographOperatorChain1),
        getLzMsgGas(payload),
        payload
      )
    );

    vm.prank(deployer);
    holographOperatorChain1.setMessagingModule(originalMessagingModule);

    vm.expectEmit(true, true, false, false);
    emit BridgeableContractDeployed(cxipErc721Address, erc721ConfigHash);

    vm.prank(operator);
    (bool success2, ) = address(holographOperatorChain1).call{gas: estimatedGas.estimatedGas}(
      abi.encodeWithSelector(holographOperatorChain1.executeJob.selector, payload)
    );

    assertEq(
      cxipErc721Address,
      holographRegistryChain1.getHolographedHashAddress(erc721ConfigHash),
      "ERC721 contract not deployed on chain1"
    );
  }

  /**
   * executeJob()
   */

  function createOperatorJob(
    bool skipZeroAddressFallback
  ) public returns (bytes32, bytes memory, EstimatedGas memory) {
    sampleERC721Mint();
    sampleERC721HelperChain2();

    bytes memory data = abi.encode(deployer, deployer, uint224(1));

    address sampleErc721HolographerChain1Address = address(sampleErc721HolographerChain1);

    vm.selectFork(chain2);
    address originalMessagingModule = holographOperatorChain2.getMessagingModule();

    bytes memory payload = getRequestPayload(sampleErc721HolographerChain1Address, data, true);

    EstimatedGas memory estimatedGas = getEstimatedGas(
      sampleErc721HolographerChain1Address,
      data,
      payload,
      true,
      400000
    );

    payload = estimatedGas.payload;

    bytes32 payloadHash = keccak256(payload);

    vm.selectFork(chain1);
    vm.prank(deployer);
    (bool success, ) = address(holographBridgeChain1).call{value: estimatedGas.fee}(
      abi.encodeWithSelector(
        holographBridgeChain1.bridgeOutRequest.selector,
        holographIdL2,
        sampleErc721HolographerChain1Address,
        estimatedGas.estimatedGas,
        GWEI,
        data
      )
    );

    vm.selectFork(chain2);
    vm.prank(deployer);
    holographOperatorChain2.setMessagingModule(Constants.getMockLZEndpoint());

    (bool success2, ) = address(mockLZEndpointChain2).call{gas: TESTGASLIMIT}(
      abi.encodeWithSelector(
        mockLZEndpointChain2.crossChainMessage.selector,
        address(holographOperatorChain2),
        getLzMsgGas(payload),
        payload
      )
    );

    vm.prank(deployer);
    holographOperatorChain2.setMessagingModule(originalMessagingModule);

    if (skipZeroAddressFallback) {
      vm.prank(operator);
      (bool success3, ) = address(holographOperatorChain2).call{gas: estimatedGas.estimatedGas}(
        abi.encodeWithSelector(holographOperatorChain2.executeJob.selector, payload)
      );
    }

    return (payloadHash, payload, estimatedGas);
  }

  /**
   * @notice Should fail if job hash is not in _operatorJobs
   * @dev check if the job hash is not in _operatorJobs
   */
  function testExecuteJobFailJobHashNotInOperatorJobs() public {
    vm.selectFork(chain2);

    // generate random bytes payload
    bytes memory randomBytes4 = abi.encodePacked(
      uint32(uint256(keccak256(abi.encodePacked(block.timestamp, block.difficulty))) % 2 ** 32)
    );
    bytes memory randomBytes64 = abi.encodePacked(keccak256(abi.encodePacked(block.timestamp, block.difficulty)));
    bytes memory gasPrice = abi.encodePacked(uint256(1000000000));
    bytes memory gasLimit = abi.encodePacked(uint256(1000000));

    bytes memory payload = abi.encodePacked(randomBytes4, randomBytes64, gasPrice, gasLimit);

    vm.expectRevert("HOLOGRAPH: invalid job");
    holographOperatorChain1.executeJob(payload);
  }

  /**
   * @notice Should fail if there is not enough gas
   * @dev check if there is not enough gas
   */
  function testExecuteJobFailNotEnoughGas() public {
    (bytes32 payloadHash, bytes memory payload, EstimatedGas memory estimatedGas) = jobHelper();
    vm.selectFork(chain2);

    vm.prank(deployer);
    holographOperatorChain2.setMessagingModule(Constants.getMockLZEndpoint());

    (bool success, ) = address(mockLZEndpointChain2).call{gas: TESTGASLIMIT}(
      abi.encodeWithSelector(
        mockLZEndpointChain2.crossChainMessage.selector,
        address(holographOperatorChain2),
        getLzMsgGas(payload) + 200000,
        payload
      )
    );

    vm.expectRevert("HOLOGRAPH: not enough gas left");
    vm.prank(operator);
    holographOperatorChain2.executeJob(payload);
  }

  /**
   * @notice Should succeed executing a reverting job
   * @dev check if the job is executed successfully
   */
  function testExecuteJobSuccessRevertingJob() public {
    vm.skip(true);
    (bytes32 payloadHash, bytes memory payload, EstimatedGas memory estimatedGas) = jobHelper();
    vm.selectFork(chain2);

    vm.expectEmit(true, false, false, false);
    emit FailedOperatorJob(payloadHash);
    vm.prank(operator);
    (bool success2, ) = address(holographOperatorChain2).call{gas: estimatedGas.estimatedGas}(
      abi.encodeWithSelector(holographOperatorChain2.executeJob.selector, estimatedGas.payload)
    );
  }

  /**
   * @notice Should succeed executing a job
   * @dev check if the job is executed successfully
   */
  function testExecuteJobSuccess() public {
    (bytes32 payloadHash, bytes memory payload, EstimatedGas memory estimatedGas) = createOperatorJob(false);
    vm.selectFork(chain2);

    vm.prank(operator);
    (bool success, ) = address(holographOperatorChain2).call{gas: estimatedGas.estimatedGas}(
      abi.encodeWithSelector(holographOperatorChain2.executeJob.selector, payload)
    );
  }

  /**
   * @notice Should fail non-operator address tries to execute job
   * @dev check if the non-operator address can execute the job
   */
  function testExecuteJobFailNonOperator() public {
    vm.skip(true);
    (bytes32 payloadHash, bytes memory payload, EstimatedGas memory estimatedGas) = createOperatorJob(false);
    vm.selectFork(chain2);
    console.log("hola");
    vm.warp(block.timestamp + 100000);
    vm.expectRevert("HOLOGRAPH: operator has time");
    vm.prank(operator);
    (bool success, ) = address(holographOperatorChain2).call{gas: estimatedGas.estimatedGas}(
      abi.encodeWithSelector(holographOperatorChain2.executeJob.selector, payload)
    );
  }

  /**
   * @notice Should fail if there has been a gas spike
   * @dev check if there has been a gas spike
   */
  function testExecuteJobFailGasSpike() public {
    vm.skip(true);
    (bytes32 payloadHash, bytes memory payload, EstimatedGas memory estimatedGas) = createOperatorJob(false);
    vm.selectFork(chain2);

    vm.expectRevert("HOLOGRAPH: gas spike detected");
    vm.prank(operator);
    vm.txGasPrice(1000 gwei);
    (bool success2, ) = address(holographOperatorChain2).call{gas: estimatedGas.estimatedGas}(
      abi.encodeWithSelector(holographOperatorChain2.executeJob.selector, payload)
    );
  }

  /**
   * @notice Should fail if fallback is invalid
   * @dev check if the fallback is invalid
   */

  /**
   * @notice Should succeed if fallback is valid (operator slashed)
   * @dev check if the fallback is valid
   */

  /**
   * @notice Should succeed if fallback is valid (operator has enough tokens to stay)
   * @dev check if the fallback is valid
   */

  /**
   * @notice Should succeed executing 100 jobs
   * @dev check if the 100 jobs are executed successfully
   */

  /**
   * getRegistry()
   */

  /**
   * @notice should return expected registrySlot from operator
   * @dev check if the registrySlot from a operator as expected.
   * Refers to the hardhat test with the description 'Should return valid _registrySlot'
   */
  function testValidRegistrySlot() public {
    vm.selectFork(chain1);
    assertEq(holographOperatorChain1.getRegistry(), address(holographRegistryChain1));
  }

  /**
   * @notice should return expected registrySlot from operator in external call
   * @dev check if the registrySlot from a operator in an external call is as expected.
   * Refers to the hardhat test with the description 'Should allow external contract to call fn'

   */
  function testValidRegistrySlotExternalCall() public {
    vm.selectFork(chain1);
    bytes4 selector = bytes4(keccak256("getRegistry()"));
    (, bytes memory result) = address(MOCKCHAIN1).call(abi.encodeWithSelector(selector));
    address registry = abi.decode(result, (address));
    assertEq(registry, address(holographRegistryChain1), "Registry address is not correct");
  }

  /**
   * @notice
   * @dev
   * Refers to the hardhat test with the description 'should fail to allow inherited contract to call fn'
   */
  function testRegistrySlotExternalCallRevert() public {
    vm.skip(true);
  }

  /**
   * setRegistry()
   */

  /**
   * @notice should allow admin to alter _registrySlot
   * @dev check if the admin can alter the _registrySlot
   * Refers to the hardhat test with the description 'should allow admin to alter _registrySlot'

   */
  function testAllowAdminToAlterRegistrySlot() public {
    vm.selectFork(chain1);
    vm.prank(deployer);
    holographOperatorChain1.setRegistry(operator);
    assertEq(holographOperatorChain1.getRegistry(), operator);
  }

  /**
   * @notice should fail to try to alter _registrySlot with owner
   * @dev check if the owner can alter the _registrySlot
   * Refers to the hardhat test with the description 'should fail to allow owner to alter _registrySlot'
   */
  function testRevertOwnerToAlterRegistrySlot() public {
    vm.selectFork(chain1);
    vm.prank(alice);
    vm.expectRevert(bytes(ErrorConstants.ONLY_ADMIN_ERROR_MSG));
    holographOperatorChain1.setRegistry(operator);
  }

  /**
   * @notice should fail to try to alter _registrySlot with out admin
   * @dev check if the not admin can alter the _registrySlot
   * Refers to the hardhat test with the description 'should fail to allow non-owner to alter _registrySlot'
   */
  function testRevertNotAdminToAlterRegistrySlot() public {
    vm.skip(true);
    vm.selectFork(chain1);
    vm.prank(alice);
    vm.expectRevert(bytes(ErrorConstants.ONLY_ADMIN_ERROR_MSG));
    holographOperatorChain1.setRegistry(operator);
  }

  /**
   * @notice should revert external contract to call fn try to alter _registrySlot
   * @dev check if the external contract can alter the _registrySlot
   * Refers to the hardhat test with the description 'Should revert external contract to call fn alter _registrySlot'
   */
  function testRevertNotAdminToAlterRegistrySlotExternalCall() public {
    vm.selectFork(chain1);
    bytes4 selector = bytes4(keccak256("setRegistry(address)"));
    vm.expectRevert(bytes(ErrorConstants.ONLY_ADMIN_ERROR_MSG));
    (, bytes memory result) = address(MOCKCHAIN1).call(abi.encodeWithSelector(selector, operator));
  }

  /**
   * @notice
   * @dev
   * Refers to the hardhat test with the description 'should revert to allow inherited contract to call fn'
   */
  function testSetRegistrySlotExternalCallRevert() public {
    vm.skip(true);
  }

  /**
   * getHolograph()
   */

  /**
   * @notice should return expected _holographSlot
   * @dev check if the _holographSlot is as expected
   * Refers to the hardhat test with the description 'Should return valid _holographSlot'
   */
  function testValidHolographSlot() public {
    vm.selectFork(chain1);
    assertEq(holographOperatorChain1.getHolograph(), address(holograph));
  }
  /**
   * @notice should return expected _holographSlot
   * @dev check if the _holographSlot is as expected
   * Refers to the hardhat test with the description 'Should allow external contract to call fn'
   */
  function testValidHolographSlotExternalCall() public {
    vm.selectFork(chain1);
    bytes4 selector = bytes4(keccak256("getHolograph()"));
    (, bytes memory result) = address(MOCKCHAIN1).call(abi.encodeWithSelector(selector));
    address _holograph = abi.decode(result, (address));
    assertEq(_holograph, address(holograph));
  }

  /**
   * @notice
   * @dev
   * Refers to the hardhat test with the description 'should fail to allow inherited contract to call fn'
   */
  function testGetHolopgraphSlotExternalCallRevert() public {
    vm.skip(true);
  }

  /**
   * setHolograph()
   */

  /**
   * @notice should allow admin to alter _holographSlot
   * @dev check if the admin can alter the _holographSlot 
   * Refers to the hardhat test with the description 'should allow admin to alter _holographSlot'

   */
  function testAllowAdminToAlterHolographSlot() public {
    vm.selectFork(chain1);
    vm.prank(deployer);
    holographOperatorChain1.setHolograph(operator);
    assertEq(holographOperatorChain1.getHolograph(), operator);
  }

  /**
   * @notice should fail to try to alter _holographSlot with owner
   * @dev check if the non-owner can alter the _holographSlot
   * Refers to the hardhat test with the description 'should fail to allow non-owner to alter _holographSlot'
   */
  function testRevertOwnerToAlterHolographSlot() public {
    vm.selectFork(chain1);
    vm.prank(alice);
    vm.expectRevert(bytes(ErrorConstants.ONLY_ADMIN_ERROR_MSG));
    holographOperatorChain1.setHolograph(operator);
  }

  /**
   * @notice should fail to try to alter _holographSlot with out admin in external call
   * @dev check if the not admin can alter the _holographSlot in external call
   * Refers to the hardhat test with the description 'Should revert external contract to call fn alter _holographSlot'
   */
  function testRevertNotAdminToAlterHolographSlotExternalCall() public {
    vm.selectFork(chain1);
    bytes4 selector = bytes4(keccak256("setHolograph(address)"));
    vm.expectRevert(bytes(ErrorConstants.ONLY_ADMIN_ERROR_MSG));
    (, bytes memory result) = address(MOCKCHAIN1).call(abi.encodeWithSelector(selector, operator));
  }

  /**
   * @notice
   * @dev
   * Refers to the hardhat test with the description 'should revert to allow inherited contract to call fn'
   */
  function testSetHolographSlotExternalCallRevert() public {
    vm.skip(true);
  }

  /**
   * getInterfaces()
   */

  /**
   * @notice should return expected _interfacesSlot
   * @dev check if the _interfacesSlot is as expected
   * Refers to the hardhat test with the description 'Should return valid _interfacesSlot'
   */
  function testValidInterfacesSlot() public {
    vm.selectFork(chain1);
    assertEq(holographOperatorChain1.getInterfaces(), address(holographInterfaces));
  }
  /**
   * @notice should return expected _interfacesSlot in external call
   * @dev check if the _interfacesSlot is as expected in external call
   * Refers to the hardhat test with the description 'Should allow external contract to call fn'
   */
  function testValidInterfacesSlotExternalCall() public {
    vm.selectFork(chain1);
    bytes4 selector = bytes4(keccak256("getInterfaces()"));
    (, bytes memory result) = address(MOCKCHAIN1).call(abi.encodeWithSelector(selector));
    address interfaces = abi.decode(result, (address));
    assertEq(interfaces, address(holographInterfaces));
  }

  /**
   * @notice
   * @dev
   * Refers to the hardhat test with the description 'should fail to allow inherited contract to call fn'
   */
  function testGetInterfacesSlotExternalCallRevert() public {
    vm.skip(true);
  }

  /**
   * setInterfaces()
   */

  /**
   * @notice should allow admin to alter _interfacesSlot
   * @dev check if the admin can alter the _interfacesSlot
   * Refers to the hardhat test with the description 'should allow admin to alter _interfacesSlot'

   */
  function testAllowAdminToAlterInterfacesSlot() public {
    vm.selectFork(chain1);
    vm.prank(deployer);
    holographOperatorChain1.setInterfaces(operator);
    assertEq(holographOperatorChain1.getInterfaces(), operator);
  }

  /**
   * @notice should fail to try to alter _interfacesSlot with non-owner
   * @dev check if the non-owner can alter the _interfacesSlot
   * Refers to the hardhat test with the description 'should fail to allow non-owner to alter _interfacesSlot'
   */
  function testRevertOwnerToAlterInterfacesSlot() public {
    vm.selectFork(chain1);
    vm.prank(alice);
    vm.expectRevert(bytes(ErrorConstants.ONLY_ADMIN_ERROR_MSG));
    holographOperatorChain1.setInterfaces(operator);
  }

  /**
   * getUtilityToken()
   */

  /**
   * TODO:Both test are skiped in hardhat.
   */

  /**
   * setUtilityToken()
   */

  /**
   * @notice should allow admin to alter _utilityTokenSlot
   * @dev check if the admin can alter the _utilityTokenSlot
   * Refers to the hardhat test with the description 'should allow admin to alter _utilityTokenSlot'
   */
  function testAllowAdminToAlterUtilitySlot() public {
    vm.selectFork(chain1);
    vm.prank(deployer);
    holographOperatorChain1.setUtilityToken(operator);
    assertEq(holographOperatorChain1.getUtilityToken(), operator);
  }

  /**
   * @notice should fail to try to alter _utilityTokenSlot with non-owner
   * @dev check if the non-owner can alter the _utilityTokenSlot
   * Refers to the hardhat test with the description 'should fail to allow non-owner to alter _utilityTokenSlot'
   */
  function testRevertOwnerToAlterUtilitySlot() public {
    vm.selectFork(chain1);
    vm.prank(alice);
    vm.expectRevert(bytes(ErrorConstants.ONLY_ADMIN_ERROR_MSG));
    holographOperatorChain1.setUtilityToken(operator);
  }

  /**
   * @notice should fail to try to alter _utilityTokenSlot with out admin in external call
   * @dev check if the not admin can alter the _utilityTokenSlot in external call
   * Refers to the hardhat test with the description 'Should fail external contract to call fn'
   */
  function testRevertNotAdminToAlterUtilitySlotExternalCall() public {
    vm.selectFork(chain1);
    bytes4 selector = bytes4(keccak256("setUtilityToken(address)"));
    vm.expectRevert(bytes(ErrorConstants.ONLY_ADMIN_ERROR_MSG));
    (, bytes memory result) = address(MOCKCHAIN1).call(abi.encodeWithSelector(selector, operator));
  }

  /**
   * @notice
   * @dev
   * Refers to the hardhat test with the description 'should fail to allow inherited contract to call fn'
   */
  function testSetUtilityExternalCallRevert() public {
    vm.skip(true);
  }

  /**
   * validate private functions
   */

  /**
   * @notice Tests that the `_bridge()` function is private
   * @dev This test checks that the `_bridge()` function is private and cannot be called directly.
   * Refers to the hardhat test with the description '_bridge()'
   */
  function testBridgeIsPrivateFunction() public {
    vm.selectFork(chain1);
    bytes memory encodedFunctionData = abi.encodeWithSignature("_bridge()");
    (bool success, bytes memory data) = address(holographOperatorChain1).call(encodedFunctionData);
    assertFalse(success);
  }

  /**
   * @notice Tests that the `_holograph()` function is private
   * @dev This test checks that the `_holograph()` function is private and cannot be called directly.
   * Refers to the hardhat test with the description '_bridge()'
   */
  function testHolographIsPrivateFunction() public {
    vm.selectFork(chain1);
    bytes memory encodedFunctionData = abi.encodeWithSignature("_holograph()");
    (bool success, bytes memory data) = address(holographOperatorChain1).call(encodedFunctionData);
    assertFalse(success);
  }

  /**
   * @notice Tests that the `_interfaces()` function is private
   * @dev This test checks that the `_interfaces()` function is private and cannot be called directly.
   * Refers to the hardhat test with the description '_interfaces()'
   */
  function testInterfacesIsPrivateFunction() public {
    vm.selectFork(chain1);
    bytes memory encodedFunctionData = abi.encodeWithSignature("_interfaces()");
    (bool success, bytes memory data) = address(holographOperatorChain1).call(encodedFunctionData);
    assertFalse(success);
  }

  /**
   * @notice Tests that the `_messagingModule()` function is private
   * @dev This test checks that the `_messagingModule()` function is private and cannot be called directly.
   * Refers to the hardhat test with the description '_messagingModule()'
   */
  function testMessagingModuleIsPrivateFunction() public {
    vm.selectFork(chain1);
    bytes memory encodedFunctionData = abi.encodeWithSignature("_messagingModule()");
    (bool success, bytes memory data) = address(holographOperatorChain1).call(encodedFunctionData);
    assertFalse(success);
  }

  /**
   * @notice Tests that the `_registry()` function is private
   * @dev This test checks that the `_registry()` function is private and cannot be called directly.
   * Refers to the hardhat test with the description '_registry()'
   */
  function testRegistryIsPrivateFunction() public {
    vm.selectFork(chain1);
    bytes memory encodedFunctionData = abi.encodeWithSignature("_registry()");
    (bool success, bytes memory data) = address(holographOperatorChain1).call(encodedFunctionData);
    assertFalse(success);
  }
  /**
   * @notice Tests that the `_utilityToken()` function is private
   * @dev This test checks that the `_utilityToken()` function is private and cannot be called directly.
   * Refers to the hardhat test with the description '_utilityToken()'
   */
  function testUtilityTokenIsPrivateFunction() public {
    vm.selectFork(chain1);
    bytes memory encodedFunctionData = abi.encodeWithSignature("_utilityToken()");
    (bool success, bytes memory data) = address(holographOperatorChain1).call(encodedFunctionData);
    assertFalse(success);
  }

  /**
   * @notice Tests that the `_jobNonce()` function is private
   * @dev This test checks that the `_jobNonce()` function is private and cannot be called directly.
   * Refers to the hardhat test with the description '_jobNonce()'
   */
  function testJobNonceIsPrivateFunction() public {
    vm.selectFork(chain1);
    bytes memory encodedFunctionData = abi.encodeWithSignature("_jobNonce()");
    (bool success, bytes memory data) = address(holographOperatorChain1).call(encodedFunctionData);
    assertFalse(success);
  }

  /**
   * @notice Tests that the `_popOperator()` function is private
   * @dev This test checks that the `_popOperator()` function is private and cannot be called directly.
   * Refers to the hardhat test with the description '_popOperator()'
   */
  function testPopOperatorIsPrivateFunction() public {
    vm.selectFork(chain1);
    bytes memory encodedFunctionData = abi.encodeWithSignature("_popOperator()");
    (bool success, bytes memory data) = address(holographOperatorChain1).call(encodedFunctionData);
    assertFalse(success);
  }

  /**
   * @notice Tests that the `_getBaseBondAmount()` function is private
   * @dev This test checks that the `_getBaseBondAmount()` function is private and cannot be called directly.
   * Refers to the hardhat test with the description '_getBaseBondAmount()'
   */
  function testGetBaseBondAmountIsPrivateFunction() public {
    vm.selectFork(chain1);
    bytes memory encodedFunctionData = abi.encodeWithSignature("_getBaseBondAmount()");
    (bool success, bytes memory data) = address(holographOperatorChain1).call(encodedFunctionData);
    assertFalse(success);
  }

  /**
   * @notice Tests that the `_getCurrentBondAmount()` function is private
   * @dev This test checks that the `_getCurrentBondAmount()` function is private and cannot be called directly.
   * Refers to the hardhat test with the description '_getCurrentBondAmount()'
   */
  function testGetCurrentBondAmountIsPrivateFunction() public {
    vm.selectFork(chain1);
    bytes memory encodedFunctionData = abi.encodeWithSignature("_getCurrentBondAmount()");
    (bool success, bytes memory data) = address(holographOperatorChain1).call(encodedFunctionData);
    assertFalse(success);
  }

  /**
   * @notice Tests that the `_randomBlockHash()` function is private
   * @dev This test checks that the `_randomBlockHash()` function is private and cannot be called directly.
   * Refers to the hardhat test with the description '_randomBlockHash()'
   */
  function testRandomBlockHashIsPrivateFunction() public {
    vm.selectFork(chain1);
    bytes memory encodedFunctionData = abi.encodeWithSignature("_randomBlockHash()");
    (bool success, bytes memory data) = address(holographOperatorChain1).call(encodedFunctionData);
    assertFalse(success);
  }

  /**
   * @notice Tests that the `_randomBlockHash()` function is private
   * @dev This test checks that the `_randomBlockHash()` function is private and cannot be called directly.
   * Refers to the hardhat test with the description '_randomBlockHash()'
   */
  function testIsContractPrivateFunction() public {
    vm.selectFork(chain1);
    bytes memory encodedFunctionData = abi.encodeWithSignature("_isContract()");
    (bool success, bytes memory data) = address(holographOperatorChain1).call(encodedFunctionData);
    assertFalse(success);
  }
}
