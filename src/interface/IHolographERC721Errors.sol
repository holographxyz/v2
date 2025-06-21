// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

interface IHolographERC721Errors {
  error ERC721_BridgeOnlyCall();
  error ERC721_SourceOnlyCall();
  error ERC721_AlreadyInitialized();
  error ERC721_CouldNotInitSource();
  error ERC721_CouldNotInitRoyalties();
  error ERC721_CannotApproveSelf();
  error ERC721_NotApprovedSender(address sender, uint256 tokenId);
  error ERC721_ZeroAddress();
  error ERC721_SenderNotApproved();
  error ERC721_FromIsNotOwner(address from, uint256 tokenId);
  error ERC721_OnERC721ReceivedFail();
  error ERC721_MaxBatchSizeIs1000();
  error ERC721_ArrayLengthMissmatch();
  error ERC721_IndexOutOfBounds(uint256 index);
  error ERC721_OperatorIsNotAContract();
  error ERC721_MintingToZeroAddress();
  error ERC721_UseBurnFunctionToBurnTokens();
  error ERC721_TokenIdCannotBeZero();
  error ERC721_ContractIsNotTokenOwner(uint256 tokenId);
  error ERC721_TokenNotOwned(uint256 tokenId);
  error ERC721_TokenHasBeenBurned(uint256 tokenId);
  error ERC721_TokenDoesNotExist(uint256 tokenId);
  error ERC721_CantMintBurnedToken(uint256 tokenId);
  error ERC721_TokenAlreadyExists(uint256 tokenId);
  error ERC721_OwnerAlreadyInitialized();

  error HOLOGRAPH_BridgeInFailed();
  error HOLOGRAPH_OnlyOwnerFunction();
}
