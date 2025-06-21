// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

import {Test, Vm, console} from "forge-std/Test.sol";

import {HolographERC721} from "../../../src/enforcer/HolographERC721.sol";
import {SampleERC721} from "../../../src/token/SampleERC721.sol";
import {MockERC721Receiver} from "../../../src/mock/MockERC721Receiver.sol";
import {Admin} from "../../../src/abstract/Admin.sol";
import {Constants, ErrorConstants} from "../utils/Constants.sol";

/// @title ERC721 Enforcer Tests Setup
/// @notice Sets up the testing environment for ERC721 token testing with specific contracts.
contract Erc721Enforcer is Test {
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
    deployer = Constants.getDeployer();
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

  /* -------------------------------------------------------------------------- */
  /*                              CHECK INTERFACES                              */
  /* -------------------------------------------------------------------------- */

  /**
   * @notice Verifies that the ERC721 contract supports the ERC165 interface
   * @dev This test checks if the ERC721 contract supports the ERC165 interface by calling the
   * supportsInterface function with the ERC165 interface ID.
   * Refers to the hardhat test with the description 'supportsInterface supported'
   */
  function testSupportinterface() public {
    bytes4 selector = holographERC721.supportsInterface.selector;
    holographERC721.supportsInterface(selector);
  }

  /**
   * @notice Verifies that the ERC721 contract supports the balanceOf interface
   * @dev This test checks if the ERC721 contract supports the balanceOf interface by
   * calling the supportsInterface function with the selector of the balanceOf function.
   * Refers to the hardhat test with the description 'balanceOf supported'
   */
  function testBalanceOfInterface() public {
    bytes4 selector = holographERC721.balanceOf.selector;
    assertTrue(holographERC721.supportsInterface(selector));
  }

  /**
   * @notice Verifies that the ERC721 contract supports the ownerOf interface
   * @dev This test checks if the ERC721 contract supports the ownerOf interface by calling
   * the supportsInterface function with the selector of the ownerOf function.
   * Refers to the hardhat test with the description 'ownerOf supported'
   */
  function testOwnerOfInterface() public {
    bytes4 selector = holographERC721.ownerOf.selector;
    assertTrue(holographERC721.supportsInterface(selector));
  }

  /**
   * @notice Verifies that the ERC721 contract supports the safeTransferFrom interface
   * @dev This test checks if the ERC721 contract supports the safeTransferFrom interface by calling the
   * supportsInterface function with the keccak256 hash of the safeTransferFrom function signature.
   * Refers to the hardhat test with the description 'safeTransferFrom supported'
   */
  function testSafeTransferFromInterface() public {
    bytes4 selector = bytes4(keccak256("safeTransferFrom(address,address,uint256)"));
    assertTrue(holographERC721.supportsInterface(selector));
  }

  /**
   * @notice Verifies that the ERC721 contract supports the safeTransferFrom with data interface
   * @dev This test checks if the ERC721 contract supports the safeTransferFrom with data interface
   * by calling the supportsInterface function with the keccak256 hash of the safeTransferFrom
   * function signature with an additional bytes parameter.
   * Refers to the hardhat test with the description 'safeTransferFrom (with bytes) supported'
   */
  function testSafeTransferFromDataInterface() public {
    bytes4 selector = bytes4(keccak256("safeTransferFrom(address,address,uint256,bytes)"));
    assertTrue(holographERC721.supportsInterface(selector));
  }

  /**
   * @notice Verifies that the ERC721 contract supports the transferFrom interface
   * @dev This test checks if the ERC721 contract supports the transferFrom interface by calling the
   * supportsInterface function with the keccak256 hash of the transferFrom function signature.
   * Refers to the hardhat test with the description 'transferFrom supported'
   */
  function testTransferFromInterface() public {
    bytes4 selector = bytes4(keccak256("transferFrom(address,address,uint256)"));
    assertTrue(holographERC721.supportsInterface(selector));
  }

  /**
   * @notice Verifies that the ERC721 contract supports the approve interface
   * @dev This test checks if the ERC721 contract supports the approve interface by calling the
   * supportsInterface function with the selector of the approve function.
   * Refers to the hardhat test with the description 'approve supported'
   */
  function testApproveInterface() public {
    bytes4 selector = holographERC721.approve.selector;
    assertTrue(holographERC721.supportsInterface(selector));
  }

  /**
   * @notice Verifies that the ERC721 contract supports the setApprovalForAll interface
   * @dev This test checks if the ERC721 contract supports the setApprovalForAll interface by calling the
   * supportsInterface function with the selector of the setApprovalForAll function.
   * Refers to the hardhat test with the description 'setApprovalForAll supported'
   */
  function testSetApprovalForAllInterface() public {
    bytes4 selector = holographERC721.setApprovalForAll.selector;
    assertTrue(holographERC721.supportsInterface(selector));
  }

  /**
   * @notice Verifies that the ERC721 contract supports the getApproved interface
   * @dev This test checks if the ERC721 contract supports the getApproved interface by calling the
   * supportsInterface function with the selector of the getApproved function.
   * Refers to the hardhat test with the description 'getApproved supported'
   */
  function testGetApprovedInterface() public {
    bytes4 selector = holographERC721.getApproved.selector;
    assertTrue(holographERC721.supportsInterface(selector));
  }

  /**
   * @notice Verifies that the ERC721 contract supports the isApprovedForAll interface
   * @dev This test checks if the ERC721 contract supports the isApprovedForAll interface by calling the
   * supportsInterface function with the selector of the isApprovedForAll function.
   * Refers to the hardhat test with the description 'isApprovedForAll supported'
   */
  function testIsApprovedForAllInterface() public {
    bytes4 selector = holographERC721.isApprovedForAll.selector;
    assertTrue(holographERC721.supportsInterface(selector));
  }

  /**
   * @notice Verifies that the ERC721 contract supports the ERC721 interface
   * @dev This test checks if the ERC721 contract supports the ERC721 interface by computing the
   * ERC721 interface ID using the XOR of the selectors of all the ERC721 functions and calling
   * the supportsInterface function with the computed ID.
   * Refers to the hardhat test with the description 'ERC721 interface supported'
   */
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

  /* -------------------------------------------------------------------------- */
  /*                              ERC721Enumerable                              */
  /* -------------------------------------------------------------------------- */
  /**
   * @notice Verifies that the ERC721 contract supports the totalSupply interface
   * @dev This test checks if the ERC721 contract supports the totalSupply interface by calling the
   * supportsInterface function with the selector of the totalSupply function.
   * Refers to the hardhat test with the description 'totalSupply supported'
   */
  function testTotalSupplyInterface() public {
    bytes4 selector = holographERC721.totalSupply.selector;
    assertTrue(holographERC721.supportsInterface(selector));
  }

  /**
   * @notice Verifies that the ERC721 contract supports the tokenByIndex interface
   * @dev This test checks if the ERC721 contract supports the tokenByIndex interface by calling the
   * supportsInterface function with the selector of the tokenByIndex function.
   * Refers to the hardhat test with the description 'tokenByIndex supported'
   */
  function testTokenByIndexInterface() public {
    bytes4 selector = holographERC721.tokenByIndex.selector;
    assertTrue(holographERC721.supportsInterface(selector));
  }

  /**
   * @notice  Verifies that the ERC721 contract supports the tokenOfOwnerByIndex
   * @dev This test checks if the ERC721 contract supports the tokenOfOwnerByIndex interface by calling the
   * supportsInterface function with the selector of the tokenOfOwnerByIndex function.
   * Refers to the hardhat test with the description 'tokenOfOwnerByIndex supported'
   */
  function testTokenOfOwnerByIndexInterface() public {
    bytes4 selector = holographERC721.tokenOfOwnerByIndex.selector;
    assertTrue(holographERC721.supportsInterface(selector));
  }

  /**
   * @notice Verifies that the ERC721 contract supports the Enumerable interface
   * @dev This test checks if the ERC721 contract supports the Enumerable interface by computing the
   * Enumerable interface ID using the XOR of the selectors of the totalSupply, tokenByIndex,
   * and tokenOfOwnerByIndex functions, and calling the supportsInterface function with the computed ID.
   * Refers to the hardhat test with the description 'ERC721Enumerable interface supported'
   */
  function testInterfaceSupportedEnumerable() public {
    bytes4 computedId = bytes4(
      keccak256("totalSupply()") ^
        keccak256("tokenByIndex(uint256)") ^
        keccak256("tokenOfOwnerByIndex(address,uint256)")
    );
    assertTrue(holographERC721.supportsInterface(computedId));
  }

  /* -------------------------------------------------------------------------- */
  /*                               ERC721Metadata                               */
  /* -------------------------------------------------------------------------- */
  /**
   * @notice Verifies that the ERC721 contract supports the name interface
   * @dev This test checks if the ERC721 contract supports the name interface by calling the
   * supportsInterface function with the selector of the name function.
   * Refers to the hardhat test with the description 'name supported'
   */
  function testNameInterface() public {
    bytes4 selector = holographERC721.name.selector;
    assertTrue(holographERC721.supportsInterface(selector));
  }

  /**
   * @notice Verifies that the ERC721 contract supports the symbol interface
   * @dev This test checks if the ERC721 contract supports the symbol interface by calling the
   * supportsInterface function with the selector of the symbol function.
   * Refers to the hardhat test with the description 'symbol supported'
   */
  function testSymbolInterface() public {
    bytes4 selector = holographERC721.symbol.selector;
    assertTrue(holographERC721.supportsInterface(selector));
  }

  /**
   * @notice Verifies that the ERC721 contract supports the tokenURI interface
   * @dev This test checks if the ERC721 contract supports the tokenURI interface by calling the
   * supportsInterface function with the selector of the tokenURI function.
   * Refers to the hardhat test with the description 'tokenURI supported'
   */
  function testTokenURIInterface() public {
    bytes4 selector = holographERC721.tokenURI.selector;
    assertTrue(holographERC721.supportsInterface(selector));
  }

  /**
   * @notice Verifies that the ERC721 contract supports the Metadata interface
   * @dev This test checks if the ERC721 contract supports the Metadata interface by
   * computing the Metadata interface ID using the XOR of the selectors of the name, symbol,
   * and tokenURI functions, and calling the supportsInterface function with the computed ID.
   * Refers to the hardhat test with the description 'ERC721Metadata interface supported'
   */
  function testInterfaceSupportedMetadata() public {
    bytes4 computedId = bytes4(keccak256("name()") ^ keccak256("symbol()") ^ keccak256("tokenURI(uint256)"));
    assertTrue(holographERC721.supportsInterface(computedId));
  }

  /* -------------------------------------------------------------------------- */
  /*                             ERC721TokenReceiver                            */
  /* -------------------------------------------------------------------------- */
  /**
   * @notice Verifies that the ERC721 contract supports the onERC721Received interface
   * @dev This test checks if the ERC721 contract supports the onERC721Received interface by calling the
   * supportsInterface function with the selector of the onERC721Received function.
   * Refers to the hardhat test with the description 'onERC721Received supported'
   */
  function testOnERC721ReceivedInterface() public {
    bytes4 selector = holographERC721.onERC721Received.selector;
    assertTrue(holographERC721.supportsInterface(selector));
  }

  /**
   * @notice Verifies that the ERC721 contract supports the onERC721Received with data interface
   * @dev This test checks if the ERC721 contract supports the onERC721Received with data interface by calling
   * the supportsInterface function with the keccak256 hash of the onERC721Received function signature with the
   * additional bytes parameter.
   * Refers to the hardhat test with the description 'ERC721TokenReceiver interface supported'
   */
  function testOnERC721ReceivedDataInterface() public {
    bytes4 computedId = bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"));
    assertTrue(holographERC721.supportsInterface(computedId));
  }

  /* -------------------------------------------------------------------------- */
  /*                                CollectionURI                               */
  /* -------------------------------------------------------------------------- */
  /**
   * @notice Verifies that the ERC721 contract supports the contractURI interface
   * @dev This test checks if the ERC721 contract supports the contractURI interface by calling the
   * supportsInterface function with the selector of the contractURI function.
   * Refers to the hardhat test with the description 'contractURI supported'
   */
  function testContractURIInterface() public {
    bytes4 selector = holographERC721.contractURI.selector;
    assertTrue(holographERC721.supportsInterface(selector));
  }

  /**
   * @notice Verifies that the ERC721 contract supports the collectionURI interface
   * @dev This test checks if the ERC721 contract supports the collectionURI interface by calling the
   * supportsInterface function with the keccak256 hash of the contractURI function signature.
   * Refers to the hardhat test with the description 'contractURI supported'
   */
  function testInterfaceSupportedCollectionURI() public {
    bytes4 computedId = bytes4(keccak256("contractURI()"));
    assertTrue(holographERC721.supportsInterface(computedId));
  }

  /* -------------------------------------------------------------------------- */
  /*                              Test Initializer                              */
  /* -------------------------------------------------------------------------- */

  /**
   * @notice Verifies that reinitializing the HolographERC721 contract fails
   * @dev This test attempts to reinitialize the HolographERC721 contract by calling the init function
   * with the deployer address as the initData. It expects the "HOLOGRAPHER: already initialized" revert error.
   * Refers to the hardhat test with the description 'should fail initializing already initialized Holographer'
   */
  function testReinitializationHolographer() public {
    bytes memory initData = abi.encodePacked(address(0));
    vm.expectRevert(bytes(ErrorConstants.HOLOGRAPHER_ALREADY_INITIALIZED_ERROR_MSG));
    holographERC721.init(initData);
  }

  /**
   * @notice Verifies that reinitializing the SampleERC721Enforcer contract fails
   * @dev This test attempts to reinitialize the SampleERC721Enforcer contract by calling the init function
   * with various parameters. It expects the "ERC721: already initialized" revert error.
   * Refers to the hardhat test with the description 'should fail initializing already initialized ERC721 Enforcer'
   */
  // TODO: dont have sampleErc721Enforcer
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
    vm.expectRevert(bytes(ErrorConstants.ERC721_ALREADY_INITIALIZED_ERROR_MSG));
    sampleERC721.init(initData);
  }

  /* -------------------------------------------------------------------------- */
  /*                             Test ERC721Metadata                            */
  /* -------------------------------------------------------------------------- */
  /**
   * @notice Verifies the name of the ERC721 contract
   * @dev This test checks if the name of the ERC721 contract matches the expected value by calling the name function.
   * Refers to the hardhat test with the description 'collection name:'
   */
  function testName() public {
    assertEq(holographERC721.name(), "Sample ERC721 Contract (localhost)");
  }

  /**
   * @notice Verifies the symbol of the ERC721 contract
   * @dev This test checks if the symbol of the ERC721 contract matches the expected value by calling the symbol function.
   * Refers to the hardhat test with the description 'collection symbol:'
   */
  function testSymbol() public {
    assertEq(holographERC721.symbol(), "SMPLR");
  }

  /**
   * @notice Verifies that the contract URI of the ERC721 contract is a base64 encoded string
   * @dev This test checks if the contract URI of the ERC721 contract matches the expected base64
   * encoded string by calling the contractURI function.
   * Refers to the hardhat test with the description 'contract URI:'
   */
  // TODO: find a way to autogenerate the base64 string
  function testContractURI() public {
    string
      memory expectedURI = "data:application/json;base64,eyJuYW1lIjoiU2FtcGxlIEVSQzcyMSBDb250cmFjdCAobG9jYWxob3N0KSIsImRlc2NyaXB0aW9uIjoiU2FtcGxlIEVSQzcyMSBDb250cmFjdCAobG9jYWxob3N0KSIsImltYWdlIjoiIiwiZXh0ZXJuYWxfbGluayI6IiIsInNlbGxlcl9mZWVfYmFzaXNfcG9pbnRzIjoxMDAwLCJmZWVfcmVjaXBpZW50IjoiMHg4NDZhZjRjODdmNWFmMWYzMDNlNWE1ZDIxNWQ4M2E2MTFiMDgwNjljIn0";
    assertEq(holographERC721.contractURI(), expectedURI, "The contract URI does not match.");
  }

  /* -------------------------------------------------------------------------- */
  /*                              Mint ERC721 NFTs                              */
  /* -------------------------------------------------------------------------- */
  /**
   * @notice Verifies that the total supply of the ERC721 contract is 0
   * @dev This test checks if the total supply of the ERC721 contract is 0 by calling the totalSupply function.
   * Refers to the hardhat test with the description 'should have a total supply of 0 '
   */
  function testTotalSupply() public {
    assertEq(holographERC721.totalSupply(), 0);
  }

  /**
   * @notice  Verifies that the #1 SMPLR NFT does not exist
   * @dev This test checks if the #1 SMPLR NFT does not exist by calling the exists function with the token ID 1.
   * Refers to the hardhat test with the description 'should not exist #'
   */
  function testTokenByIndex() public {
    uint256 tokenId = 1;
    assertFalse(holographERC721.exists(tokenId));
  }

  /**
   * @notice  Verifies that calling tokenByIndex with index 0 reverts with the expected error message
   * @dev This test attempts to call the tokenByIndex function with index 0 and expects the
   * "ERC721: index out of bounds" revert error.
   * Refers to the hardhat test with the description 'NFT index 0 should fail'
   */
  function testTokenIndex0() public {
    vm.expectRevert(bytes(ErrorConstants.ERC721_INDEX_OUT_OF_BOUNDS_ERROR_MSG));
    holographERC721.tokenByIndex(0);
  }

  /**
   * @notice Verifies that calling tokenOfOwnerByIndex with index 0 reverts with the expected error message
   * @dev This test attempts to call the tokenOfOwnerByIndex function with index 0 and expects the
   * "ERC721: index out of bounds"" revert error.
   * Refers to the hardhat test with the description 'NFT owner index 0 should fail'
   */
  function testTokenOwnerIndex0() public {
    vm.expectRevert(bytes(ErrorConstants.ERC721_INDEX_OUT_OF_BOUNDS_ERROR_MSG));
    holographERC721.tokenOfOwnerByIndex(deployer, 0);
  }

  /**
   * @notice Verifies that minting the #1 SMPLR NFT emits the expected Transfer event
   * @dev This test expects the Transfer event to be emitted when minting the #1 SMPLR NFTto the alice address.
   * It also verifies various properties of the minted NFT, such as the total supply, existence, ownership,
   * and index.
   * Refers to the hardhat tests with the descriptions 'should exist #', 'should not mark as burned #', 'should not mark as burned #',
   * 'should specify deployer as owner of #', 'NFT index 0 should return #' and 'NFT owner index 0 should return #'
   */
  function testMint() public {
    vm.expectEmit(true, true, true, false);
    emit Transfer(address(0), alice, tokenId1);

    _mint(alice, tokenId1, tokenURI1);

    assertEq(holographERC721.totalSupply(), 1);

    /// should exist #1 SMPLR NFT
    assertTrue(holographERC721.exists(tokenId1));

    /// should not mark as burned #1 SMPLR NFT
    assertFalse(holographERC721.burned(tokenId1));

    /// should specify alice as owner of #1 SMPLR NFT
    assertEq(holographERC721.ownerOf(tokenId1), alice);

    /// NFT index 0 should return #1 SMPLR NFT
    assertEq(holographERC721.tokenByIndex(0), tokenId1);

    /// NFT owner index 0 should return #1 SMPLR NFT
    assertEq(holographERC721.tokenOfOwnerByIndex(alice, 0), tokenId1);
  }

  /**
   * @notice Verifies that minting the #2 SMPLR NFT emits the expected Transfer event
   * @dev This test expects the Transfer event to be emitted when minting the #2 SMPLR NFT to the bob address.
   * It also verifies the total supply of the ERC721 contract.
   * Refers to the hardhat test with the description 'should emit Transfer event for #'
   */
  function testMint2() public {
    _mint(alice, tokenId1, tokenURI1);

    vm.expectEmit(true, true, true, false);
    emit Transfer(address(0), bob, tokenId2);

    _mint(bob, tokenId2, tokenURI2);

    assertEq(holographERC721.totalSupply(), 2);
  }

  /**
   * @notice Verifies that minting to the zero address reverts with the expected error message
   * @dev This test attempts to mint an NFT to the zero address and expects the
   * "ERC721: minting to burn address"  revert error.
   * Refers to the hardhat test with the description 'should fail minting to zero address'
   */
  function testMintToZeroAddress() public {
    vm.expectRevert(bytes(ErrorConstants.ERC721_MINTING_TO_BURN_ADDRESS_ERROR_MSG));
    _mint(address(0), tokenId1, tokenURI1);
  }

  /**
   * @notice Verifies that minting an existing NFT reverts with the expected error message
   * @dev This test mints the #1 SMPLR NFT and then attempts to mint the same NFT again.
   * It expects the "ERC721: token already exist" revert error.
   * Refers to the hardhat test with the description 'should fail minting existing #'
   */
  function testMintExisting() public {
    _mint(alice, tokenId1, tokenURI1);

    vm.expectRevert(bytes(ErrorConstants.ERC721_TOKEN_ALREADY_EXISTS_ERROR_MSG));
    _mint(alice, tokenId1, tokenURI1);
  }

  /**
   * @notice Verifies that minting a burned NFT reverts with the expected error message
   * @dev This test mints the #3 SMPLR NFT, burns it, and then attempts to mint the same NFT again.
   * It expects the "ERC721: can't mint burned token" revert error.
   * Refers to the hardhat tests with the descriptions 'should fail minting burned #' and 'should mark as burned #'
   */
  function testMintBurned() public {
    _mint(alice, tokenId3, tokenURI3);

    vm.expectEmit(true, true, true, false);
    emit Transfer(alice, address(0), tokenId3);

    vm.prank(alice);
    holographERC721.burn(tokenId3);

    vm.expectRevert(bytes(ErrorConstants.ERC721_CANT_MINT_BURNED_TOKEN_ERROR_MSG));
    _mint(alice, tokenId3, tokenURI3);

    /// should mark as burned #3 SMPLR NFT
    assertTrue(holographERC721.burned(tokenId3));
  }

  /**
   * @notice Verifies the minting, total supply, and balances of the ERC721 contract
   * @dev This test mints two NFTs to the alice address, checks the total supply, alice's balance,
   * the list of token IDs, the list of owner's token IDs, and the token URIs.
   * Refers to the hardhat tests with the descriptions 'should have a total supply of ', 'deployer wallet should show a balance of ',
   * 'should return an array of token ids', 'should return an array of token ids', 'should return an array of owner token ids',
   * and 'Check NFT data'
   */
  function testMintBalances() public {
    _mint(alice, tokenId1, tokenURI1);
    _mint(alice, tokenId2, tokenURI2);

    /// should have a total supply of 2 SMPLR NFts
    assertEq(holographERC721.totalSupply(), 2);

    /// alice address should have 2 SMPLR NFts
    assertEq(holographERC721.balanceOf(alice), 2);

    /// should return an array of token ids
    uint256[] memory tokenIds = holographERC721.tokens(0, 10);
    assertEq(tokenIds.length, 2);
    assertEq(tokenIds[0], tokenId1);
    assertEq(tokenIds[1], tokenId2);

    /// should return an array of owner token ids
    uint256[] memory ownerTokenIds = holographERC721.tokensOfOwner(alice);
    assertEq(ownerTokenIds.length, 2);
    assertEq(ownerTokenIds[0], tokenId1);
    assertEq(ownerTokenIds[1], tokenId2);

    /// check NFT data
    assertEq(holographERC721.tokenURI(tokenId1), tokenURI1);
    assertEq(holographERC721.tokenURI(tokenId2), tokenURI2);
  }

  /**
   * @notice Verifies the approval functionality for the #1 SMPLR NFT
   * @dev This test mints the #1 SMPLR NFT to the alice address, checks that there is no approval set,
   * then sets the approval for the bob address, verifies the approval, and finally unsets the approval.
   * It expects the Approval event to be emitted when setting and unsetting the approval.
   * Refers to the first five tests of the 'approval' section in hardhat.
   */
  function testApprove() public {
    _mint(alice, tokenId1, tokenURI1);

    assertEq(holographERC721.getApproved(tokenId1), address(0));

    /// should succeed when approving bob for #1 SMPLR NFT
    vm.expectEmit(true, true, true, false);
    emit Approval(alice, bob, tokenId1);

    vm.prank(alice);
    holographERC721.approve(bob, tokenId1);

    /// should return bob as approved for #1 SMPLR NFT
    assertEq(holographERC721.getApproved(tokenId1), bob);

    /// should succeed when unsetting approval for #1 SMPLR NFT
    vm.expectEmit(true, true, true, false);
    emit Approval(alice, address(0), tokenId1);

    vm.prank(alice);
    holographERC721.approve(address(0), tokenId1);

    /// should return no approval for #1 SMPLR NFT
    assertEq(holographERC721.getApproved(tokenId1), address(0));
  }

  /**
   * @notice Verifies that transferring an approved NFT removes the approval
   * @dev This test mints the #1 SMPLR NFT to the alice address, sets the approval for the bob address,
   * checks that the approval is set correctly, then transfers the NFT to the charlie address using
   * the alice account, and finally verifies that the approval is removed.
   * Refers to the hardhat test with the description 'should clear approval on transfer for #'
   */
  function testTransferApproval() public {
    _mint(alice, tokenId1, tokenURI1);

    vm.startPrank(alice);
    holographERC721.approve(bob, tokenId1);

    assertEq(holographERC721.getApproved(tokenId1), bob);

    holographERC721.transfer(charlie, tokenId1);

    assertEq(holographERC721.getApproved(tokenId1), address(0));
  }

  /**
   * @notice  Verifies that bob is not an approved operator for alice by default
   * @dev This test checks that the isApprovedForAll function returns false when
   * checking if bob is an approved operator for alice.
   * Refers to the hardhat test with the description 'wallet1 should not be approved operator for deployer'
   */
  function testIsApprovedForAll() public {
    assertFalse(holographERC721.isApprovedForAll(alice, bob));
  }

  /**
   * @notice Verifies the setApprovalForAll functionality
   * @dev This test sets bob as an approved operator for alice, expects the ApprovalForAll event to be emitted,
   * checks that bob is an approved operator for alice, then unsets the approval, expects the ApprovalForAll event
   * to be emitted again, and finally verifies that bob is no longer an approved operator for alice.
   * Refers to the hardhat tests with the descriptions 'should succeed setting wallet1 as operator for deployer',
   * 'should return wallet1 as approved operator for deployer', 'should succeed unsetting wallet1 as operator for deployer',
   * and 'wallet1 should not be approved operator for deployer'
   */
  function testSetApprovalForAll() public {
    vm.expectEmit(true, true, false, false);
    emit ApprovalForAll(alice, bob, true);

    vm.prank(alice);
    holographERC721.setApprovalForAll(bob, true);

    /// should return bob as approved operator for alice
    assertTrue(holographERC721.isApprovedForAll(alice, bob));

    /// should succeed unsetting bob as approved operator for alice
    vm.expectEmit(true, true, false, false);
    emit ApprovalForAll(alice, bob, false);

    vm.prank(alice);
    holographERC721.setApprovalForAll(bob, false);

    /// should bob not be approved operator for alice
    assertFalse(holographERC721.isApprovedForAll(alice, bob));
  }

  /* -------------------------------------------------------------------------- */
  /*                               Failed transfer                              */
  /* -------------------------------------------------------------------------- */

  /**
   * @notice Verifies the transfer functionality and its failure cases
   * @dev This test mints the #1 SMPLR NFT to the alice address, then attempts to transfer it to the bob address
   * using the default sender, expects the 'ERC721: not approved sender' revert error.
   * It then attempts to transfer the NFT to the zero address using the alice account, expects the
   * 'ERC721: use burn instead' revert error.
   * It also attempts to transfer the NFT from the zero address to the bob address using the alice account,
   * expects the 'ERC721: token not owned' revert error.
   * Finally, it attempts to transfer the NFT from the alice address to the bob address using the default sender,
   * expects the 'ERC721: not approved sender' revert error.
   * Refers to the first four tests of the 'failed transfer' section in hardhat.
   */
  //
  function testTransfer() public {
    _mint(alice, tokenId1, tokenURI1);

    vm.expectRevert(bytes(ErrorConstants.ERC721_NOT_APPROVED_SENDER_ERROR_MSG));
    holographERC721.transfer(bob, tokenId1);

    /// should fail if transferring to zero address
    vm.expectRevert(bytes(ErrorConstants.ERC721_USE_BURN_INSTEAD_ERROR_MSG));

    vm.prank(alice);
    holographERC721.transfer(address(0), tokenId1);

    /// should fail if transferring from zero address
    vm.expectRevert(bytes(ErrorConstants.ERC721_TOKEN_NOT_OWNED_ERROR_MSG));

    vm.prank(alice);
    holographERC721.transferFrom(address(0), bob, tokenId1);

    /// should fail if transferring not owned NFT
    vm.expectRevert(bytes(ErrorConstants.ERC721_NOT_APPROVED_SENDER_ERROR_MSG));

    holographERC721.transferFrom(alice, bob, tokenId1);
  }

  /**
   * @notice Verifies that transferring a non-existent NFT reverts with the expected error message
   * @dev This test attempts to transfer the #3 SMPLR NFT, which does not exist, and expects the
   * 'ERC721: token does not exist' revert error.
   * Refers to the hardhat test with the description 'should fail if transferring non-existant #'
   */
  function testTransferNonExistent() public {
    vm.expectRevert(bytes(ErrorConstants.ERC721_TOKEN_NOT_EXISTS_ERROR_MSG));
    holographERC721.transfer(alice, 3);
  }

  /**
   * @notice Verifies that safe transfer to a broken ERC721TokenReceiver reverts with the expected error message
   * @dev This test mints the #1 SMPLR NFT to the deployer address, then sets the mock ERC721Receiver to be broken,
   * and attempts to safely transfer the NFT to the mock receiver, expecting the 'ERC721: onERC721Received fail' revert error.
   * Refers to the hardhat test with the description 'should fail safe transfer for broken "ERC721TokenReceiver"'
   */
  function testSafeTransferBrokenReceiver() public {
    _mint(deployer, tokenId1, tokenURI1);

    mockERC721Receiver.toggleWorks(false);

    vm.expectRevert(bytes(ErrorConstants.ERC721_onERC721Received_FAIL_ERROR_MSG));
    vm.prank(deployer);
    holographERC721.safeTransferFrom(deployer, address(mockERC721Receiver), tokenId1);
  }

  /**
   * @notice Verifies that safe transfer to a non-contract receiver reverts with the expected error message
   * @dev This test attempts to call the onERC721Received function directly with a non-contract receiver address,
   * and expects the "ERC721: operator not contract" revert error.
   * Refers to the hardhat test with the description 'should fail for non-contract onERC721Received call'
   */
  function testSafeTransferNonContractReceiver() public {
    vm.expectRevert(bytes(ErrorConstants.ERC721_OPERATOR_NOT_CONTRACT_ERROR_MSG));
    holographERC721.onERC721Received(deployer, deployer, tokenId1, "0x");
  }

  /**
   * @notice Verifies that safe transfer of a non-existent NFT reverts with the expected error message
   * @dev This test attempts to call the onERC721Received function directly with a non-existent NFT,
   * and expects the "ERC721: token does not exist" revert error.
   * Refers to the hardhat test with the description 'should fail for non-existant NFT onERC721Received call'
   */
  function testSafeTransferNonExistentNFT() public {
    vm.expectRevert(bytes(ErrorConstants.ERC721_TOKEN_NOT_EXISTS_ERROR_MSG));
    holographERC721.onERC721Received(Constants.getCxipERC721(), deployer, tokenId1, "0x");
  }

  /**
   * @notice Verifies that safe transfer from a fake receiver reverts with the expected error message
   * @dev This test mints the #1 SMPLR NFT to the deployer address, then attempts to call the onERC721Received
   * function directly with the ERC721 contract address as the receiver, expecting the "ERC721: contract not token owner"
   * Refers to the hardhat test with the description 'should fail for fake onERC721Received call'
   */
  function testSafeTransferFakeReceiver() public {
    _mint(deployer, tokenId1, tokenURI1);

    vm.expectRevert(bytes(ErrorConstants.ERC721_CONTRACT_NOT_TOKEN_OWNER_ERROR_MSG));
    holographERC721.onERC721Received(address(holographERC721), deployer, tokenId1, "0x");
  }

  /* -------------------------------------------------------------------------- */
  /*                             Successful transfer                            */
  /* -------------------------------------------------------------------------- */
  /**
   * @notice Verifies the successful transfer of the #1 SMPLR NFT from the deployer to alice, and back
   * @dev This test mints the #1 SMPLR NFT to the deployer address, expects the Transfer event to be emitted,
   * then transfers the NFT to the alice address using the deployer account, and verifies that alice is the new owner.
   * It then has alice safely transfer the NFT back to the deployer, expects the Transfer event to be emitted again,
   * and verifies that the deployer is the new owner.
   * Refers to the hardhat test with the description 'deployer should succeed transferring #',
   * 'wallet1 should succeed safely transferring #'
   */
  function testTransferSuccess() public {
    _mint(deployer, tokenId1, tokenURI1);

    vm.expectEmit(true, true, true, false);
    emit Transfer(deployer, alice, tokenId1);

    vm.prank(deployer);
    holographERC721.transfer(alice, tokenId1);

    /// should return alice as owner of #1 SMPLR NFT
    assertEq(holographERC721.ownerOf(tokenId1), alice);

    /// alice should succeed safely transferring #1 SMPLR NFT to deployer
    vm.prank(alice);

    vm.expectEmit(true, true, true, false);
    emit Transfer(alice, deployer, tokenId1);

    holographERC721.safeTransferFrom(alice, deployer, tokenId1);

    /// should return deployer as owner of #1 SMPLR NFT
    assertEq(holographERC721.ownerOf(tokenId1), deployer);
  }

  /**
   * @notice Verifies the successful safe transfer of the #1 SMPLR NFT to an ERC721TokenReceiver
   * @dev This test mints the #1 SMPLR NFT to the deployer address, expects the Transfer event to be emitted,
   * then safely transfers the NFT to the mock ERC721Receiver using the deployer account, and verifies that
   * the mock receiver is the new owner.
   * It then has the mock receiver transfer the NFT back to the deployer, expects the Transfer event to be
   * emitted again, and verifies that the deployer is the new owner.
   * Refers to the hardhat test with the description 'should succeed safe transfer #'
   */
  function testSafeTransfer() public {
    _mint(deployer, tokenId1, tokenURI1);
    vm.startPrank(deployer);

    vm.expectEmit(true, true, true, false);
    emit Transfer(deployer, address(mockERC721Receiver), tokenId1);

    holographERC721.safeTransferFrom(deployer, address(mockERC721Receiver), tokenId1);

    /// should return mockERC721Receiver as owner of #1 SMPLR NFT
    assertEq(holographERC721.ownerOf(tokenId1), address(mockERC721Receiver));

    vm.expectEmit(true, true, true, false);
    emit Transfer(address(mockERC721Receiver), deployer, tokenId1);

    mockERC721Receiver.transferNFT(payable(address(holographERC721)), tokenId1, deployer);

    /// should return deployer as owner of #1 SMPLR NFT
    assertEq(holographERC721.ownerOf(tokenId1), deployer);
  }

  /**
   * @notice Verifies the successful transferFrom of the #1 SMPLR NFT
   * @dev This test mints the #1 SMPLR NFT to the deployer address, expects the Approval event to be emitted,
   * then approves the alice address to transfer the NFT using the deployer account, and verifies the approval.
   * It then expects the Transfer event to be emitted, and has the alice account transfer the NFT to the bob address,
   * verifying that bob is the new owner and the approval is removed.
   * Finally, it has the bob account transfer the NFT back to the deployer, expects the Transfer event to be emitted,
   * and verifies that the deployer is the new owner.
   * Refers to the hardhat test with the description 'approved should succeed transferring #'
   */
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

    /// should return bob as owner of #1 SMPLR NFT
    assertEq(holographERC721.ownerOf(tokenId1), bob);
    assertEq(holographERC721.getApproved(tokenId1), address(0));

    vm.expectEmit(true, true, true, false);
    emit Transfer(bob, deployer, tokenId1);

    vm.prank(bob);
    holographERC721.transfer(deployer, tokenId1);

    /// should return deployer as owner of #1 SMPLR NFT
    assertEq(holographERC721.ownerOf(tokenId1), deployer);
  }

  /**
   * @notice Verifies that an approved operator can successfully transfer multiple NFTs
   * @dev This test mints the #1 and #2 SMPLR NFTs to the deployer address, expects the ApprovalForAll
   * event to be emitted,then sets the alice address as an approved operator for the deployer using the
   * deployer account, and verifies the approval.
   * It then expects the Transfer event to be emitted twice, and has the alice account transfer the #1 a
   * nd #2 NFTs to the bob address, verifying that bob is the new owner.
   * Finally, it has the deployer account remove the approval for alice, expects the ApprovalForAll event
   * to be emitted, and then has the bob account transfer the #1 and #2 NFTs back to the deployer, verifying
   * that the deployer is the new owner.
   * Refers to the hardhat test with the description 'approved operator should succeed transferring #'
   */
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

    /// should return bob as owner of #1 and #2 SMPLR NFTs
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

    /// should return deployer as owner of #1 and #2 SMPLR NFTs
    assertEq(holographERC721.ownerOf(tokenId1), deployer);
    assertEq(holographERC721.ownerOf(tokenId2), deployer);
  }

  /* -------------------------------------------------------------------------- */
  /*                                  Burn NFTs                                 */
  /* -------------------------------------------------------------------------- */
  /**
   * @notice Verifies that burning a non-existent NFT reverts with the expected error message
   * @dev This test attempts to burn the #3 SMPLR NFT, which does not exist, and expects the
   * "ERC721: token does not exist" revert error.
   * Refers to the hardhat test with the description 'should fail burning non-existant #'
   */
  function testBurnNonExistent() public {
    vm.expectRevert(bytes(ErrorConstants.ERC721_TOKEN_NOT_EXISTS_ERROR_MSG));
    holographERC721.burn(tokenId3);
  }

  /**
   * @notice Verifies that burning an NFT that is not owned by the sender reverts with the expected error message
   * @dev This test mints the #1 SMPLR NFT to the alice address, then attempts to burn the NFT using the default sender,
   * and expects the "ERC721: not approved sender" revert error.
   * Refers to the hardhat test with the description 'should fail burning not owned #'
   */
  function testBurnNotOwned() public {
    _mint(alice, tokenId1, tokenURI1);

    vm.expectRevert(bytes(ErrorConstants.ERC721_NOT_APPROVED_SENDER_ERROR_MSG));
    holographERC721.burn(tokenId1);
  }

  /**
   * @notice Verifies the successful burning of an owned NFT
   * @dev This test mints the #1 SMPLR NFT to the deployer address, verifies that the NFT is not marked
   * as burned, then expects the Transfer event to be emitted, and has the deployer account burn the NFT.
   * It also verifies that the NFT is now marked as burned.
   * Refers to the hardhat test with the description 'should succeed burning owned #'
   */
  function testBurn() public {
    _mint(deployer, tokenId1, tokenURI1);
    assertEq(holographERC721.burned(tokenId1), false);

    vm.expectEmit(true, true, true, false);
    emit Transfer(deployer, address(0), tokenId1);

    vm.prank(deployer);
    holographERC721.burn(tokenId1);

    /// should mark as burned #1 SMPLR NFT
    assertTrue(holographERC721.burned(tokenId1));
  }

  /**
   * @notice Verifies the successful burning of an approved NFT
   * @dev This test mints the #1 SMPLR NFT to the deployer address, verifies that the NFT is not marked as burned,
   * then expects the Approval event to be emitted, and has the deployer account approve the alice address to transfer the NFT.
   * It then expects the Transfer event to be emitted, and has the alice account burn the NFT.
   * It also verifies that the NFT is now marked as burned.
   * Refers to the hardhat test with the description 'should succeed burning approved #'
   */
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

    /// should mark as burned #1 SMPLR NFT
    assertTrue(holographERC721.burned(tokenId1));
  }

  /**
   * @notice Verifies that an approved operator can successfully burn an NFT
   * @dev This test mints the #1 SMPLR NFT to the deployer address, verifies that the NFT is not marked as burned,
   * then expects the ApprovalForAll event to be emitted, and has the deployer account set the alice address as
   * an approved operator.
   * It then expects the Transfer event to be emitted, and has the alice account burn the NFT.
   * It also verifies that the NFT is now marked as burned, and that alice remains an approved operator.
   * Refers to the hardhat test with the description 'operator should succeed burning #'
   */
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

    /// should mark as burned #1 SMPLR NFT
    assertTrue(holographERC721.burned(tokenId1));
    assertEq(holographERC721.isApprovedForAll(deployer, alice), true);
  }

  /* -------------------------------------------------------------------------- */
  /*                                  Ownership                                 */
  /* -------------------------------------------------------------------------- */
  /**
   * @notice Verifies that the owner of the holographERC721 contract is the deployer address
   * @dev This test checks that the owner() function of the holographERC721 contract returns the deployer address.
   * Refers to the hardhat test with the description 'should return deployer address'
   */
  function testOwner() public {
    assertEq(holographERC721.owner(), deployer);
  }

  /**
   * @notice Verifies the isOwner functionality of the ERC721 contract
   * @dev This test checks that the deployer address returns true for the isOwner() function,
   * and that the alice address returns false for the isOwner() function.
   * Refers to the hardhat test with the description 'deployer should return true for isOwner'
   */
  function testIsOwner() public {
    vm.startPrank(deployer);
    assertTrue(sampleERC721.isOwner());
    assertTrue(SampleERC721(payable(address(holographERC721))).isOwner());
    vm.stopPrank();

    /// alice should return false for isOwner
    vm.prank(alice);
    assertFalse(sampleERC721.isOwner());
  }

  /**
   * @notice Verifies the getOwner function of the ERC721 contract
   * @dev This test checks that the getOwner() function of the holographERC721 contract returns
   * the holographFactoryProxyAddress.
   * Refers to the hardhat test with the description 'should return "HolographFactoryProxy" address
   */
  function testHolographer() public {
    assertEq(holographERC721.getOwner(), holographFactoryProxyAddress);
  }

  /**
   * @notice Verifies that the deployer cannot transfer ownership of the ERC721 contract
   * @dev This test attempts to transfer ownership of the holographERC721 contract from the deployer
   * to the alice address, and expects the "HOLOGRAPH: owner only function" revert error.
   * Refers to the hardhat test with the description 'deployer should fail transferring ownership'
   */
  function testTransferOwnership() public {
    vm.expectRevert(bytes(ErrorConstants.ONLY_OWNER_ERROR_MSG));
    holographERC721.setOwner(alice);
  }

  /**
   * @notice Verifies the successful transfer of ownership of the ERC721 contract
   * @dev This test first sets the owner of the holographERC721 contract to the deployer address, expects the
   *  OwnershipTransferred event to be emitted, and then verifies that the deployer is the new owner.
   * It then transfers the ownership of the holographERC721 contract to the holographFactoryProxyAddress,
   * expects the OwnershipTransferred event to be emitted again,
   * Refers to the hardhat tests with the description 'deployer should set owner to deployer' and
   * 'deployer should transfer ownership to "HolographFactoryProxy"'
   */
  function testSetOwner() public {
    bytes memory data = abi.encodeWithSelector(bytes4(keccak256("setOwner(address)")), deployer);
    vm.expectEmit(true, true, false, false);
    emit OwnershipTransferred(address(admin), address(deployer));
    vm.prank(deployer);
    admin.adminCall(address(holographERC721), data);
    assertEq(holographERC721.getOwner(), deployer);

    vm.expectEmit(true, true, false, false);
    emit OwnershipTransferred(address(deployer), holographFactoryProxyAddress);
    vm.prank(deployer);
    holographERC721.setOwner(holographFactoryProxyAddress);
    assertEq(holographERC721.getOwner(), holographFactoryProxyAddress);
  }

  /* -------------------------------------------------------------------------- */
  /*                                    Admin                                   */
  /* -------------------------------------------------------------------------- */
  /**
   * @notice Verifies that the admin of the ERC721 contract is the HolographFactoryProxy address
   * @dev This test checks that the admin() function of the holographERC721 contract returns
   * the holographFactoryProxy address.
   * Refers to the hardhat test with the description 'admin() should return "HolographFactoryProxy" address'
   */
  function testAdmin() public {
    assertEq(holographERC721.admin(), holographFactoryProxyAddress);
  }

  /**
   * @notice Verifies that the getAdmin function of the ERC721 contract returns the HolographFactoryProxy address
   * @dev This test checks that the getAdmin() function of the holographERC721 contract returns
   * the holographFactoryProxy address.
   * Refers to the hardhat test with the description 'getAdmin() should return "HolographFactoryProxy" address'
   */
  function testGetAdmin() public {
    assertEq(holographERC721.getAdmin(), holographFactoryProxyAddress);
  }

  /**
   * @notice Verifies that a non-admin wallet cannot set the admin of the ERC721 contract
   * @dev This test attempts to set the admin of the holographERC721 contract to the alice address using a
   * non-admin wallet, and expects the "HOLOGRAPH: admin only function" revert error.
   * Refers to the hardhat test with the description 'wallet1 should fail setting admin'
   */
  function testSetAdmin() public {
    vm.expectRevert(bytes(ErrorConstants.ONLY_ADMIN_ERROR_MSG));
    holographERC721.setAdmin(alice);
  }

  /**
   * @notice Verifies that the deployer can successfully set the admin of the ERC721 contract via the HolographFactoryProxy
   * @dev This test first sets the admin of the holographERC721 contract to the deployer address using
   * the admin.adminCall function, and verifies that the admin is now the deployer.
   * It then sets the admin back to the holographFactoryProxyAddress.
   * Refers to the hardhat test with the description 'deployer should succeed setting admin via "HolographFactoryProxy"'
   */
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
