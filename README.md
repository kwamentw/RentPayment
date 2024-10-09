## Rent Contract

**This is a contract that is designed to help Landlords that are crypto oriented manage their properties up for sale and rent.**

This contract consists of these major components:

-   **Rent**: Tenants can rent apartments in ETH and landlords can also take their rent in ETH
-   **Buy**: Tenants can buy properties in ETHER permanently instead of renting
-   **Remove**: When there's any misbehaviour or defaulting of payment Landlords can eject tenants.
-   **withdraw**: Module to help landlord withdraw all rent accumulated in contract.

## Purpose

This contract was first designed just to illustrate the power of smart contracts in our daily lives to some of my Elders.

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Deploy

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```
