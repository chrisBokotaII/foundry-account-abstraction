// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {MinimalAccount} from "src/ethereum/MinimalAccount.sol";
import {DeployMinimal} from "script/DeployMinimal.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {SendPackedUserOp, PackedUserOperation} from "script/SendPackedUserOp.s.sol"; // Assuming PackedUserOperation is exported or accessible
import {IEntryPoint} from "lib/account-abstraction/contracts/interfaces/IEntryPoint.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract MinimalAccountTest is Test {
    using MessageHashUtils for bytes32;
    HelperConfig helperConfig;
    MinimalAccount minimalAccount;
    ERC20Mock usdc;
    uint256 constant AMOUNT = 1e18; // Standard amount for minting (1 token with 18 decimals)
    address randomUser = makeAddr("randomUser"); // A deterministic address for non-owner tests
    SendPackedUserOp sendPackedUserOpScript;
    function setUp() public {
        DeployMinimal deployMinimal = new DeployMinimal();
        // Deploy MinimalAccount using our deployment script
        (helperConfig, minimalAccount) = deployMinimal.deployMinimalAccount();
          
        usdc = new ERC20Mock();
                sendPackedUserOpScript = new SendPackedUserOp();
     
    }

    function testOwnerCanExecuteCommands() public {
    // Arrange
    assertEq(usdc.balanceOf(address(minimalAccount)), 0, "Initial USDC balance should be 0");
    address dest = address(usdc); // Target contract is the mock USDC
    uint256 value = 0;           // No ETH value sent in the internal call from account to USDC
    
    // Prepare calldata for: usdc.mint(address(minimalAccount), AMOUNT)
    bytes memory functionData = abi.encodeWithSelector(
        ERC20Mock.mint.selector,      // Function selector for mint(address,uint256)
        address(minimalAccount),      // Argument 1: recipient of minted tokens
        AMOUNT                        // Argument 2: amount to mint
    );

    // Act
    // Impersonate the owner of the MinimalAccount for the next call
    vm.prank(minimalAccount.owner()); 
    minimalAccount.execute(dest, value, functionData); // Owner calls execute

    // Assert
    // Check if MinimalAccount now has the minted USDC
    assertEq(usdc.balanceOf(address(minimalAccount)), AMOUNT, "MinimalAccount should have minted USDC");
}

    function testNonOwnerCannotExecuteCommands() public {
    // Arrange
    address dest = address(usdc);
    uint256 value = 0;
    bytes memory functionData = abi.encodeWithSelector(
        ERC20Mock.mint.selector,
        address(minimalAccount),
        AMOUNT
    );
    // Act & Assert (Combined using expectRevert)
    vm.prank(randomUser); // Impersonate a random, non-owner address

    // Expect the call to revert with the specific error from the modifier
    // MinimalAccount__NotFromEntryPointOrOwner is the custom error
    vm.expectRevert(MinimalAccount.MinimalAccount__NotFromEntryPointOrOwner.selector);
    minimalAccount.execute(dest, value, functionData); // Attempt to call execute
}
   function testRecoverSignedOp() public {
        // Arrange:​
        // 1. Define the target call data (e.g., minting USDC through the MinimalAccount)
        // Assume 'usdc' is an ERC20Mock instance deployed in setUp
        bytes memory functionDataForUSDCMint = abi.encodeWithSelector(
            usdc.mint.selector,
            address(minimalAccount), // Mint to the smart account itself
            AMOUNT
        );
        // 2. Define the callData for MinimalAccount.execute
        // This is what the EntryPoint will use to call our smart account.
        bytes memory executeCallData = abi.encodeWithSelector(
            minimalAccount.execute.selector,
            address(usdc),             // dest: the USDC contract
            0,                         // value: no ETH sent with this call
            functionDataForUSDCMint    // data: the encoded call to usdc.mint
        );
        // 3. Generate the signed PackedUserOperation
        // Note: If generateSignedUserOperation needs the private key for testing as discussed,
        // that logic would be inside it or passed appropriately.
        // Here, we assume config.account (owner) is usable by vm.sign IF workaround is applied
        // or if this test itself is run as a script with --account.
        // For pure 'forge test', the private key workaround inside generateSignedUserOperation is needed.
        PackedUserOperation memory packedUserOp = sendPackedUserOpScript. getGenerateSignedUserOperation(
            executeCallData,
            helperConfig.getConfig() ,
            address(minimalAccount) // Contains EntryPoint address and EOA signer (owner)
        );
        // 4. Get the userOpHash again (as the EntryPoint would calculate it)
        // Ensure we use the same EntryPoint address as used during signing.
        bytes32 userOperationHash = IEntryPoint(helperConfig.getConfig().entryPoint)
            .getUserOpHash(packedUserOp);

        // Act:
        // Recover the signer's address from the EIP-191 compliant digest and the signature.
        // The digest MUST match what was signed.
        address actualSigner = ECDSA.recover(
            userOperationHash.toEthSignedMessageHash(), // Re-apply EIP-191 for recovery
            packedUserOp.signature
        );
        // Assert:
        // Check if the recovered signer is the owner of the MinimalAccount.
        assertEq(actualSigner, minimalAccount.owner(), "Signer recovery failed");
    }

    function testValidateUserOps() public{
           // Assume 'usdc' is an ERC20Mock instance deployed in setUp
        bytes memory functionDataForUSDCMint = abi.encodeWithSelector(
            usdc.mint.selector,
            address(minimalAccount), // Mint to the smart account itself
            AMOUNT
        );
        // 2. Define the callData for MinimalAccount.execute
        // This is what the EntryPoint will use to call our smart account.
        bytes memory executeCallData = abi.encodeWithSelector(
            minimalAccount.execute.selector,
            address(usdc),             // dest: the USDC contract
            0,                         // value: no ETH sent with this call
            functionDataForUSDCMint    // data: the encoded call to usdc.mint
        );
        // 3. Generate the signed PackedUserOperation
        // Note: If generateSignedUserOperation needs the private key for testing as discussed,
        // that logic would be inside it or passed appropriately.
        // Here, we assume config.account (owner) is usable by vm.sign IF workaround is applied
        // or if this test itself is run as a script with --account.
        // For pure 'forge test', the private key workaround inside generateSignedUserOperation is needed.
        PackedUserOperation memory packedUserOp = sendPackedUserOpScript. getGenerateSignedUserOperation(
            executeCallData,
            helperConfig.getConfig(),
            address(minimalAccount) // Contains EntryPoint address and EOA signer (owner)
        );
        // 4. Get the userOpHash again (as the EntryPoint would calculate it)
        // Ensure we use the same EntryPoint address as used during signing.
        bytes32 userOperationHash = IEntryPoint(helperConfig.getConfig().entryPoint)
            .getUserOpHash(packedUserOp);

            uint256 missingFunds = 1e18; // Standard amount for minting (1 token with 18 decimals)

            vm.prank(helperConfig.getConfig().entryPoint); // Impersonate the entryPoint for the next call
            uint256 validationResult = minimalAccount.validateUserOp(packedUserOp,userOperationHash, missingFunds);

            assertEq(validationResult, 0, "Validation failed");

    }
    function testEntrypointCanExecute() public{
           // Assume 'usdc' is an ERC20Mock instance deployed in setUp
        bytes memory functionDataForUSDCMint = abi.encodeWithSelector(
            usdc.mint.selector,
            address(minimalAccount), // Mint to the smart account itself
            AMOUNT
        );
        // 2. Define the callData for MinimalAccount.execute
        // This is what the EntryPoint will use to call our smart account.
        bytes memory executeCallData = abi.encodeWithSelector(
            minimalAccount.execute.selector,
            address(usdc),             // dest: the USDC contract
            0,                         // value: no ETH sent with this call
            functionDataForUSDCMint    // data: the encoded call to usdc.mint
        );
        // 3. Generate the signed PackedUserOperation
        // Note: If generateSignedUserOperation needs the private key for testing as discussed,
        // that logic would be inside it or passed appropriately.
        // Here, we assume config.account (owner) is usable by vm.sign IF workaround is applied
        // or if this test itself is run as a script with --account.
        // For pure 'forge test', the private key workaround inside generateSignedUserOperation is needed.
        PackedUserOperation memory packedUserOp = sendPackedUserOpScript. getGenerateSignedUserOperation(
            executeCallData,
            helperConfig.getConfig(),
            address(minimalAccount) // Contains EntryPoint address and EOA signer (owner)
        );
        // 4. Get the userOpHash again (as the EntryPoint would calculate it)
        // Ensure we use the same EntryPoint address as used during signing.
        // bytes32 userOperationHash = IEntryPoint(helperConfig.getConfig().entryPoint)
        //     .getUserOpHash(packedUserOp);
            vm.deal(address(minimalAccount), 1e18);
            vm.deal(address(helperConfig.getConfig().entryPoint), 1e18);

            PackedUserOperation[] memory ops = new PackedUserOperation[](1);
            ops[0] = packedUserOp;

            vm.prank(randomUser);
            IEntryPoint(helperConfig.getConfig().entryPoint).handleOps(ops,payable(randomUser)); // Impersonate the entryPoint for the next call
            assertEq(usdc.balanceOf(address(minimalAccount)), AMOUNT, "MinimalAccount should have minted USDC");

    }
}