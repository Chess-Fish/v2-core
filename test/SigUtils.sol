// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { GaslessGame } from "./../src/GaslessGame.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract SigUtils {
    /// @dev EIP-712 typed move signature
    bytes32 public immutable MOVE_METHOD_HASH;

    /// @dev EIP-712 typed delegation signature
    bytes32 public immutable DELEGATION_METHOD_HASH;

    bytes32 internal DOMAIN_SEPARATOR;

    constructor() {
        MOVE_METHOD_HASH = keccak256(
            "GaslessMove(address gameAddress,uint gameNumber,uint expiration,uint16[] moves)"
        );

        DELEGATION_METHOD_HASH = keccak256(
            "Delegation(address delegatorAddress,address delegatedAddress,address gameAddress)"
        );

        // DOMAIN_SEPARATOR = getDomainSeparator();
    }

    bytes32 private constant TYPE_HASH = keccak256(
        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
    );

    function _buildDomainSeparator(address _gaslessGame)
        internal
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                TYPE_HASH,
                keccak256(bytes("ChessFish")),
                keccak256(bytes("1")),
                block.chainid,
                _gaslessGame
            )
        );
    }

    // computes the hash of a permit
    // computes the hash of a permit, including proper handling of dynamic types
    function getStructHashMove(GaslessGame.GaslessMove memory _move)
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
                _move.movesHash
            )
        );
    }

    // computes the hash of the fully encoded EIP-712 message for the domain, which can be
    // used to recover the signer
    function getTypedDataHashMove(
        GaslessGame.GaslessMove memory _move,
        address _gaslessGame
    )
        public
        view
        returns (bytes32)
    {
        return MessageHashUtils.toTypedDataHash(
            _buildDomainSeparator(_gaslessGame), getStructHashMove(_move)
        );
    }

    // computes the hash of a permit
    // computes the hash of a permit, including proper handling of dynamic types
    function getStructHashDelegation(GaslessGame.Delegation memory _delegation)
        internal
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                DELEGATION_METHOD_HASH,
                _delegation.delegatorAddress,
                _delegation.delegatedAddress,
                _delegation.gameAddress
            )
        );
    }

    // computes the hash of the fully encoded EIP-712 message for the domain, which can be
    // used to recover the signer
    function getTypedDataHashDelegation(
        GaslessGame.Delegation memory _delegation,
        address _gaslessGame
    )
        public
        view
        returns (bytes32)
    {
        return MessageHashUtils.toTypedDataHash(
            _buildDomainSeparator(_gaslessGame), getStructHashDelegation(_delegation)
        );
    }
}
