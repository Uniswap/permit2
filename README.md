# permit2

Permit2 introduces a low-overhead, next-generation token approval/meta-tx system to make token approvals easier, more secure, and more consistent across applications.

## Features

- **Signature Based Approvals**: Any ERC20 token, even those that do not support [EIP-2612](https://eips.ethereum.org/EIPS/eip-2612), can now use permit style approvals. This allows applications to have a single transaction flow by sending a permit signature along with the transaction data when using `Permit2` integrated contracts.
- **Batched Token Approvals**: Set permissions on different tokens to different spenders with one signature.
- **Signature Based Token Transfers**: Owners can sign messages to transfer tokens directly to signed spenders, bypassing setting any allowance. This means that approvals aren't necessary for applications to receive tokens and that there will never be hanging approvals when using this method. The signature is valid only for the duration of the transaction in which it is spent.
- **Batched Token Transfers**: Transfer different tokens to different recipients with one signature.
- **Safe Arbitrary Data Verification**: Verify any extra data by passing through a witness hash and witness type. The type string must follow the [EIP-712](https://eips.ethereum.org/EIPS/eip-712) standard.
- **Signature Verification for Contracts**: All signature verification supports [EIP-1271](https://eips.ethereum.org/EIPS/eip-1271) so contracts can approve tokens and transfer tokens through signatures.
- **Non-monotonic Replay Protection**: Signature based transfers use unordered, non-monotonic nonces so that signed permits do not need to be transacted in any particular order.
- **Expiring Approvals**: Approvals can be time-bound, removing security concerns around hanging approvals on a wallet’s entire token balance. This also means that revoking approvals do not necessarily have to be a new transaction since an approval that expires will no longer be valid.
- **Batch Revoke Allowances**: Remove allowances on any number of tokens and spenders in one transaction.

## Architecture

Permit2 is the union of two contracts: [`AllowanceTransfer`](https://github.com/Uniswap/permit2/blob/main/src/AllowanceTransfer.sol) and [`SignatureTransfer`](https://github.com/Uniswap/permit2/blob/main/src/SignatureTransfer.sol).

The `SignatureTransfer` contract handles all signature-based transfers, meaning that an allowance on the token is bypassed and permissions to the spender only last for the duration of the transaction that the one-time signature is spent.

The `AllowanceTransfer` contract handles setting allowances on tokens, giving permissions to spenders on a specified amount for a specified duration of time. Any transfers that then happen through the `AllowanceTransfer` contract will only succeed if the proper permissions have been set.

## Integrating with Permit2

Before integrating, contracts can request users’ tokens through `Permit2`, users must approve the `Permit2` contract through the specific token contract. To see a detailed technical reference, visit the Uniswap [documentation site](https://docs.uniswap.org/contracts/permit2/overview).

### Note on viaIR compilation
Permit2 uses viaIR compilation, so importing and deploying it in an integration for tests will require the integrating repository to also use viaIR compilation. This is often quite slow, so can be avoided using the precompiled `DeployPermit2` utility:
```
import {DeployPermit2} from "permit2/test/utils/DeployPermit2.sol";

contract MyTest is DeployPermit2 {
    address permit2;

    function setUp() public {
        permit2 = deployPermit2();
    }
}
```

## Bug Bounty

This repository is subject to the Uniswap Labs Bug Bounty program, per the terms defined [here](https://uniswap.org/bug-bounty).

## Contributing

You will need a copy of [Foundry](https://github.com/foundry-rs/foundry) installed before proceeding. See the [installation guide](https://github.com/foundry-rs/foundry#installation) for details.

### Setup

```sh
git clone https://github.com/Uniswap/permit2.git
cd permit2
forge install
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

### Deploy

Run the command below. Remove `--broadcast`, `---rpc-url`, `--private-key` and `--verify` options to test locally

```sh
forge script --broadcast --rpc-url <RPC-URL> --private-key <PRIVATE_KEY> --verify script/DeployPermit2.s.sol:DeployPermit2
```

## Acknowledgments

Inspired by [merklejerk](https://github.com/merklejerk)'s [permit-everywhere](https://github.com/merklejerk/permit-everywhere) contracts which introduce permit based approvals for all tokens regardless of EIP2612 support.
