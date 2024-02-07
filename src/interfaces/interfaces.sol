// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IChessFishNFT {
    function awardWinner(address player, address wagerHash) external returns (uint256);
}

interface IChessGame {
    function createGameWagerTournamentSingle(
        address player0,
        address player1,
        address wagerToken,
        uint256 wagerAmount,
        uint256 numberOfGames,
        uint256 timeLimit
    )
        external
        returns (address wagerAddress);

    function startWagersInTournament(address wagerAddress) external;

    function getWagerStatus(address wagerAddress)
        external
        view
        returns (address, address, uint256, uint256);
}
