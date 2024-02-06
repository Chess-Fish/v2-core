// SPDX-License-Identifier: MIT

/* 
   _____ _                   ______ _     _     
  / ____| |                 |  ____(_)   | |    
 | |    | |__   ___  ___ ___| |__   _ ___| |__  
 | |    | '_ \ / _ \/ __/ __|  __| | / __| '_ \ 
 | |____| | | |  __/\__ \__ \ |    | \__ \ | | |
  \_____|_| |_|\___||___/___/_|    |_|___/_| |_|
                             
*/

pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import "./interfaces/interfaces.sol";
import "./MoveHelper.sol";

import "./GaslessGame.sol";

/**
 * @title ChessFish GameData Contract
 * @author ChessFish
 * @notice https://github.com/Chess-Fish
 *
 * @dev This contract is designed for managing chess games between users,
 * saving game moves, and handling the payout of 1v1 matches.
 *  The Tournament contract can call into this contract to
 * create tournament matches among users.
 */
contract ChessGame is MoveHelper {
    using SafeERC20 for IERC20;

    struct GameData {
        address player0;
        address player1;
        address gameToken;
        uint256 tokenAmount;
        uint256 numberOfGames;
        bool hasPlayerAccepted;
        uint256 timeLimit;
        uint256 timeLastMove;
        uint256 timePlayer0;
        uint256 timePlayer1;
        bool isTournament;
        bool isComplete;
        bool hasBeenPaid;
    }

    struct GameStatus {
        bool isPlayer0White;
        uint256 winsPlayer0;
        uint256 winsPlayer1;
    }

    struct GameMoves {
        uint16[] moves;
    }

    struct GaslessMoveData {
        address signer;
        address player0;
        address player1;
        uint16 move;
        uint256 moveNumber;
        uint256 expiration;
        bytes32 messageHash;
    }

    /// @dev address game => GameData
    mapping(address => GameData) public gameData;

    /// @dev address game => GamePrize
    mapping(address => uint256) public gamePrizes;

    /// @dev address game => gameID => Game
    mapping(address => mapping(uint256 => GameMoves)) gameMoves;

    /// @dev address game => gameIDs
    mapping(address => uint256[]) gameIDs;

    /// @dev address game => Player Wins
    mapping(address => GameStatus) public gameStatus;

    /// @dev player can see game challenges
    mapping(address => address[]) public userGames;

    /// @dev address[] games
    address[] public allGames;

    /// @dev CFSH Token Address
    address public ChessFishToken;

    /// @dev Dividend Splitter contract
    address public DividendSplitter;

    /// @dev ChessFish Winner NFT contract
    address public ChessFishNFT;

    /// @dev Gasless Game Helper Contract
    GaslessGame public gaslessGame;

    constructor(
        address moveVerificationAddress,
        address _GaslessGame,
        address _DividendSplitter,
        address _ChessFishNFT
    ) {
        moveVerification = MoveVerification(moveVerificationAddress);
        gaslessGame = GaslessGame(_GaslessGame);

        initPieces();

        DividendSplitter = _DividendSplitter;
        ChessFishNFT = _ChessFishNFT;

        deployer = msg.sender;
    }

    /* 
    //// EVENTS ////
    */

    event createGameDataEvent(
        address gameAddress,
        address gameToken,
        uint256 tokenAmount,
        uint256 timeLimit,
        uint256 numberOfGames
    );
    event acceptWagerEvent(address gameAddress, address userAddress);
    event playMoveEvent(address gameAddress, uint16 move);
    event payoutWagerEvent(
        address gameAddress,
        address winner,
        address gameToken,
        uint256 tokenAmount,
        uint256 protocolFee
    );
    event cancelWagerEvent(address gameAddress, address userAddress);

    /* 
    //// VIEW FUNCTIONS ////
    */

    function getAllGamesCount() external view returns (uint256) {
        return allGames.length;
    }

    function getAllGameAddresses() external view returns (address[] memory) {
        return allGames;
    }

    function getAllUserGames(address player)
        external
        view
        returns (address[] memory)
    {
        return userGames[player];
    }

    function getGameLength(address gameAddress)
        external
        view
        returns (uint256)
    {
        return gameIDs[gameAddress].length;
    }

    function getGameMoves(
        address gameAddress,
        uint256 gameID
    )
        external
        view
        returns (GameMoves memory)
    {
        return gameMoves[gameAddress][gameID];
    }

    function getLatestGameMoves(address gameAddress)
        external
        view
        returns (uint16[] memory)
    {
        return gameMoves[gameAddress][gameIDs[gameAddress].length].moves;
    }

    function getNumberOfGamesPlayed(address gameAddress)
        internal
        view
        returns (uint256)
    {
        return gameIDs[gameAddress].length + 1;
    }

    function getGameData(address gameAddress)
        external
        view
        returns (GameData memory)
    {
        return gameData[gameAddress];
    }

    function getGamePlayers(address gameAddress)
        external
        view
        returns (address, address)
    {
        return
            (gameData[gameAddress].player0, gameData[gameAddress].player1);
    }

    /// @notice Get game Status
    /// @dev Returns the current status of a specific game.
    /// @param gameAddress The address of the game for which the status is
    /// being requested.
    /// @return player0 The address of the first player in the game.
    /// @return player1 The address of the second player in the game.
    /// @return winsPlayer0 The number of wins recorded for player0.
    /// @return winsPlayer1 The number of wins recorded for player1.
    function getGameStatus(address gameAddress)
        public
        view
        returns (address, address, uint256, uint256)
    {
        return (
            gameData[gameAddress].player0,
            gameData[gameAddress].player1,
            gameStatus[gameAddress].winsPlayer0,
            gameStatus[gameAddress].winsPlayer1
        );
    }

    /// @notice Checks how much time is remaining in game
    /// @dev using int to quickly check if game lost on time and to prevent
    /// underflow revert
    /// @return timeRemainingPlayer0
    /// @return timeRemainingPlayer1
    function checkTimeRemaining(address gameAddress)
        public
        view
        returns (int256, int256)
    {
        address player0 = gameData[gameAddress].player0;

        uint256 player0Time = gameData[gameAddress].timePlayer0;
        uint256 player1Time = gameData[gameAddress].timePlayer1;

        uint256 elapsedTime =
            block.timestamp - gameData[gameAddress].timeLastMove;
        int256 timeLimit = int256(gameData[gameAddress].timeLimit);

        address player = getPlayerMove(gameAddress);

        int256 timeRemainingPlayer0;
        int256 timeRemainingPlayer1;

        if (player == player0) {
            timeRemainingPlayer0 = timeLimit - int256(elapsedTime + player0Time);
            timeRemainingPlayer1 = timeLimit - int256(player1Time);
        } else {
            timeRemainingPlayer0 = timeLimit - int256(player0Time);
            timeRemainingPlayer1 = timeLimit - int256(elapsedTime + player1Time);
        }

        return (timeRemainingPlayer0, timeRemainingPlayer1);
    }

    /// @notice Gets the address of the player whose turn it is
    /// @param gameAddress address of the wager
    /// @return playerAddress
    function getPlayerMove(address gameAddress)
        public
        view
        returns (address)
    {
        uint256 gameID = gameIDs[gameAddress].length;
        uint256 moves = gameMoves[gameAddress][gameID].moves.length;

        bool isPlayer0White = gameStatus[gameAddress].isPlayer0White;

        if (isPlayer0White) {
            if (moves % 2 == 1) {
                return gameData[gameAddress].player1;
            } else {
                return gameData[gameAddress].player0;
            }
        } else {
            if (moves % 2 == 1) {
                return gameData[gameAddress].player0;
            } else {
                return gameData[gameAddress].player1;
            }
        }
    }

    /// @notice Returns boolean if player is white or not
    /// @param gameAddress address of the wager
    /// @param player address player
    /// @return isPlayerWhite
    function isPlayerWhite(
        address gameAddress,
        address player
    )
        public
        view
        returns (bool)
    {
        if (gameData[gameAddress].player0 == player) {
            return gameStatus[gameAddress].isPlayer0White;
        } else {
            return !gameStatus[gameAddress].isPlayer0White;
        }
    }

    /// @notice Gets the game status for the last played game in a wager
    /// @param gameAddress address of the wager
    /// @return outcome,
    /// @return gameState
    /// @return player0State
    /// @return player1State
    function getGameBoardState(address gameAddress)
        public
        view
        returns (uint8, uint256, uint32, uint32)
    {
        uint256 gameID = gameIDs[gameAddress].length;
        uint16[] memory moves = gameMoves[gameAddress][gameID].moves;

        if (moves.length == 0) {
            moves = gameMoves[gameAddress][gameID - 1].moves;
        }

        (
            uint8 outcome,
            uint256 gameState,
            uint32 player0State,
            uint32 player1State
        ) = moveVerification.checkGameFromStart(moves);

        return (outcome, gameState, player0State, player1State);
    }

    /// @notice Returns chainId
    /// @dev used for ensuring unique hash independent of chain
    /// @return chainId
    function getChainId() internal view returns (uint256) {
        uint256 chainId;
        assembly {
            chainId := chainid()
        }
        return chainId;
    }

    /// @notice Generates unique hash for a game wager
    /// @dev using keccak256 to generate a hash which is converted to an address
    /// @return gameAddress
    function getgameAddress(GameData memory game)
        internal
        view
        returns (address)
    {
        require(game.player0 != game.player1, "players must be different");
        require(game.numberOfGames % 2 == 1, "number of games must be odd");

        uint256 blockNumber = block.number;
        uint256 chainId = getChainId();
        bytes32 blockHash = blockhash(blockNumber);

        bytes32 salt = keccak256(
            abi.encodePacked(
                game.player0,
                game.player1,
                game.gameToken,
                game.tokenAmount,
                game.timeLimit,
                game.numberOfGames,
                blockNumber,
                chainId,
                blockHash
            )
        );

        address gameAddress = address(uint160(bytes20(salt)));

        return gameAddress;
    }

    /* 
    //// GASLESS GAME FUNCTIONS ////
    */

    /// @notice Verifies game moves and updates the state of the wager
    /// @return isEndGame
    function verifyGameUpdateState(
        bytes[] memory message,
        bytes[] memory signature
    )
        external
        returns (bool)
    {
        (address gameAddress, uint256 outcome, uint16[] memory moves) =
            gaslessGame.verifyGameView(message, signature);

        uint256 gameID = gameIDs[gameAddress].length;
        gameMoves[gameAddress][gameID].moves = moves;

        if (outcome != 0) {
            updateWagerState(gameAddress);
            return true;
        }
        if (outcome == 0) {
            return updateWagerStateInsufficientMaterial(gameAddress);
        } else {
            return false;
        }
    }

    /// @notice Verifies game moves and updates the state of the wager
    /// @return isEndGame
    function verifyGameUpdateStateDelegated(
        bytes[2] memory delegations,
        bytes[] memory messages,
        bytes[] memory signatures
    )
        external
        returns (bool)
    {
        (address gameAddress, uint256 outcome, uint16[] memory moves) =
        gaslessGame.verifyGameViewDelegated(delegations, messages, signatures);

        uint256 gameID = gameIDs[gameAddress].length;
        gameMoves[gameAddress][gameID].moves = moves;

        if (outcome != 0) {
            updateWagerState(gameAddress);
            return true;
        }
        if (outcome == 0) {
            return updateWagerStateInsufficientMaterial(gameAddress);
        } else {
            return false;
        }
    }

    /* 
    //// TOURNAMENT FUNCTIONS ////
    */

    // Tournament Contract Address
    address public TournamentHandler;

    modifier onlyTournament() {
        require(
            msg.sender == address(TournamentHandler), "not tournament contract"
        );
        _;
    }

    /// @notice Adds Tournament contract
    function addTournamentHandler(address _tournamentHandler)
        external
        OnlyDeployer
    {
        TournamentHandler = _tournamentHandler;
    }

    /// @notice Starts tournament wagers
    function startWagersInTournament(address gameAddress)
        external
        onlyTournament
    {
        gameData[gameAddress].timeLastMove = block.timestamp;
    }

    /// @notice Creates a wager between two players
    /// @dev only the tournament contract can call
    /// @return gameAddress created wager address
    function createGameWagerTournamentSingle(
        address player0,
        address player1,
        address gameToken,
        uint256 wagerAmount,
        uint256 numberOfGames,
        uint256 timeLimit
    )
        external
        onlyTournament
        returns (address gameAddress)
    {
        GameData memory gameWager = GameData(
            player0,
            player1,
            gameToken,
            wagerAmount,
            numberOfGames,
            true, // hasPlayerAccepted
            timeLimit,
            0, // timeLastMove => setting to zero since tournament hasn't
                // started
            0, // timePlayer0
            0, // timePlayer1
            true, // isTournament
            false, // isComplete
            false // hasBeenPaid
        );
        gameAddress = getgameAddress(gameWager);

        gameData[gameAddress] = gameWager;

        GameStatus memory status = GameStatus(false, 0, 0);
        gameStatus[gameAddress] = status;

        userGames[player0].push(gameAddress);
        userGames[player1].push(gameAddress);

        // update global state
        allGames.push(gameAddress);

        emit createGameDataEvent(
            gameAddress, gameToken, wagerAmount, timeLimit, numberOfGames
        );

        return gameAddress;
    }

    /*
    //// WRITE FUNCTIONS ////
    */

    /// @notice Creates a 1v1 chess wager
    function createGameWager(
        address player1,
        address gameToken,
        uint256 wager,
        uint256 timeLimit,
        uint256 numberOfGames
    )
        external
        payable
        returns (address gameAddress)
    {
        GameData memory gameWager = GameData(
            msg.sender, // player0
            player1,
            gameToken,
            wager,
            numberOfGames,
            false, // hasPlayerAccepted
            timeLimit,
            0, // timeLastMove
            0, // timePlayer0
            0, // timePlayer1
            false, // isTournament
            false, // isComplete
            false // hasBeenPaid
        );

        IERC20(gameToken).safeTransferFrom(msg.sender, address(this), wager);

        gameAddress = getgameAddress(gameWager);

        require(
            gameData[gameAddress].player0 == address(0),
            "failed to create wager"
        );

        gameData[gameAddress] = gameWager;

        GameStatus memory status = GameStatus(false, 0, 0);
        gameStatus[gameAddress] = status;

        userGames[msg.sender].push(gameAddress);
        userGames[player1].push(gameAddress);

        // update global state
        allGames.push(gameAddress);

        emit createGameDataEvent(
            gameAddress, gameToken, wager, timeLimit, numberOfGames
        );

        return gameAddress;
    }

    /// @notice Player1 calls if they accept challenge
    function acceptWager(address gameAddress) external {
        address player1 = gameData[gameAddress].player1;

        if (player1 == address(0)) {
            gameData[gameAddress].player1 = msg.sender;
            userGames[msg.sender].push(gameAddress);
        } else {
            require(
                gameData[gameAddress].player1 == msg.sender,
                "msg.sender != player1"
            );
        }

        address gameToken = gameData[gameAddress].gameToken;
        uint256 wager = gameData[gameAddress].tokenAmount;

        gameData[gameAddress].hasPlayerAccepted = true;
        gameData[gameAddress].timeLastMove = block.timestamp;

        IERC20(gameToken).safeTransferFrom(msg.sender, address(this), wager);

        emit acceptWagerEvent(gameAddress, msg.sender);
    }

    /// @notice Plays move on the board
    /// @return bool true if endGame, adds extra game if stalemate
    function playMove(
        address gameAddress,
        uint16 move
    )
        external
        returns (bool)
    {
        require(getPlayerMove(gameAddress) == msg.sender, "Not your turn");
        require(
            getNumberOfGamesPlayed(gameAddress)
                <= gameData[gameAddress].numberOfGames,
            "Wager ended"
        );
        require(
            gameData[gameAddress].timeLastMove != 0,
            "Tournament not started yet"
        );

        /// @dev checking if time ran out
        updateTime(gameAddress, msg.sender);

        bool isEndgameTime = updateWagerStateTime(gameAddress);
        if (isEndgameTime) {
            return true;
        }

        uint256 gameID = gameIDs[gameAddress].length;
        uint256 size = gameMoves[gameAddress][gameID].moves.length;

        uint16[] memory moves = new uint16[](size + 1);

        /// @dev copy array
        for (uint256 i = 0; i < size;) {
            moves[i] = gameMoves[gameAddress][gameID].moves[i];
            unchecked {
                i++;
            }
        }

        /// @dev append move to last place in array
        moves[size] = move;

        /// @dev optimistically write to state
        gameMoves[gameAddress][gameID].moves = moves;

        /// @dev fails on invalid move
        bool isEndgame = updateWagerState(gameAddress);

        emit playMoveEvent(gameAddress, move);

        return isEndgame;
    }

    /// @notice Handles payout of wager
    /// @dev smallest wager amount is 18 wei before fees => 0
    function payoutWager(address gameAddress) external returns (bool) {
        require(
            gameData[gameAddress].player0 == msg.sender
                || gameData[gameAddress].player1 == msg.sender,
            "not listed"
        );
        require(
            gameData[gameAddress].isComplete == true, "wager not finished"
        );
        require(
            gameData[gameAddress].isTournament == false,
            "tournament payment handled by tournament contract"
        );
        require(gameData[gameAddress].hasBeenPaid == false, "already paid");

        gameData[gameAddress].hasBeenPaid = true;

        address winner;

        /// @dev if there was a stalemate and now both players have the same
        /// score
        /// @dev add another game to play, and return payout successful as false
        if (
            gameStatus[gameAddress].winsPlayer0
                == gameStatus[gameAddress].winsPlayer1
        ) {
            gameData[gameAddress].numberOfGames++;
            return false;
        }

        if (
            gameStatus[gameAddress].winsPlayer0
                > gameStatus[gameAddress].winsPlayer1
        ) {
            winner = gameData[gameAddress].player0;
        } else {
            winner = gameData[gameAddress].player1;
        }

        address token = gameData[gameAddress].gameToken;
        uint256 wagerAmount = gameData[gameAddress].tokenAmount * 2;
        uint256 prize = gamePrizes[gameAddress];

        gameData[gameAddress].tokenAmount = 0;
        gamePrizes[gameAddress] = 0;

        /// @dev Mint NFT for Winner
        IChessFishNFT(ChessFishNFT).awardWinner(winner, gameAddress);

        /// @dev 5% shareholder fee
        uint256 shareHolderFee = ((wagerAmount + prize) * protocolFee) / 10_000;
        uint256 wagerPayout = (wagerAmount + prize) - shareHolderFee;

        IERC20(token).safeTransfer(DividendSplitter, shareHolderFee);
        IERC20(token).safeTransfer(winner, wagerPayout);

        emit payoutWagerEvent(
            gameAddress, winner, token, wagerPayout, protocolFee
        );

        return true;
    }

    /// @notice mint tournament winner NFT
    function mintWinnerNFT(address gameAddress) external {
        require(
            gameData[gameAddress].isComplete == true, "wager not finished"
        );
        require(gameData[gameAddress].hasBeenPaid == false, "already paid");

        gameData[gameAddress].hasBeenPaid == true;

        (address player0, address player1, uint256 wins0, uint256 wins1) =
            getGameStatus(gameAddress);

        address winner;
        if (wins0 > wins1) {
            winner = player0;
        } else {
            winner = player1;
        }

        IChessFishNFT(ChessFishNFT).awardWinner(winner, gameAddress);
    }

    /// @notice Cancel wager
    /// @dev cancel wager only if other player has not yet accepted
    /// @dev && only if msg.sender is one of the players
    function cancelWager(address gameAddress) external {
        require(
            gameData[gameAddress].hasPlayerAccepted == false, "in progress"
        );
        require(gameData[gameAddress].player0 == msg.sender, "not listed");
        require(
            gameData[gameAddress].isTournament == false,
            "cannot cancel tournament wager"
        );

        address token = gameData[gameAddress].gameToken;
        uint256 wagerAmount = gameData[gameAddress].tokenAmount;

        gameData[gameAddress].tokenAmount = 0;

        IERC20(token).safeTransfer(msg.sender, wagerAmount);

        emit cancelWagerEvent(gameAddress, msg.sender);
    }

    /// @notice Updates the state of the wager if player time is < 0
    /// @dev check when called with timeout w tournament
    /// @dev set to public so that anyone can update time if player disappears
    /// @return wasUpdated returns true if status was updated
    function updateWagerStateTime(address gameAddress) public returns (bool) {
        require(
            getNumberOfGamesPlayed(gameAddress)
                <= gameData[gameAddress].numberOfGames,
            "wager ended"
        );
        require(
            gameData[gameAddress].timeLastMove != 0,
            "tournament match not started yet"
        );

        (int256 timePlayer0, int256 timePlayer1) =
            checkTimeRemaining(gameAddress);

        uint256 addedWins = gameData[gameAddress].numberOfGames
            - getNumberOfGamesPlayed(gameAddress) + 1;

        if (timePlayer0 < 0) {
            gameStatus[gameAddress].winsPlayer1 += addedWins;
            gameData[gameAddress].isComplete = true;
            return true;
        }
        if (timePlayer1 < 0) {
            gameStatus[gameAddress].winsPlayer0 += addedWins;
            gameData[gameAddress].isComplete = true;
            return true;
        }
        return false;
    }

    /// @notice Update wager state if insufficient material
    /// @dev set to public so that anyone can update
    /// @return wasUpdated returns true if status was updated
    function updateWagerStateInsufficientMaterial(address gameAddress)
        public
        returns (bool)
    {
        require(
            getNumberOfGamesPlayed(gameAddress)
                <= gameData[gameAddress].numberOfGames,
            "wager ended"
        );

        uint256 gameID = gameIDs[gameAddress].length;
        uint16[] memory moves = gameMoves[gameAddress][gameID].moves;

        (, uint256 gameState,,) = moveVerification.checkGameFromStart(moves);

        bool isInsufficientMaterial =
            moveVerification.isStalemateViaInsufficientMaterial(gameState);

        if (isInsufficientMaterial) {
            gameStatus[gameAddress].winsPlayer0 += 1;
            gameStatus[gameAddress].winsPlayer1 += 1;
            gameStatus[gameAddress].isPlayer0White =
                !gameStatus[gameAddress].isPlayer0White;
            gameIDs[gameAddress].push(gameIDs[gameAddress].length);
            gameData[gameAddress].numberOfGames += 1;
            return true;
        } else {
            return false;
        }
    }

    /// @notice Deposits prize to wager address
    /// @dev used to deposit prizes to wager
    function depositToWager(address gameAddress, uint256 amount) external {
        require(!gameData[gameAddress].isComplete, "wager completed");
        IERC20(gameData[gameAddress].gameToken).safeTransferFrom(
            msg.sender, address(this), amount
        );
        gamePrizes[gameAddress] += amount;
    }

    /// @notice Checks the moves of the wager and updates state if neccessary
    /// @return isEndGame
    function updateWagerState(address gameAddress) private returns (bool) {
        require(
            getNumberOfGamesPlayed(gameAddress)
                <= gameData[gameAddress].numberOfGames,
            "wager ended"
        );

        uint256 gameID = gameIDs[gameAddress].length;
        uint16[] memory moves = gameMoves[gameAddress][gameID].moves;

        // fails on invalid move
        (uint8 outcome,,,) = moveVerification.checkGameFromStart(moves);

        // Inconclusive Outcome
        if (outcome == 0) {
            return false;
        }
        // Stalemate
        if (outcome == 1) {
            gameStatus[gameAddress].winsPlayer0 += 1;
            gameStatus[gameAddress].winsPlayer1 += 1;
            gameStatus[gameAddress].isPlayer0White =
                !gameStatus[gameAddress].isPlayer0White;
            gameIDs[gameAddress].push(gameIDs[gameAddress].length);
            gameData[gameAddress].numberOfGames += 1;
            return true;
        }
        // Checkmate White
        if (outcome == 2) {
            if (isPlayerWhite(gameAddress, gameData[gameAddress].player0)) {
                gameStatus[gameAddress].winsPlayer0 += 1;
            } else {
                gameStatus[gameAddress].winsPlayer1 += 1;
            }
            gameStatus[gameAddress].isPlayer0White =
                !gameStatus[gameAddress].isPlayer0White;
            gameIDs[gameAddress].push(gameIDs[gameAddress].length);
            if (
                gameIDs[gameAddress].length
                    == gameData[gameAddress].numberOfGames
            ) {
                gameData[gameAddress].isComplete = true;
            }
            return true;
        }
        // Checkmate Black
        if (outcome == 3) {
            if (isPlayerWhite(gameAddress, gameData[gameAddress].player0)) {
                gameStatus[gameAddress].winsPlayer1 += 1;
            } else {
                gameStatus[gameAddress].winsPlayer0 += 1;
            }
            gameStatus[gameAddress].isPlayer0White =
                !gameStatus[gameAddress].isPlayer0White;
            gameIDs[gameAddress].push(gameIDs[gameAddress].length);
            if (
                gameIDs[gameAddress].length
                    == gameData[gameAddress].numberOfGames
            ) {
                gameData[gameAddress].isComplete = true;
            }
            return true;
        }
        return false;
    }

    /// @notice Updates wager time
    function updateTime(address gameAddress, address player) private {
        bool isPlayer0 = gameData[gameAddress].player0 == player;
        uint256 startTime = gameData[gameAddress].timeLastMove;
        uint256 currentTime = block.timestamp;
        uint256 dTime = currentTime - startTime;

        if (isPlayer0) {
            gameData[gameAddress].timePlayer0 += dTime;
            gameData[gameAddress].timeLastMove = currentTime; // Update the
                // start time for the next turn
        } else {
            gameData[gameAddress].timePlayer1 += dTime;
            gameData[gameAddress].timeLastMove = currentTime; // Update the
                // start time for the next turn
        }
    }
}
