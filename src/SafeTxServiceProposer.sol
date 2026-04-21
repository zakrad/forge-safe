// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import "forge-std/Vm.sol";

library SafeTxServiceProposer {
    Vm internal constant vm =
        Vm(address(bytes20(uint160(uint256(keccak256("hevm cheat code"))))));

    address internal constant ZERO_ADDRESS = address(0);
    // MultiSendCallOnly v1.4.1 — trustedForDelegateCall on all Safe-supported chains
    address internal constant MULTISEND = 0x9641d764fc13c8B624c04430C7356C1C7C8102e2;

    uint8 internal constant OP_CALL = 0;
    uint8 internal constant OP_DELEGATE_CALL = 1;

    error UnsupportedSafeTxServiceChain(uint256 chainId);
    error SafeTxServiceRequestFailed(uint256 status, string body);

    struct SafeTransactionData {
        address to;
        uint256 value;
        bytes data;
        uint8 operation;
        uint256 safeTxGas;
        uint256 baseGas;
        uint256 gasPrice;
        address gasToken;
        address refundReceiver;
        uint256 nonce;
    }

    struct ProposalResult {
        bytes32 safeTxHash;
        address sender;
        uint256 nonce;
        bool alreadyProposed;
        string txServiceUrl;
    }

    struct ProposeArgs {
        string txServiceUrl;
        address safe;
        SafeTransactionData safeTx;
        uint256 signerKey;
        string apiKey;
        string origin;
    }

    struct ConfirmArgs {
        string txServiceUrl;
        bytes32 safeTxHash;
        uint256 signerKey;
        string apiKey;
    }

    // solhint-disable-next-line code-complexity
    function defaultTxServiceUrl(uint256 chainId) internal pure returns (string memory) {
        // Mainnets
        if (chainId == 1)          return "https://api.safe.global/tx-service/eth";
        if (chainId == 10)         return "https://api.safe.global/tx-service/oeth";
        if (chainId == 50)         return "https://api.safe.global/tx-service/xdc";
        if (chainId == 56)         return "https://api.safe.global/tx-service/bnb";
        if (chainId == 100)        return "https://api.safe.global/tx-service/gno";
        if (chainId == 130)        return "https://api.safe.global/tx-service/unichain";
        if (chainId == 137)        return "https://api.safe.global/tx-service/pol";
        if (chainId == 143)        return "https://api.safe.global/tx-service/monad";
        if (chainId == 146)        return "https://api.safe.global/tx-service/sonic";
        if (chainId == 196)        return "https://api.safe.global/tx-service/okb";
        if (chainId == 204)        return "https://api.safe.global/tx-service/opbnb";
        if (chainId == 232)        return "https://api.safe.global/tx-service/lens";
        if (chainId == 324)        return "https://api.safe.global/tx-service/zksync";
        if (chainId == 480)        return "https://api.safe.global/tx-service/wc";
        if (chainId == 988)        return "https://api.safe.global/tx-service/stable";
        if (chainId == 999)        return "https://api.safe.global/tx-service/hyper";
        if (chainId == 1101)       return "https://api.safe.global/tx-service/zkevm";
        if (chainId == 3338)       return "https://api.safe.global/tx-service/peaq";
        if (chainId == 3637)       return "https://api.safe.global/tx-service/btc";
        if (chainId == 4217)       return "https://api.safe.global/tx-service/tempo";
        if (chainId == 4326)       return "https://api.safe.global/tx-service/mega";
        if (chainId == 5000)       return "https://api.safe.global/tx-service/mantle";
        if (chainId == 8453)       return "https://api.safe.global/tx-service/base";
        if (chainId == 9745)       return "https://api.safe.global/tx-service/plasma";
        if (chainId == 16661)      return "https://api.safe.global/tx-service/0g";
        if (chainId == 25363)      return "https://api.5afe.dev/tx-service/fluent";
        if (chainId == 42161)      return "https://api.safe.global/tx-service/arb1";
        if (chainId == 42220)      return "https://api.safe.global/tx-service/celo";
        if (chainId == 42431)      return "https://api.safe.global/tx-service/tempo-moderato";
        if (chainId == 43111)      return "https://api.safe.global/tx-service/hemi";
        if (chainId == 43114)      return "https://api.safe.global/tx-service/avax";
        if (chainId == 57073)      return "https://api.safe.global/tx-service/ink";
        if (chainId == 59144)      return "https://api.safe.global/tx-service/linea";
        if (chainId == 80094)      return "https://api.safe.global/tx-service/berachain";
        if (chainId == 81224)      return "https://api.safe.global/tx-service/codex";
        if (chainId == 102030)     return "https://api.safe.global/tx-service/ctc";
        if (chainId == 534352)     return "https://api.safe.global/tx-service/scr";
        if (chainId == 747474)     return "https://api.safe.global/tx-service/katana";
        if (chainId == 1313161554) return "https://api.safe.global/tx-service/aurora";
        // Testnets
        if (chainId == 5003)       return "https://api.safe.global/tx-service/mnt-sep";
        if (chainId == 10143)      return "https://api.safe.global/tx-service/monad-testnet";
        if (chainId == 10200)      return "https://api.safe.global/tx-service/chi";
        if (chainId == 11155111)   return "https://api.safe.global/tx-service/sep";
        if (chainId == 46630)      return "https://api.safe.global/tx-service/robinhood-testnet";
        if (chainId == 80069)      return "https://api.safe.global/tx-service/bep";
        if (chainId == 84532)      return "https://api.safe.global/tx-service/basesep";
        if (chainId == 5042002)    return "https://api.safe.global/tx-service/arc-testnet";
        revert UnsupportedSafeTxServiceChain(chainId);
    }

    function buildTransaction(
        address[] memory tos,
        uint256[] memory values,
        bytes[] memory datas,
        uint256 nonce
    ) internal pure returns (SafeTransactionData memory safeTx) {
        require(
            tos.length == values.length && tos.length == datas.length,
            "plan length mismatch"
        );
        require(tos.length > 0, "empty plan");

        safeTx.safeTxGas = 0;
        safeTx.baseGas = 0;
        safeTx.gasPrice = 0;
        safeTx.gasToken = ZERO_ADDRESS;
        safeTx.refundReceiver = ZERO_ADDRESS;
        safeTx.nonce = nonce;

        if (tos.length == 1) {
            safeTx.to = tos[0];
            safeTx.value = values[0];
            safeTx.data = datas[0];
            safeTx.operation = OP_CALL;
            return safeTx;
        }

        safeTx.to = MULTISEND;
        safeTx.value = 0;
        safeTx.data = abi.encodeWithSignature(
            "multiSend(bytes)", _encodeMultiSend(tos, values, datas)
        );
        safeTx.operation = OP_DELEGATE_CALL;
    }

    function propose(ProposeArgs memory args)
        internal
        returns (ProposalResult memory result)
    {
        result.sender = vm.addr(args.signerKey);
        result.safeTxHash = _safeTransactionHash(args.safe, args.safeTx);
        result.nonce = args.safeTx.nonce;
        result.txServiceUrl = args.txServiceUrl;

        string[] memory headers = _headers(args.apiKey);

        (uint256 getStatus, bytes memory getBody) =
            _getExistingTransaction(args.txServiceUrl, result.safeTxHash, headers);
        if (getStatus == 200) {
            result.alreadyProposed = true;
            return result;
        }
        if (getStatus != 404) {
            revert SafeTxServiceRequestFailed(getStatus, string(getBody));
        }

        bytes memory signature = _signHash(args.signerKey, result.safeTxHash);
        string memory payload = _proposalPayload(
            args.safeTx, result.safeTxHash, result.sender, signature, args.origin
        );

        (uint256 postStatus, bytes memory postBody) =
            _postTransaction(args.txServiceUrl, args.safe, headers, payload);
        if (postStatus < 200 || postStatus >= 300) {
            revert SafeTxServiceRequestFailed(postStatus, string(postBody));
        }

        result.alreadyProposed = false;
    }

    /// @notice Add a confirmation (signature) from signerKey to an already-proposed tx.
    /// @dev Returns true if the confirmation was already present (idempotent).
    function confirm(ConfirmArgs memory args) internal returns (bool alreadyConfirmed) {
        bytes memory signature = _signHash(args.signerKey, args.safeTxHash);
        string memory payload = string.concat('{"signature":"', vm.toString(signature), '"}');

        string memory url = string.concat(
            args.txServiceUrl,
            "/api/v1/multisig-transactions/",
            vm.toString(args.safeTxHash),
            "/confirmations/"
        );

        (uint256 status, bytes memory body) =
            _ffiRequest("POST", url, _headers(args.apiKey), payload);

        // Safe API returns 400 when the signature is already submitted
        if (status == 400) {
            alreadyConfirmed = true;
            return alreadyConfirmed;
        }
        if (status < 200 || status >= 300) {
            revert SafeTxServiceRequestFailed(status, string(body));
        }
    }

    /// @notice Fetch the next nonce to use from the tx service (accounts for queued pending txs).
    /// @dev Use this instead of ISafe(safe).nonce() when other txs may already be queued.
    function getNonceFromService(string memory txServiceUrl, address safe)
        internal
        returns (uint256)
    {
        string[] memory noHeaders = new string[](0);
        string memory url = string.concat(txServiceUrl, "/api/v1/safes/", vm.toString(safe), "/");
        (uint256 status, bytes memory body) = _ffiRequest("GET", url, noHeaders, "");
        if (status != 200) revert SafeTxServiceRequestFailed(status, string(body));
        return vm.parseJsonUint(string(body), ".nonce");
    }

    function _headers(string memory apiKey)
        private
        pure
        returns (string[] memory headers)
    {
        headers = new string[](2);
        headers[0] = "Content-Type: application/json";
        headers[1] = string.concat("Authorization: Bearer ", apiKey);
    }

    function _getExistingTransaction(
        string memory txServiceUrl,
        bytes32 safeTxHash,
        string[] memory headers
    ) private returns (uint256, bytes memory) {
        string memory url = string.concat(
            txServiceUrl, "/api/v1/multisig-transactions/", vm.toString(safeTxHash), "/"
        );
        return _ffiRequest("GET", url, headers, "");
    }

    function _postTransaction(
        string memory txServiceUrl,
        address safe,
        string[] memory headers,
        string memory payload
    ) private returns (uint256, bytes memory) {
        string memory url = string.concat(
            txServiceUrl, "/api/v1/safes/", vm.toString(safe), "/multisig-transactions/"
        );
        return _ffiRequest("POST", url, headers, payload);
    }

    function _ffiRequest(
        string memory method,
        string memory url,
        string[] memory headers,
        string memory body
    ) private returns (uint256 status, bytes memory data) {
        string memory headerArgs = "";
        for (uint256 i = 0; i < headers.length; i++) {
            headerArgs = string.concat(headerArgs, '-H "', headers[i], '" ');
        }

        string memory bodyArg = "";
        if (bytes(body).length > 0) {
            string memory tmpFile = "/tmp/safe_request.json";
            vm.writeFile(tmpFile, body);
            bodyArg = string.concat("-d @", tmpFile, " ");
        }

        string[] memory inputs = new string[](3);
        inputs[0] = "bash";
        inputs[1] = "-c";
        inputs[2] = string.concat(
            'response=$(curl -s -w "\\n%{http_code}" ',
            headerArgs,
            "-X ",
            method,
            " ",
            bodyArg,
            '"',
            url,
            '"',
            '); status=$(tail -n1 <<< "$response"); body=$(sed "$ d" <<< "$response"); body=$(echo "$body" | tr -d "\\n"); cast abi-encode "f(uint256,string)" "$status" "$body";'
        );

        bytes memory res = vm.ffi(inputs);
        return abi.decode(res, (uint256, bytes));
    }

    function _encodeMultiSend(
        address[] memory tos,
        uint256[] memory values,
        bytes[] memory datas
    ) private pure returns (bytes memory encoded) {
        for (uint256 i = 0; i < tos.length; i++) {
            encoded = bytes.concat(
                encoded,
                abi.encodePacked(OP_CALL, tos[i], values[i], datas[i].length, datas[i])
            );
        }
    }

    function _proposalPayload(
        SafeTransactionData memory safeTx,
        bytes32 safeTxHash,
        address sender,
        bytes memory signature,
        string memory origin
    ) private returns (string memory) {
        string memory obj = "safeProposal";
        vm.serializeAddress(obj, "to", safeTx.to);
        vm.serializeString(obj, "value", vm.toString(safeTx.value));
        vm.serializeString(
            obj, "data", bytes(safeTx.data).length == 0 ? "0x" : vm.toString(safeTx.data)
        );
        vm.serializeUint(obj, "operation", uint256(safeTx.operation));
        vm.serializeAddress(obj, "gasToken", safeTx.gasToken);
        vm.serializeString(obj, "safeTxGas", vm.toString(safeTx.safeTxGas));
        vm.serializeString(obj, "baseGas", vm.toString(safeTx.baseGas));
        vm.serializeString(obj, "gasPrice", vm.toString(safeTx.gasPrice));
        vm.serializeAddress(obj, "refundReceiver", safeTx.refundReceiver);
        vm.serializeString(obj, "nonce", vm.toString(safeTx.nonce));
        vm.serializeString(obj, "contractTransactionHash", vm.toString(safeTxHash));
        vm.serializeAddress(obj, "sender", sender);
        vm.serializeString(obj, "signature", vm.toString(signature));
        return vm.serializeString(obj, "origin", origin);
    }

    function _safeTransactionHash(address safe, SafeTransactionData memory safeTx)
        private
        view
        returns (bytes32)
    {
        return ISafe(safe)
            .getTransactionHash(
                safeTx.to,
                safeTx.value,
                safeTx.data,
                safeTx.operation,
                safeTx.safeTxGas,
                safeTx.baseGas,
                safeTx.gasPrice,
                safeTx.gasToken,
                safeTx.refundReceiver,
                safeTx.nonce
            );
    }

    function _signHash(uint256 signerKey, bytes32 safeTxHash)
        private
        returns (bytes memory)
    {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerKey, safeTxHash);
        return abi.encodePacked(r, s, v);
    }
}

interface ISafe {
    function getOwners() external view returns (address[] memory);
    function nonce() external view returns (uint256);
    function getTransactionHash(
        address to,
        uint256 value,
        bytes memory data,
        uint8 operation,
        uint256 safeTxGas,
        uint256 baseGas,
        uint256 gasPrice,
        address gasToken,
        address refundReceiver,
        uint256 _nonce
    ) external view returns (bytes32);
}
