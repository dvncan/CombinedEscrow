/********************************************************************************
 *                                                                              *
 *           █████████████████████████████                                  *
 *           █                                                              █   *
 *           █          AUTHOR: dvncan.eth                                  █   *
 *           █          DATE:   03/09/2024                                  █   *
 *           █          PROJECT: CombinedEscrow.sol                         █   *
 *           █          VERSION: 2.0                                        █   *
 *           █                                                              █   *
 *           █████████████████████████████████                                  *
 *                                                                              *
 ********************************************************************************/

// SPDX-License-Identifier: BONSAI3
pragma solidity >=0.8.19;

import {SelfDestruct} from "./SelfDestruct.sol";
import {IERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuard} from "../lib/openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import {RefundEscrow} from "./RefundEscrow.sol";
import {SafeERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

/***********************************************************************************
 *                                                                                 *
 *           █████████████████████████████████████████████████████████████████    *
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
contract CombinedEscrow is SelfDestruct, RefundEscrow, ReentrancyGuard {
    using SafeERC20 for IERC20;

    mapping(address => mapping(address => uint256)) public userErc20Balances; // token => user => amount
    uint256 public totalErcBalance;
    IERC20 public immutable _saleToken; // token address is immutable
    address payable private immutable vault; // vault [takes a 5% fee currently] TODO:

    uint8 immutable fee_numerator = 5;
    uint8 immutable fee_denominator = 100;

    // Events
    event NewEscrowCreated(
        address indexed beneficiary,
        address indexed saleToken
    );
    event Deposit(address indexed payee, uint256 weiAmount);
    event Withdrawal(address indexed payee, uint256 weiAmount);
    event BeneficiaryWithdrawal(uint256 amount, uint256 fee);
    // Errors
    error InsufficientBalance();
    error EscrowStateError();
    error AdminError();
    error BalanceTransferError();

    modifier onlyWhen(State internalState, State state) {
        if (internalState != state) revert EscrowStateError();
        _;
    }

    // The owner of the reundescrow contract will be this contract which holds the eth. combined can execute transactions on refund but only through bonsai proxy.
    constructor(
        address payable __vault,
        address payable projectTreasury,
        address __saleToken
    ) RefundEscrow(projectTreasury) {
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
    )
        public
        payable
        override
        nonReentrant
        contractNotDestroyed
        onlyWhen(state(), State.Active)
    {
        if (msg.value <= 0) revert InsufficientBalance();
        super.deposit(refundee);
        emit Deposit(refundee, msg.value);
    }

    /**
     * @dev this is allowed only if escrow is refunding.
     */
    function withdraw(
        address payable payee
    )
        public
        virtual
        override
        nonReentrant
        contractNotDestroyed
        onlyWhen(state(), State.Refunding)
    {
        if (super.depositsOf(payee) <= 0) revert InsufficientBalance();
        require(
            withdrawalAllowed(payee),
            "ConditionalEscrow: payee is not allowed to withdraw"
        );
        super.withdraw(payee);
        if (getTotalEthBalance() == 0) _burnAfterReading();
        emit Withdrawal(payee, super.depositsOf(payee));
    }

    // @dev verify fee before transfer
    function verifyAmountsBeforeTransfer(
        uint256 amountToSend,
        uint256 balance,
        uint256 fee
    ) internal pure returns (bool) {
        if (balance <= 0) revert InsufficientBalance();
        if (amountToSend <= 0 || amountToSend >= balance)
            revert BalanceTransferError();
        if (amountToSend + fee != balance) revert BalanceTransferError();
        return true;
    }

    /**
     * @dev Withdraws the beneficiary's funds after the sale has concluded successfully.
     */
    function beneficiaryWithdraw()
        public
        override
        nonReentrant
        contractNotDestroyed
        onlyWhen(state(), State.Closed)
    {
        bool sent = false;
        uint256 balanceB4Transfer = address(this).balance;
        uint256 fee = (balanceB4Transfer * fee_numerator) / fee_denominator;
        uint256 amountToSend = balanceB4Transfer - fee;

        if (!verifyAmountsBeforeTransfer(amountToSend, balanceB4Transfer, fee))
            revert AdminError();

        // send 95% to beneficiary
        (sent, ) = beneficiary().call{value: amountToSend}("");

        if (!sent) revert BalanceTransferError();
        // take 5% fee
        (sent, ) = vault.call{value: fee}("");

        if (!sent) revert BalanceTransferError();

        if (address(this).balance != 0) revert BalanceTransferError();
        emit BeneficiaryWithdrawal(amountToSend, fee);
    }

    receive() external payable {
        deposit(msg.sender);
    }

    function beneficiaryWithdrawRefund()
        public
        nonReentrant
        contractNotDestroyed
        onlyWhen(state(), State.Refunding)
    {
        if (!verifyAmountsBeforeTransfer(totalErcBalance, totalErcBalance, 0))
            revert AdminError();

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
     * @param router Address holding the tokens.
     * @param payee Address of the user.
     */
    function depositERC20(
        uint256 amount,
        address router,
        address payee
    ) public nonReentrant contractNotDestroyed {
        if (state() != State.Active) revert EscrowStateError();
        require(amount > 0, "Amount must be greater than 0");
        _saleToken.safeTransferFrom(router, address(this), amount);
        userErc20Balances[address(_saleToken)][payee] += amount;
        totalErcBalance += amount;
        emit Deposit(payee, amount);
    }

    /**pret
     * @dev Withdraws ERC20 tokens from the escrow.
     * @param payee Address of the recipient.
     */
    function withdrawERC20(
        address payee
    ) public virtual nonReentrant contractNotDestroyed {
        if (state() != State.Closed) revert EscrowStateError();
        uint256 amount = userErc20Balances[address(_saleToken)][payee];
        if (amount <= 0) revert InsufficientBalance();
        userErc20Balances[address(_saleToken)][payee] = 0;
        totalErcBalance -= amount;
        _saleToken.safeTransfer(payee, amount);
        emit Withdrawal(payee, amount);
        if (totalErcBalance == 0) _burnAfterReading();
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
