// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

import { console } from "forge-std/Test.sol";

contract ChessGameTest is EIP712 {
    struct GaslessMove {
        address wagerAddress;
        uint256 gameNumber;
        uint256 moveNumber;
        uint16 move;
        uint256 expiration;
    }

    struct GaslessMoveData {
        address signer;
        address player0;
        address player1;
        GaslessMove move;
        bytes signature;
    }

    /// @dev EIP-712 typed move signature
    bytes32 public immutable MOVE_METHOD_HASH;

    constructor() EIP712("ChessFish", "1") {
        MOVE_METHOD_HASH = keccak256(
            "GaslessMove(address wagerAddress,uint gameNumber,uint moveNumber,uint16 move,uint expiration)"
        );
    }

    function verifySignature(
        uint16[] memory moves,
        bytes memory signature,
        address signer
    )
        public
        pure
        returns (bool)
    {
        bytes32 digest = keccak256(abi.encode(moves));
        return ECDSA.recover(digest, signature) == signer;
    }

    function verifySignatures(
        uint16[] memory moves,
        bytes[2] memory signatures,
        address user1,
        address user2
    )
        public
        pure
        returns (bool)
    {
        uint256 moveLength = moves.length;

        uint16[] memory moves1 = new uint16[](moveLength - 1);
        uint16[] memory moves2 = new uint16[](moveLength);

        for (uint256 i = 0; i < moveLength; i++) {
            if (i < moveLength - 1) {
                moves1[i] = moves[i];
                moves2[i] = moves[i];
            } else {
                moves2[i] = moves[i];
            }
        }

        return verifySignature(moves1, signatures[0], user1)
            && verifySignature(moves1, signatures[1], user2);
    }
}
