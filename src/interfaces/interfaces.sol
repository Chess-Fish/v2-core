// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

interface IChessFishNFT {
    function awardWinner(address player, address gameHash) external returns (uint256);
}

interface IChessGame {
    function createGameTournamentSingle(
        address player0,
        address player1,
        address gameToken,
        uint256 tokenAmount,
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
