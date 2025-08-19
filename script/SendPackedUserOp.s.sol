// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {PackedUserOperation} from "lib/account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {PackedUserOperation} from "lib/account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {HelperConfig} from "script/HelperConfig.s.sol"; // Assuming NetworkConfig is defined or imported here
import {IEntryPoint} from "lib/account-abstraction/contracts/interfaces/IEntryPoint.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract SendPackedUserOp is Script {
    using MessageHashUtils for bytes32;
    HelperConfig public helperConfig;

    function run() public {
        helperConfig = new HelperConfig();
    } // Entry point for script execution, empty for now
function getGenerateSignedUserOperation(bytes memory callData,        // The target call data for the smart account's execution
        HelperConfig.NetworkConfig memory config,address minimalAccount ) public view  returns (PackedUserOperation memory) {
        
        return _generateSignedUserOperation(callData, config, minimalAccount);
    }
    // Helper functions will be defined below
 function _generateSignedUserOperation(
        bytes memory callData,        // The target call data for the smart account's execution
        HelperConfig.NetworkConfig memory config ,
        address minimalAccount// Network config containing EntryPoint address and signer
    ) internal view returns (PackedUserOperation memory) {
        // Step 1: Generate the Unsigned UserOperation
        // Fetch the nonce for the sender (smart account address) from the EntryPoint
        // For simplicity, we'll assume the 'config.account' is the smart account for now,
        // though in reality, this would be the smart account address, and config.account the EOA owner.
        // Nonce would be: IEntryPoint(config.entryPoint).getNonce(config.account, nonceKey);
        // For this example, let's use a placeholder nonce or assume it's passed in.
        
        uint256 nonce = vm.getNonce(minimalAccount)-1; 

        PackedUserOperation memory userOp = _generateUnsignedUserOperation(
            callData,
            minimalAccount, // This should be the smart account address
            nonce
        );
        // Step 2: Get the userOpHash from the EntryPoint
        // We need to cast the config.entryPoint address to the IEntryPoint interface
        // the userOpHash is derived from the user operation details.
        //without the signature field
        bytes32 userOpHash = IEntryPoint(config.entryPoint).getUserOpHash(userOp);

        // Prepare the hash for EIP-191 signing (standard Ethereum signed message)
        // This prepends "\x19Ethereum Signed Message:\n32" and re-hashes.
        // bytes32 digest = userOpHash.toEthSignedMessageHash();
        // // Step 3: Sign the digest
        // // 'config.account' here is the EOA that owns/controls the smart account.
        // // This EOA must be unlocked for vm.sign to work without a private key.
        // (uint8 v, bytes32 r, bytes32 s) = vm.sign(config.account, digest);
        // // Construct the final signature.
        // // IMPORTANT: The order is R, S, V (abi.encodePacked(r, s, v)).
        // // This differs from vm.sign's return order (v, r, s).
        // userOp.signature = abi.encodePacked(r, s, v);
 uint256 ANVIL_DEFAULT_PRIVATE_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80; // Default Anvil key 0​
bytes32 digest = userOpHash.toEthSignedMessageHash();
uint8 v;
 bytes32 r;
 bytes32 s;

 if (block.chainid == 31337) {
    (v, r, s) = vm.sign(ANVIL_DEFAULT_PRIVATE_KEY, digest);
} else {
    // For scripts or other networks where config.account is unlocked
    (v, r, s) = vm.sign(config.account, digest);
}
userOp.signature = abi.encodePacked(r, s, v);
        return userOp;
    }

function _generateUnsignedUserOperation(bytes memory callData, address sender, uint256 nonce)
    internal
    pure // This function doesn't read state or use cheatcodes
    returns (PackedUserOperation memory)
{
    // Example gas parameters (these may need tuning)
    uint128 verificationGasLimit = 16777216; 
    uint128 callGasLimit = verificationGasLimit; // Often different in practice
    uint128 maxPriorityFeePerGas = 256; 
    uint128 maxFeePerGas = maxPriorityFeePerGas; // Simplification for example
    // Pack accountGasLimits: (verificationGasLimit << 128) | callGasLimit
    bytes32 accountGasLimits = bytes32(
        (uint256(verificationGasLimit) << 128) | uint256(callGasLimit)
    );
    // Pack gasFees: (maxFeePerGas << 128) | maxPriorityFeePerGas
    bytes32 gasFees = bytes32(
        (uint256(maxFeePerGas) << 128) | uint256(maxPriorityFeePerGas)
    );

    return PackedUserOperation({
        sender: sender,
        nonce: nonce,
        initCode: hex"", // Empty for existing accounts
        callData: callData,
        accountGasLimits: accountGasLimits,
        preVerificationGas: verificationGasLimit, // Often related to verificationGasLimit
        gasFees: gasFees,
        paymasterAndData: hex"", // Empty if not using a paymaster
        signature: hex"" // Crucially, the signature is blank for an unsigned operation
    });
}
}