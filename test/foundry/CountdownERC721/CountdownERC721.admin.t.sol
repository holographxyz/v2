// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {ICustomERC721Errors} from "test/foundry/interface/ICustomERC721Errors.sol";
import {CountdownERC721Fixture} from "test/foundry/fixtures/CountdownERC721Fixture.t.sol";

import {Vm} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

import {DEFAULT_MAX_SUPPLY, HOLOGRAPH_TREASURY_ADDRESS} from "test/foundry/CountdownERC721/utils/Constants.sol";

import {CountdownERC721} from "src/token/CountdownERC721.sol";
import {Strings} from "src/library/Strings.sol";
import {IHolographDropERC721V2} from "src/drops/interface/IHolographDropERC721V2.sol";
import {HolographERC721} from "src/enforcer/HolographERC721.sol";

contract CountdownERC721AdminTest is CountdownERC721Fixture, ICustomERC721Errors {
  using Strings for uint256;

  constructor() {}

  function setUp() public override {
    super.setUp();
  }

  function test_InitialOwner() public setupTestCountdownErc721(DEFAULT_MAX_SUPPLY) {
    assertEq(countdownErc721.owner(), DEFAULT_OWNER_ADDRESS);
    HolographERC721 enforcer = HolographERC721(payable(address(countdownErc721)));
    assertEq(enforcer.getOwner(), DEFAULT_OWNER_ADDRESS);
  }

  function test_SetOwner() public setupTestCountdownErc721(DEFAULT_MAX_SUPPLY) {
    assertEq(countdownErc721.owner(), DEFAULT_OWNER_ADDRESS);

    address newOwner = address(0x1234567890123456789012345678901234567890);
    HolographERC721 enforcer = HolographERC721(payable(address(countdownErc721)));
    vm.prank(DEFAULT_OWNER_ADDRESS);
    enforcer.setOwner(newOwner);

    assertEq(enforcer.getOwner(), newOwner);
    assertEq(countdownErc721.owner(), newOwner);
  }

  function test_CantSetOwnerIfNotOwner() public setupTestCountdownErc721(DEFAULT_MAX_SUPPLY) {
    assertEq(countdownErc721.owner(), DEFAULT_OWNER_ADDRESS);
    HolographERC721 enforcer = HolographERC721(payable(address(countdownErc721)));
    assertEq(enforcer.getOwner(), DEFAULT_OWNER_ADDRESS);

    address notOwnerAddress = address(uint160(DEFAULT_OWNER_ADDRESS) + 1);
    vm.prank(notOwnerAddress);
    vm.expectRevert(abi.encodeWithSelector(HOLOGRAPH_OnlyOwnerFunction.selector));
    enforcer.setOwner(address(0xfffff));

    assertEq(countdownErc721.owner(), DEFAULT_OWNER_ADDRESS);
    assertEq(enforcer.getOwner(), DEFAULT_OWNER_ADDRESS);
  }

  function test_Withdraw(uint128 amount) public setupTestCountdownErc721(DEFAULT_MAX_SUPPLY) {
    vm.assume(amount > 0.01 ether);
    vm.deal(address(countdownErc721), amount);
    vm.prank(DEFAULT_OWNER_ADDRESS);

    // withdrawnBy and withdrawnTo are indexed in the first two positions
    vm.expectEmit(true, true, false, false);
    uint256 leftoverFunds = amount - (amount * 1) / 20;
    emit FundsWithdrawn(DEFAULT_OWNER_ADDRESS, DEFAULT_FUNDS_RECIPIENT_ADDRESS, leftoverFunds);
    countdownErc721.withdraw();

    assertTrue(
      HOLOGRAPH_TREASURY_ADDRESS.balance < ((uint256(amount) * 1_000 * 5) / 100000) + 2 ||
        HOLOGRAPH_TREASURY_ADDRESS.balance > ((uint256(amount) * 1_000 * 5) / 100000) + 2
    );
    assertTrue(
      DEFAULT_FUNDS_RECIPIENT_ADDRESS.balance > ((uint256(amount) * 1_000 * 95) / 100000) - 2 ||
        DEFAULT_FUNDS_RECIPIENT_ADDRESS.balance < ((uint256(amount) * 1_000 * 95) / 100000) + 2
    );
  }

  function test_SetSalesConfiguration() public setupTestCountdownErc721(DEFAULT_MAX_SUPPLY) {
    vm.prank(DEFAULT_OWNER_ADDRESS);
    countdownErc721.setSaleConfiguration({publicSalePrice: mintEthPrice, maxSalePurchasePerAddress: 10});

    (uint104 publicSalePrice, uint24 maxSalePurchasePerAddress) = countdownErc721.salesConfig();
    assertEq(publicSalePrice, mintEthPrice);
    assertEq(maxSalePurchasePerAddress, 10);

    vm.startPrank(DEFAULT_OWNER_ADDRESS);
    countdownErc721.setSaleConfiguration({publicSalePrice: mintEthPrice * 2, maxSalePurchasePerAddress: 5});

    (publicSalePrice, maxSalePurchasePerAddress) = countdownErc721.salesConfig();
    assertEq(publicSalePrice, mintEthPrice * 2);
    assertEq(maxSalePurchasePerAddress, 5);
  }

  function test_WithdrawNotAllowed() public setupTestCountdownErc721(DEFAULT_MAX_SUPPLY) {
    vm.expectRevert(IHolographDropERC721V2.Access_WithdrawNotAllowed.selector);
    countdownErc721.withdraw();
  }
}
