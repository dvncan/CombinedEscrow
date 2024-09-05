// pragma solidity ^0.8.24;

// import {CombinedEscrow} from "src/CombinedEscrow.sol";
// import {IERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
// import {SafeERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
// contract TokenSale is CombinedEscrow {
//     using SafeERC20 for IERC20;
//     // receive() external payable override {
//     //     // deposit(msg.sender);
//     // }

//     constructor(
//         address payable __vault,
//         address payable projectTreasury,
//         address __saleToken
//     ) CombinedEscrow(__vault, projectTreasury, __saleToken) {}

//     /**
//      * @dev Withdraws ERC20 tokens from the escrow.
//      * @param payee Address of the recipient.
//      */
//     function withdrawERC20(
//         address payee
//     ) public override nonReentrant onlyOwner contractNotDestroyed {
//         if (state() != State.Active) revert EscrowStateError();
//         uint256 amount = userErc20Balances[address(_saleToken)][payee]; // pricing function
//         if (amount <= 0) revert InsufficientBalance();
//         userErc20Balances[address(_saleToken)][payee] = 0;
//         _saleToken.safeTransfer(payee, amount);
//         totalErcBalance -= amount;
//         emit Withdrawal(payee, amount);
//         if (totalErcBalance == 0) _burnAfterReading();
//     }

//     function sellToken(address user, uint256 amount) external payable {
//         // deposit{value: amount}(user);
//         // withdrawERC20(user);
//     }
// }
