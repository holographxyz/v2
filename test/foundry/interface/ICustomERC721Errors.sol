// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * This ownership interface matches OZ's ownable interface.
 *
 */
interface ICustomERC721Errors {
  error BatchMintInvalidTokenId(uint256 tokenId);
  error Purchase_CountdownCompleted();
  error Sale_Inactive();
  error Access_OnlyMinter();
  error LazyMint_AlreadyInitialized();
  error HOLOGRAPH_OnlyOwnerFunction();
}
