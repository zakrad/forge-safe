# forge-safe

A Foundry library for proposing and confirming transactions to the [Safe](https://safe.global/) transaction service from Foundry scripts — no external dependencies beyond `forge-std`.

## What it does

`SafeTxServiceProposer` lets a Foundry deployment script:

1. Build a Safe transaction (single call or multi-call via `MultiSendCallOnly`)
2. Sign it with a proposer key
3. Check if it was already proposed (idempotent)
4. POST it to the Safe transaction service API
5. Add additional confirmations from other signer keys
6. Fetch the next nonce from the tx service (accounting for queued pending txs)

All HTTP calls go through Foundry's `vm.ffi` (curl), so no Node.js or off-chain tooling is needed.

## Installation

```bash
forge install zakrad/forge-safe
```

Add to your `foundry.toml`:

```toml
remappings = [
  "forge-safe/=lib/forge-safe/src/"
]
```

## Usage

### Propose a transaction

```solidity
import {SafeTxServiceProposer} from "forge-safe/SafeTxServiceProposer.sol";

contract MyProposalScript is Script {
    using SafeTxServiceProposer for *;

    function run() external {
        address safe = 0xYourSafeAddress;
        uint256 signerKey = vm.envUint("SAFE_OWNER_CI_PRIVATE_KEY");
        string memory apiKey = vm.envString("SAFE_TRANSACTION_SERVICE_API_KEY");

        address[] memory tos = new address[](2);
        uint256[] memory values = new uint256[](2);
        bytes[] memory datas = new bytes[](2);

        tos[0] = 0xContractA;
        datas[0] = abi.encodeCall(IContractA.initialize, (arg1));

        tos[1] = 0xContractB;
        datas[1] = abi.encodeCall(IContractB.configure, (arg1, arg2));

        string memory txServiceUrl = SafeTxServiceProposer.defaultTxServiceUrl(block.chainid);

        // Use getNonceFromService when other txs may already be queued in the service
        uint256 nonce = SafeTxServiceProposer.getNonceFromService(txServiceUrl, safe);

        SafeTxServiceProposer.SafeTransactionData memory safeTx =
            SafeTxServiceProposer.buildTransaction(tos, values, datas, nonce);

        SafeTxServiceProposer.ProposalResult memory result = SafeTxServiceProposer.propose(
            SafeTxServiceProposer.ProposeArgs({
                txServiceUrl: txServiceUrl,
                safe: safe,
                safeTx: safeTx,
                signerKey: signerKey,
                apiKey: apiKey,
                origin: "my-deploy-script"
            })
        );

        if (result.alreadyProposed) {
            console.log("Already proposed:", vm.toString(result.safeTxHash));
        } else {
            console.log("Proposed:", vm.toString(result.safeTxHash));
        }
    }
}
```

### Add a second confirmation

If your script has access to a second signer key (e.g. a CI key that is also a Safe owner), you can confirm the tx in the same script run:

```solidity
bool alreadyConfirmed = SafeTxServiceProposer.confirm(
    SafeTxServiceProposer.ConfirmArgs({
        txServiceUrl: txServiceUrl,
        safeTxHash: result.safeTxHash,
        signerKey: secondSignerKey,
        apiKey: apiKey
    })
);
```

`confirm` is idempotent — it returns `true` if the signature was already present.

## Multi-call batching

When `tos.length > 1`, the library automatically wraps the calls in a `MultiSendCallOnly v1.4.1` delegate call — the only multi-send contract that is `trustedForDelegateCall` in the Safe transaction service registry. All inner operations are `CALL` (not delegate call), so the Safe remains the `msg.sender` for every inner transaction.

## Nonce: on-chain vs tx-service

| Method | Use when |
|---|---|
| `ISafe(safe).nonce()` | No other txs are pending in the queue |
| `getNonceFromService(url, safe)` | Other txs may already be queued — returns the next available nonce counting queued txs |

## Supported chains

### Mainnets

| Chain | Chain ID | tx-service slug |
|---|---|---|
| Ethereum | 1 | `eth` |
| Optimism | 10 | `oeth` |
| XDC | 50 | `xdc` |
| BNB Chain | 56 | `bnb` |
| Gnosis | 100 | `gno` |
| Unichain | 130 | `unichain` |
| Polygon | 137 | `pol` |
| Monad | 143 | `monad` |
| Sonic | 146 | `sonic` |
| X Layer | 196 | `okb` |
| opBNB | 204 | `opbnb` |
| Lens | 232 | `lens` |
| zkSync Era | 324 | `zksync` |
| World Chain | 480 | `wc` |
| Stable | 988 | `stable` |
| HyperEVM | 999 | `hyper` |
| Polygon zkEVM | 1101 | `zkevm` |
| Peaq | 3338 | `peaq` |
| Bitlayer | 3637 | `btc` |
| Tempo | 4217 | `tempo` |
| MegaETH | 4326 | `mega` |
| Mantle | 5000 | `mantle` |
| Base | 8453 | `base` |
| Plasma | 9745 | `plasma` |
| 0G | 16661 | `0g` |
| Fluent | 25363 | `fluent` |
| Arbitrum One | 42161 | `arb1` |
| Celo | 42220 | `celo` |
| Tempo Moderato | 42431 | `tempo-moderato` |
| Hemi | 43111 | `hemi` |
| Avalanche | 43114 | `avax` |
| Ink | 57073 | `ink` |
| Linea | 59144 | `linea` |
| Berachain | 80094 | `berachain` |
| Codex | 81224 | `codex` |
| Citrea | 102030 | `ctc` |
| Scroll | 534352 | `scr` |
| Katana | 747474 | `katana` |
| Aurora | 1313161554 | `aurora` |

### Testnets

| Chain | Chain ID | tx-service slug |
|---|---|---|
| Mantle Sepolia | 5003 | `mnt-sep` |
| Monad Testnet | 10143 | `monad-testnet` |
| Gnosis Chiado | 10200 | `chi` |
| Sepolia | 11155111 | `sep` |
| Robinhood Testnet | 46630 | `robinhood-testnet` |
| Berachain Bepolia | 80069 | `bep` |
| Base Sepolia | 84532 | `basesep` |
| ARC Testnet | 5042002 | `arc-testnet` |

Add more chains by extending `defaultTxServiceUrl`, or pass your own URL directly via `ProposeArgs.txServiceUrl`.

## Requirements

- Foundry with `ffi = true` (or run with `--ffi`)
- `curl` and `cast` available in `$PATH`
- A Safe owner private key for the proposer
- A Safe transaction service API key

## License

MIT
