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

import "../abstract/StrictERC721H.sol";

import "../interface/HolographERC721Interface.sol";

/**
 * @title Sample ERC-721 Collection that is bridgeable via Holograph
 * @author Holograph Foundation
 * @notice A smart contract for minting and managing Holograph Bridgeable ERC721 NFTs.
 * @dev The entire logic and functionality of the smart contract is self-contained.
 */
contract SampleERC721 is StrictERC721H {
  /// @notice Getter for the init payload
  /// @dev This storage variable is set only once in the init and can be considered as immutable
  bytes private INIT_PAYLOAD;
  
  /**
   * @dev Mapping of all token URIs.
   */
  mapping(uint256 => string) private _tokenURIs;

  /**
   * @dev Internal reference used for minting incremental token ids.
   */
  uint224 private _currentTokenId;

  /**
   * @dev Temporary implementation to suppress compiler state mutability warnings.
   */
  bool private _dummy;

  /**
   * @dev Constructor is left empty and init is used instead
   */
  constructor() {}

  /**
   * @notice Used internally to initialize the contract instead of through a constructor
   * @dev This function is called by the deployer/factory when creating a contract
   * @param initPayload abi encoded payload to use for contract initilaization
   */
  function init(bytes memory initPayload) external override returns (bytes4) {
    // Store the init payload
    INIT_PAYLOAD = initPayload;

    // do your own custom logic here
    address contractOwner = abi.decode(initPayload, (address));
    _setOwner(contractOwner);
    // run underlying initializer logic
    return _init(initPayload);
  }

  /**
   * @notice Get's the URI of the token.
   * @dev Defaults the the Arweave URI
   * @return string The URI.
   */
  function tokenURI(uint256 _tokenId) external view onlyHolographer returns (string memory) {
    return _tokenURIs[_tokenId];
  }

  /**
   * @notice Getter for the SampleERC721 init payload
   */
  function getInitProperties() external view returns (address) {
    return abi.decode(INIT_PAYLOAD, (address));
  }

  /**
   * @dev Sample mint where anyone can mint specific token, with a custom URI
   */
  function mint(address to, uint224 tokenId, string calldata URI) external onlyHolographer onlyOwner {
    HolographERC721Interface H721 = HolographERC721Interface(holographer());
    if (tokenId == 0) {
      _currentTokenId += 1;
      while (H721.exists(uint256(_currentTokenId)) || H721.burned(uint256(_currentTokenId))) {
        _currentTokenId += 1;
      }
      tokenId = _currentTokenId;
    }
    H721.sourceMint(to, tokenId);
    uint256 id = H721.sourceGetChainPrepend() + uint256(tokenId);
    _tokenURIs[id] = URI;
  }

  function bridgeIn(
    uint32 /* _chainId*/,
    address /* _from*/,
    address /* _to*/,
    uint256 _tokenId,
    bytes calldata _data
  ) external override onlyHolographer returns (bool) {
    string memory URI = abi.decode(_data, (string));
    _tokenURIs[_tokenId] = URI;
    return true;
  }

  function bridgeOut(
    uint32 /* _chainId*/,
    address /* _from*/,
    address /* _to*/,
    uint256 _tokenId
  ) external override onlyHolographer returns (bytes memory _data) {
    _dummy = false;
    _data = abi.encode(_tokenURIs[_tokenId]);
  }

  function afterBurn(address /* _owner*/, uint256 _tokenId) external override onlyHolographer returns (bool) {
    delete _tokenURIs[_tokenId];
    return true;
  }
}
