import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { ethers } from "hardhat";

import {
	generateRandomHash,
	coordinates_array,
	bitCoordinates_array,
	pieceSymbols,
} from "../scripts/constants";
describe("ChessFish Large Tournament Unit Tests", function () {
	// We define a fixture to reuse the same setup in every test.
	async function deploy() {
		const [
			deployer,
			player0,
			player1,
			player2,
			player3,
			player4,
			player5,
			player6,
			player7,
			player8,
			player9,
			player10,
			otherAccount,
		] = await ethers.getSigners();

		const Token = await ethers.getContractFactory("Token");
		const token = await Token.deploy();

		const addressZero = "0x0000000000000000000000000000000000000000";
		const dividendSplitter = "0x973C170C3BC2E7E1B3867B3B29D57865efDDa59a";

		const MoveVerification = await ethers.getContractFactory("MoveVerification");
		const moveVerification = await MoveVerification.deploy();

		const ChessGame = await ethers.getContractFactory("ChessGame");
		const chessGame = await ChessGame.deploy();

		const GaslessGame = await ethers.getContractFactory("GaslessGame");
		const gaslessGame = await GaslessGame.deploy();

		const Tournament = await ethers.getContractFactory("Tournament");
		const tournament = await Tournament.deploy();

		// NFT
		const PieceSVG = await ethers.getContractFactory("PieceSVG");
		const pieceSVG = await PieceSVG.deploy();

		const TokenSVG = await ethers.getContractFactory("TokenSVG");
		const tokenSVG = await TokenSVG.deploy();

		const ChessFishNFT = await ethers.getContractFactory("ChessFishNFT");
		const chessNFT = await ChessFishNFT.deploy(
			chessGame.address,
			moveVerification.address,
			tournament.address,
			pieceSVG.address,
			tokenSVG.address
		);

		await pieceSVG.initialize(chessNFT.address);
		await tokenSVG.initialize(chessNFT.address);

		// Initializing
		await chessGame.initialize(
			moveVerification.address,
			gaslessGame.address,
			tournament.address,
			tournament.address,
			chessNFT.address
		);

		await tournament.initialize(chessGame.address, dividendSplitter, chessNFT.address);

		await chessGame.initCoordinatesAndSymbols(
			coordinates_array,
			bitCoordinates_array,
			pieceSymbols
		);

		await gaslessGame.initialize(moveVerification.address, chessGame.address);

		// typed signature data
		const domain = {
			chainId: 1, // replace with the chain ID on frontend
			name: "ChessFish", // Contract Name
			verifyingContract: gaslessGame.address, // for testing
			version: "1", // version
		};

		const delegationTypes = {
			Delegation: [
				{ name: "delegatorAddress", type: "address" },
				{ name: "delegatedAddress", type: "address" },
				{ name: "gameAddress", type: "address" },
			],
		};

		const gaslessMoveTypes = {
			GaslessMove: [
				{ name: "gameAddress", type: "address" },
				{ name: "gameNumber", type: "uint256" },
				{ name: "expiration", type: "uint256" },
				{ name: "movesHash", type: "bytes32" },
			],
		};

		const amount = ethers.utils.parseEther("100");

		await token.transfer(player0.address, amount);
		await token.transfer(player1.address, amount);
		await token.transfer(player2.address, amount);
		await token.transfer(player3.address, amount);
		await token.transfer(player4.address, amount);
		await token.transfer(player4.address, amount);
		await token.transfer(player5.address, amount);
		await token.transfer(player6.address, amount);
		await token.transfer(player7.address, amount);
		await token.transfer(player8.address, amount);
		await token.transfer(player9.address, amount);
		await token.transfer(player10.address, amount);
		await token.transfer(otherAccount.address, amount);

		await token.connect(player0).approve(tournament.address, amount);
		await token.connect(player1).approve(tournament.address, amount);
		await token.connect(player2).approve(tournament.address, amount);
		await token.connect(player3).approve(tournament.address, amount);
		await token.connect(player4).approve(tournament.address, amount);
		await token.connect(player5).approve(tournament.address, amount);
		await token.connect(player6).approve(tournament.address, amount);
		await token.connect(player7).approve(tournament.address, amount);
		await token.connect(player8).approve(tournament.address, amount);
		await token.connect(player9).approve(tournament.address, amount);
		await token.connect(player10).approve(tournament.address, amount);
		await token.connect(otherAccount).approve(tournament.address, amount);

		const players = [
			player0,
			player1,
			player2,
			player3,
			player4,
			player5,
			player6,
			player7,
			player8,
			player9,
			player10,
		];

		return {
			players,
			otherAccount,
			chessGame,
			tournament,
			gaslessGame,
			dividendSplitter,
			chessNFT,
			domain,
			delegationTypes,
			gaslessMoveTypes,
			addressZero,
			token,
		};
	}

	describe("Tournament Unit Tests", function () {
		it("Should start authenticated tournament and play games 11 players", async function () {
			this.timeout(100000); // sets the timeout to 100 seconds

			const { chessGame, tournament, players, otherAccount, token } = await loadFixture(deploy);

			let gameToken = token.address;
			let gameAmount = ethers.utils.parseEther("10.0");
			let numberOfGames = 1;
			let timeLimit = 86400;

			let specificPlayers = [
				players[0].address,
				players[1].address,
				players[2].address,
				players[3].address,
				players[4].address,
				players[5].address,
				players[6].address,
				players[7].address,
				players[8].address,
				players[9].address,
				players[10].address,
			];

			let tx = await tournament
				.connect(players[0])
				.createTournamentWithSpecificPlayers(
					specificPlayers,
					numberOfGames,
					gameToken,
					gameAmount,
					timeLimit
				);

			await tx.wait();

			const tournamentNonce = await tournament.tournamentNonce();

			const playersSansPlayer0 = [...players];
			playersSansPlayer0.shift();

			await Promise.all(
				playersSansPlayer0.map(async (player) => {
					return await tournament.connect(player).joinTournament(tournamentNonce - 1);
				})
			);

			let revertNotAuthorized = tournament
				.connect(otherAccount)
				.joinTournament(tournamentNonce - 1);
			await expect(revertNotAuthorized).to.be.revertedWith("not authorized");

			// players[0] should be able to join since they weren't automatically added when gameToken != address(0)
			await tournament.connect(players[0]).joinTournament(tournamentNonce - 1);

			// Now players[0] is joined, so trying to join again should revert
			let revertTx = tournament.connect(players[0]).joinTournament(tournamentNonce - 1);
			await expect(revertTx).to.be.revertedWith("already joined");

			let gameAddresses = await tournament.getTournamentGameAddresses(tournamentNonce - 1);
			expect(gameAddresses.length).to.equal(55); // 11 players

			await tournament.connect(otherAccount).depositToTournament(tournamentNonce - 1, gameAmount);

			const balance0 = await token.balanceOf(tournament.address);
			expect(balance0).to.equal(gameAmount.mul(13)); // 12 players (11 + players[0]) + 10 deposit

			const playerAddresses = await tournament.getTournamentPlayers(tournamentNonce - 1);
			expect(playerAddresses.length).to.equal(11);

			await ethers.provider.send("evm_increaseTime", [86400]);
			await ethers.provider.send("evm_mine");

			await tournament.startTournament(tournamentNonce - 1);

			gameAddresses = await tournament.getTournamentGameAddresses(tournamentNonce - 1);
			expect(gameAddresses.length).to.equal(55); // 11 players

			const moves = ["f2f3", "e7e5", "g2g4", "d8h4"];

			for (let i = 0; i < gameAddresses.length; i++) {
				for (let j = 0; j < moves.length; j++) {
					// console.log(`Game ${i} of ${gameAddresses.length}`);
					let playerAddress = await chessGame.getPlayerMove(gameAddresses[i]);
					let player = await ethers.getSigner(playerAddress);
					let hex_move = await chessGame.moveToHex(moves[j]);
					await chessGame.connect(player).playMove(gameAddresses[i], hex_move);
				}
			}
			await ethers.provider.send("evm_increaseTime", [86400 * 2]);
			await ethers.provider.send("evm_mine");

			const player0bal0 = await token.balanceOf(players[0].address);
			const player1bal0 = await token.balanceOf(players[1].address);
			const player2bal0 = await token.balanceOf(players[2].address);
			const player3bal0 = await token.balanceOf(players[3].address);
			const player4bal0 = await token.balanceOf(players[4].address);
			const player5bal0 = await token.balanceOf(players[5].address);
			const player6bal0 = await token.balanceOf(players[6].address);
			const player7bal0 = await token.balanceOf(players[7].address);
			const player8bal0 = await token.balanceOf(players[8].address);
			const player9bal0 = await token.balanceOf(players[9].address);
			const player10bal0 = await token.balanceOf(players[10].address);

			await tournament.payoutTournament(tournamentNonce - 1);

			const player0bal1 = await token.balanceOf(players[0].address);
			const player1bal1 = await token.balanceOf(players[1].address);
			const player2bal1 = await token.balanceOf(players[2].address);
			const player3bal1 = await token.balanceOf(players[3].address);
			const player4bal1 = await token.balanceOf(players[4].address);
			const player5bal1 = await token.balanceOf(players[5].address);
			const player6bal1 = await token.balanceOf(players[6].address);
			const player7bal1 = await token.balanceOf(players[7].address);
			const player8bal1 = await token.balanceOf(players[8].address);
			const player9bal1 = await token.balanceOf(players[9].address);
			const player10bal1 = await token.balanceOf(players[10].address);

			// Get tournament data
			let data = await tournament.tournaments(tournamentNonce - 1);
			let prizePool = ethers.BigNumber.from(data.prizePool.toString());
			const pool = gameAmount.mul(11).add(prizePool);
			const scale = ethers.BigNumber.from(10000);

			// Get all player balances after payout and calculate actual payouts
			const actualPayouts: { player: string; payout: any }[] = [];
			const balancesBefore = [
				player0bal0,
				player1bal0,
				player2bal0,
				player3bal0,
				player4bal0,
				player5bal0,
				player6bal0,
				player7bal0,
				player8bal0,
				player9bal0,
				player10bal0,
			];
			const balancesAfter = [
				player0bal1,
				player1bal1,
				player2bal1,
				player3bal1,
				player4bal1,
				player5bal1,
				player6bal1,
				player7bal1,
				player8bal1,
				player9bal1,
				player10bal1,
			];

			for (let i = 0; i < 11; i++) {
				const payout = balancesAfter[i].sub(balancesBefore[i]);
				actualPayouts.push({ player: players[i].address, payout });
			}

			// Sort by payout amount (descending) to get actual ranking
			actualPayouts.sort((a, b) => (b.payout.gt(a.payout) ? 1 : -1));

			// Expected payout percentages for 10-25 players: [3650, 2300, 1350, 1000, 500, 250, 250]
			const expectedPercentages = [3650, 2300, 1350, 1000, 500, 250, 250];

			// Test that the correct number of players get payouts
			let playersWithPayouts = actualPayouts.filter((p) => p.payout.gt(0)).length;
			expect(playersWithPayouts).to.equal(7, "Exactly 7 players should receive payouts");

			// Test that the top 7 players get the correct payout percentages
			for (let i = 0; i < 7; i++) {
				const expectedPayout = pool.mul(expectedPercentages[i]).div(scale);
				expect(actualPayouts[i].payout.toString()).to.equal(
					expectedPayout.toString(),
					`Player at rank ${i + 1} should get ${
						expectedPercentages[i] / 100
					}% of pool (${expectedPayout.toString()})`
				);
			}

			// Test that remaining players get 0 payout
			for (let i = 7; i < actualPayouts.length; i++) {
				expect(actualPayouts[i].payout.toString()).to.equal(
					"0",
					`Player at rank ${i + 1} should get 0 payout`
				);
			}

			// Test that total payouts equal expected amount (93% of pool, 7% goes to protocol)
			const totalPayouts = actualPayouts.reduce(
				(sum, p) => sum.add(p.payout),
				ethers.BigNumber.from(0)
			);
			const expectedTotalPayouts = pool.mul(9300).div(10000); // 93% of pool (100% - 7% protocol fee)
			expect(totalPayouts.toString()).to.equal(
				expectedTotalPayouts.toString(),
				"Total payouts should equal 93% of pool"
			);

			// Test that the tournament scoring system works
			const scoreData = await tournament.viewTournamentScore(tournamentNonce - 1);
			expect(scoreData[0].length).to.equal(11, "Should have 11 players in score data");
			expect(scoreData[1].length).to.equal(11, "Should have 11 win counts in score data");

			// Test that total wins make sense (each game has exactly one winner)
			const totalWins = scoreData[1].reduce((sum: any, wins: any) => sum + wins.toNumber(), 0);
			expect(totalWins).to.equal(
				55,
				"Total wins should equal number of games (55 games in 11-player tournament)"
			);

			let isComplete = (await tournament.tournaments(tournamentNonce - 1)).isComplete;
			expect(isComplete).to.equal(true);
		});
	});
});
