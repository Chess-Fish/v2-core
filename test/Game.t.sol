// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Test, console } from "forge-std/Test.sol";
import { GaslessGame } from "../src/GaslessGame.sol";

import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import { SigUtils } from "./SigUtils.sol";

contract GameTest is Test, SigUtils {
    using ECDSA for bytes32;

    GaslessGame public gaslessGame;

    string mnemonic = "test test test test test test test test test test test junk";

    function setUp() public {
        gaslessGame = new GaslessGame(address(0));
    }

    function testSignature() public {
        // address user1 = vm.addr()
        uint256 privateKey1 = vm.deriveKey(mnemonic, 0);
        uint256 privateKey2 = vm.deriveKey(mnemonic, 1);

        address user1 = vm.addr(privateKey1);
        address user2 = vm.addr(privateKey2);

        uint256 delegatedPrivateKey1 = vm.deriveKey(mnemonic, 3);
        uint256 delegatedPrivateKey2 = vm.deriveKey(mnemonic, 4);

        address delegatedSigner1 = vm.addr(delegatedPrivateKey1);
        address delegatedSigner2 = vm.addr(delegatedPrivateKey2);

        // 1) Create Delegation
        GaslessGame.Delegation memory delegation =
            GaslessGame.Delegation(user1, delegatedSigner1, address(0));

        bytes32 delegationHash1 =
            getTypedDataHashDelegation(delegation, address(gaslessGame));

        vm.startPrank(user1);
        bytes memory delegationSig1;
        {
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey1, delegationHash1);
            delegationSig1 = abi.encodePacked(r, s, v);
        }

        GaslessGame.SignedDelegation memory signedDelegation1 =
            GaslessGame.SignedDelegation(delegation, delegationSig1);

        bytes memory rawSignedDelegation1 = abi.encode(signedDelegation1);

        gaslessGame.verifyDelegation(rawSignedDelegation1);
        vm.stopPrank();

        // USER 1
        uint16[] memory moves1 = new uint16[](1);
        moves1[0] = 1; // first move

        GaslessGame.GaslessMove memory move =
            GaslessGame.GaslessMove(address(0), 0, 0, moves1);
        bytes32 movesHash1 = getTypedDataHashMove(move, address(gaslessGame));
        console.logBytes32(movesHash1);

        vm.startPrank(delegatedSigner1);
        bytes memory signature1;
        {
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(delegatedPrivateKey1, movesHash1);
            signature1 = abi.encodePacked(r, s, v);
        }

        GaslessGame.GaslessMoveData memory moveData =
            GaslessGame.GaslessMoveData(move, signature1);

        console.log("Signer");
        console.log(delegatedSigner1);

        console.log("USER1");
        console.log(user1);

        gaslessGame.verifyMoveDelegated(rawSignedDelegation1, abi.encode(moveData));

        vm.stopPrank();

        /*         // USER 2
        uint16[] memory moves2 = new uint16[](2);
        moves2[0] = moves1[0]; // previous move
        moves2[1] = 2; // new move

        bytes32 movesHash2 = keccak256(abi.encode(moves2));

        vm.startPrank(user2);
        bytes memory signature2;
        {
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey1, movesHash2);
            signature2 = abi.encodePacked(r, s, v);
        }
        // game.verifySignature(moves2, signature1, user1);
        vm.stopPrank();

        bytes[2] memory signatures;
        signatures[0] = signature1;
        signatures[1] = signature2;

        // game.verifySignatures(moves2, signatures, user1, user2); */
    }
}
