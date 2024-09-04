# CombinedEscrow.sol

**CombinedEscrow** is a Solidity smart contract that facilitates both ETH and ERC20 token escrow services with support for refund mechanisms, withdrawals, and automated destruction after contract use. It integrates OpenZeppelin’s `RefundEscrow`, ensures secure handling of assets, and provides both ETH and token management within a single contract.

## Features:
- ETH and ERC20 token escrow support.
- Refund mechanism in case of unmet conditions (e.g., soft cap failure).
- Secure deposit and withdrawal functionalities for both ETH and ERC20 tokens.
- Implements `burnAfterReading()` to self-destruct after successful withdrawal.
- Integrated with OpenZeppelin's `ReentrancyGuard` for added security.
- Suitable for token sales, crowdfunding, and similar use cases.

## Use Cases:
- Decentralized token sales or fundraising platforms.
- Crowdfunding with refund capabilities.
- Secure contract-based escrow services for ETH and tokens.

## Installation:
1.  Clone the repository:
    ```bash
    git clone https://github.com/dvncan/CombinedEscrow.git

2.  Install forge libs
```bash
    forge install OpenZeppelin/openzeppelin-contracts@4.8.0
```
3.  Compile 
```bash
    forge build
```
3.a Test
```bash
    forge test --match-path test/CombinedEscrow.t.sol -vvv
```

## Appendix A
**Happy Path**
![combinedEs_happy_path](https://github.com/user-attachments/assets/86f390ad-bac8-4922-9f4f-f42b2d156b93)

**Unhappy Path**
![combinedEs_unhappy_path drawio](https://github.com/user-attachments/assets/a64f8111-39c4-4e00-8822-80545a042739)
