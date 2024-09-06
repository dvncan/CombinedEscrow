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
pragma solidity >=0.8.24;

// OZ-Contracts
import {IERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuard} from "../lib/openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import {SafeERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

// Custom/Modified
import {RefundEscrow} from "./oz-escrow/RefundEscrow.sol";
import {TypeValidation} from "./utils/TypeValidation.sol";
import {SelfDestruct} from "./SelfDestruct.sol";
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
 *              1. escrow.enableRefund(); // active -> refund // onlyOwner
 *              2. escrow.withdraw(user);
 *              3. escrow.beneficiaryWithdrawRefund() // last step
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
contract CombinedEscrow is
    SelfDestruct,
    RefundEscrow,
    ReentrancyGuard,
    TypeValidation
{
    using SafeERC20 for IERC20;

    mapping(address => mapping(address => uint256)) public userErc20Balances; // token => user => amount
    uint256 public totalErcBalance;
    IERC20 private immutable _saleToken; // token address is immutable
    address payable private immutable _vault; // vault [takes a 5% fee currently] TODO:

    uint8 private immutable _fee_numerator = 5;
    uint8 private immutable _fee_denominator = 100;

    // Events
    event NewEscrowCreated(
        address indexed beneficiary,
        address indexed saleToken
    );
    // event Deposited(address indexed payee, uint256 weiAmount);
    // event Withdrawn(address indexed payee, uint256 weiAmount);
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

    receive() external payable {
        deposit(msg.sender);
    }

    // The owner of the reundescrow contract will be this contract which holds the eth. combined can execute transactions on refund but only through bonsai proxy.
    constructor(
        address payable __vault,
        address payable projectTreasury,
        address __saleToken
    ) RefundEscrow(projectTreasury) {
        _vault = __vault;
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
        // checkNumberForType(int256(msg.value));
        validateAddressStrict(refundee);
        validateAmountStrictPositive(msg.value);
        //check overflow for total balance
        validateNewBalanceOverflow(ethBalance(), msg.value);
        //check overflow for individual balance
        validateNewBalanceOverflow(super.depositsOf(refundee), msg.value);
        super.deposit(refundee);
    }

    /**
     * @dev this is allowed only if escrow is refunding.
     */ function withdraw(
        address payable payee
    )
        public
        virtual
        override
        nonReentrant
        contractNotDestroyed
        onlyWhen(state(), State.Refunding)
    {
        uint256 deposits = super.depositsOf(payee);
        validateAmountStrictPositive(deposits);
        validateAddress(payee);
        validateNewBalanceUnderflow(ethBalance(), deposits);

        super.withdraw(payee);

        if (super.depositsOf(payee) != 0) revert BalanceTransferError();
        if (ethBalance() == 0) _burnAfterReading();
        emit Withdrawn(payee, deposits);
    }
    // @dev verify fee before transfer
    function verifyAmountsBeforeTransfer(
        uint256 amountToSend,
        uint256 balance,
        uint256 fee
    ) internal returns (bool) {
        checkNumberForType(int256(amountToSend));
        if (balance <= 0) revert InsufficientBalance();
        if (amountToSend <= 0) revert BalanceTransferError();
        if (amountToSend + fee != balance) revert BalanceTransferError();
        validateNewBalanceUnderflow(amountToSend, balance);
        return true;
    }

    /**
     * @dev Withdraws the beneficiary's funds after the sale has concluded successfully.
     */
    function beneficiaryWithdraw()
        public
        override
        onlyOwner
        nonReentrant
        contractNotDestroyed
        onlyWhen(state(), State.Closed)
    {
        bool sent = false;
        uint256 balanceB4Transfer = address(this).balance;
        uint256 fee = (balanceB4Transfer * _fee_numerator) / _fee_denominator;
        uint256 amountToSend = balanceB4Transfer - fee;

        if (!verifyAmountsBeforeTransfer(amountToSend, balanceB4Transfer, fee))
            revert AdminError();

        // send 95% to beneficiary
        (sent, ) = beneficiary().call{value: amountToSend}("");
        // beneficiary transfer failure
        if (!sent) revert BalanceTransferError();

        // take 5% fee
        (sent, ) = _vault.call{value: fee}("");
        // fee transfer failure
        if (!sent) revert BalanceTransferError();

        // balance == 0
        if (address(this).balance != 0) revert BalanceTransferError();
        emit BeneficiaryWithdrawal(amountToSend, fee);
    }

    function beneficiaryWithdrawRefund()
        public
        onlyOwner
        nonReentrant
        contractNotDestroyed
        onlyWhen(state(), State.Refunding)
    {
        if (!verifyAmountsBeforeTransfer(totalErcBalance, totalErcBalance, 0))
            revert AdminError();

        uint256 amountToSend = totalErcBalance;
        totalErcBalance = 0;
        _saleToken.safeTransfer(address(beneficiary()), amountToSend);
        // check that funds were received

        if (IERC20(_saleToken).balanceOf(beneficiary()) < amountToSend)
            revert BalanceTransferError();
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
        if (_saleToken.balanceOf(msg.sender) == 0) revert InsufficientBalance();
        if (state() != State.Active) revert EscrowStateError();
        require(amount > 0, "Amount must be greater than 0");
        _saleToken.safeTransferFrom(router, address(this), amount);
        userErc20Balances[address(_saleToken)][payee] += amount;
        totalErcBalance += amount;
        emit Deposited(payee, amount);
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
        if (totalErcBalance == 0) _burnAfterReading();
    }

    function saleToken() public view returns (address) {
        return address(_saleToken);
    }

    function vault() public view returns (address) {
        return _vault;
    }

    // Get ETH Balance
    function ethBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function getUserEthBalance(
        address saleParticipant
    ) public view returns (uint256) {
        return super.depositsOf(saleParticipant);
    }

    function erc20Balance() public view returns (uint256) {
        return totalErcBalance;
    }

    // Get ERC20 Balance
    function getERC20Balance(address user) public view returns (uint256) {
        return userErc20Balances[address(_saleToken)][user];
    }
}
