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

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./ChessGame.sol";
import "./ERC721/ChessFishNFT.sol";

/**
 * @title ChessFish Tournament Contract
 * @author ChessFish
 * @notice https://github.com/Chess-Fish
 *
 * @notice This contract handles the functionality of creating Round Robbin style
 * tournaments as well as handling the payouts of ERC-20 tokens to tournament winners.
 * This contract creates games in the ChessGame smart contract and then reads the result
 * of the created games to calculate the number of wins for each user in the tournament.
 */
contract Tournament {
    using SafeERC20 for IERC20;

    struct TournamentParams {
        uint256 numberOfPlayers; // number of players in tournament
        address[] authedPlayers; // authorized players
        address[] joinedPlayers; // joined players
        bool isByInvite; // is tournament by invite only
        uint256 numberOfGames; // number of games per match
        address gameToken; // game token address
        uint256 tokenAmount; // token amount
        uint256 prizePool; // size of prize pool
        bool isInProgress; // is tournament in progress
        uint256 creationTime; // unix timestamp creation time
        uint256 startTime; // unix timestamp start time
        uint256 timeLimit; // timeLimit for tournament
        bool isComplete; // is tournament complete
    }

    struct PlayerWins {
        address player; // address player
        uint256 wins; // number of wins
    }

    /// @dev 7% protocol fee
    uint256 protocolFee = 700;

    /// @dev 56% 37%
    uint256[3] public payoutProfile3 = [5600, 3700];

    /// @dev 33% 29% 18% 13%
    uint256[4] public payoutProfile4_9 = [3300, 2900, 1800, 1300];

    /// @dev 36.5% 23% 13.5% 10% 5% 2.5% 2.5%
    uint256[7] public payoutProfile10_25 = [3650, 2300, 1350, 1000, 500, 250, 250];

    /// @dev increments for each new tournament
    uint256 public tournamentNonce;

    /// @dev uint tournamentNonce => Tournament struct
    mapping(uint256 => TournamentParams) public tournaments;

    /// @dev uint tournament nonce => address[] gameIDs
    mapping(uint256 => address[]) private tournamentGameAddresses;

    /// @dev uint tournamentID => address player => wins
    mapping(uint256 => mapping(address => uint256)) public tournamentWins;

    address deployer;
    ChessGame public chessGame;
    address public PaymentSplitter;
    ChessFishNFT public cfshNFT;

    constructor() {
        deployer = msg.sender;
    }

    modifier onlyDeployer() {
        require(deployer == msg.sender);
        _;
    }

    bool isSet;

    modifier notInitialized() {
        require(isSet == false);
        isSet = true;
        _;
    }

    function initialize(address _chessGame, address _paymentSplitter, address _chessFishNFT)
        public
        onlyDeployer
        notInitialized
    {
        chessGame = ChessGame(_chessGame);
        PaymentSplitter = _paymentSplitter;
        cfshNFT = ChessFishNFT(_chessFishNFT);
    }
    /* 
    //// VIEW FUNCTIONS ////
    */

    /// @notice Returns players in tournament
    function getTournamentPlayers(uint256 tournamentID) external view returns (address[] memory) {
        return (tournaments[tournamentID].joinedPlayers);
    }

    /// @notice Returns authorized players in tournament
    function getAuthorizedPlayers(uint256 tournamentID) external view returns (address[] memory) {
        return (tournaments[tournamentID].authedPlayers);
    }

    /// @notice Returns game addresses in tournament
    function getTournamentGameAddresses(uint256 tournamentID) external view returns (address[] memory) {
        return (tournamentGameAddresses[tournamentID]);
    }

    /// @notice Returns the game addresses for player and tournament ID
    function getTournamentGamesPlayer(address player, uint256 tournamentID) public view returns (address[] memory) {
        address[] memory tournamentGames = tournamentGameAddresses[tournamentID];
        address[] memory playerGames = chessGame.getAllUserGames(player);
        address[] memory tempGames = new address[](tournamentGames.length);
        uint256 count = 0;

        for (uint256 i = 0; i < tournamentGames.length; i++) {
            for (uint256 j = 0; j < playerGames.length; j++) {
                if (tournamentGames[i] == playerGames[j]) {
                    tempGames[count] = tournamentGames[i];
                    count++;
                    break;
                }
            }
        }
        return tempGames;
    }

    /// @notice Calculates score
    /// @dev designed as view only
    /// @dev returns addresses[] players
    /// @dev returns uint[] scores
    function viewTournamentScore(uint256 tournamentID) external view returns (address[] memory, uint256[] memory) {
        address[] memory players = tournaments[tournamentID].joinedPlayers;
        uint256 numberOfGamesInTournament = tournamentGameAddresses[tournamentID].length;

        uint256[] memory wins = new uint256[](players.length);

        for (uint256 i = 0; i < numberOfGamesInTournament;) {
            (address player0, address player1, uint256 wins0, uint256 wins1) =
                chessGame.getGameStatus(tournamentGameAddresses[tournamentID][i]);

            for (uint256 j = 0; j < players.length;) {
                if (players[j] == player0) wins[j] += wins0;
                if (players[j] == player1) wins[j] += wins1;
                unchecked {
                    j++;
                }
            }
            unchecked {
                i++;
            }
        }

        return (players, wins);
    }

    /// @notice Returns the rank of a player in a tournament based on wins
    /// @param tournamentID The ID of the tournament
    /// @param playerAddress The address of the player whose rank is to be found
    /// @return rank The rank of the player in the tournament (1-based index), returns 0
    /// if the player did not join or the tournament is not finished
    function getPlayerRankByWins(uint256 tournamentID, address playerAddress) public view returns (uint256 rank) {
        address[] memory players = tournaments[tournamentID].joinedPlayers;
        PlayerWins[] memory playerWinsArray = new PlayerWins[](players.length);

        // Populate the playerWinsArray
        for (uint256 i = 0; i < players.length;) {
            playerWinsArray[i] = PlayerWins({player: players[i], wins: tournamentWins[tournamentID][players[i]]});
            unchecked {
                i++;
            }
        }

        // Bubble sort (consider optimizing for large arrays)
        bool swapped;
        for (uint256 i = 0; i < playerWinsArray.length - 1;) {
            swapped = false;
            for (uint256 j = 0; j < playerWinsArray.length - i - 1;) {
                if (playerWinsArray[j].wins < playerWinsArray[j + 1].wins) {
                    // swap
                    (playerWinsArray[j], playerWinsArray[j + 1]) = (playerWinsArray[j + 1], playerWinsArray[j]);
                    swapped = true;
                }
                unchecked {
                    j++;
                }
            }
            if (!swapped) break;
            unchecked {
                i++;
            }
        }

        // Find the rank of the playerAddress
        for (uint256 i = 0; i < playerWinsArray.length; i++) {
            if (playerWinsArray[i].player == playerAddress) {
                return i + 1; // Return 1-based rank
            }
        }

        return 0; // Player not found or did not join
    }

    /// @notice Returns addresses winners sorted by highest wins
    function getPlayersSortedByWins(uint256 tournamentID) public view returns (address[] memory) {
        address[] memory players = tournaments[tournamentID].joinedPlayers;
        PlayerWins[] memory playerWinsArray = new PlayerWins[](players.length);

        for (uint256 i = 0; i < players.length;) {
            playerWinsArray[i] = PlayerWins({player: players[i], wins: tournamentWins[tournamentID][players[i]]});
            unchecked {
                i++;
            }
        }

        bool swapped;
        for (uint256 i = 0; i < playerWinsArray.length - 1;) {
            swapped = false;
            for (uint256 j = 0; j < playerWinsArray.length - i - 1;) {
                if (playerWinsArray[j].wins < playerWinsArray[j + 1].wins) {
                    // swap
                    (playerWinsArray[j], playerWinsArray[j + 1]) = (playerWinsArray[j + 1], playerWinsArray[j]);
                    swapped = true;
                }
                unchecked {
                    j++;
                }
            }
            if (!swapped) break;
            unchecked {
                i++;
            }
        }

        address[] memory sortedPlayers = new address[](players.length);
        for (uint256 i = 0; i < playerWinsArray.length;) {
            sortedPlayers[i] = playerWinsArray[i].player;
            unchecked {
                i++;
            }
        }

        return sortedPlayers;
    }

    /// @notice Checks if address is in tournament
    function isPlayerInTournament(uint256 tournamentID, address player) private view returns (bool) {
        for (uint256 i = 0; i < tournaments[tournamentID].joinedPlayers.length;) {
            if (tournaments[tournamentID].joinedPlayers[i] == player) {
                return true;
            }
            unchecked {
                i++;
            }
        }
        return false;
    }

    function isPlayerAuthenticatedInTournament(uint256 tournamentID, address player) private view returns (bool) {
        if (tournaments[tournamentID].isByInvite == true) {
            for (uint256 i = 0; i < tournaments[tournamentID].authedPlayers.length;) {
                if (tournaments[tournamentID].authedPlayers[i] == player) {
                    return true;
                }
                unchecked {
                    i++;
                }
            }
        } else {
            return true;
        }
        return false;
    }

    /* 
    //// WRITE FUNCTIONS ////
    */

    /// @notice Creates a Tournament
    /// @dev creates a tournament, and increases the global tournament nonce
    function createTournament(
        uint256 numberOfPlayers,
        uint256 numberOfGames,
        address gameToken,
        uint256 tokenAmount,
        uint256 timeLimit
    ) external returns (uint256) {
        require(numberOfPlayers <= 25, "Too many players"); // how much gas is too much?

        if (gameToken != address(0)) {
            IERC20(gameToken).safeTransferFrom(msg.sender, address(this), tokenAmount);
        } else {
            require(tokenAmount == 0, "not zero");
        }

        TournamentParams memory tournament;

        address[] memory player = new address[](1);
        player[0] = msg.sender;

        tournament.numberOfPlayers = numberOfPlayers;

        tournament.joinedPlayers = player;
        tournament.isByInvite = false;

        tournament.gameToken = gameToken;
        tournament.tokenAmount = tokenAmount;
        tournament.numberOfGames = numberOfGames;
        tournament.isInProgress = false;
        tournament.startTime = block.timestamp;
        tournament.timeLimit = timeLimit;
        tournament.isComplete = false;

        tournaments[tournamentNonce] = tournament;
        tournamentNonce++;

        return tournamentNonce - 1;
    }

    /// @notice Creates a Tournament with specific players
    /// @dev Creates a tournament, and increases the global tournament nonce

    // @DEV make is so that when amount is 0, everyone is already joined. Also add a
    // property to deposit to the pool prize in this tx
    function createTournamentWithSpecificPlayers(
        address[] calldata specificPlayers,
        uint256 numberOfGames,
        address gameToken,
        uint256 tokenAmount,
        uint256 timeLimit
    ) external {
        require(numberOfGames > 0, "numberOfGames > 0");
        require(specificPlayers.length <= 25, "lte 25");

        TournamentParams memory tournament;

        // Use the provided specific players
        tournament.authedPlayers = specificPlayers;

        // if token amount is zero then everyone is already joined
        if (gameToken == address(0)) {
            tournament.joinedPlayers = specificPlayers;
        }

        // order this
        tournament.isByInvite = true;
        tournament.numberOfPlayers = specificPlayers.length;
        tournament.gameToken = gameToken;
        tournament.tokenAmount = tokenAmount;
        tournament.numberOfGames = numberOfGames;
        tournament.isInProgress = false;
        tournament.creationTime = block.timestamp;
        tournament.startTime = block.timestamp;
        tournament.timeLimit = timeLimit;
        tournament.isComplete = false;

        tournaments[tournamentNonce] = tournament;

        if (gameToken != address(0)) {
            IERC20(gameToken).safeTransferFrom(msg.sender, address(this), tokenAmount);
        } else {
            require(tokenAmount == 0, "not zero");

            for (uint256 i = 0; i < specificPlayers.length; i++) {
                for (uint256 j = i + 1; j < specificPlayers.length; j++) {
                    address player0 = specificPlayers[i];
                    address player1 = specificPlayers[j];

                    address gameAddress = chessGame.createGameTournamentSingle(
                        player0, player1, gameToken, tokenAmount, numberOfGames, timeLimit, tournamentNonce
                    );
                    tournamentGameAddresses[tournamentNonce].push(gameAddress);
                }
            }

            // If game token is 0, then start tournament automatically
            if (gameToken == address(0)) {
                tournaments[tournamentNonce].isInProgress = true;
                for (uint256 i = 0; i < tournamentGameAddresses[tournamentNonce].length;) {
                    chessGame.startGamesInTournament(tournamentGameAddresses[tournamentNonce][i]);
                    unchecked {
                        i++;
                    }
                }
            }
        }

        tournamentNonce++;
    }

    /// @notice Join tournament
    /// @param tournamentID the tournamentID of the tournament that the user wants to join
    function joinTournament(uint256 tournamentID) external {
        /// @dev add functionality so that user can't accidentally join twice
        /// @dev add functionality to start tournament function to check if someone hasn't
        /// joined...
        require(!isPlayerInTournament(tournamentID, msg.sender), "already joined");
        if (tournaments[tournamentID].isByInvite) {
            require(isPlayerAuthenticatedInTournament(tournamentID, msg.sender), "not authorized");
            // require(!isPlayerInTournament(tournamentID, msg.sender), "already joined");
            require(tournaments[tournamentID].isInProgress == false, "tournament in progress");
        } else {
            require(
                tournaments[tournamentID].numberOfPlayers >= tournaments[tournamentID].joinedPlayers.length,
                "max number of players reached"
            );
            require(tournaments[tournamentID].isInProgress == false, "tournament in progress");
        }

        address gameToken = tournaments[tournamentID].gameToken;
        uint256 tokenAmount = tournaments[tournamentID].tokenAmount;
        uint256 numberOfGames = tournaments[tournamentID].numberOfGames;
        uint256 timeLimit = tournaments[tournamentID].timeLimit;

        if (gameToken != address(0)) {
            IERC20(gameToken).safeTransferFrom(msg.sender, address(this), tokenAmount);
        }

        // creating game for msg.sender and each player already joined
        for (uint256 i = 0; i < tournaments[tournamentID].joinedPlayers.length;) {
            address player0 = tournaments[tournamentID].joinedPlayers[i];

            address gameAddress = chessGame.createGameTournamentSingle(
                player0, msg.sender, gameToken, tokenAmount, numberOfGames, timeLimit, tournamentID
            );
            tournamentGameAddresses[tournamentID].push(gameAddress);
            unchecked {
                i++;
            }
        }

        tournaments[tournamentID].joinedPlayers.push(msg.sender);
    }

    /// @notice Starts the tournament
    /// @dev minimum number of players = 3
    /// @dev if the number of players is greater than 3 and not equal to
    /// the maxNumber of players the tournament can start 1 day after creation
    function startTournament(uint256 tournamentID) external {
        require(tournaments[tournamentID].isInProgress == false, "already started");
        require(tournaments[tournamentID].joinedPlayers.length >= 3, "not enough players");

        if (tournaments[tournamentID].joinedPlayers.length != tournaments[tournamentID].numberOfPlayers) {
            require(block.timestamp - tournaments[tournamentID].startTime > 86_400, "must wait 1day before starting");
        }

        tournaments[tournamentID].isInProgress = true;
        tournaments[tournamentID].startTime = block.timestamp;

        for (uint256 i = 0; i < tournamentGameAddresses[tournamentID].length;) {
            chessGame.startGamesInTournament(tournamentGameAddresses[tournamentID][i]);
            unchecked {
                i++;
            }
        }
    }

    /// @notice Exit tournament
    /// @dev user can exit if tournament is not in progress
    function exitTournament(uint256 tournamentID) external {
        require(tournaments[tournamentID].isInProgress == false, "Tournament in progress");
        require(isPlayerInTournament(tournamentID, msg.sender), "msg.sender not in tournament");

        address gameToken = tournaments[tournamentID].gameToken;
        uint256 tokenAmount = tournaments[tournamentID].tokenAmount;

        removePlayerFromPlayers(tournamentID, msg.sender);

        IERC20(gameToken).safeTransfer(msg.sender, tokenAmount);
    }

    /// @notice Handle payout of tournament
    /// @dev tallies, gets payout profile, sorts players by wins, handles payout
    /// @dev one day must pass after end time for all games in ChessGame contract
    function payoutTournament(uint256 tournamentID) external {
        require(
            tournaments[tournamentID].timeLimit + 86_400 < block.timestamp - tournaments[tournamentID].startTime,
            "Tournament not finished yet"
        );
        require(tournaments[tournamentID].isComplete == false, "Tournament completed");

        tallyWins(tournamentID);

        address payoutToken = tournaments[tournamentID].gameToken;
        tournaments[tournamentID].isComplete = true;

        // @dev put in separate function?
        address[] memory gameAddresses = tournamentGameAddresses[tournamentID];
        for (uint256 i = 0; i < gameAddresses.length; i++) {
            (address player0, address player1, uint256 wins0, uint256 wins1) = chessGame.getGameStatus(gameAddresses[i]);
            address winner = wins0 > wins1 ? player0 : player1;
            cfshNFT.awardWinner(winner, gameAddresses[i]);
        }

        if (payoutToken != address(0)) {
            uint256 numberOfPlayers = tournaments[tournamentID].joinedPlayers.length;
            uint256[] memory payoutProfile;

            /// @dev handling different payout profiles
            if (numberOfPlayers == 3) {
                payoutProfile = new uint256[](3);
                for (uint256 i = 0; i < 3;) {
                    payoutProfile[i] = payoutProfile3[i];
                    unchecked {
                        i++;
                    }
                }
            } else if (numberOfPlayers > 3 && numberOfPlayers <= 9) {
                payoutProfile = new uint256[](4);
                for (uint256 i = 0; i < 4;) {
                    payoutProfile[i] = payoutProfile4_9[i];
                    unchecked {
                        i++;
                    }
                }
            } else if (numberOfPlayers > 9 && numberOfPlayers <= 25) {
                payoutProfile = new uint256[](7);
                for (uint256 i = 0; i < 7;) {
                    payoutProfile[i] = payoutProfile10_25[i];
                    unchecked {
                        i++;
                    }
                }
            }
            address[] memory playersSorted = getPlayersSortedByWins(tournamentID);

            uint256 poolSize = tournaments[tournamentID].joinedPlayers.length * tournaments[tournamentID].tokenAmount
                + tournaments[tournamentID].prizePool;
            uint256 poolRemaining = poolSize;

            require(poolSize <= IERC20(payoutToken).balanceOf(address(this)), "NL");

            for (uint16 i = 0; i < payoutProfile.length;) {
                uint256 payout = (poolSize * payoutProfile[i]) / 10_000;

                if (payout > 0) {
                    IERC20(payoutToken).safeTransfer(playersSorted[i], payout);
                    poolRemaining -= payout;
                }

                unchecked {
                    i++;
                }
            }
            IERC20(payoutToken).safeTransfer(PaymentSplitter, poolRemaining);
        }
    }

    /// @dev Used to calculate wins, saving score to storage.
    function tallyWins(uint256 tournamentID) private returns (address[] memory, uint256[] memory) {
        address[] memory players = tournaments[tournamentID].joinedPlayers;

        uint256 numberOfGamesInTournament = tournamentGameAddresses[tournamentID].length;

        for (uint256 i = 0; i < numberOfGamesInTournament;) {
            (address player0, address player1, uint256 wins0, uint256 wins1) =
                chessGame.getGameStatus(tournamentGameAddresses[tournamentID][i]);
            tournamentWins[tournamentID][player0] += wins0;
            tournamentWins[tournamentID][player1] += wins1;
            unchecked {
                i++;
            }
        }

        uint256[] memory wins = new uint256[](players.length);
        for (uint256 i = 0; i < players.length;) {
            wins[i] = tournamentWins[tournamentID][players[i]];
            unchecked {
                i++;
            }
        }

        return (players, wins);
    }

    /// @dev private func that withdraws player from tournament if they exit
    function removePlayerFromPlayers(uint256 tournamentID, address player) private {
        bool isInPlayers = false;
        uint256 count = 0;
        for (count; count < tournaments[tournamentID].joinedPlayers.length;) {
            if (tournaments[tournamentID].joinedPlayers[count] == player) {
                isInPlayers = true;
                break;
            }
            unchecked {
                count++;
            }
        }

        if (isInPlayers == true) {
            assert(count < tournaments[tournamentID].joinedPlayers.length);
            tournaments[tournamentID].joinedPlayers[count] =
                tournaments[tournamentID].joinedPlayers[tournaments[tournamentID].joinedPlayers.length - 1];
            tournaments[tournamentID].joinedPlayers.pop();
        }

        // removing all instances of player games from tournament games
        address[] memory playerGames = getTournamentGamesPlayer(player, tournamentID);
        for (uint256 i = 0; i < tournamentGameAddresses[tournamentID].length;) {
            for (uint256 j = 0; j < playerGames.length; j++) {
                if (tournamentGameAddresses[tournamentID][i] == playerGames[j]) {
                    tournamentGameAddresses[tournamentID][i] =
                        tournamentGameAddresses[tournamentID][tournamentGameAddresses[tournamentID].length - 1];
                    tournamentGameAddresses[tournamentID].pop();
                    if (i > 0) {
                        i--;
                    }
                    break;
                }
            }
            unchecked {
                i++;
            }
        }
    }

    /// @notice Used to deposit prizes to tournament
    function depositToTournament(uint256 tournamentID, uint256 amount) external {
        require(!tournaments[tournamentID].isComplete, "tournament completed");
        tournaments[tournamentID].prizePool += amount;

        IERC20(tournaments[tournamentID].gameToken).safeTransferFrom(msg.sender, address(this), amount);
    }
}
