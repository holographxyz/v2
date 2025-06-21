// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

import {Test, Vm, console} from "forge-std/Test.sol";

import {HolographERC721} from "../../../src/enforcer/HolographERC721.sol";
import {SampleERC721} from "../../../src/token/SampleERC721.sol";
import {MockERC721Receiver} from "../../../src/mock/MockERC721Receiver.sol";
import {Admin} from "../../../src/abstract/Admin.sol";
import {Constants} from "../utils/Constants.sol";
import {IHolographERC721Errors} from "src/interface/IHolographERC721Errors.sol";

/// @title ERC721 Enforcer Tests Setup
/// @notice Sets up the testing environment for ERC721 token testing with specific contracts.
contract Erc721Enforcer is Test, IHolographERC721Errors {
  event Transfer(address indexed _from, address indexed _to, uint256 indexed _tokenId);
  event Approval(address indexed _owner, address indexed _approved, uint256 indexed _tokenId);
  event ApprovalForAll(address indexed _owner, address indexed _operator, bool _approved);
  event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

  uint256 public localHostFork;
  string public LOCALHOST_RPC_URL = vm.envString("LOCALHOST_RPC_URL");

  HolographERC721 public holographERC721;
  SampleERC721 public sampleERC721;
  MockERC721Receiver public mockERC721Receiver;
  Admin public admin;

  address public deployer;
  address public alice;
  address public bob;
  address public charlie;

  // @dev Constants for the ERC721 Enforcer tests.
  address public holographFactoryProxyAddress = Constants.getHolographFactoryProxy();

  uint256 public tokenId1 = 1;
  uint256 public tokenId2 = 2;
  uint256 public tokenId3 = 3;

  string public constant tokenURI1 = "https://holograph.xyz/sample1.json";
  string public constant tokenURI2 = "https://holograph.xyz/sample2.json";
  string public constant tokenURI3 = "https://holograph.xyz/sample3.json";

  /// @notice Set up the testing environment by initializing all necessary contracts and accounts.
  function setUp() public {
    vm.createSelectFork(LOCALHOST_RPC_URL);

    _setupAccounts();
    _setupContracts();
  }

  /// @dev Initializes testing accounts.
  function _setupAccounts() private {
    deployer = vm.addr(0xff22437ccbedfffafa93a9f1da2e8c19c1711052799acf3b58ae5bebb5c6bd7b);
    alice = vm.addr(1);
    bob = vm.addr(2);
    charlie = vm.addr(3);
  }

  /// @dev Deploys the contract instances used in the tests.
  function _setupContracts() private {
    holographERC721 = HolographERC721(payable(Constants.getSampleERC721()));
    sampleERC721 = SampleERC721(payable(Constants.getSampleERC721()));
    mockERC721Receiver = MockERC721Receiver(Constants.getMockERC721Receiver());
    admin = Admin(payable(holographFactoryProxyAddress));
  }

  /// @dev Helper to mint NFTs for testing.
  function _mint(address _to, uint256 _tokenId, string memory _tokenURI) private {
    vm.prank(deployer);
    sampleERC721.mint(_to, uint224(_tokenId), _tokenURI);
  }

  /*
   * CHECK INTERFACES
   */

  /// @notice Should support supportsInterface interface
  function testSupportinterface() public {
    bytes4 selector = holographERC721.supportsInterface.selector;
    holographERC721.supportsInterface(selector);
  }

  /// @notice Should support balanceOf interface
  function testBalanceOfInterface() public {
    bytes4 selector = holographERC721.balanceOf.selector;
    assertTrue(holographERC721.supportsInterface(selector));
  }

  /// @notice Should support ownerOf interface
  function testOwnerOfInterface() public {
    bytes4 selector = holographERC721.ownerOf.selector;
    assertTrue(holographERC721.supportsInterface(selector));
  }

  /// @notice Should support safeTransferFrom interface
  function testSafeTransferFromInterface() public {
    bytes4 selector = bytes4(keccak256("safeTransferFrom(address,address,uint256)"));
    assertTrue(holographERC721.supportsInterface(selector));
  }

  /// @notice Should support safeTransferFrom data interface
  function testSafeTransferFromDataInterface() public {
    bytes4 selector = bytes4(keccak256("safeTransferFrom(address,address,uint256,bytes)"));
    assertTrue(holographERC721.supportsInterface(selector));
  }

  /// @notice Should support transferFrom interface
  function testTransferFromInterface() public {
    bytes4 selector = bytes4(keccak256("transferFrom(address,address,uint256)"));
    assertTrue(holographERC721.supportsInterface(selector));
  }

  /// @notice Should support approve interface
  function testApproveInterface() public {
    bytes4 selector = holographERC721.approve.selector;
    assertTrue(holographERC721.supportsInterface(selector));
  }

  /// @notice Should support setApprovalForAll interface
  function testSetApprovalForAllInterface() public {
    bytes4 selector = holographERC721.setApprovalForAll.selector;
    assertTrue(holographERC721.supportsInterface(selector));
  }

  /// @notice Should support getApproved interface
  function testGetApprovedInterface() public {
    bytes4 selector = holographERC721.getApproved.selector;
    assertTrue(holographERC721.supportsInterface(selector));
  }

  /// @notice Should support isApprovedForAll interface
  function testIsApprovedForAllInterface() public {
    bytes4 selector = holographERC721.isApprovedForAll.selector;
    assertTrue(holographERC721.supportsInterface(selector));
  }

  /// @notice Should support ERC721 interface
  function testInterfaceSupportedERC721() public {
    bytes4 computedId = bytes4(
      keccak256("balanceOf(address)") ^
        keccak256("ownerOf(uint256)") ^
        keccak256("safeTransferFrom(address,address,uint256)") ^
        keccak256("safeTransferFrom(address,address,uint256,bytes)") ^
        keccak256("transferFrom(address,address,uint256)") ^
        keccak256("approve(address,uint256)") ^
        keccak256("setApprovalForAll(address,bool)") ^
        keccak256("getApproved(uint256)") ^
        keccak256("isApprovedForAll(address,address)")
    );
    assertTrue(holographERC721.supportsInterface(computedId));
  }

  /*
   * ERC721Enumerable
   */

  /// @notice Should support totalSupply interface
  function testTotalSupplyInterface() public {
    bytes4 selector = holographERC721.totalSupply.selector;
    assertTrue(holographERC721.supportsInterface(selector));
  }

  /// @notice Should support tokenByIndex interface
  function testTokenByIndexInterface() public {
    bytes4 selector = holographERC721.tokenByIndex.selector;
    assertTrue(holographERC721.supportsInterface(selector));
  }

  /// @notice Should support tokenOfOwnerByIndex interface
  function testTokenOfOwnerByIndexInterface() public {
    bytes4 selector = holographERC721.tokenOfOwnerByIndex.selector;
    assertTrue(holographERC721.supportsInterface(selector));
  }

  /// @notice Should support enumerable interface
  function testInterfaceSupportedEnumerable() public {
    bytes4 computedId = bytes4(
      keccak256("totalSupply()") ^
        keccak256("tokenByIndex(uint256)") ^
        keccak256("tokenOfOwnerByIndex(address,uint256)")
    );
    assertTrue(holographERC721.supportsInterface(computedId));
  }

  /*
   * ERC721Metadata
   */

  /// @notice Should support name interface
  function testNameInterface() public {
    bytes4 selector = holographERC721.name.selector;
    assertTrue(holographERC721.supportsInterface(selector));
  }

  /// @notice Should support symbol interface
  function testSymbolInterface() public {
    bytes4 selector = holographERC721.symbol.selector;
    assertTrue(holographERC721.supportsInterface(selector));
  }

  /// @notice Should support tokenURI interface
  function testTokenURIInterface() public {
    bytes4 selector = holographERC721.tokenURI.selector;
    assertTrue(holographERC721.supportsInterface(selector));
  }

  /// @notice Should support metadata interface
  function testInterfaceSupportedMetadata() public {
    bytes4 computedId = bytes4(keccak256("name()") ^ keccak256("symbol()") ^ keccak256("tokenURI(uint256)"));
    assertTrue(holographERC721.supportsInterface(computedId));
  }

  /*
   * ERC721TokenReceiver
   */

  /// @notice Should support onERC721Received interface
  function testOnERC721ReceivedInterface() public {
    bytes4 selector = holographERC721.onERC721Received.selector;
    assertTrue(holographERC721.supportsInterface(selector));
  }

  /// @notice Should support onERC721Received data interface
  function testOnERC721ReceivedDataInterface() public {
    bytes4 computedId = bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"));
    assertTrue(holographERC721.supportsInterface(computedId));
  }

  /*
   * CollectionURI
   */

  /// @notice Should support contractURI interface
  function testContractURIInterface() public {
    bytes4 selector = holographERC721.contractURI.selector;
    assertTrue(holographERC721.supportsInterface(selector));
  }

  /// @notice Should support collectionURI interface
  function testInterfaceSupportedCollectionURI() public {
    bytes4 computedId = bytes4(keccak256("contractURI()"));
    assertTrue(holographERC721.supportsInterface(computedId));
  }

  /*
   * Test Initializer
   */

  /// @notice Should fail reinitializing HolographERC721
  function testReinitializationHolographer() public {
    bytes memory initData = abi.encodePacked(address(0));
    vm.expectRevert("HOLOGRAPHER: already initialized");
    holographERC721.init(initData);
  }

  // TODO: dont have sampleErc721Enforcer
  /// @notice Should fail reinitializing SampleERC721Enforcer
  function testReinitializationSample() public {
    vm.skip(true);
    bytes memory initData = abi.encode(
      address(this),
      "Another Title",
      "SMPL2",
      uint16(500),
      uint256(5000),
      false,
      bytes("new data")
    );
    vm.expectRevert("ERC721: already initialized");
    sampleERC721.init(initData);
  }

  /*
   * Test ERC721Metadata
   */

  /// @notice Should return "Sample ERC721 Contract (localhost)" as name
  function testName() public {
    assertEq(holographERC721.name(), "Sample ERC721 Contract (localhost)");
  }

  /// @notice Should return "SMPLR" as symbol
  function testSymbol() public {
    assertEq(holographERC721.symbol(), "SMPLR");
  }

  // TODO: find a way to autogenerate the base64 string
  /// @notice Should return contract URI as base64 string
  function testContractURI() public {
    string
      memory expectedURI = "data:application/json;base64,eyJuYW1lIjoiU2FtcGxlIEVSQzcyMSBDb250cmFjdCAobG9jYWxob3N0KSIsImRlc2NyaXB0aW9uIjoiU2FtcGxlIEVSQzcyMSBDb250cmFjdCAobG9jYWxob3N0KSIsImltYWdlIjoiIiwiZXh0ZXJuYWxfbGluayI6IiIsInNlbGxlcl9mZWVfYmFzaXNfcG9pbnRzIjoxMDAwLCJmZWVfcmVjaXBpZW50IjoiMHg4NDZhZjRjODdmNWFmMWYzMDNlNWE1ZDIxNWQ4M2E2MTFiMDgwNjljIn0";
    assertEq(holographERC721.contractURI(), expectedURI, "The contract URI does not match.");
  }

  /*
   * Mint ERC721 NFTs
   */

  /// @notice should have a total supply of 0 SMPLR NFts
  function testTotalSupply() public {
    assertEq(holographERC721.totalSupply(), 0);
  }

  /// @notice should not exist #1 SMPLR NFT
  function testTokenByIndex() public {
    uint256 tokenId = 1;
    assertFalse(holographERC721.exists(tokenId));
  }

  /// @notice NFT index 0 should fail
  function testTokenIndex0() public {
    vm.expectRevert(
      abi.encodeWithSelector(ERC721_IndexOutOfBounds.selector, 0)
    );
    holographERC721.tokenByIndex(0);
  }

  /// @notice NFT owner index 0 should fail
  function testTokenOwnerIndex0() public {
    vm.expectRevert(
      abi.encodeWithSelector(ERC721_IndexOutOfBounds.selector, 0)
    );
    holographERC721.tokenOfOwnerByIndex(deployer, 0);
  }

  /// @notice should emit Transfer event for #1 SMPLR NFT
  function testMint() public {
    vm.expectEmit(true, true, true, false);
    emit Transfer(address(0), alice, tokenId1);

    _mint(alice, tokenId1, tokenURI1);

    assertEq(holographERC721.totalSupply(), 1);

    /// @notice should exist #1 SMPLR NFT
    assertTrue(holographERC721.exists(tokenId1));

    /// @notice should not mark as burned #1 SMPLR NFT
    assertFalse(holographERC721.burned(tokenId1));

    /// @notice should specify alice as owner of #1 SMPLR NFT
    assertEq(holographERC721.ownerOf(tokenId1), alice);

    /// @notice NFT index 0 should return #1 SMPLR NFT
    assertEq(holographERC721.tokenByIndex(0), tokenId1);

    /// @notice NFT owner index 0 should return #1 SMPLR NFT
    assertEq(holographERC721.tokenOfOwnerByIndex(alice, 0), tokenId1);
  }

  /// @notice should emit Transfer event for #2 SMPLR NFT
  function testMint2() public {
    _mint(alice, tokenId1, tokenURI1);

    vm.expectEmit(true, true, true, false);
    emit Transfer(address(0), bob, tokenId2);

    _mint(bob, tokenId2, tokenURI2);

    assertEq(holographERC721.totalSupply(), 2);
  }

  /// @notice should fail minting to zero address
  function testMintToZeroAddress() public {
    vm.expectRevert(abi.encodeWithSelector(ERC721_MintingToZeroAddress.selector));
    _mint(address(0), tokenId1, tokenURI1);
  }

  /// @notice should fail minting existing #1 SMPLR NFT
  function testMintExisting() public {
    _mint(alice, tokenId1, tokenURI1);

    vm.expectRevert(abi.encodeWithSelector(ERC721_TokenAlreadyExists.selector, tokenId1));
    _mint(alice, tokenId1, tokenURI1);
  }

  /// @notice should fail minting burned #3 SMPLR NFT
  function testMintBurned() public {
    _mint(alice, tokenId3, tokenURI3);

    vm.expectEmit(true, true, true, false);
    emit Transfer(alice, address(0), tokenId3);

    vm.prank(alice);
    holographERC721.burn(tokenId3);

    vm.expectRevert(abi.encodeWithSelector(ERC721_CantMintBurnedToken.selector, tokenId3));
    _mint(alice, tokenId3, tokenURI3);

    /// @notice should mark as burned #3 SMPLR NFT
    assertTrue(holographERC721.burned(tokenId3));
  }

  function testMintBalances() public {
    _mint(alice, tokenId1, tokenURI1);
    _mint(alice, tokenId2, tokenURI2);

    /// @notice should have a total supply of 2 SMPLR NFts
    assertEq(holographERC721.totalSupply(), 2);

    /// @notice alice address should have 2 SMPLR NFts
    assertEq(holographERC721.balanceOf(alice), 2);

    /// @notice should return an array of token ids
    uint256[] memory tokenIds = holographERC721.tokens(0, 10);
    assertEq(tokenIds.length, 2);
    assertEq(tokenIds[0], tokenId1);
    assertEq(tokenIds[1], tokenId2);

    /// @notice should return an array of owner token ids
    uint256[] memory ownerTokenIds = holographERC721.tokensOfOwner(alice);
    assertEq(ownerTokenIds.length, 2);
    assertEq(ownerTokenIds[0], tokenId1);
    assertEq(ownerTokenIds[1], tokenId2);

    /// @notice check NFT data
    assertEq(holographERC721.tokenURI(tokenId1), tokenURI1);
    assertEq(holographERC721.tokenURI(tokenId2), tokenURI2);
  }

  /// @notice should return no approval for #1 SMPLR NFT
  function testApprove() public {
    _mint(alice, tokenId1, tokenURI1);

    assertEq(holographERC721.getApproved(tokenId1), address(0));

    /// @notice should succeed when approving bob for #1 SMPLR NFT
    vm.expectEmit(true, true, true, false);
    emit Approval(alice, bob, tokenId1);

    vm.prank(alice);
    holographERC721.approve(bob, tokenId1);

    /// @notice should return bob as approved for #1 SMPLR NFT
    assertEq(holographERC721.getApproved(tokenId1), bob);

    /// @notice should succeed when unsetting approval for #1 SMPLR NFT
    vm.expectEmit(true, true, true, false);
    emit Approval(alice, address(0), tokenId1);

    vm.prank(alice);
    holographERC721.approve(address(0), tokenId1);

    /// @notice should return no approval for #1 SMPLR NFT
    assertEq(holographERC721.getApproved(tokenId1), address(0));
  }

  /// @notice should clear approval on transfer #1 SMPLR NFT
  function testTransferApproval() public {
    _mint(alice, tokenId1, tokenURI1);

    vm.startPrank(alice);
    holographERC721.approve(bob, tokenId1);

    assertEq(holographERC721.getApproved(tokenId1), bob);

    holographERC721.transfer(charlie, tokenId1);

    assertEq(holographERC721.getApproved(tokenId1), address(0));
  }

  /// @notice should bob not be approved operator for alice
  function testIsApprovedForAll() public {
    assertFalse(holographERC721.isApprovedForAll(alice, bob));
  }

  /// @notice should succeed setting bob as approved operator for alice
  function testSetApprovalForAll() public {
    vm.expectEmit(true, true, false, false);
    emit ApprovalForAll(alice, bob, true);

    vm.prank(alice);
    holographERC721.setApprovalForAll(bob, true);

    /// @notice should return bob as approved operator for alice
    assertTrue(holographERC721.isApprovedForAll(alice, bob));

    /// @notice should succeed unsetting bob as approved operator for alice
    vm.expectEmit(true, true, false, false);
    emit ApprovalForAll(alice, bob, false);

    vm.prank(alice);
    holographERC721.setApprovalForAll(bob, false);

    /// @notice should bob not be approved operator for alice
    assertFalse(holographERC721.isApprovedForAll(alice, bob));
  }

  /*
   * Failed transfer
   */

  /// @notice should fail if sender doesn't own #1 SMPLR NFT
  function testTransfer() public {
    _mint(alice, tokenId1, tokenURI1);

    vm.expectRevert(abi.encodeWithSelector(ERC721_NotApprovedSender.selector, address(this), tokenId1));
    holographERC721.transfer(bob, tokenId1);

    /// @notice should fail if transferring to zero address
    vm.expectRevert(abi.encodeWithSelector(ERC721_UseBurnFunctionToBurnTokens.selector));

    vm.prank(alice);
    holographERC721.transfer(address(0), tokenId1);

    /// @notice should fail if transferring from zero address
    vm.expectRevert(abi.encodeWithSelector(ERC721_TokenNotOwned.selector, tokenId1));

    vm.prank(alice);
    holographERC721.transferFrom(address(0), bob, tokenId1);

    /// @notice should fail if transferring not owned NFT
    vm.expectRevert(abi.encodeWithSelector(ERC721_NotApprovedSender.selector, address(this), tokenId1));

    holographERC721.transferFrom(alice, bob, tokenId1);
  }

  /// @notice should fail if transferring non-existent #3 SMPLR NFT
  function testTransferNonExistent() public {
    vm.expectRevert(abi.encodeWithSelector(ERC721_TokenDoesNotExist.selector, 3));
    holographERC721.transfer(alice, 3);
  }

  /// @notice should fail safe transfer for broken ERC721TokenReceiver
  function testSafeTransferBrokenReceiver() public {
    _mint(deployer, tokenId1, tokenURI1);

    mockERC721Receiver.toggleWorks(false);

    vm.expectRevert(
      abi.encodeWithSelector(ERC721_OnERC721ReceivedFail.selector)
    );
    vm.prank(deployer);
    holographERC721.safeTransferFrom(deployer, address(mockERC721Receiver), tokenId1);
  }

  /// @notice should fail for non-contract onERC721Received call
  function testSafeTransferNonContractReceiver() public {
    vm.expectRevert(abi.encodeWithSelector(ERC721_OperatorIsNotAContract.selector));
    holographERC721.onERC721Received(deployer, deployer, tokenId1, "0x");
  }

  /// @notice should fail for non-existant NFT onERC721Received call
  function testSafeTransferNonExistentNFT() public {
    vm.expectRevert(abi.encodeWithSelector(ERC721_TokenDoesNotExist.selector, tokenId1));
    holographERC721.onERC721Received(Constants.getCxipERC721(), deployer, tokenId1, "0x");
  }

  /// @notice should fail for fake onERC721Received call
  function testSafeTransferFakeReceiver() public {
    _mint(deployer, tokenId1, tokenURI1);

    vm.expectRevert(abi.encodeWithSelector(ERC721_ContractIsNotTokenOwner.selector, tokenId1));
    holographERC721.onERC721Received(address(holographERC721), deployer, tokenId1, "0x");
  }

  /*
   * Successful transfer
   */

  /// @notice deployer should succeed transferring #1 SMPLR NFT to alice
  function testTransferSuccess() public {
    _mint(deployer, tokenId1, tokenURI1);

    vm.expectEmit(true, true, true, false);
    emit Transfer(deployer, alice, tokenId1);

    vm.prank(deployer);
    holographERC721.transfer(alice, tokenId1);

    /// @notice should return alice as owner of #1 SMPLR NFT
    assertEq(holographERC721.ownerOf(tokenId1), alice);

    /// @notice alice should succeed safely transferring #1 SMPLR NFT to deployer
    vm.prank(alice);

    vm.expectEmit(true, true, true, false);
    emit Transfer(alice, deployer, tokenId1);

    holographERC721.safeTransferFrom(alice, deployer, tokenId1);

    /// @notice should return deployer as owner of #1 SMPLR NFT
    assertEq(holographERC721.ownerOf(tokenId1), deployer);
  }

  /// @notice should succeed safe transfer #1 SMPLR NFT to ERC721TokenReceiver
  function testSafeTransfer() public {
    _mint(deployer, tokenId1, tokenURI1);
    vm.startPrank(deployer);

    vm.expectEmit(true, true, true, false);
    emit Transfer(deployer, address(mockERC721Receiver), tokenId1);

    holographERC721.safeTransferFrom(deployer, address(mockERC721Receiver), tokenId1);

    /// @notice should return mockERC721Receiver as owner of #1 SMPLR NFT
    assertEq(holographERC721.ownerOf(tokenId1), address(mockERC721Receiver));

    vm.expectEmit(true, true, true, false);
    emit Transfer(address(mockERC721Receiver), deployer, tokenId1);

    mockERC721Receiver.transferNFT(payable(address(holographERC721)), tokenId1, deployer);

    /// @notice should return deployer as owner of #1 SMPLR NFT
    assertEq(holographERC721.ownerOf(tokenId1), deployer);
  }

  /// @notice approved should succeed transferring #1 SMPLR NFT
  function testTransferFrom() public {
    _mint(deployer, tokenId1, tokenURI1);

    vm.expectEmit(true, true, true, false);
    emit Approval(deployer, alice, tokenId1);

    vm.prank(deployer);
    holographERC721.approve(alice, tokenId1);

    assertEq(holographERC721.getApproved(tokenId1), alice);
    assertEq(holographERC721.isApprovedForAll(deployer, alice), false);

    vm.expectEmit(true, true, true, false);
    emit Transfer(deployer, bob, tokenId1);

    vm.prank(alice);
    holographERC721.transferFrom(deployer, bob, tokenId1);

    /// @notice should return bob as owner of #1 SMPLR NFT
    assertEq(holographERC721.ownerOf(tokenId1), bob);
    assertEq(holographERC721.getApproved(tokenId1), address(0));

    vm.expectEmit(true, true, true, false);
    emit Transfer(bob, deployer, tokenId1);

    vm.prank(bob);
    holographERC721.transfer(deployer, tokenId1);

    /// @notice should return deployer as owner of #1 SMPLR NFT
    assertEq(holographERC721.ownerOf(tokenId1), deployer);
  }

  /// @notice approved operator should succeed transferring #1 and #2 SMPLR NFTs
  function testTransferFromOperator() public {
    _mint(deployer, tokenId1, tokenURI1);
    _mint(deployer, tokenId2, tokenURI2);

    vm.expectEmit(true, true, true, false);
    emit ApprovalForAll(deployer, alice, true);

    vm.prank(deployer);
    holographERC721.setApprovalForAll(alice, true);

    assertEq(holographERC721.getApproved(tokenId1), address(0));
    assertEq(holographERC721.getApproved(tokenId2), address(0));
    assertEq(holographERC721.isApprovedForAll(deployer, alice), true);

    vm.expectEmit(true, true, true, false);
    emit Transfer(deployer, bob, tokenId1);

    vm.startPrank(alice);
    holographERC721.transferFrom(deployer, bob, tokenId1);

    vm.expectEmit(true, true, true, false);
    emit Transfer(deployer, bob, tokenId2);

    holographERC721.transferFrom(deployer, bob, tokenId2);

    /// @notice should return bob as owner of #1 and #2 SMPLR NFTs
    assertEq(holographERC721.ownerOf(tokenId1), bob);
    assertEq(holographERC721.ownerOf(tokenId2), bob);
    assertEq(holographERC721.isApprovedForAll(deployer, alice), true);

    vm.stopPrank();

    vm.expectEmit(true, true, true, false);
    emit ApprovalForAll(deployer, alice, false);

    vm.prank(deployer);
    holographERC721.setApprovalForAll(alice, false);

    assertEq(holographERC721.isApprovedForAll(deployer, alice), false);

    vm.startPrank(bob);

    vm.expectEmit(true, true, true, false);
    emit Transfer(bob, deployer, tokenId1);

    holographERC721.transfer(deployer, tokenId1);

    vm.expectEmit(true, true, true, false);
    emit Transfer(bob, deployer, tokenId2);

    holographERC721.transfer(deployer, tokenId2);

    /// @notice should return deployer as owner of #1 and #2 SMPLR NFTs
    assertEq(holographERC721.ownerOf(tokenId1), deployer);
    assertEq(holographERC721.ownerOf(tokenId2), deployer);
  }

  /*
   * Burn NFTs
   */

  /// @notice should fail burning non-existent #4 SMPLR NFT
  function testBurnNonExistent() public {
    vm.expectRevert(abi.encodeWithSelector(ERC721_TokenDoesNotExist.selector, tokenId3));
    holographERC721.burn(tokenId3);
  }

  /// @notice should fail burning not owned #1 SMPLR NFT
  function testBurnNotOwned() public {
    _mint(alice, tokenId1, tokenURI1);

    vm.expectRevert(abi.encodeWithSelector(ERC721_NotApprovedSender.selector, address(this), tokenId1));
    holographERC721.burn(tokenId1);
  }

  /// @notice should succeed burning owned #1 SMPLR NFT
  function testBurn() public {
    _mint(deployer, tokenId1, tokenURI1);
    assertEq(holographERC721.burned(tokenId1), false);

    vm.expectEmit(true, true, true, false);
    emit Transfer(deployer, address(0), tokenId1);

    vm.prank(deployer);
    holographERC721.burn(tokenId1);

    /// @notice should mark as burned #1 SMPLR NFT
    assertTrue(holographERC721.burned(tokenId1));
  }

  /// @notice should succeed burning approved #1 SMPLR NFT
  function testBurnApproved() public {
    _mint(deployer, tokenId1, tokenURI1);
    assertEq(holographERC721.burned(tokenId1), false);

    vm.expectEmit(true, true, true, false);
    emit Approval(deployer, alice, tokenId1);

    vm.prank(deployer);
    holographERC721.approve(alice, tokenId1);

    assertEq(holographERC721.getApproved(tokenId1), alice);
    assertEq(holographERC721.isApprovedForAll(deployer, alice), false);

    vm.expectEmit(true, true, true, false);
    emit Transfer(deployer, address(0), tokenId1);

    vm.prank(alice);
    holographERC721.burn(tokenId1);

    /// @notice should mark as burned #1 SMPLR NFT
    assertTrue(holographERC721.burned(tokenId1));
  }

  /// @notice operator should succeed burning #1 SMPLR NFT
  function testBurnOperator() public {
    _mint(deployer, tokenId1, tokenURI1);

    assertEq(holographERC721.burned(tokenId1), false);
    assertEq(holographERC721.getApproved(tokenId1), address(0));
    assertEq(holographERC721.isApprovedForAll(deployer, alice), false);

    vm.expectEmit(true, true, true, false);
    emit ApprovalForAll(deployer, alice, true);

    vm.prank(deployer);
    holographERC721.setApprovalForAll(alice, true);

    assertEq(holographERC721.getApproved(tokenId1), address(0));
    assertEq(holographERC721.isApprovedForAll(deployer, alice), true);

    vm.expectEmit(true, true, true, false);
    emit Transfer(deployer, address(0), tokenId1);

    vm.prank(alice);
    holographERC721.burn(tokenId1);

    /// @notice should mark as burned #1 SMPLR NFT
    assertTrue(holographERC721.burned(tokenId1));
    assertEq(holographERC721.isApprovedForAll(deployer, alice), true);
  }

  /*
   * Ownership
   */

  /// @notice holographERC721 owner should return "holographFactoryProxyAddress" address
  function testOwner() public {
    assertEq(holographERC721.owner(), holographFactoryProxyAddress);
  }

  /// @notice deployer should return true for isOwner
  function testIsOwner() public {
    vm.startPrank(deployer);
    assertTrue(sampleERC721.isOwner());
    assertTrue(SampleERC721(payable(address(holographERC721))).isOwner());
    vm.stopPrank();

    /// @notice alice should return false for isOwner
    vm.prank(alice);
    assertFalse(sampleERC721.isOwner());
  }

  /// @notice should return "HolographFactoryProxy" address
  function testHolographer() public {
    assertEq(holographERC721.getOwner(), holographFactoryProxyAddress);
  }

  /// @notice deployer should fail transferring ownership
  function testTransferOwnership() public {
    vm.expectRevert(abi.encodeWithSelector(HOLOGRAPH_OnlyOwnerFunction.selector));
    holographERC721.setOwner(alice);
  }

  /// @notice deployer should set owner to deployer
  function testSetOwner() public {
    bytes memory data = abi.encodeWithSelector(bytes4(keccak256("setOwner(address)")), deployer);
    vm.expectEmit(true, true, false, false);
    emit OwnershipTransferred(address(admin), address(deployer));
    vm.prank(deployer);
    admin.adminCall(address(holographERC721), data);
    assertEq(holographERC721.getOwner(), deployer);

    /// @notice deployer should transfer ownership to "HolographFactoryProxy"
    vm.expectEmit(true, true, false, false);
    emit OwnershipTransferred(address(deployer), holographFactoryProxyAddress);
    vm.prank(deployer);
    holographERC721.setOwner(holographFactoryProxyAddress);
    assertEq(holographERC721.getOwner(), holographFactoryProxyAddress);
  }

  /*
   * Admi
   */

  /// @notice admin() should return "HolographFactoryProxy" address
  function testAdmin() public {
    assertEq(holographERC721.admin(), holographFactoryProxyAddress);
  }

  /// @notice getAdmin() should return "HolographFactoryProxy" address
  function testGetAdmin() public {
    assertEq(holographERC721.getAdmin(), holographFactoryProxyAddress);
  }

  /// @notice wallet1 should fail setting admin
  function testSetAdmin() public {
    vm.expectRevert("HOLOGRAPH: admin only function");
    holographERC721.setAdmin(alice);
  }

  /// @notice deployer should succeed setting admin via "HolographFactoryProxy"
  function testSetAdminViaProxy() public {
    bytes memory data = abi.encodeWithSelector(bytes4(keccak256("setAdmin(address)")), deployer);
    vm.startPrank(deployer);
    admin.adminCall(address(holographERC721), data);
    assertEq(holographERC721.admin(), address(deployer));
    holographERC721.setAdmin(holographFactoryProxyAddress);
    assertEq(holographERC721.admin(), holographFactoryProxyAddress);
    vm.stopPrank();
  }
}
