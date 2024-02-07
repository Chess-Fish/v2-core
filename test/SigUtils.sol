// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { GaslessGame } from "./../src/GaslessGame.sol";

contract SigUtils {
    /// @dev EIP-712 typed move signature
    bytes32 public immutable MOVE_METHOD_HASH;

    /// @dev EIP-712 typed delegation signature
    bytes32 public immutable DELEGATION_METHOD_HASH;

    bytes32 internal DOMAIN_SEPARATOR;

    constructor() {
        MOVE_METHOD_HASH = keccak256(
            "GaslessMove(address gameAddress,uint gameNumber,uint moveNumber,uint16 move,uint expiration)"
        );

        DELEGATION_METHOD_HASH = keccak256(
            "Delegation(address delegatorAddress,address delegatedAddress,address gameAddress)"
        );

        DOMAIN_SEPARATOR = getDomainSeparator();
    }

    function getDomainSeparator() public view returns (bytes32) {
        uint256 chainId;
        assembly {
            chainId := chainid()
        }
        return keccak256(
            abi.encode(
                // keccak256('EIP712Domain(string name,string version,uint256
                // chainId,address verifyingContract)')
                0x8b73c3c69bb8fe3d512ecc4cf759cc79239f7b179b0ffacaa9a75d522b39400f,
                "ChessFish",
                "1",
                chainId,
                address(this)
            )
        );
    }

    // computes the hash of a permit
    function getStructHash(GaslessGame.GaslessMove memory _move)
        internal
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                MOVE_METHOD_HASH,
                _move.gameAddress,
                _move.gameNumber,
                _move.expiration,
                _move.moves
            )
        );
    }

    // computes the hash of the fully encoded EIP-712 message for the domain, which can be
    // used to recover the signer
    function getTypedDataHash(GaslessGame.GaslessMove memory _move)
        public
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, getStructHash(_move))
        );
    }
}
