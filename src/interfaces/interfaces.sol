// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

interface IChessFishNFT {
    function awardWinner(
        address player,
        address gameHash
    )
        external
        returns (uint256);
}

interface IChessGame {
    function createChessGameTournamentSingle(
        address player0,
        address player1,
        address gameToken,
        uint256 gameAmount,
        uint256 numberOfGames,
        uint256 timeLimit
    )
        external
        returns (address gameAddress);

    function startGamesInTournament(address gameAddress) external;

    function getGameStatus(address gameAddress)
        external
        view
        returns (address, address, uint256, uint256);
}
