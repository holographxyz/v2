// SPDX-License-Identifier: UNLICENSED
/*

                         ┌───────────┐
                         │ HOLOGRAPH │
                         └───────────┘
╔═════════════════════════════════════════════════════════════╗
║                                                             ║
║                            / ^ \                            ║
║                            ~~*~~            ¸               ║
║                         [ '<>:<>' ]         │░░░            ║
║               ╔╗           _/"\_           ╔╣               ║
║             ┌─╬╬─┐          """          ┌─╬╬─┐             ║
║          ┌─┬┘ ╠╣ └┬─┐       \_/       ┌─┬┘ ╠╣ └┬─┐          ║
║       ┌─┬┘ │  ╠╣  │ └┬─┐           ┌─┬┘ │  ╠╣  │ └┬─┐       ║
║    ┌─┬┘ │  │  ╠╣  │  │ └┬─┐     ┌─┬┘ │  │  ╠╣  │  │ └┬─┐    ║
║ ┌─┬┘ │  │  │  ╠╣  │  │  │ └┬┐ ┌┬┘ │  │  │  ╠╣  │  │  │ └┬─┐ ║
╠┬┘ │  │  │  │  ╠╣  │  │  │  │└¤┘│  │  │  │  ╠╣  │  │  │  │ └┬╣
║│  │  │  │  │  ╠╣  │  │  │  │   │  │  │  │  ╠╣  │  │  │  │  │║
╠╩══╩══╩══╩══╩══╬╬══╩══╩══╩══╩═══╩══╩══╩══╩══╬╬══╩══╩══╩══╩══╩╣
╠┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴╬╬┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴╬╬┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴╣
║               ╠╣                           ╠╣               ║
║               ╠╣                           ╠╣               ║
║    ,          ╠╣     ,        ,'      *    ╠╣               ║
║~~~~~^~~~~~~~~┌╬╬┐~~~^~~~~~~~~^^~~~~~~~~^~~┌╬╬┐~~~~~~~^~~~~~~║
╚══════════════╩╩╩╩═════════════════════════╩╩╩╩══════════════╝
     - one protocol, one bridge = infinite possibilities -


 ***************************************************************

 DISCLAIMER: U.S Patent Pending

 LICENSE: Holograph Limited Public License (H-LPL)

 https://holograph.xyz/licenses/h-lpl/1.0.0

 This license governs use of the accompanying software. If you
 use the software, you accept this license. If you do not accept
 the license, you are not permitted to use the software.

 1. Definitions

 The terms "reproduce," "reproduction," "derivative works," and
 "distribution" have the same meaning here as under U.S.
 copyright law. A "contribution" is the original software, or
 any additions or changes to the software. A "contributor" is
 any person that distributes its contribution under this
 license. "Licensed patents" are a contributor’s patent claims
 that read directly on its contribution.

 2. Grant of Rights

 A) Copyright Grant- Subject to the terms of this license,
 including the license conditions and limitations in sections 3
 and 4, each contributor grants you a non-exclusive, worldwide,
 royalty-free copyright license to reproduce its contribution,
 prepare derivative works of its contribution, and distribute
 its contribution or any derivative works that you create.
 B) Patent Grant- Subject to the terms of this license,
 including the license conditions and limitations in section 3,
 each contributor grants you a non-exclusive, worldwide,
 royalty-free license under its licensed patents to make, have
 made, use, sell, offer for sale, import, and/or otherwise
 dispose of its contribution in the software or derivative works
 of the contribution in the software.

 3. Conditions and Limitations

 A) No Trademark License- This license does not grant you rights
 to use any contributors’ name, logo, or trademarks.
 B) If you bring a patent claim against any contributor over
 patents that you claim are infringed by the software, your
 patent license from such contributor is terminated with
 immediate effect.
 C) If you distribute any portion of the software, you must
 retain all copyright, patent, trademark, and attribution
 notices that are present in the software.
 D) If you distribute any portion of the software in source code
 form, you may do so only under this license by including a
 complete copy of this license with your distribution. If you
 distribute any portion of the software in compiled or object
 code form, you may only do so under a license that complies
 with this license.
 E) The software is licensed “as-is.” You bear all risks of
 using it. The contributors give no express warranties,
 guarantees, or conditions. You may have additional consumer
 rights under your local laws which this license cannot change.
 To the extent permitted under your local laws, the contributors
 exclude all implied warranties, including those of
 merchantability, fitness for a particular purpose and
 non-infringement.

 4. (F) Platform Limitation- The licenses granted in sections
 2.A & 2.B extend only to the software or derivative works that
 you create that run on a Holograph system product.

 ***************************************************************

*/

pragma solidity 0.8.13;

import "./interface/InitializableInterface.sol";

/**
 * @title HOLOGRAPH GENESIS
 * @dev In the beginning there was a smart contract...
 */
contract HolographGenesis {
  uint32 private immutable _version;

  // Nonce to prevent replay attacks on deployer approvals
  uint256 private _approveDeployerNonce;

  // Immutable addresses of the initial deployers
  address private immutable deployer1 = 0xBB566182f35B9E5Ae04dB02a5450CC156d2f89c1;
  address private immutable deployer2 = 0x22ED36947DDd1ae317F7816c410D3c0c58Bb9b90;
  address private immutable deployer3 = 0xFfCA0d6986099FbDb3b6AD9b6aa5DF5ed1d44f0C;
  address private immutable deployer4 = 0xDF9013a9Af763b181EF8acFC0e3229494004e001;
  address private immutable deployer5 = 0x00Ac9Fd50C63f176B49F05FfedA324bD68C7cD69;
  address private immutable deployer6 = 0xfFc178694Ea206E10F2314A3a9661fdA41FE486D;
  address private immutable deployer7 = 0xa4F88bC984084D0bf8e6F9499FC9F7CB908e44B4;

  // Mapping of addresses that are approved deployers
  mapping(address => bool) private _approvedDeployers;

  // Events
  event Message(string message);
  event ContractDeployed(address deployedContract);

  // Modifier to restrict function calls to approved deployers
  modifier onlyDeployer() {
    require(_approvedDeployers[msg.sender], "HOLOGRAPH: deployer not approved");
    _;
  }

  /**
   * @dev Sets the initial deployers as approved upon contract creation.
   */
  constructor() {
    _version = 2;

    // Set the immutable deployers as approved
    _approvedDeployers[deployer1] = true;
    _approvedDeployers[deployer2] = true;
    _approvedDeployers[deployer3] = true;
    _approvedDeployers[deployer4] = true;
    _approvedDeployers[deployer5] = true;
    _approvedDeployers[deployer6] = true;
    _approvedDeployers[deployer7] = true;

    emit Message("The future is Holographic");
  }

  /**
   * @dev Deploy a contract using the EIP-1014 (create2) opcode for deterministic addresses.
   * @param chainId The chain on which to deploy
   * @param saltHash A unique salt for contract creation
   * @param secret A secret part of the salt
   * @param sourceCode The bytecode of the contract to deploy
   * @param initCode The initialization code for the contract
   */
  function deploy(
    uint256 chainId,
    bytes12 saltHash,
    bytes20 secret,
    bytes memory sourceCode,
    bytes memory initCode
  ) external onlyDeployer {
    require(chainId == block.chainid, "HOLOGRAPH: incorrect chain id");
    bytes32 salt = bytes32(abi.encodePacked(secret, saltHash));
    address contractAddress = address(
      uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff), address(this), salt, keccak256(sourceCode)))))
    );
    require(!_isContract(contractAddress), "HOLOGRAPH: already deployed");
    assembly {
      contractAddress := create2(0, add(sourceCode, 0x20), mload(sourceCode), salt)
    }
    require(_isContract(contractAddress), "HOLOGRAPH: deployment failed");
    require(
      InitializableInterface(contractAddress).init(initCode) == InitializableInterface.init.selector,
      "HOLOGRAPH: initialization failed"
    );

    emit ContractDeployed(contractAddress);
  }

  /**
   * @dev Check if an address is an approved deployer.
   * @param deployer Address to check
   * @return bool representing approval status
   */
  function isApprovedDeployer(address deployer) external view returns (bool) {
    return _approvedDeployers[deployer];
  }

  /**
   * @dev Internal function to determine if an address is a deployed contract.
   * @param contractAddress The address to check
   * @return bool representing if the address is a contract
   */
  function _isContract(address contractAddress) internal view returns (bool) {
    bytes32 codehash;
    assembly {
      codehash := extcodehash(contractAddress)
    }
    return (codehash != 0x0 && codehash != 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470);
  }

  /**
   * @dev Approve or disapprove a deployer using multi-signature verification.
   * @param nonce A unique nonce
   * @param newDeployer The address of the deployer to approve or disapprove
   * @param approve Boolean representing the approval status
   * @param sig1 The first signature for multisig
   * @param sig2 The second signature for multisig
   */
  function approveDeployer(
    uint256 nonce,
    address newDeployer,
    bool approve,
    bytes memory sig1,
    bytes memory sig2
  ) external onlyDeployer {
    require(nonce > _approveDeployerNonce, "HOLOGRAPH: invalid nonce");
    _approveDeployerNonce = nonce; // Update the nonce

    // Recover signers
    address signer1 = recoverSigner(nonce, newDeployer, approve, sig1);
    address signer2 = recoverSigner(nonce, newDeployer, approve, sig2);

    // Check that both signers are approved deployers
    require(_approvedDeployers[signer1], "HOLOGRAPH: signer 1 not approved");
    require(_approvedDeployers[signer2], "HOLOGRAPH: signer 2 not approved");

    // Ensure signatures come from two different deployers
    require(signer1 != signer2, "HOLOGRAPH: signatures must be from different deployers");

    // All checks passed, update the deployer approval status
    _approvedDeployers[newDeployer] = approve;

    emit Message(approve ? "HOLOGRAPH: deployer approved" : "HOLOGRAPH: deployer disapproved");
  }

  /**
   * @dev Generates a hash of the message containing nonce, deployer address, and approval status.
   * @param nonce Nonce used in the message
   * @param newDeployer Address of the deployer in the message
   * @param approve Approval status in the message
   * @return bytes32 Ethereum signed message hash
   */
  function getMessageHash(uint256 nonce, address newDeployer, bool approve) public pure returns (bytes32) {
    return keccak256(abi.encodePacked(nonce, newDeployer, approve));
  }

  /**
   * @dev Recreates the Ethereum signed message hash from the plain message hash.
   * @param _messageHash The hash of the original message
   * @return bytes32 Ethereum signed message hash
   */
  function getEthSignedMessageHash(bytes32 _messageHash) public pure returns (bytes32) {
    return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", _messageHash));
  }

  /**
   * @dev Recovers the signer from the signature.
   * @param nonce Nonce used in the message
   * @param newDeployer Address of the deployer in the message
   * @param approve Approval status in the message
   * @param signature The signature to recover
   * @return address of the signer
   */
  function recoverSigner(
    uint256 nonce,
    address newDeployer,
    bool approve,
    bytes memory signature
  ) public pure returns (address) {
    bytes32 messageHash = getMessageHash(nonce, newDeployer, approve);
    bytes32 prefixedHash = getEthSignedMessageHash(messageHash);
    (bytes32 r, bytes32 s, uint8 v) = splitSignature(signature);

    return ecrecover(prefixedHash, v, r, s);
  }

  /**
   * @dev Splits a signature into its r, s, and v components.
   * @param sig The signature to split.
   * @return r The r component of the signature.
   * @return s The s component of the signature.
   * @return v The recovery id component of the signature.
   */
  function splitSignature(bytes memory sig) internal pure returns (bytes32 r, bytes32 s, uint8 v) {
    require(sig.length == 65, "Invalid signature length");

    assembly {
      // first 32 bytes, after the length prefix
      r := mload(add(sig, 32))
      // second 32 bytes
      s := mload(add(sig, 64))
      // final byte (first byte of the next 32 bytes)
      v := byte(0, mload(add(sig, 96)))
    }
  }

  /**
   * @dev Returns the current nonce for deployer approvals.
   * @return uint256 representing the current nonce
   */
  function getApproveDeployerNonce() external view onlyDeployer returns (uint256) {
    return _approveDeployerNonce;
  }

  /**
   * @dev Returns the version number of the Genesis contract
   * @return uint32 representing the version number
   */
  function getVersion() external view returns (uint32) {
    return _version;
  }
}
