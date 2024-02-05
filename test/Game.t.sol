// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Test, console } from "forge-std/Test.sol";
import { ChessGameTest } from "../src/ChessGameTest.sol";

import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract GameTest is Test {
    using ECDSA for bytes32;

    ChessGameTest public game;

    string mnemonic =
        "test test test test test test test test test test test junk";

    function setUp() public {
        game = new ChessGameTest();
    }

    function testSignature() public {
        // address user1 = vm.addr()
        uint256 privateKey1 = vm.deriveKey(mnemonic, 0);
        uint256 privateKey2 = vm.deriveKey(mnemonic, 1);

        address user1 = vm.addr(privateKey1);
        address user2 = vm.addr(privateKey2);

        // USER 1
        uint16[] memory moves1 = new uint16[](1);
        moves1[0] = 1; // first move

        bytes32 movesHash1 = keccak256(abi.encode(moves1));

        vm.startPrank(user1);
        bytes memory signature1;
        {
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey1, movesHash1);
            signature1 = abi.encodePacked(r, s, v);
        }

        game.verifySignature(moves1, signature1, user1);
        vm.stopPrank();

        // USER 2
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
        game.verifySignature(moves2, signature1, user1);
        vm.stopPrank();

        bytes[2] memory signatures;
        signatures[0] = signature1;
        signatures[1] = signature2;

        game.verifySignatures(moves2, signatures, user1, user2);
    }
}
