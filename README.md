# forge-safe

A Foundry library for proposing transactions to the [Safe](https://safe.global/) transaction service from Foundry scripts — no external dependencies beyond `forge-std`.

## What it does

`SafeTxServiceProposer` lets a Foundry deployment script:

1. Build a Safe transaction (single call or multi-call via `MultiSendCallOnly`)
2. Sign it with a proposer key
3. Check if it was already proposed (idempotent)
4. POST it to the Safe transaction service API

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

```solidity
import {SafeTxServiceProposer} from "forge-safe/SafeTxServiceProposer.sol";

contract MyProposalScript is Script {
    using SafeTxServiceProposer for *;

    function run() external {
        address safe = 0xYourSafeAddress;
        uint256 signerKey = vm.envUint("SAFE_OWNER_CI_PRIVATE_KEY");
        string memory apiKey = vm.envString("SAFE_TRANSACTION_SERVICE_API_KEY");

        // Build the call list
        address[] memory tos = new address[](2);
        uint256[] memory values = new uint256[](2);
        bytes[] memory datas = new bytes[](2);

        tos[0] = 0xContractA;
        datas[0] = abi.encodeCall(IContractA.initialize, (arg1));

        tos[1] = 0xContractB;
        datas[1] = abi.encodeCall(IContractB.configure, (arg1, arg2));

        // Fetch current nonce from the Safe
        uint256 nonce = ISafe(safe).nonce();

        SafeTxServiceProposer.SafeTransactionData memory safeTx =
            SafeTxServiceProposer.buildTransaction(tos, values, datas, nonce);

        string memory txServiceUrl = SafeTxServiceProposer.defaultTxServiceUrl(block.chainid);

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

## Multi-call batching

When `tos.length > 1`, the library automatically wraps the calls in a `MultiSendCallOnly v1.4.1` delegate call — the only multi-send contract that is `trustedForDelegateCall` in the Safe transaction service registry. All inner operations are `CALL` (not delegate call), so the Safe remains the `msg.sender` for every inner transaction.

## Supported chains

| Chain | Chain ID | tx-service slug |
|---|---|---|
| Base Sepolia | 84532 | `basesep` |

Add more chains by extending `defaultTxServiceUrl`, or pass your own URL directly via `ProposeArgs.txServiceUrl`.

## Requirements

- Foundry with `ffi = true` (or run with `--ffi`)
- `curl` and `cast` available in `$PATH`
- A Safe owner private key for the proposer
- A Safe transaction service API key

## License

MIT
