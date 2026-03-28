//SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ZkMinimalAccount} from "src/zksync/ZkMinimalAccount.sol";

// Era Imports
import {Transaction, MemoryTransactionHelper} from "lib/foundry-era-contracts/src/system-contracts/contracts/libraries/MemoryTransactionHelper.sol";
import {SystemContractsCaller} from "lib/foundry-era-contracts/src/system-contracts/contracts/libraries/SystemContractsCaller.sol";
import {BOOTLOADER_FORMAL_ADDRESS} from "lib/foundry-era-contracts/src/system-contracts/contracts/Constants.sol";
import {ACCOUNT_VALIDATION_SUCCESS_MAGIC} from "lib/foundry-era-contracts/src/system-contracts/contracts/interfaces/IAccount.sol";

// OZ Imports
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract ZkMinimalAccountTest is Test {
    ZkMinimalAccount minimalAccount;
    ERC20Mock usdc;

    uint256 constant AMOUNT = 1e18;
    bytes32 constant EMPTY_BYTES32 = bytes32(0);
    address constant ANVIL_DEFAULT_ACCOUNT = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

    address randomUser = makeAddr("randomUser");

    function setUp() public {
        minimalAccount = new ZkMinimalAccount();
        minimalAccount.transferOwnership(ANVIL_DEFAULT_ACCOUNT);
        usdc = new ERC20Mock();
        vm.deal(address(minimalAccount), AMOUNT);
    }

    function testZkOwnerCanExecuteCommands() public {
        //Arrange
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(minimalAccount), AMOUNT);

        Transaction memory transaction = _createUnsighnedTransaction(
            minimalAccount.owner(),
            dest,
            value,
            functionData,
            113
        );

        //Act
        vm.prank(minimalAccount.owner());
        minimalAccount.executeTransaction(EMPTY_BYTES32, EMPTY_BYTES32, transaction);

        //Assert
        assertEq(usdc.balanceOf(address(minimalAccount)), AMOUNT);
    }

    function testZkNotOwnerCannotExecuteCommands() public {
        //Arrange
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(minimalAccount), AMOUNT);

        Transaction memory transaction = _createUnsighnedTransaction(
            minimalAccount.owner(),
            dest,
            value,
            functionData,
            113
        );

        //Act & Assert
        vm.prank(randomUser);
        vm.expectRevert(ZkMinimalAccount.ZkMinimalAccount__NotFromBootLoaderOrOwner.selector);
        minimalAccount.executeTransaction(EMPTY_BYTES32, EMPTY_BYTES32, transaction);
    }

    function testZkValidateTransaction() public {
        //Arrange
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(minimalAccount), AMOUNT);

        Transaction memory transaction = _createUnsighnedTransaction(
            minimalAccount.owner(),
            dest,
            value,
            functionData,
            113
        );
        transaction = _signTransaction(transaction);

        // Act
        vm.prank(BOOTLOADER_FORMAL_ADDRESS);
        bytes4 magic = minimalAccount.validateTransaction(EMPTY_BYTES32, EMPTY_BYTES32, transaction);

        // Assert
        assertEq(magic, ACCOUNT_VALIDATION_SUCCESS_MAGIC);
    }

    /*//////////////////////////////////////////////////////////////
                            HELPERS
    //////////////////////////////////////////////////////////////*/
    function _signTransaction(Transaction memory transaction) internal view returns (Transaction memory) {
        bytes32 unsignedTransactionHash = MemoryTransactionHelper.encodeHash(transaction);
        uint8 v;
        bytes32 r;
        bytes32 s;
        uint256 ANVIL_DEFAULT_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        (v, r, s) = vm.sign(ANVIL_DEFAULT_KEY, unsignedTransactionHash);
        Transaction memory signedTransaction = transaction;
        signedTransaction.signature = abi.encodePacked(r, s, v);
        return signedTransaction;
    }

    function _createUnsighnedTransaction(
        address from,
        address to,
        uint256 value,
        bytes memory data,
        uint8 transactionType
    ) internal view returns (Transaction memory) {
        // uint256 nonce = SystemContractsCaller.nonceHolder().getAccountNonce(address(minimalAccount));
        // uint256 nonce = vm.getNonce(address(minimalAccount));
        // bytes32[] memory factoryDeps = new bytes32[](0);
        Transaction memory txObj;

        txObj.txType = transactionType;
        txObj.from = uint256(uint160(from));
        txObj.to = uint256(uint160(to));
        txObj.gasLimit = 16777216;
        txObj.gasPerPubdataByteLimit = 16777216;
        txObj.maxFeePerGas = 16777216;
        txObj.maxPriorityFeePerGas = 16777216;
        txObj.paymaster = 0;
        txObj.nonce = vm.getNonce(address(minimalAccount));
        txObj.value = value;
        txObj.reserved = [uint256(0), uint256(0), uint256(0), uint256(0)];
        txObj.data = data;
        txObj.signature = hex"";
        txObj.factoryDeps = new bytes32[](0);
        txObj.paymasterInput = hex"";
        txObj.reservedDynamic = hex"";

        return txObj;
    }
}
