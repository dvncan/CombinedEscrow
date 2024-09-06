//SP
pragma solidity ^0.8.24;

import {BaseCombinedEscrowTest} from "test/BaseCombinedEscrow.t.sol";
import {EscrowFunctions} from "test/utils/EscrowFunctions.t.sol";
import {Escrow} from "src/oz-escrow/Escrow.sol";
import {TypeValidation} from "test/utils/TypeValidation.t.sol";
contract AdvancedCombinedEscrowTests is
    BaseCombinedEscrowTest,
    EscrowFunctions,
    TypeValidation
{
    /********************************************************************************
     *                                                                              *
     *           Test ERC20 deposit and withdrawal                                  *
     *           █████████████████████████████████                                  *
     *           █   1. Close the escrow                                            *
     *           █   2. Deposit ERC20 tokens                                        *
     *           █   3. Withdraw ERC20 tokens                                       *
     *           █   4. Assert correct balances                                     *
     *           █████████████████████████████████                                  *
     *                                                                              *
     ********************************************************************************/

    function testFail_depositErc_escrowClosed() public {
        vm.deal(user, 1 ether);
        user_close_escrow(escrow, _owner);
        vm.prank(user);
        vm.expectRevert("EscrowStateError()");
        escrow.deposit{value: 1 ether}(user);
    }
    function test_multipleDeposits_singleWithdraw_steal() public {
        // Test multiple deposits from different users and single withdrawal
        // 1. Deposit from user1
        // 2. Deposit from user2
        // 3. Refund the escrow
        // 4. Withdraw all funds to a single address
        // 5. Assert correct balances
        vm.deal(user, 1 ether);
        (address alice, uint256 alicePk) = makeAddrAndKey("alice");
        vm.deal(alice, 1 ether);
        user_deposit_escrow_good(escrow, user, 1 ether);
        assertEq(user.balance, 0, "fail");
        user_deposit_escrow_good(escrow, alice, 1 ether);
        assertEq(alice.balance, 0, "fail");

        user_refund_escrow(escrow, _owner);

        escrow.withdraw(payable(user));
        vm.expectRevert(InputValidationError.selector);
        escrow.withdraw(payable(user));
    }

    function test_multipleDeposits_singleWithdraw() public {
        // Test multiple deposits from different users and single withdrawal
        // 1. Deposit from user1
        // 2. Deposit from user2
        // 3. Refund the escrow
        // 4. Withdraw all funds to a single address
        // 5. Assert correct balances
        vm.deal(user, 1 ether);
        // (address alice, uint256 alicePk) = makeAddrAndKey("alice");
        // vm.deal(alice, 1 ether);
        user_deposit_escrow_good(escrow, user, 0.5 ether);
        assertEq(user.balance, 0.5 ether, "fail");
        user_deposit_escrow_good(escrow, user, 0.5 ether);
        assertEq(user.balance, 0, "fail");

        user_refund_escrow(escrow, _owner);

        vm.expectEmit();
        emit Escrow.Withdrawn(user, 1 ether);
        escrow.withdraw(payable(user));
        assertEq(escrow.ethBalance(), 0, "ethBalance - Fail");
        assertEq(user.balance, 1 ether, "user.balance - Fail");
    }

    function test_multipleDeposits_singleWithdraw_project() public {
        // Test multiple deposits from different users and single withdrawal
        // 1. Deposit from user1
        // 2. Deposit from user1
        // 3. Refund the escrow
        // 4. user2 attempts to steal user1
        // 5. Withdraw all funds to a single address < attempt to steal >
        // 6. Assert correct balances
    }
}
