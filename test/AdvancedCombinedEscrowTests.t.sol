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

    /********************************************************************************
     *                                                                              *
     *           Test multiple deposits from different users and single withdrawal  *
     *           █████████████████████████████████████████████████████████████████  *
     *           █   1. Deposit from user1                                          *
     *           █   2. Deposit from user2                                          *
     *           █   3. Refund the escrow                                           *
     *           █   4. Withdraw twice to a single address                          *
     *           █   5. Assert correct balances                                     *
     *           █████████████████████████████████                                  *
     *                                                                              *
     ********************************************************************************/

    function test_multipleDeposits_singleWithdraw_steal() public {
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
        assertEq(user.balance, 1 ether, "Fail");
        assertEq(alice.balance, 0, "Fail");
    }

    /********************************************************************************
     *                                                                              *
     *           Test multiple deposits from different users and single withdrawal  *
     *           █████████████████████████████████████████████████████████████████  *
     *           █   1. Deposit from user1                                          *
     *           █   2. Deposit from user2                                          *
     *           █   3. Refund the escrow                                           *
     *           █   4. Withdraw all funds to a single address                      *
     *           █   5. Assert correct balances                                     *
     *           █████████████████████████████████                                  *
     *                                                                              *
     ********************************************************************************/

    function test_multipleDeposits_singleWithdraw() public {
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

    /********************************************************************************
     *                                                                              *
     *           Test multiple deposits from different users and single withdrawal  *
     *           █████████████████████████████████████████████████████████████████  *
     *           █   1. Deposit from user1                                          *
     *           █   2. Deposit from user1                                          *
     *           █   3. Refund the escrow                                           *
     *           █   4. Withdraw all funds to a single address                      *
     *           █   5. Assert correct balances                                     *
     *           █████████████████████████████████                                  *
     *                                                                              *
     ********************************************************************************/

    function test_multipleDeposits_singleWithdraw_project() public {
        // 1. Deposit from user1
        // 2. Deposit from user1
        // 3. Refund the escrow
        // 4.
        // 5. Withdraw all funds to a single address < attempt to steal >
        // 6. Assert correct balances
    }

    function testReentrancyProtectionStrict() public {
        // Create a malicious contract that tries to re-enter the withdraw function
        MaliciousContract maliciousContract = new MaliciousContract(
            address(escrow)
        );

        // Additional test logic
        (address ai, uint256 aiPk) = makeAddrAndKey("ai");
        vm.prank(ai);
        vm.deal(ai, 1 ether);
        maliciousContract.deposit{value: 1 ether}();
        // escrow.deposit{value: 1 ether}(ai);

        // Deposit funds
        uint256 depositAmount = 1 ether;
        vm.deal(address(maliciousContract), depositAmount);
        vm.prank(address(maliciousContract));
        maliciousContract.deposit{value: depositAmount}();

        // Refund the escrow
        user_refund_escrow(escrow, _owner);

        // Attempt to withdraw using the malicious contract
        // vm.expectRevert("revert: ReentrancyGuard: reentrant call");
        vm.expectRevert(); // "revert: ReentrancyGuard: reentrant call"
        vm.prank(address(maliciousContract));
        escrow.withdraw(payable(address(maliciousContract)));

        // Assert that the reentrancy attack failed
        assertEq(
            address(escrow).balance,
            2 * depositAmount,
            "Escrow balance should remain unchanged"
        );
        assertEq(
            address(maliciousContract).balance,
            0,
            "Malicious contract should not receive funds"
        );
    }
    function testReentrancyProtection() public {
        // Create a malicious contract that tries to re-enter the withdraw function
        MaliciousContract maliciousContract = new MaliciousContract(
            address(escrow)
        );

        // Additional test logic
        // (address ai, uint256 aiPk) = makeAddrAndKey("ai");
        // vm.prank(ai);
        // vm.deal(ai, 1 ether);
        // // maliciousContract.deposit{value: 1 ether}();
        // escrow.deposit{value: 1 ether}(ai);

        // Deposit funds
        uint256 depositAmount = 1 ether;
        vm.deal(address(maliciousContract), depositAmount);
        vm.prank(address(maliciousContract));
        maliciousContract.deposit{value: depositAmount}();

        // Refund the escrow
        user_refund_escrow(escrow, _owner);

        // Attempt to withdraw using the malicious contract
        // vm.expectRevert("revert: ReentrancyGuard: reentrant call");
        vm.expectRevert(); // "revert: ReentrancyGuard: reentrant call"
        vm.prank(address(maliciousContract));
        escrow.withdraw(payable(address(maliciousContract)));

        // Assert that the reentrancy attack failed
        assertEq(
            address(escrow).balance,
            depositAmount,
            "Escrow balance should remain unchanged"
        );
        assertEq(
            address(maliciousContract).balance,
            0,
            "Malicious contract should not receive funds"
        );
    }
}
import {CombinedEscrow} from "../src/CombinedEscrow.sol";

// Malicious contract for testing reentrancy
contract MaliciousContract {
    CombinedEscrow private immutable escrow;
    uint256 private constant ATTACK_COUNT = 3;
    uint256 private attackCounter;

    constructor(address _escrow) {
        escrow = CombinedEscrow(payable(_escrow));
    }

    function deposit() external payable {
        escrow.deposit{value: msg.value}(address(this));
    }

    receive() external payable {
        if (attackCounter < ATTACK_COUNT) {
            attackCounter++;
            escrow.withdraw(payable(address(this)));
        }
    }
}
