// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "../lib/forge-std/src/Test.sol";
import "../src/CombinedEscrow.sol";
import {SimpletToken} from "./utils/SimpleToken.sol";

contract BaseCombinedEscrowTest is Test {
    CombinedEscrow public escrow;
    address private _owner;
    address private _beneficiary;
    address payable private _vault;

    SimpletToken private _tok;

    function setUp() public {
        _owner = address(0xFF);
        _beneficiary = payable(address(0x1));
        _vault = payable(address(0x3));

        vm.startPrank(_owner);

        // Create & mint test tokens
        _tok = new SimpletToken();

        // Create Combined Escrow for test token & ether
        // @dev vault is for the fee payout
        escrow = new CombinedEscrow(
            _vault,
            payable(_beneficiary),
            address(_tok)
        );
        vm.stopPrank();
    }

    function beforeStateClose() public {
        vm.startPrank(_owner);
        escrow.close();
        vm.stopPrank();
    }

    function testStateClose() public {
        beforeStateClose();
        assertEq(
            escrow.state() == RefundEscrow.State.Closed,
            true,
            "State issue"
        );
    }

    function beforeStateRefund() public {
        vm.startPrank(_owner);
        escrow.enableRefunds();
        vm.stopPrank();
    }

    function testStateRefund() public {
        beforeStateRefund();
        assertEq(
            escrow.state() == RefundEscrow.State.Refunding,
            true,
            "State issue"
        );
    }
}
