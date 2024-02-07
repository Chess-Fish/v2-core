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

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/interfaces.sol";

/**
 * @title ChessFish Tournament Contract
 * @author ChessFish
 * @notice https://github.com/Chess-Fish
 *
 * @notice This contract handles the functionality of creating Round Robbin style
 * tournaments as well as handling the payouts of ERC-20 tokens to tournament winners.
 * This contract creates wagers in the ChessWager smart contract and then reads the result
 * of the created wagers to calculate the number of wins for each user in the tournament.
 */
contract ChessFishTournament {
    using SafeERC20 for IERC20;

    struct Tournament {
        uint256 numberOfPlayers; // number of players in tournament
        address[] authed_players; // authenticated players
        address[] joined_players; // joined players
        bool isByInvite; // is tournament by invite only
        uint256 numberOfGames; // number of games per match
        address token; // wager token address
        uint256 tokenAmount; // token amount
        uint256 prizePool; // size of prize pool
        bool isInProgress; // is tournament in progress
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
    mapping(uint256 => Tournament) public tournaments;

    /// @dev uint tournament nonce => address[] wagerIDs
    mapping(uint256 => address[]) internal tournamentWagerAddresses;

    /// @dev uint tournamentID => address player => wins
    mapping(uint256 => mapping(address => uint256)) public tournamentWins;

    address public immutable ChessWagerAddress;
    address public immutable PaymentSplitter;

    constructor(address _chessWager, address _paymentSplitter) {
        ChessWagerAddress = _chessWager;
        PaymentSplitter = _paymentSplitter;
    }

    /* 
    //// VIEW FUNCTIONS ////
    */

    /// @notice Returns players in tournament
    function getTournamentPlayers(uint256 tournamentID)
        external
        view
        returns (address[] memory)
    {
        return (tournaments[tournamentID].joined_players);
    }

    /// @notice Returns authorized players in tournament
    function getAuthorizedPlayers(uint256 tournamentID)
        external
        view
        returns (address[] memory)
    {
        return (tournaments[tournamentID].authed_players);
    }

    /// @notice Returns wager addresses in tournament
    function getTournamentWagerAddresses(uint256 tournamentID)
        external
        view
        returns (address[] memory)
    {
        return (tournamentWagerAddresses[tournamentID]);
    }

    /// @notice Calculates score
    /// @dev designed as view only
    /// @dev returns addresses[] players
    /// @dev returns uint[] scores
    function viewTournamentScore(uint256 tournamentID)
        external
        view
        returns (address[] memory, uint256[] memory)
    {
        address[] memory players = tournaments[tournamentID].joined_players;
        uint256 numberOfWagersInTournament = tournamentWagerAddresses[tournamentID].length;

        uint256[] memory wins = new uint256[](players.length);

        for (uint256 i = 0; i < numberOfWagersInTournament;) {
            (address player0, address player1, uint256 wins0, uint256 wins1) = IChessGame(
                ChessWagerAddress
            ).getWagerStatus(tournamentWagerAddresses[tournamentID][i]);

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

    /// @notice Returns addresses winners sorted by highest wins
    function getPlayersSortedByWins(uint256 tournamentID)
        public
        view
        returns (address[] memory)
    {
        require(
            tournaments[tournamentID].timeLimit
                < block.timestamp - tournaments[tournamentID].startTime,
            "Tournament not finished yet"
        );

        address[] memory players = tournaments[tournamentID].joined_players;
        PlayerWins[] memory playerWinsArray = new PlayerWins[](players.length);

        for (uint256 i = 0; i < players.length;) {
            playerWinsArray[i] = PlayerWins({
                player: players[i],
                wins: tournamentWins[tournamentID][players[i]]
            });
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
                    (playerWinsArray[j], playerWinsArray[j + 1]) =
                        (playerWinsArray[j + 1], playerWinsArray[j]);
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
    function isPlayerInTournament(
        uint256 tournamentID,
        address player
    )
        internal
        view
        returns (bool)
    {
        for (uint256 i = 0; i < tournaments[tournamentID].joined_players.length;) {
            if (tournaments[tournamentID].joined_players[i] == player) {
                return true;
            }
            unchecked {
                i++;
            }
        }
        return false;
    }

    function isPlayerAuthenticatedInTournament(
        uint256 tournamentID,
        address player
    )
        internal
        view
        returns (bool)
    {
        if (tournaments[tournamentID].isByInvite == true) {
            for (uint256 i = 0; i < tournaments[tournamentID].authed_players.length;) {
                if (tournaments[tournamentID].authed_players[i] == player) {
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
    )
        external
        returns (uint256)
    {
        require(numberOfPlayers <= 25, "Too many players"); // how much gas is too much?

        if (gameToken != address(0)) {
            IERC20(gameToken).safeTransferFrom(msg.sender, address(this), tokenAmount);
        } else {
            require(tokenAmount == 0, "not zero");
        }

        Tournament memory tournament;

        address[] memory player = new address[](1);
        player[0] = msg.sender;

        tournament.numberOfPlayers = numberOfPlayers;

        tournament.joined_players = player;
        tournament.isByInvite = false;

        tournament.token = gameToken;
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
    )
        external
        returns (uint256)
    {
        require(numberOfGames > 0, "Number of games must be positive");

        Tournament memory tournament;

        // Use the provided specific players
        tournament.authed_players = specificPlayers;
        tournament.isByInvite = true;

        if (gameToken != address(0)) {
            IERC20(gameToken).safeTransferFrom(msg.sender, address(this), tokenAmount);
        } else {
            require(tokenAmount == 0, "not zero");
        }

        address[] memory authed_players =
            new address[](tournament.authed_players.length + 1);

        for (uint256 i = 0; i < tournament.authed_players.length; i++) {
            authed_players[i] = tournament.authed_players[i];
        }

        authed_players[tournament.authed_players.length] = msg.sender;
        tournament.authed_players = authed_players;

        address[] memory joined_players = new address[](1);
        joined_players[0] = msg.sender;
        tournament.joined_players = joined_players;

        require(tournament.authed_players.length <= 25, "Too many players");

        tournament.numberOfPlayers = tournament.authed_players.length;
        tournament.token = gameToken;
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

    /// @notice Join tournament
    /// @param tournamentID the tournamentID of the tournament that the user wants to join
    function joinTournament(uint256 tournamentID) external {
        /// @dev add functionality so that user can't accidentally join twice
        /// @dev add functionality to start tournament function to check if someone hasn't
        /// joined...
        if (tournaments[tournamentID].isByInvite) {
            require(
                isPlayerAuthenticatedInTournament(tournamentID, msg.sender),
                "not authorized"
            );
            require(!isPlayerInTournament(tournamentID, msg.sender), "already Joined");
            require(
                tournaments[tournamentID].isInProgress == false, "tournament in progress"
            );
        } else {
            require(
                tournaments[tournamentID].numberOfPlayers
                    >= tournaments[tournamentID].joined_players.length,
                "max number of players reached"
            );
            require(
                tournaments[tournamentID].isInProgress == false, "tournament in progress"
            );
            require(!isPlayerInTournament(tournamentID, msg.sender), "already Joined");
        }

        address gameToken = tournaments[tournamentID].token;
        uint256 tokenAmount = tournaments[tournamentID].tokenAmount;
        uint256 numberOfGames = tournaments[tournamentID].numberOfGames;
        uint256 timeLimit = tournaments[tournamentID].timeLimit;

        if (gameToken != address(0)) {
            IERC20(gameToken).safeTransferFrom(msg.sender, address(this), tokenAmount);
        }

        // creating wager for msg.sender and each player already joined
        for (uint256 i = 0; i < tournaments[tournamentID].joined_players.length;) {
            address player0 = tournaments[tournamentID].joined_players[i];

            address wagerAddress = IChessGame(ChessWagerAddress)
                .createGameWagerTournamentSingle(
                player0, msg.sender, gameToken, tokenAmount, numberOfGames, timeLimit
            );
            tournamentWagerAddresses[tournamentID].push(wagerAddress);
            unchecked {
                i++;
            }
        }

        tournaments[tournamentID].joined_players.push(msg.sender);
    }

    /// @notice Starts the tournament
    /// @dev minimum number of players = 3
    /// @dev if the number of players is greater than 3 and not equal to
    /// the maxNumber of players the tournament can start 1 day after creation
    function startTournament(uint256 tournamentID) external {
        require(tournaments[tournamentID].isInProgress == false, "already started");
        require(
            tournaments[tournamentID].joined_players.length >= 3, "not enough players"
        );

        if (
            tournaments[tournamentID].joined_players.length
                != tournaments[tournamentID].numberOfPlayers
        ) {
            require(
                block.timestamp - tournaments[tournamentID].startTime > 86_400,
                "must wait 1day before starting"
            );
        }

        tournaments[tournamentID].isInProgress = true;
        for (uint256 i = 0; i < tournamentWagerAddresses[tournamentID].length;) {
            IChessGame(ChessWagerAddress).startWagersInTournament(
                tournamentWagerAddresses[tournamentID][i]
            );
            unchecked {
                i++;
            }
        }
    }

    /// @notice Exit tournament
    /// @dev user can exit if tournament is not in progress
    function exitTournament(uint256 tournamentID) external {
        require(tournaments[tournamentID].isInProgress == false, "Tournament in progress");
        require(
            isPlayerInTournament(tournamentID, msg.sender), "msg.sender not in tournament"
        );

        address token = tournaments[tournamentID].token;
        uint256 tokenAmount = tournaments[tournamentID].tokenAmount;

        removePlayerFromPlayers(tournamentID, msg.sender);

        IERC20(token).safeTransfer(msg.sender, tokenAmount);
    }

    /// @notice Handle payout of tournament
    /// @dev tallies, gets payout profile, sorts players by wins, handles payout
    /// @dev one day must pass after end time for all games in GameWager contract
    function payoutTournament(uint256 tournamentID) external {
        require(
            tournaments[tournamentID].timeLimit + 86_400
                < block.timestamp - tournaments[tournamentID].startTime,
            "Tournament not finished yet"
        );
        require(tournaments[tournamentID].isComplete == false, "Tournament completed");

        tallyWins(tournamentID);

        tournaments[tournamentID].isComplete = true;
        uint256 numberOfPlayers = tournaments[tournamentID].joined_players.length;
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
        address payoutToken = tournaments[tournamentID].token;

        uint256 poolSize = tournaments[tournamentID].joined_players.length
            * tournaments[tournamentID].tokenAmount + tournaments[tournamentID].prizePool;
        uint256 poolRemaining = poolSize;

        assert(poolSize >= IERC20(payoutToken).balanceOf(address(this)));

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
        IERC20(payoutToken).transfer(PaymentSplitter, poolRemaining);
    }

    /// @dev Used to calculate wins, saving score to storage.
    function tallyWins(uint256 tournamentID)
        private
        returns (address[] memory, uint256[] memory)
    {
        address[] memory players = tournaments[tournamentID].joined_players;

        uint256 numberOfWagersInTournament = tournamentWagerAddresses[tournamentID].length;

        for (uint256 i = 0; i < numberOfWagersInTournament;) {
            (address player0, address player1, uint256 wins0, uint256 wins1) = IChessGame(
                ChessWagerAddress
            ).getWagerStatus(tournamentWagerAddresses[tournamentID][i]);
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

    /// @dev internal func that withdraws player from tournament if they exit
    function removePlayerFromPlayers(uint256 tournamentID, address player) private {
        bool isInPlayers = false;
        uint256 i = 0;
        for (i; i < tournaments[tournamentID].joined_players.length;) {
            if (tournaments[tournamentID].joined_players[i] == player) {
                isInPlayers = true;
                break;
            }
            unchecked {
                i++;
            }
        }

        if (isInPlayers == true) {
            assert(i < tournaments[tournamentID].joined_players.length);
            tournaments[tournamentID].joined_players[i] = tournaments[tournamentID]
                .joined_players[tournaments[tournamentID].joined_players.length - 1];
            tournaments[tournamentID].joined_players.pop();
        }
    }

    /// @notice Used to deposit prizes to tournament
    function depositToTournament(uint256 tournamentID, uint256 amount) external {
        require(!tournaments[tournamentID].isComplete, "tournament completed");
        tournaments[tournamentID].prizePool += amount;

        IERC20(tournaments[tournamentID].token).safeTransferFrom(
            msg.sender, address(this), amount
        );
    }
}
