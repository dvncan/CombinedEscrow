// function beforeStateClose() public {
//     vm.startPrank(_owner);
//     escrow.close();
//     vm.stopPrank();
// }

// function testStateClose() public {
//     beforeStateClose();
//     assertEq(
//         escrow.state() == RefundEscrow.State.Closed,
//         true,
//         "State issue"
//     );
// }

// function beforeStateRefund() public {
//     vm.startPrank(_owner);
//     escrow.enableRefunds();
//     vm.stopPrank();
// }

// function testStateRefund() public {
//     beforeStateRefund();
//     assertEq(
//         escrow.state() == RefundEscrow.State.Refunding,
//         true,
//         "State issue"
//     );
// }

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {CombinedEscrow, RefundEscrow} from "../src/CombinedEscrow.sol";
import {SimpleToken, ERC20} from "../src/utils/SimpleToken.sol";

//TEST IMPORTS
import {Test, console} from "../lib/forge-std/src/Test.sol";
import {BaseCombinedEscrowTest} from "./BaseCombinedEscrow.t.sol";
import {EscrowFunctions} from "./utils/EscrowFunctions.t.sol";

contract StateCombinedEscrowTest is BaseCombinedEscrowTest, EscrowFunctions {
    function test_stateClose() public {
        user_close_escrow(escrow, _owner);
        assertEq(
            escrow.state() == RefundEscrow.State.Closed,
            true,
            "State issue"
        );
    }

    function test_stateRefund() public {
        user_refund_escrow(escrow, _owner);
        assertEq(
            escrow.state() == RefundEscrow.State.Refunding,
            true,
            "State issue"
        );
    }

    function test_depositAfterClose() public {
        // Test that deposits are not allowed after escrow is closed
        // 1. Close the escrow
        // 2. Attempt to deposit (should revert)
        // 3. Assert that the deposit failed
        vm.deal(user, 1 ether);
        user_close_escrow(escrow, _owner);
        assertEq(escrow.state() == RefundEscrow.State.Closed, true, "Fail");
        user_deposit_escrow_revert(escrow, user, 1 ether);
    }

    function test_withdrawBeforeRefund() public {
        // Test that withdrawal is not allowed before refund
        // 1. Deposit funds
        // 2. Attempt to withdraw (should revert)
        // 3. Assert that the withdrawal failed
    }
}
