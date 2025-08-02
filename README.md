# ChessFish v2-Core
[![Twitter](https://img.shields.io/twitter/url/https/twitter.com/cloudposse.svg?style=social&label=Follow%20%40evmchess)](https://twitter.com/evmchess)

In-depth documentation on ChessFish located at [docs.chess.fish](http://docs.chess.fish)

## About
ChessFish is a non-custodial chess wager smart contract and chess move verification algorithm implemented for the Ethereum Virtual Machine. ChessFish v2 offers the ability to play 1v1 chess or in tournaments up to 25 players while betting cryptocurrency on the outcome of the game. Users can specify different parameters for 1v1 wagers and tournaments, including the ERC-20 token to wager, number of games, and time limits. Games can be played without paying for transaction fees by using ECDSA signatures.

## Tournament NFTs
ChessFish generates beautiful onchain SVG NFTs for tournament winners that display the final board position, player addresses, and tournament metadata.

## Development

### Run Tests
```bash
npx hardhat test
```

### Code Formatting
```bash
forge fmt
npx prettier --write '**/*.ts'
```

### Test Coverage
```bash
npx hardhat coverage
```

### Documentation Generation
```bash
npx hardhat docgen
```
