// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {Vm} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

import {ICustomERC721Errors} from "test/foundry/interface/ICustomERC721Errors.sol";
import {HolographERC721Fixture} from "test/foundry/fixtures/HolographERC721Fixture.t.sol";

contract HolographERC721InitPayloadTest is HolographERC721Fixture, ICustomERC721Errors {
  constructor() {}

  function setUp() public override {
    super.setUp();
  }

  function test_CountdownERC721InitPayload() public {
    console.log(usedInitPayload.length);

    (bool success, bytes memory initPayload) = address(countdownErc721).call(abi.encodeWithSignature("getInitProperties()"));

    assertEq(success, true, "getInitProperties() call should succeed");
    assertEq(initPayload, usedInitPayload, "initPayload should match usedInitPayload");
  }
}
