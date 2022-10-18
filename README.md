# permit2

Backwards compatible, low-overhead, next generation token approval/meta-tx system.

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
