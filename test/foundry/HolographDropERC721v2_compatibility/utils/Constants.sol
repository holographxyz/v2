// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

// NOTE: These are the addresses of the Holograph Protocol that depends on a couple .env variables being set
//       Those variable are:
//         HOLOGRAPH_ENVIRONMENT="develop"
//         DEVELOP_DEPLOYMENT_SALT=1000
//         DEPLOYER=0xff22437ccbedfffafa93a9f1da2e8c19c1711052799acf3b58ae5bebb5c6bd7b
//         LOCALHOST_DEPLOYER_SECRET=something
//
// These addresses are for the develop environment ONLY on localhost and are not meant to be used in production.
// They are generated from a localhost deployment using the custom HolographGenesisLocal.sol contract that is a
// modified version of the HolographGenesis.sol contract.
//
// The reason we use a custom version of the HolographGenesis.sol contract is because the original contract has
// dedicated approved deployers that do not include local test accounts. This allows us to test the Holograph Protocol
// on localhost without having to modify the original HolographGenesis.sol contract.
library Constants {
  function getHolographGenesis() internal pure returns (address) {
    return address(0x2694a14ea8D91F4CC314A3dBe8819eaadb7E025E);
  }

  function getHolograph() internal pure returns (address) {
    return address(0x1Ed99DFE7462763eaF6925271D7Cb2232a61854C);
  }

  function getHolographBridge() internal pure returns (address) {
    return address(0xdcDbb4A68C2a88C3fC0c9187A2D1218e0289c226);
  }

  function getHolographBridgeProxy() internal pure returns (address) {
    return address(0x8D5b1b160D33ce8B6CAFE2674A81916D33C6Ff0B);
  }

  function getHolographFactory() internal pure returns (address) {
    return address(0xCEd76Ed7baC3b88b1a0E27493b6F74aaE0b3c0Ed);
  }

  function getHolographFactoryProxy() internal pure returns (address) {
    return address(0xf3dDf3Dc6ebB5c5Dc878c7A0c8B2C5e051c37594);
  }

  function getHolographOperator() internal pure returns (address) {
    return address(0x443d6F2051716473e0849fb475e19f09ed488404);
  }

  function getHolographOperatorProxy() internal pure returns (address) {
    return address(0xE1dD53589c001982d06247E1259DCC366b8DdB1B);
  }

  function getHolographRegistry() internal pure returns (address) {
    return address(0x1052ae1742fc6878010a31aA53671fEF7D51bf65);
  }

  function getHolographRegistryProxy() internal pure returns (address) {
    return address(0xC0768Aa301FA733E45b2de64657f952407EC564B);
  }

  function getHolographTreasury() internal pure returns (address) {
    return address(0x76c4fC0627405741Db0959E66d64c0ECeAceDC94);
  }

  function getHolographTreasuryProxy() internal pure returns (address) {
    return address(0xec440e8786C34C9752793e1e00Db39e5E94b6b14);
  }

  function getHolographInterfaces() internal pure returns (address) {
    return address(0xd295e04977e253D8c8387472e70079E36Ad8E3a3);
  }

  function getDropsEventConfig() internal pure returns (uint256) {
    return 0x0000000000000000000000000000000000000000000000000000000000040000;
  }
}
