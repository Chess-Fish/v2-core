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

import "./MoveVerification.sol";
import "./ChessGame.sol";

import "forge-std/console.sol";

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
contract GaslessGame is EIP712 {
    /*       */

    struct Delegation {
        address delegatorAddress;
        address delegatedAddress;
        address gameAddress;
    }

    struct SignedDelegation {
        Delegation delegation;
        bytes signature;
    }

    /// @dev MoveVerification contract
    MoveVerification public immutable moveVerification;

    // @dev ChessGame contract
    ChessGame public chessGame;

    /// @dev address deployer
    address deployer;

    /// @dev EIP-712 typed move signature
    bytes32 public immutable MOVE_METHOD_HASH;

    /// @dev EIP-712 typed delegation signature
    bytes32 public immutable DELEGATION_METHOD_HASH;

    modifier onlyDeployer() {
        _;
        require(msg.sender == deployer);
    }

    constructor(address moveVerificationAddress) EIP712("ChessFish", "1") {
        moveVerification = MoveVerification(moveVerificationAddress);
        deployer = msg.sender;

        MOVE_METHOD_HASH = keccak256(
            "GaslessMove(address gameAddress,uint gameNumber,uint expiration,uint16[] moves)"
        );

        DELEGATION_METHOD_HASH = keccak256(
            "Delegation(address delegatorAddress,address delegatedAddress,address gameAddress)"
        );
    }

    struct GaslessMove {
        address gameAddress;
        uint256 gameNumber;
        uint256 expiration;
        uint16[] moves;
    }

    struct GaslessMoveData {
        GaslessMove move;
        bytes signature;
    }

    function verifyDelegation(bytes memory rawSignedDelegation) external returns (bool) {
        SignedDelegation memory signedDelegation =
            decodeSignedDelegation(rawSignedDelegation);
        verifyDelegation(signedDelegation);
    }

    function verifyGaslessMove(bytes memory rawMoveData) external returns (bool) {
        GaslessMoveData memory moveData = decodeMoveData(rawMoveData);

        // verifyMoveSigner(moveData, moveData.signature);

        return true;
    }

    function verifyMoveDelegated(
        bytes memory rawSignedDelegation,
        bytes memory rawMoveData
    )
        external
        view
    {
        SignedDelegation memory signedDelegation =
            decodeSignedDelegation(rawSignedDelegation);
        verifyDelegation(signedDelegation);

        GaslessMoveData memory moveData = decodeMoveData(rawMoveData);

        console.log(signedDelegation.delegation.delegatedAddress);

        verifyMoveSigner(
            moveData, moveData.signature, signedDelegation.delegation.delegatedAddress
        );

    }

    function decodeMoveData(bytes memory moveData)
        internal
        pure
        returns (GaslessMoveData memory)
    {
        return abi.decode(moveData, (GaslessMoveData));
    }

    /// @notice set ChessGame contract
    function setChessGame(address _chessGame) external onlyDeployer {
        chessGame = ChessGame(_chessGame);
    }


    /// @notice Decodes gasless move message and returns game address
    function decodegameAddress(bytes memory message) internal pure returns (address) {
        GaslessMove memory move = abi.decode(message, (GaslessMove));
        return move.gameAddress;
    }

    /// @dev typed signature verification
    function verifyMoveSigner(
        GaslessMoveData memory moveData,
        bytes memory signature,
        address signer
    )
        internal
        view
    {
        bytes32 digest = _hashTypedDataV4(
            keccak256(
                abi.encode(
                    MOVE_METHOD_HASH,
                    moveData.move.gameAddress,
                    moveData.move.gameNumber,
                    moveData.move.expiration,
                    moveData.move.moves
                )
            )
        );
        console.logBytes32(digest);
        console.log(signer);
        console.log(ECDSA.recover(digest, signature));

        require(ECDSA.recover(digest, signature) == signer, "140 invalid signature");
    }


    function verifyGameView(
        bytes[] memory messages,
        bytes[] memory signatures
    )
        public
        view
        returns (address gameAddress, uint8 outcome, uint16[] memory moves)
    { }

    /*
      //// DELEGATED GASLESS MOVE VERIFICATION FUNCTIONS ////
      */

    /// @notice Create delegation data type helper function
    function createDelegation(
        address delegatorAddress,
        address delegatedAddress,
        address gameAddress
    )
        external
        pure
        returns (Delegation memory)
    {
        Delegation memory delegation =
            Delegation(delegatorAddress, delegatedAddress, gameAddress);
        return delegation;
    }

    /// @notice Encode signed delegation helper function
    function encodeSignedDelegation(
        Delegation memory delegation,
        bytes memory signature
    )
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
    function checkIfAddressesArePlayers(
        address delegator0,
        address delegator1,
        address gameAddress
    )
        internal
        view
    {
        (address player0, address player1) = chessGame.getGamePlayers(gameAddress);
        require(delegator0 == player0 && delegator1 == player1, "players don't match");
    }

    /// @notice Check delegations
    function checkDelegations(
        SignedDelegation memory signedDelegation0,
        SignedDelegation memory signedDelegation1
    )
        internal
        view
    {
        require(
            signedDelegation0.delegation.gameAddress
                == signedDelegation1.delegation.gameAddress,
            "non matching addresses"
        );

        verifyDelegation(signedDelegation0);
        verifyDelegation(signedDelegation1);
    }

    /// @dev typed signature verification
    function verifyDelegation(SignedDelegation memory signedDelegation) internal view {
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
            ECDSA.recover(digest, signedDelegation.signature)
                == signedDelegation.delegation.delegatorAddress,
            "Invalid signature"
        );
    }

    function verifyGameViewDelegated(
        bytes[2] memory delegations,
        bytes[] memory messages,
        bytes[] memory signatures
    )
        external
        view
        returns (address gameAddress, uint8 outcome, uint16[] memory moves)
    { }

    /*     /// @notice Verify game moves via delegated signature
    function verifyGameViewDelegated(
        bytes[2] memory delegations,
        bytes[] memory messages,
        bytes[] memory signatures
    )
        external
        view
        returns (address gameAddress, uint8 outcome, uint16[] memory moves)
    {
        require(messages.length == signatures.length, "573");

    SignedDelegation memory signedDelegation0 = decodeSignedDelegation(delegations[0]);
    SignedDelegation memory signedDelegation1 = decodeSignedDelegation(delegations[1]);

        checkDelegations(signedDelegation0, signedDelegation1);

        gameAddress = signedDelegation0.delegation.gameAddress;

        GaslessMoveData memory moveData;
        moveData.player0 = signedDelegation0.delegation.delegatedAddress;
        moveData.player1 = signedDelegation1.delegation.delegatedAddress;
        moveData.move.gameAddress = gameAddress;

        checkIfAddressesArePlayers(
            signedDelegation0.delegation.delegatorAddress,
            signedDelegation1.delegation.delegatorAddress,
            gameAddress
        );

        address playerToMove = chessGame.getPlayerMove(gameAddress)
            == signedDelegation0.delegation.delegatorAddress
            ? moveData.player0
            : moveData.player1;

        moves = verifyMoves(playerToMove, moveData, messages, signatures);

        uint16[] memory onChainMoves = chessGame.getLatestGameMoves(gameAddress);
        if (onChainMoves.length > 0) {
            uint16[] memory combinedMoves =
                new uint16[](onChainMoves.length + moves.length);
            for (uint256 i = 0; i < onChainMoves.length; i++) {
                combinedMoves[i] = onChainMoves[i];
            }
            for (uint256 i = 0; i < moves.length; i++) {
                combinedMoves[i + onChainMoves.length] = moves[i];
            }
            moves = combinedMoves;
        }

        (outcome,,,) = moveVerification.checkGameFromStart(moves);

        return (gameAddress, outcome, moves);
    } */
}
