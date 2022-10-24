# permit2

Permit2 introduces a low-overhead, next generation token approval/meta-tx system.

## Features

- **Signature Based Approvals**: Any ERC20 token, even those that do not support [EIP-2612](https://eips.ethereum.org/EIPS/eip-2612), can now use permit style approvals.
- **Batched Token Approvals**: Set permissions on different tokens to different spenders with one signature.
- **Signature Based Token Transfers**: Owners can sign messages to transfer tokens directly to signed spenders.
- **Batched Token Transfers**: Transfer different tokens to different recipients with one signature.
- **Safe Arbitrary Data Verification**: Verify any extra data by passing through a witness hash and witness type.
- **Signature Verification for Contracts**: All signature verification supports [EIP-1271](https://eips.ethereum.org/EIPS/eip-1271) so contracts can approve tokens and transfer tokens through signatures.
- **Non-monotonic Replay Protection**: Signature based transfers use unordered, non-monotonic nonces so that signed permits do not need to be transacted in any particular order.

## Architecture

Permit2 is the union of two contracts: `AllowanceTransfer` and `SignatureTransfer`. These contracts handle signature based allowances of tokens and signature based transfers of tokens, respectively.

## Contributing

You will need a copy of [Foundry](https://github.com/foundry-rs/foundry) installed before proceeding. See the [installation guide](https://github.com/foundry-rs/foundry#installation) for details.

### Setup

```sh
git clone https://github.com/Uniswap/permit2.git
cd permit2
```

### Lint

```sh
forge fmt [--check]
```

### Run Tests

```sh
# unit
forge test

# integration
source .env
FOUNDRY_PROFILE=integration forge test
```

### Update Gas Snapshots

```sh
forge snapshot
```

## Acknowledgments

Inspired by [permit-everywhere](https://github.com/merklejerk/permit-everywhere).
