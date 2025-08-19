// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import {IAccount} from "lib/account-abstraction/contracts/interfaces/IAccount.sol";
import {PackedUserOperation} from "lib/account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {SIG_VALIDATION_FAILED, SIG_VALIDATION_SUCCESS} from "lib/account-abstraction/contracts/core/Helpers.sol";
import {IEntryPoint} from "lib/account-abstraction/contracts/interfaces/IEntryPoint.sol";

contract MinimalAccount is IAccount, Ownable {
    ////////////////////////////////////////////////////////////////
    //                         ERRORS                             //
    ////////////////////////////////////////////////////////////////
    error MinimalAccount__NotFromEntryPoint();
    error MinimalAccount__NotFromEntryPointOrOwner(); // New
    error MinimalAccount__CallFailed(bytes result);   // New

    ////////////////////////////////////////////////////////////////
    //                    STATE VARIABLES                         //
    ////////////////////////////////////////////////////////////////
    IEntryPoint private immutable i_entryPoint;

    ////////////////////////////////////////////////////////////////
    //                        MODIFIERS                           //
    ////////////////////////////////////////////////////////////////
    modifier requireFromEntryPoint() {
        if (msg.sender != address(i_entryPoint)) {
            revert MinimalAccount__NotFromEntryPoint();
        }
        _;
    }

    modifier requireFromEntryPointOrOwner() { // New
        if (msg.sender != address(i_entryPoint) && msg.sender != owner()) {
            revert MinimalAccount__NotFromEntryPointOrOwner();
        }
        _;
    }

    ////////////////////////////////////////////////////////////////
    //                        FUNCTIONS                           //
    ////////////////////////////////////////////////////////////////
    constructor(address entryPoint) Ownable(msg.sender) { // msg.sender here is the deployer EOA
        i_entryPoint = IEntryPoint(entryPoint);
    }

    receive() external payable {} // New
    

   function validateUserOp(
    PackedUserOperation calldata userOp,
    bytes32 userOpHash,
    uint256 missingAccountFunds
) external   requireFromEntryPoint returns (uint256 validationData) { // 'override' if IAccount is an interface
    validationData = _validateSignature(userOp, userOpHash);
    if (validationData != SIG_VALIDATION_SUCCESS) {
        return validationData;
    }
        _payPrefund(missingAccountFunds);

}

  ////////////////////////////////////////////////////////////////
    //                   EXTERNAL FUNCTIONS                       //
    ////////////////////////////////////////////////////////////////
    function execute(address dest, uint256 value, bytes calldata functionData)
        external
        requireFromEntryPointOrOwner 
    {
        (bool success, bytes memory result) = dest.call{value: value}(functionData);
        if (!success) {
            revert MinimalAccount__CallFailed(result);
        }
    }

 function _validateSignature(PackedUserOperation calldata userOp, bytes32 userOpHash) internal view returns (uint256 validationData) {
    // A signature is valid if it's from the MinimalAccount owner
    bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(userOpHash);
    address signer = ECDSA.recover(ethSignedMessageHash, userOp.signature);

    if (signer == address(0) || signer != owner()) { // Also check for invalid signature recovery
        return SIG_VALIDATION_FAILED; // Returns 1
    }

    return SIG_VALIDATION_SUCCESS; // Returns 0
}
  function _payPrefund(uint256 missingAccountFunds) internal {
        if (missingAccountFunds != 0) {
            (bool success,) = payable(msg.sender).call{value: missingAccountFunds, gas: type(uint256).max}("");
            (success);
        }
    }
// / ///////////////////////////////////////////////////////////////////////////
// / ////////////////////////////// GETTERS ////////////////////////////////////
// / ///////////////////////////////////////////////////////////////////////////

function getEntryPoint() external view returns (address) {
    return address(i_entryPoint);
}
}