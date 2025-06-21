// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

import {Test, Vm, console} from "forge-std/Test.sol";
import {Constants} from "../utils/Constants.sol";
import {HelperDeploymentConfig} from "../utils/HelperDeploymentConfig.sol";
import {HelperSignEthMessage} from "../utils/HelperSignEthMessage.sol";

import {Holograph} from "../../../src/Holograph.sol";
import {HolographBridge} from "../../../src/HolographBridge.sol";
import {HolographRegistry} from "../../../src/HolographRegistry.sol";
import {HolographFactory} from "../../../src/HolographFactory.sol";
import {HolographOperator, OperatorJob} from "../../../src/HolographOperator.sol";

import {LayerZeroModule, GasParameters} from "../../../src/module/LayerZeroModule.sol";
import {HolographERC20} from "../../../src/enforcer/HolographERC20.sol";
import {Holographer} from "../../../src/enforcer/Holographer.sol";
import {HolographERC721} from "../../../src/enforcer/HolographERC721.sol";
import {SampleERC721} from "../../../src/token/SampleERC721.sol";
import {MockLZEndpoint} from "../../../src/mock/MockLZEndpoint.sol";
import {Verification} from "../../../src/struct/Verification.sol";
import {DeploymentConfig} from "../../../src/struct/DeploymentConfig.sol";
import {SampleERC20} from "../../../src/token/SampleERC20.sol";

contract CrossChainUtils is Test {
  event BridgeableContractDeployed(address indexed contractAddress, bytes32 indexed hash);
  event Transfer(address indexed _from, address indexed _to, uint256 indexed _tokenId);
  event AvailableOperatorJob(bytes32 jobHash, bytes payload);
  event FailedOperatorJob(bytes32 jobHash);

  uint256 public chain1;
  uint256 public chain2;
  string public LOCALHOST_RPC_URL = vm.envString("LOCALHOST_RPC_URL");
  string public LOCALHOST2_RPC_URL = vm.envString("LOCALHOST2_RPC_URL");

  address public alice;
  address public operator;

  uint256 privateKeyDeployer = Constants.getPKDeployer();
  address deployer = vm.addr(privateKeyDeployer);

  uint32 holographIdL1 = Constants.getHolographIdL1();
  uint32 holographIdL2 = Constants.getHolographIdL2();

  uint16 constant BLOCKTIME = 60;
  uint256 constant GWEI = 1000000000; // 1 Gwei
  uint256 constant TESTGASLIMIT = 10000000; // Gas limit
  uint256 constant GASPRICE = 1000000000; // 1 Gwei as gas price

  uint256 msgBaseGas;
  uint256 msgGasPerByte;
  uint256 jobBaseGas;
  uint256 jobGasPerByte;

  HolographOperator holographOperatorChain1;
  HolographOperator holographOperatorChain2;
  MockLZEndpoint mockLZEndpointChain1;
  MockLZEndpoint mockLZEndpointChain2;
  HolographFactory holographFactoryChain1;
  HolographFactory holographFactoryChain2;
  HolographBridge holographBridgeChain1;
  HolographBridge holographBridgeChain2;
  LayerZeroModule lzModuleChain1;
  Holographer sampleErc721HolographerChain1;
  Holographer sampleErc721HolographerChain2;
  Holographer sampleErc20HolographerChain1;
  HolographERC20 HLGCHAIN1;
  HolographERC20 HLGCHAIN2;

  HolographRegistry holographRegistryChain1;
  HolographRegistry holographRegistryChain2;

  struct EstimatedGas {
    bytes payload;
    uint256 estimatedGas;
    uint256 fee;
    uint256 hlgFee;
    uint256 msgFee;
    uint256 dstGasPrice;
  }

  /**
   * @notice Get the gas cost for a message with payload in the local chain
   * @param _payload The payload of the message
   * @return The total gas cost for the message
   */
  function getLzMsgGas(bytes memory _payload) public view returns (uint256) {
    uint256 totalGas = msgBaseGas + (_payload.length * msgGasPerByte);
    return totalGas;
  }

  /**
   * @notice Get the gas cost for a message with payload in the holograph job
   * @param _gasLimit The gas limit for the message
   * @param _payload The payload of the message
   * @return The total gas cost for the message
   */
  function getHlgMsgGas(uint256 _gasLimit, bytes memory _payload) public view returns (uint256) {
    uint256 totalGas = _gasLimit + jobBaseGas + (_payload.length * jobGasPerByte);
    return totalGas;
  }

  /**
   * @notice Get the request payload for a bridge out request
   * @param _target The target address for the request
   * @param _data The data for the request
   * @param isL1 Flag indicating if the request is for chain 1 (localhost)
   * @return The request payload
   */
  function getRequestPayload(address _target, bytes memory _data, bool isL1) public returns (bytes memory) {
    if (isL1) {
      vm.selectFork(chain1);
      vm.prank(deployer);
      return
        holographBridgeChain1.getBridgeOutRequestPayload(
          holographIdL2,
          _target,
          type(uint256).max,
          type(uint256).max,
          _data
        );
    } else {
      vm.selectFork(chain2);
      vm.prank(deployer);
      return
        holographBridgeChain2.getBridgeOutRequestPayload(
          holographIdL1,
          _target,
          type(uint256).max,
          type(uint256).max,
          _data
        );
    }
  }

  /**
   * @dev Get estimated gas for a cross-chain transaction.
   * @param _target The target contract address.
   * @param _data The transaction data.
   * @param _payload The payload data.
   * @param isL1 Flag indicating if the transaction is on chain1 (true) or chain2 (false).
   * @param _gasLimitAddition The additional gas limit.
   * @return The estimated gas and fee information.
   */
  function getEstimatedGas(
    address _target,
    bytes memory _data,
    bytes memory _payload,
    bool isL1,
    uint256 _gasLimitAddition
  ) public returns (EstimatedGas memory) {
    if (isL1) {
      // Select chain2 fork
      vm.selectFork(chain2);
      // Call holographOperatorChain2.jobEstimator to get job estimator gas
      (, bytes memory result) = address(holographOperatorChain2).call{gas: TESTGASLIMIT}(
        abi.encodeWithSelector(holographOperatorChain2.jobEstimator.selector, _payload)
      );
      uint256 jobEstimatorGas = abi.decode(result, (uint256));

      // Calculate estimated gas
      uint256 estimatedGas = TESTGASLIMIT - jobEstimatorGas + _gasLimitAddition;

      // Select chain1 fork
      vm.selectFork(chain1);
      vm.prank(deployer);
      // Get bridge out request payload
      bytes memory payload = holographBridgeChain1.getBridgeOutRequestPayload(
        holographIdL2,
        _target,
        estimatedGas,
        GWEI,
        _data
      );

      // Get message fee
      (uint256 fee1, uint256 fee2, uint256 fee3) = holographBridgeChain1.getMessageFee(
        holographIdL2,
        estimatedGas,
        GWEI,
        payload
      );

      uint256 total = fee1 + fee2;

      // Select chain2 fork
      vm.selectFork(chain2);
      // Call holographOperatorChain2.jobEstimator to get job estimator gas
      (, bytes memory result2) = address(holographOperatorChain2).call{gas: TESTGASLIMIT, value: total}(
        abi.encodeWithSelector(holographOperatorChain2.jobEstimator.selector, payload)
      );

      uint256 jobEstimatorGas2 = abi.decode(result2, (uint256));

      estimatedGas = TESTGASLIMIT - jobEstimatorGas2 + _gasLimitAddition;

      // Calculate HLG message gas
      estimatedGas = getHlgMsgGas(estimatedGas, payload);

      return
        EstimatedGas({
          payload: payload,
          estimatedGas: estimatedGas,
          fee: total,
          hlgFee: fee1,
          msgFee: fee2,
          dstGasPrice: fee3
        });
    } else {
      // Select chain1 fork
      vm.selectFork(chain1);
      // Call holographOperatorChain1.jobEstimator to get job estimator gas
      (, bytes memory result) = address(holographOperatorChain1).call{gas: TESTGASLIMIT}(
        abi.encodeWithSelector(holographOperatorChain1.jobEstimator.selector, _payload)
      );
      uint256 jobEstimatorGas = abi.decode(result, (uint256));

      // Calculate estimated gas
      uint256 estimatedGas = TESTGASLIMIT - jobEstimatorGas + _gasLimitAddition;

      // Select chain2 fork
      vm.selectFork(chain2);
      vm.prank(deployer);
      // Get bridge out request payload
      bytes memory payload = holographBridgeChain2.getBridgeOutRequestPayload(
        holographIdL1,
        _target,
        estimatedGas,
        GWEI,
        _data
      );

      // Get message fee
      (uint256 fee1, uint256 fee2, uint256 fee3) = holographBridgeChain2.getMessageFee(
        holographIdL1,
        estimatedGas,
        GWEI,
        payload
      );

      uint256 total = fee1 + fee2;

      // Select chain1 fork
      vm.selectFork(chain1);
      // Call holographOperatorChain1.jobEstimator to get job estimator gas
      (, bytes memory result2) = address(holographOperatorChain1).call{gas: TESTGASLIMIT, value: total}(
        abi.encodeWithSelector(holographOperatorChain1.jobEstimator.selector, payload)
      );

      uint256 jobEstimatorGas2 = abi.decode(result2, (uint256));

      estimatedGas = TESTGASLIMIT - jobEstimatorGas2 + _gasLimitAddition;

      // Calculate HLG message gas
      estimatedGas = getHlgMsgGas(estimatedGas, payload);

      return
        EstimatedGas({
          payload: payload,
          estimatedGas: estimatedGas,
          fee: total,
          hlgFee: fee1,
          msgFee: fee2,
          dstGasPrice: fee3
        });
    }
  }

  /**
   * @notice Add an operator to the contract
   * @param _operator The address of the operator to be added
   */
  function addOperator(address _operator) public {
    vm.selectFork(chain1);
    (uint256 bondAmount, ) = holographOperatorChain1.getPodBondAmounts(1);

    vm.selectFork(chain1);
    vm.prank(deployer);
    HLGCHAIN1.transfer(_operator, bondAmount);
    vm.startPrank(_operator);
    HLGCHAIN1.approve(address(holographOperatorChain1), bondAmount);
    holographOperatorChain1.bondUtilityToken(_operator, bondAmount, 1);
    vm.stopPrank();

    vm.selectFork(chain2);
    vm.prank(deployer);
    HLGCHAIN2.transfer(_operator, bondAmount);
    vm.startPrank(_operator);
    HLGCHAIN2.approve(address(holographOperatorChain2), bondAmount);
    holographOperatorChain2.bondUtilityToken(_operator, bondAmount, 1);
    vm.stopPrank();
  }

  /**
   * @notice Get the configuration for SampleERC721 contract
   * @dev Returns the deployment configuration and hash for SampleERC721 contract
   * @param isL1 Boolean indicating if it's chain1 or chain2
   * @return deployConfig The deployment configuration for SampleERC721 contract
   * @return hashSampleERC721 The hash of the deployment configuration for SampleERC721 contract
   */
  function getConfigSampleERC721(
    bool isL1
  ) public view returns (DeploymentConfig memory deployConfig, bytes32 hashSampleERC721) {
    deployConfig = HelperDeploymentConfig.getERC721(
      isL1 ? Constants.getHolographIdL1() : Constants.getHolographIdL2(),
      vm.getCode("SampleERC721.sol:SampleERC721"),
      0x0000000000000000000000000000000000000000000000000000000000000086, // eventConfig,
      isL1
    );

    hashSampleERC721 = HelperDeploymentConfig.getDeployConfigHash(deployConfig, deployer);
    return (deployConfig, hashSampleERC721);
  }

  /**
   * @notice Get the configuration for SampleERC20 contract
   * @dev Returns the deployment configuration and hash for SampleERC20 contract
   * @param isL1 Boolean indicating if it's chain1 or chain2
   * @return deployConfig The deployment configuration for SampleERC20 contract
   * @return hashSampleERC20 The hash of the deployment configuration for SampleERC20 contract
   */
  function getConfigSampleERC20(
    bool isL1
  ) public view returns (DeploymentConfig memory deployConfig, bytes32 hashSampleERC20) {
    deployConfig = HelperDeploymentConfig.getERC20(
      isL1 ? Constants.getHolographIdL1() : Constants.getHolographIdL2(),
      vm.getCode("SampleERC20.sol:SampleERC20"),
      isL1
    );

    hashSampleERC20 = HelperDeploymentConfig.getDeployConfigHash(deployConfig, deployer);
    return (deployConfig, hashSampleERC20);
  }

  /**
   * @notice Get the configuration for hTokenETH contract
   * @dev Returns the deployment configuration and hash for hTokenETH contract
   * @param isL1 Boolean indicating if it's chain1 or chain2
   * @return deployConfig The deployment configuration for hTokenETH contract
   * @return hashHtokenTest The hash of the deployment configuration for hTokenETH contract
   */
  function getConfigHtokenETH(
    bool isL1
  ) internal returns (DeploymentConfig memory deployConfig, bytes32 hashHtokenTest) {
    string memory tokenName = string.concat("Holographed TestToken chain ", ((isL1) ? "one" : "two"));

    deployConfig = HelperDeploymentConfig.getDeployConfigERC20(
      bytes32(0x000000000000000000000000000000000000486f6c6f67726170684552433230), //hToken hash
      (isL1) ? Constants.getHolographIdL1() : Constants.getHolographIdL2(),
      vm.getCode("hTokenProxy.sol:hTokenProxy"),
      tokenName,
      "hTTC1",
      bytes32(0x0000000000000000000000000000000000000000000000000000000000000000),
      tokenName,
      HelperDeploymentConfig.getInitCodeHtokenETH()
    );
    hashHtokenTest = HelperDeploymentConfig.getDeployConfigHash(deployConfig, Constants.getDeployer());

    (uint8 v, bytes32 r, bytes32 s) = vm.sign(
      Constants.getPKDeployer(),
      HelperSignEthMessage.toEthSignedMessageHash(hashHtokenTest)
    );
    Verification memory signature = Verification({v: v, r: r, s: s});

    if ((isL1)) {
      vm.selectFork(chain1);
      holographFactoryChain1.deployHolographableContract(deployConfig, signature, Constants.getDeployer());
    } else {
      vm.selectFork(chain2);
      holographFactoryChain2.deployHolographableContract(deployConfig, signature, Constants.getDeployer());
    }

    return (deployConfig, hashHtokenTest);
  }

  /**
   * TODO: refactoring in progress, re-engineering of tests.
   * @notice Get the configuration for SampleERC20 contract
   * @dev Returns the deployment configuration and hash for SampleERC20 contract
   * @param isL1 Boolean indicating if it's chain1 or chain2
   * @return deployConfig The deployment configuration for SampleERC20 contract
   * @return hashSampleERC20 The hash of the deployment configuration for SampleERC20 contract
   */
  //
  function getConfigSampleERC20II(
    bool isL1
  ) public view returns (DeploymentConfig memory deployConfig, bytes32 hashSampleERC20) {
    deployConfig = HelperDeploymentConfig.getERC20(
      isL1 ? Constants.getHolographIdL1() : Constants.getHolographIdL2(),
      vm.getCode("SampleERC20.sol:SampleERC20"),
      isL1
    );

    hashSampleERC20 = HelperDeploymentConfig.getDeployConfigHash(deployConfig, deployer);
    return (deployConfig, hashSampleERC20);
  }

  /**
   * TODO: refactoring in progress, re-engineering of tests. 
   * @notice Get the configuration for CxipERC721 contract
   * @dev Returns the deployment configuration and hash for CxipERC721 contract
   * @param isL1 Boolean indicating if it's chain1 or chain2
   * @return deployConfig The deployment configuration for CxipERC721 contract
   * @return hashSampleERC721 The hash of the deployment configuration for CxipERC721 contract
   */
  function getConfigCxipERC721(
    bool isL1
  ) public view returns (DeploymentConfig memory deployConfig, bytes32 hashSampleERC721) {
    deployConfig = HelperDeploymentConfig.getCxipERC721(
      isL1 ? Constants.getHolographIdL1() : Constants.getHolographIdL2(),
      vm.getCode("CxipERC721Proxy.sol:CxipERC721Proxy"),
      0x0000000000000000000000000000000000000000000000000000000000000086, // eventConfig,
      isL1
    );

    hashSampleERC721 = HelperDeploymentConfig.getDeployConfigHash(deployConfig, deployer);
    return (deployConfig, hashSampleERC721);
  }

  /**
   * @notice Helper function to deploy SampleERC721 contract on chain2
   * @dev This helper exists because the same logic will be used for other tests
   */
  function sampleERC721HelperChain2() internal returns (address sampleErc721Address, bytes32 configHash) {
    (DeploymentConfig memory erc721Config, bytes32 erc721ConfigHash) = getConfigSampleERC721(true);
    configHash = erc721ConfigHash;
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKeyDeployer, erc721ConfigHash);
    Verification memory signature = Verification({r: r, s: s, v: v});

    vm.selectFork(chain2);
    sampleErc721Address = holographRegistryChain2.getHolographedHashAddress(erc721ConfigHash);

    assertEq(sampleErc721Address, address(0), "ERC721 contract not deployed on chain2");

    vm.selectFork(chain1);
    sampleErc721Address = holographRegistryChain1.getHolographedHashAddress(erc721ConfigHash);

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
    emit BridgeableContractDeployed(sampleErc721Address, erc721ConfigHash);

    vm.prank(operator);
    (bool success2, ) = address(holographOperatorChain2).call{gas: estimatedGas.estimatedGas}(
      abi.encodeWithSelector(holographOperatorChain2.executeJob.selector, payload)
    );
  }

  /**
   * @notice Helper function to deploy SampleERC721 contract on chain1
   * @dev This helper exists because the same logic will be used for other tests
   */
  function sampleERC721HelperChain1() internal returns (address sampleErc721Address, bytes32 configHash) {
    (DeploymentConfig memory erc721Config, bytes32 erc721ConfigHash) = getConfigSampleERC721(false);
    configHash = erc721ConfigHash;
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKeyDeployer, erc721ConfigHash);
    Verification memory signature = Verification({r: r, s: s, v: v});

    vm.selectFork(chain1);
    sampleErc721Address = holographRegistryChain1.getHolographedHashAddress(erc721ConfigHash);

    assertEq(sampleErc721Address, address(0), "ERC721 contract not deployed on chain1");

    vm.selectFork(chain2);
    sampleErc721Address = holographRegistryChain2.getHolographedHashAddress(erc721ConfigHash);

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
    emit BridgeableContractDeployed(sampleErc721Address, erc721ConfigHash);

    vm.prank(operator);
    (bool success2, ) = address(holographOperatorChain1).call{gas: estimatedGas.estimatedGas}(
      abi.encodeWithSelector(holographOperatorChain1.executeJob.selector, payload)
    );
  }
}
