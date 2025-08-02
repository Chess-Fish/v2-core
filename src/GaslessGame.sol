// SPDX-License-Identifier: MIT

/* 
   _____ _                   ______ _     _     
  / ____| |                 |  ____(_)   | |    
 | |    | |__   ___  ___ ___| |__   _ ___| |__  
 | |    | '_ \ / _ \/ __/ __|  __| | / __| '_ \ 
 | |____| | | |  __/\__ \__ \ |    | \__ \ | | |
  \_____|_| |_|\___||___/___/_|    |_|___/_| |_|
                             
*/

pragma solidity ^0.8.23;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";

import "./MoveVerification.sol";
import "./ChessGame.sol";

import "hardhat/console.sol";

/**
 * @title ChessFish GaslessGame Contract
 * @author ChessFish
 * @notice https://github.com/Chess-Fish
 *
 * This smart contract is designed to handle gasless game moves. Key features
 * include:
 *
 * 1. Off-Chain Move Signing: This contract enables game moves to be signed
 * off-chain,
 *    significantly reducing the need for constant on-chain transactions. This
 * approach
 *    substantially lowers transaction costs.
 *
 * 2. Delegated Signer Functionality: Players have the option to delegate a
 * signer
 *    (generated on the front end) to execute moves on their behalf. This
 * delegated
 *    signer functionality reduces the frequency of wallet signature requests,
 *    providing a smoother and more uninterrupted gameplay experience. It
 * ensures
 *    that players can focus on strategy rather than managing transaction
 * confirmations.
 */
contract GaslessGame is Initializable, EIP712 {
    struct Delegation {
        address delegatorAddress;
        address delegatedAddress;
        address gameAddress;
    }

    struct SignedDelegation {
        Delegation delegation;
        bytes signature;
    }

    struct GaslessMove {
        address gameAddress;
        uint256 gameNumber;
        uint256 expiration;
        bytes32 movesHash;
    }

    struct GaslessMoveData {
        GaslessMove move;
        bytes signature;
        uint16[] moves;
    }

    /// @dev MoveVerification contract
    MoveVerification public moveVerification;

    ChessGame public chessGame;

    /// @dev address deployer
    address deployer;

    /// @dev EIP-712 typed move signature
    bytes32 public immutable MOVE_METHOD_HASH;

    /// @dev EIP-712 typed delegation signature
    bytes32 public immutable DELEGATION_METHOD_HASH;

    bytes32 public immutable TEST_METHOD_HASH;
    bytes32 public immutable TEST_METHOD_HASH1;

    modifier onlyDeployer() {
        _;
        require(msg.sender == deployer);
    }

    constructor() EIP712("ChessFish", "1") {
        MOVE_METHOD_HASH =
            keccak256("GaslessMove(address gameAddress,uint256 gameNumber,uint256 expiration,bytes32 movesHash)");

        DELEGATION_METHOD_HASH =
            keccak256("Delegation(address delegatorAddress,address delegatedAddress,address gameAddress)");

        deployer = msg.sender;
    }

    function initialize(address _moveVerification, address _chessGame) external initializer {
        moveVerification = MoveVerification(_moveVerification);
        chessGame = ChessGame(_chessGame);
    }

    function encodeMoveMessage(GaslessMove memory move, bytes memory signature, uint16[] memory moves)
        external
        pure
        returns (bytes memory)
    {
        GaslessMoveData memory moveData = GaslessMoveData(move, signature, moves);
        return abi.encode(moveData);
    }

    function verifyGameViewDelegatedSingle(bytes memory rawSignedDelegation, bytes memory rawMoveData)
        external
        view
        returns (address gameAddress, uint8 outcome, uint256 gameState, uint16[] memory moves)
    {
        console.log("gasless game address");
        console.log(gameAddress);

        SignedDelegation memory signedDelegation = decodeSignedDelegation(rawSignedDelegation);
        verifyDelegation(signedDelegation);

        GaslessMoveData memory moveData = decodeMoveData(rawMoveData);

        require(moveData.move.movesHash == keccak256(abi.encode(moveData.moves)), "Hash1 != moves");

        verifyMoveSigner(moveData, signedDelegation.delegation.delegatedAddress);

        gameAddress = moveData.move.gameAddress;
        
        checkIfDelegatorIsPlayer(signedDelegation.delegation.delegatorAddress, gameAddress);

        require(moveData.move.expiration >= block.timestamp, "move0 expired");

        moves = moveData.moves;

        if (gameAddress != address(0)) {
            uint16[] memory onChainMoves = chessGame.getLatestGameMoves(gameAddress);

            if (onChainMoves.length > 0) {
                uint16[] memory combinedMoves = new uint16[](onChainMoves.length + moves.length);
                for (uint256 i = 0; i < onChainMoves.length; i++) {
                    combinedMoves[i] = onChainMoves[i];
                }
                for (uint256 i = 0; i < moves.length; i++) {
                    combinedMoves[i + onChainMoves.length] = moves[i];
                }
                moves = combinedMoves;
            }
        }
        console.log("gasless game address 1");
        console.log(gameAddress);

        (outcome, gameState,,) = moveVerification.checkGameFromStart(moves);
        return (gameAddress, outcome, gameState, moves);
    }

    function verifyGameViewDelegated(bytes[2] memory rawSignedDelegations, bytes[2] memory rawMoveData)
        external
        view
        returns (address gameAddress, uint8 outcome, uint256 gameState, uint16[] memory moves)
    {
        SignedDelegation memory signedDelegation0 = decodeSignedDelegation(rawSignedDelegations[0]);
        verifyDelegation(signedDelegation0);

        SignedDelegation memory signedDelegation1 = decodeSignedDelegation(rawSignedDelegations[1]);
        verifyDelegation(signedDelegation1);

        GaslessMoveData memory moveData0 = decodeMoveData(rawMoveData[0]);
        GaslessMoveData memory moveData1 = decodeMoveData(rawMoveData[1]);

        uint256 size = moveData1.moves.length;
        uint16[] memory moves0 = new uint16[](size - 1);
        for (uint256 i = 0; i < size - 1; i++) {
            moves0[i] = moveData1.moves[i];
        }
        gameAddress = moveData0.move.gameAddress;
        require(moveData0.move.gameAddress == moveData1.move.gameAddress, "gameAddress mismatch");

        require(moveData0.move.gameAddress == signedDelegation0.delegation.gameAddress, "gameAddress != delegation");
        require(moveData1.move.gameAddress == signedDelegation1.delegation.gameAddress, "gameAddress != delegation");

        require(moveData0.move.movesHash == keccak256(abi.encode(moves0)), "Hash0 != moves");
        require(moveData1.move.movesHash == keccak256(abi.encode(moveData1.moves)), "Hash1 != moves");

        verifyMoveSigner(moveData0, signedDelegation0.delegation.delegatedAddress);
        verifyMoveSigner(moveData1, signedDelegation1.delegation.delegatedAddress);

        if (gameAddress != address(0)) {
            checkIfDelegatorsArePlayers(
                signedDelegation0.delegation.delegatorAddress,
                signedDelegation1.delegation.delegatorAddress,
                gameAddress
            );
        }

        require(moveData0.move.expiration >= block.timestamp, "move0 expired");
        require(moveData1.move.expiration >= block.timestamp, "move1 expired");

        moves = moveData1.moves;

        if (gameAddress != address(0)) {
            uint16[] memory onChainMoves = chessGame.getLatestGameMoves(gameAddress);

            if (onChainMoves.length > 0) {
                uint16[] memory combinedMoves = new uint16[](onChainMoves.length + moves.length);
                for (uint256 i = 0; i < onChainMoves.length; i++) {
                    combinedMoves[i] = onChainMoves[i];
                }
                for (uint256 i = 0; i < moves.length; i++) {
                    combinedMoves[i + onChainMoves.length] = moves[i];
                }
                moves = combinedMoves;
            }
        }

        (outcome, gameState,,) = moveVerification.checkGameFromStart(moves);
        return (gameAddress, outcome, gameState, moves);
    }

    function decodeMoveData(bytes memory moveData) private pure returns (GaslessMoveData memory) {
        return abi.decode(moveData, (GaslessMoveData));
    }

    /// @dev typed signature verification
    function verifyMoveSigner(GaslessMoveData memory moveData, address signer) private view {
        bytes32 digest = _hashTypedDataV4(
            keccak256(
                abi.encode(
                    MOVE_METHOD_HASH,
                    moveData.move.gameAddress,
                    moveData.move.gameNumber,
                    moveData.move.expiration,
                    moveData.move.movesHash
                )
            )
        );
        // console.log("Verifier");
        // console.log(signer);
        // console.log(ECDSA.recover(digest, moveData.signature));
        require(ECDSA.recover(digest, moveData.signature) == signer, "299 invalid signature");
    }

    /*
      //// DELEGATED GASLESS MOVE VERIFICATION FUNCTIONS ////
    */

    /// @notice Create delegation data type helper function
    function createDelegation(address delegatorAddress, address delegatedAddress, address gameAddress)
        external
        pure
        returns (Delegation memory)
    {
        Delegation memory delegation = Delegation(delegatorAddress, delegatedAddress, gameAddress);
        return delegation;
    }

    /// @notice Encode signed delegation helper function
    function encodeSignedDelegation(Delegation memory delegation, bytes memory signature)
        external
        pure
        returns (bytes memory)
    {
        SignedDelegation memory signedDelegation = SignedDelegation(delegation, signature);
        return abi.encode(signedDelegation);
    }

    /// @notice Decode Signed Delegation
    function decodeSignedDelegation(bytes memory signedDelegationBytes)
        public
        pure
        returns (SignedDelegation memory signedDelegation)
    {
        return abi.decode(signedDelegationBytes, (SignedDelegation));
    }

    /// @notice Check if delegators match players in gameAddress
    function checkIfDelegatorsArePlayers(address delegator0, address delegator1, address gameAddress) private view {
        if (gameAddress == address(0)) {
            return;
        } else {
            (address player0, address player1) = chessGame.getGamePlayers(gameAddress);
            require(
                (delegator0 == player0 && delegator1 == player1) || (delegator1 == player0 && delegator0 == player1),
                "players don't match"
            );
        }
    }

    /// @notice Check if delegator matches player in gameAddress
    function checkIfDelegatorIsPlayer(address delegator, address gameAddress) private view {
        if (gameAddress == address(0)) {
            return;
        } else {
            (address player0, address player1) = chessGame.getGamePlayers(gameAddress);
            require(delegator == player0 || delegator == player1, "not in match");
        }
    }

    /// @dev typed signature verification
    function verifyDelegation(SignedDelegation memory signedDelegation) private view {
        bytes32 digest = _hashTypedDataV4(
            keccak256(
                abi.encode(
                    DELEGATION_METHOD_HASH,
                    signedDelegation.delegation.delegatorAddress,
                    signedDelegation.delegation.delegatedAddress,
                    signedDelegation.delegation.gameAddress
                )
            )
        );
        require(
            ECDSA.recover(digest, signedDelegation.signature) == signedDelegation.delegation.delegatorAddress,
            "Invalid signature"
        );
    }
}
