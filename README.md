## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

- **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
- **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
- **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
- **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

https://book.getfoundry.sh/

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

example:

```shell
forge test --match-contract TestEndToEndAirdrop -vv --via-ir --chain 11155111 --fork-url https://eth-sepolia.g.alchemy.com/v2/INSERT_ALCHEMY_SEPOLIA_KEY
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

Example:

```shell
forge script script/DeployMetalFunFactoryV2.s.sol  --rpc-url https://eth-sepolia.g.alchemy.com/v2/ALCHEMY_SEPOLIA_EY  --sender 0x123 --private-key PRIVATE_KEY --optimize --optimizer-runs 200 --verify --verifier-url https://api-sepolia.etherscan.io/api --etherscan-api-key ETHERSCAN_KEY --broadcast --chain-id 11155111 --constructor-args 0x0
```

### Verify

If the verification fails on deploy:

```shell
forge verify-contract --verifier-url https://api-sepolia.etherscan.io/api --etherscan-api-key ETHERSCAN_KEY 0x123contractAddress... "PATH:src/FundMe.sol:FundMe"
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```
