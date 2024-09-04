/********************************************************************************
 *                                                                              *
 *           █████████████████████████████████                                  *
 *           █                                                              █   *
 *           █          AUTHOR: dvncan.eth                                  █   *
 *           █          DATE:   03/09/2024                                  █   *
 *           █          PROJECT: CombinedEscrow.sol                         █   *
 *           █          VERSION: 2.0                                        █   *
 *           █                                                              █   *
 *           █████████████████████████████████                                  *
 *                                                                              *
 ********************************************************************************/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "../lib/openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import {RefundEscrow} from "../lib/openzeppelin-contracts/contracts/utils/escrow/RefundEscrow.sol";
import "./SelfDestruct.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

/***********************************************************************************
 *                                                                                 *
 *           ██████████████████████████████████████████████████████████████████    *
 *           █                                                           █         *
 *           █   @dev: CombinedEscrow uses RefundEscrow                  █         *
 *           █         for States & state change logic                   █         *
 *           █                                                           █         *
 *           █   @dev: CombinedEscrow uses Escrow                        █         *
 *           █         for deposit & withdraw                            █         *
 *           █         & internal mapping                                █         *
 *           █                                                           █         *
 *           █           enum State {                                    █         *
 *           █                     Active,                               █         *
 *           █                     Refunding,                            █         *
 *           █                     Closed                                █         *
 *           █                    }:                                     █         *
 *           █                                                           █         *
 *           █    active -> refund or closed                             █         *
 *           █    refund -> user claim eth & erc returned to beneficiary █         *
 *           █    closed -> user claim erc & eth sent to beneficiary     █         *
 *           █                                                           █         *
 *           ██████████████████████████████████████████████████████████████████    *
 *
 *
 *
 *  @notice: steps to refund are
 *              1. escrow.enableRefund(); // active -> refund
 *              2. escrow.withdrawAfterRefund();
 *              3. escrow.
 *
 ***********************************************************************************/

/**
 * @title CombinedEscrow.sol
 * @author dvncan.eth
 * @notice A contract that securely manages deposit of ETH and ERC20, providing mechanisms-
 *         for conditional changing state allowing for withdrawing, or refunding of escrow.
 * @notice Contract is single use plastic.
 * @notice Contract can be used with ERC20 & ERC404
 * @dev    Funds can only be withdrawn if escrow.closed();
 */
contract CombinedEscrow is ReentrancyGuard, RefundEscrow, Destroy {
    using SafeERC20 for IERC20;

    mapping(address => mapping(address => uint256)) public userErc20Balances; // token => user => amount
    uint256 public totalErcBalance;
    IERC20 public immutable _saleToken; // token address is immutable
    address payable private immutable vault; // vault [takes a 5% fee currently] TODO:

    uint8 immutable fee_numerator = 5;
    uint8 immutable fee_denominator = 100;

    /*********************************************************************************
     *                                                                               *
     *                           █████████████████████████████████                   *
     *                           █                                                   *
     *                           █   abstract contract Destroy {                     *
     *                           █     enum SelfDestruct {                           *
     *                           █           Inactive,                               *
     *                           █           Active                                  *
     *                           █     }                                             *
     *                           █     function burnAfterReading() internal virtual; *
     *                           █     event Burned(SelfDestruct state);             *
     *                           █   }                                               *
     *                           █                                                   *
     *                           █████████████████████████████████                   *
     *                                                                               *
     *********************************************************************************/

    //@dev _current can only be flipped when contract is closed
    SelfDestruct private _current;

    error EscrowStateError();
    error InsufficientBalance();
    error BalanceTransferError();

    event NewEscrowCreated(address beneficiary, address saleToken);
    event Deposit(address payee, uint256 weiAmount);
    event Withdrawal(address payee, uint256 weiAmount);

    modifier contractNotDestroyed() {
        require(
            _current == SelfDestruct.Inactive,
            "CombinedEscrow: Contract has been destroyed"
        );
        _;
    }

    // The owner of the reundescrow contract will be this contract which holds the eth. combined can execute transactions on refund but only through bonsai proxy.
    constructor(
        address payable __vault,
        address payable projectTreasury,
        address __saleToken
    ) RefundEscrow(projectTreasury) Ownable() {
        vault = __vault;
        _saleToken = IERC20(__saleToken);
        emit NewEscrowCreated(projectTreasury, __saleToken);
    }

    /***
     * @dev deposit does param validation and then calls super.deposit
     * @param refundee is the user address to credit the deposit
     * @return <void> @event Deposit
     *
     **/
    function deposit(
        address refundee
    ) public payable override nonReentrant onlyOwner contractNotDestroyed {
        if (msg.value <= 0) revert InsufficientBalance();
        if (state() != State.Active) revert EscrowStateError();
        super.deposit(refundee);
        emit Deposit(refundee, msg.value);
    }

    /**
     * @dev this is allowed if escrow is refunding.
     */
    function withdraw(
        address payable payee
    ) public virtual override nonReentrant onlyOwner contractNotDestroyed {
        if (super.depositsOf(payee) <= 0) revert InsufficientBalance();
        require(
            withdrawalAllowed(payee),
            "ConditionalEscrow: payee is not allowed to withdraw"
        );
        super.withdraw(payee);
        if (getTotalEthBalance() == 0) burnAfterReading();
        emit Withdrawal(payee, super.depositsOf(payee));
    }

    /**
     * @dev Withdraws the beneficiary's funds after the sale has concluded successfully.
     */
    function beneficiaryWithdraw()
        public
        override
        nonReentrant
        onlyOwner
        contractNotDestroyed
    {
        if (state() != State.Closed) revert EscrowStateError();
        (bool sent, ) = beneficiary().call{
            value: ((address(this).balance) * (1 - fee_numerator)) /
                fee_denominator
        }("");
        if (!sent) revert BalanceTransferError();
        (sent, ) = vault.call{value: (address(this).balance)}("");
        if (!sent) revert BalanceTransferError();
        if (address(this).balance != 0) revert BalanceTransferError();
    }

    receive() external payable {
        deposit(msg.sender);
    }

    function withdrawAfterRefund()
        public
        nonReentrant
        onlyOwner
        contractNotDestroyed
    {
        if ((state() != State.Refunding) && (state() != State.Closed))
            revert EscrowStateError();
        _saleToken.safeTransfer(address(beneficiary()), totalErcBalance);
        require(
            IERC20(_saleToken).balanceOf(beneficiary()) >= totalErcBalance,
            "withdrawAfterRefund Balance Failure"
        );
        totalErcBalance = 0;
    }

    /**
     * @dev Deposits ERC20 tokens into the escrow.
     * @param amount Amount of tokens to deposit.
     * @param bonsaiHoldings Address holding the tokens.
     * @param payee Address of the user.
     */
    function depositERC20(
        uint256 amount,
        address bonsaiHoldings,
        address payee
    ) external nonReentrant onlyOwner contractNotDestroyed {
        if (state() != State.Active) revert EscrowStateError();
        require(amount > 0, "Amount must be greater than 0");
        _saleToken.safeTransferFrom(bonsaiHoldings, address(this), amount);
        userErc20Balances[address(_saleToken)][payee] += amount;
        totalErcBalance += amount;
        emit Deposit(payee, amount);
    }

    /**
     * @dev Withdraws ERC20 tokens from the escrow.
     * @param payee Address of the recipient.
     * @return amount The amount withdrawn.
     */
    function withdrawERC20(
        address payee
    ) external nonReentrant onlyOwner contractNotDestroyed returns (uint256) {
        if (state() != State.Closed) revert EscrowStateError();
        uint256 amount = userErc20Balances[address(_saleToken)][payee];
        if (amount <= 0) revert InsufficientBalance();
        userErc20Balances[address(_saleToken)][payee] = 0;
        _saleToken.safeTransfer(payee, amount);
        totalErcBalance -= amount;
        emit Withdrawal(payee, amount);
        if (totalErcBalance == 0) burnAfterReading();
        return amount;
    }

    // Internal functions to manage contract destruction when do i call this?
    function burnAfterReading() internal virtual override {
        _current = SelfDestruct.Active;
        emit Burned(_current);
    }

    // Get ETH Balance
    function getTotalEthBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function getUserEthBalance(
        address saleParticipant
    ) public view returns (uint256) {
        return super.depositsOf(saleParticipant);
    }

    function getTotalERCBalance() public view returns (uint256) {
        return totalErcBalance;
    }

    // Get ERC20 Balance
    function getERC20Balance(address user) public view returns (uint256) {
        return userErc20Balances[address(_saleToken)][user];
    }

    function getEthEscrowBalance() public view returns (uint256) {
        return address(this).balance;
    }
}
