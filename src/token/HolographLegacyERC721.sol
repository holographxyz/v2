// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

import "../abstract/ERC721H.sol";

import "../enum/TokenUriType.sol";

import "../interface/HolographERC721Interface.sol";
import "../interface/HolographInterfacesInterface.sol";
import "../interface/HolographInterface.sol";
import "../interface/HolographerInterface.sol";

/**
 * @title Holograph ERC-721 Collection
 * @author Holograph Foundation
 * @notice A smart contract for minting and managing Holograph Bridgeable ERC721 NFTs.
 * @dev The entire logic and functionality of the smart contract is self-contained.
 */
contract HolographLegacyERC721 is ERC721H {
  /// @notice Getter for the init payload
  /// @dev This storage variable is set only once in the init and can be considered as immutable
  bytes private INIT_PAYLOAD;

  /**
   * @dev Internal reference used for minting incremental token ids.
   */
  uint224 private _currentTokenId;

  /**
   * @dev Enum of type of token URI to use globally for the entire contract.
   */
  TokenUriType private _uriType;

  /**
   * @dev Enum mapping of type of token URI to use for specific tokenId.
   */
  mapping(uint256 => TokenUriType) private _tokenUriType;

  /**
   * @dev Mapping of IPFS URIs for tokenIds.
   */
  mapping(uint256 => mapping(TokenUriType => string)) private _tokenURIs;

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

    // we set this as default type since that's what Mint is currently using
    _uriType = TokenUriType.IPFS;
    address owner = abi.decode(initPayload, (address));
    _setOwner(owner);
    // run underlying initializer logic
    return _init(initPayload);
  }

  /**
   * @notice Getter for the HolographLegacyERC721 init payload
   */
  function getInitProperties() external view returns (address) {
    return abi.decode(INIT_PAYLOAD, (address));
  }

  /**
   * @notice Get's the URI of the token.
   * @return string The URI.
   */
  function tokenURI(uint256 _tokenId) external view onlyHolographer returns (string memory) {
    TokenUriType uriType = _getEffectiveUriType(_tokenId);
    return
      string(
        abi.encodePacked(
          HolographInterfacesInterface(
            HolographInterface(HolographerInterface(holographer()).getHolograph()).getInterfaces()
          ).getUriPrepend(uriType),
          _tokenURIs[_tokenId][uriType]
        )
      );
  }

  /**
   * @notice Mints a new token with a given URI.
   * @dev Only callable by the Holographer and the owner.
   * @param tokenId The ID of the token to be minted.
   * @param uriType The type of the URI for the token.
   * @param tokenUri The URI of the token.
   */
  function mint(uint224 tokenId, TokenUriType uriType, string calldata tokenUri) external onlyHolographer onlyOwner {
    HolographERC721Interface H721 = HolographERC721Interface(holographer());
    uint256 chainPrepend = H721.sourceGetChainPrepend();
    if (tokenId == 0) {
      _currentTokenId += 1;
      while (
        H721.exists(chainPrepend + uint256(_currentTokenId)) || H721.burned(chainPrepend + uint256(_currentTokenId))
      ) {
        _currentTokenId += 1;
      }
      tokenId = _currentTokenId;
    }
    H721.sourceMint(msgSender(), tokenId);
    uint256 id = chainPrepend + uint256(tokenId);
    if (uriType == TokenUriType.UNDEFINED) {
      uriType = _uriType;
    }
    _tokenUriType[id] = uriType;
    _tokenURIs[id][uriType] = tokenUri;
  }

  /**
   * @notice Handles the bridging in of a token.
   * @dev Only callable by the Holographer.
   * @param _tokenId The ID of the token being bridged in.
   * @param _data The data containing the URI type and URI of the token.
   * @return bool indicating the success of the operation.
   */
  function bridgeIn(
    uint32 /* _chainId*/,
    address /* _from*/,
    address /* _to*/,
    uint256 _tokenId,
    bytes calldata _data
  ) external onlyHolographer returns (bool) {
    (TokenUriType uriType, string memory tokenUri) = abi.decode(_data, (TokenUriType, string));
    _tokenUriType[_tokenId] = uriType;
    _tokenURIs[_tokenId][uriType] = tokenUri;
    return true;
  }

  /**
   * @notice Handles the bridging out of a token.
   * @dev Only callable by the Holographer.
   * @param _tokenId The ID of the token being bridged out.
   * @return _data The data containing the URI type and URI of the token.
   */
  function bridgeOut(
    uint32 /* _chainId*/,
    address /* _from*/,
    address /* _to*/,
    uint256 _tokenId
  ) external view onlyHolographer returns (bytes memory _data) {
    TokenUriType uriType = _getEffectiveUriType(_tokenId);
    _data = abi.encode(uriType, _tokenURIs[_tokenId][uriType]);
  }

  /**
   * @notice Handles the after burn logic for a token.
   * @dev Only callable by the Holographer.
   * @param _tokenId The ID of the token that was burned.
   * @return bool indicating the success of the operation.
   */
  function afterBurn(address /* _owner*/, uint256 _tokenId) external onlyHolographer returns (bool) {
    TokenUriType uriType = _getEffectiveUriType(_tokenId);
    delete _tokenURIs[_tokenId][uriType];
    return true;
  }

  /**
   * @notice Retrieves the effective URI type of a token.
   * @param _tokenId The ID of the token.
   * @return uriType The effective URI type of the token.
   */
  function _getEffectiveUriType(uint256 _tokenId) internal view returns (TokenUriType) {
    TokenUriType uriType = _tokenUriType[_tokenId];
    return uriType == TokenUriType.UNDEFINED ? _uriType : uriType;
  }
}
