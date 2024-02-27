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
		it("Should start tournament and play games 11 players", async function () {
			this.timeout(100000); // sets the timeout to 100 seconds

			const { chessGame, tournament, players, otherAccount, token } = await loadFixture(deploy);

			let numberOfPlayers = 25;
			let gameToken = token.address;
			let gameAmount = ethers.utils.parseEther("10.0");
			let numberOfGames = 1;
			let timeLimit = 86400;

			let tx = await tournament
				.connect(players[0])
				.createTournament(numberOfPlayers, numberOfGames, gameToken, gameAmount, timeLimit);

			await tx.wait();

			const tournamentNonce = await tournament.tournamentNonce();

			const playersSansPlayer0 = [...players];
			playersSansPlayer0.shift();

			await Promise.all(
				playersSansPlayer0.map(async (player) => {
					return await tournament.connect(player).joinTournament(tournamentNonce - 1);
				})
			);

			await tournament.connect(otherAccount).joinTournament(tournamentNonce - 1);

			let gameAddresses = await tournament.getTournamentGameAddresses(tournamentNonce - 1);
			expect(gameAddresses.length).to.equal(66); // 12 players
			
			await tournament.connect(otherAccount).exitTournament(tournamentNonce - 1);
			gameAddresses = await tournament.getTournamentGameAddresses(tournamentNonce - 1);
			expect(gameAddresses.length).to.equal(55); // 11 players

			await tournament.connect(otherAccount).depositToTournament(tournamentNonce - 1, gameAmount);

			const balance0 = await token.balanceOf(tournament.address);
			expect(balance0).to.equal(gameAmount.mul(12)); // 11 players + 10 deposit

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
					console.log(`Game ${i} of ${gameAddresses.length}`);
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

			let data = await tournament.tournaments(tournamentNonce - 1);
			let prizePool = data.prizePool.toString();

			console.log(prizePool)

			const pool = gameAmount * 11 + prizePool;
			const expectedPayoutPlayer0 = pool * 0.365;
			const expectedPayoutPlayer1 = pool * 0.23;
			const expectedPayoutPlayer2 = pool * 0.135;
			const expectedPayoutPlayer3 = pool * 0.1;
			const expectedPayoutPlayer4 = pool * 0.05;
			const expectedPayoutPlayer5 = pool * 0.025;
			const expectedPayoutPlayer6 = pool * 0.025;
			const expectedPayoutPlayer7 = pool * 0.0;

			// winners
			expect(player0bal1.sub(player0bal0).toString()).to.equal(expectedPayoutPlayer0.toString());
			expect(player1bal1.sub(player1bal0).toString()).to.equal(expectedPayoutPlayer1.toString());
			expect(player2bal1.sub(player2bal0).toString()).to.equal(expectedPayoutPlayer2.toString());
			expect(player3bal1.sub(player3bal0).toString()).to.equal(expectedPayoutPlayer3.toString());
			expect(player4bal1.sub(player4bal0).toString()).to.equal(expectedPayoutPlayer4.toString());
			expect(player5bal1.sub(player5bal0).toString()).to.equal(expectedPayoutPlayer5.toString());
			expect(player6bal1.sub(player6bal0).toString()).to.equal(expectedPayoutPlayer6.toString());

			// payout zero
			expect(player7bal1.sub(player7bal0).toString()).to.equal(expectedPayoutPlayer7.toString());
			expect(player8bal1.sub(player8bal0).toString()).to.equal(expectedPayoutPlayer7.toString());
			expect(player9bal1.sub(player9bal0).toString()).to.equal(expectedPayoutPlayer7.toString());
			expect(player10bal1.sub(player10bal0).toString()).to.equal(expectedPayoutPlayer7.toString());

			// wins
			const player0wins = await tournament.tournamentWins(tournamentNonce - 1, players[0].address);
			const player1wins = await tournament.tournamentWins(tournamentNonce - 1, players[1].address);
			const player2wins = await tournament.tournamentWins(tournamentNonce - 1, players[2].address);
			const player3wins = await tournament.tournamentWins(tournamentNonce - 1, players[3].address);
			const player4wins = await tournament.tournamentWins(tournamentNonce - 1, players[4].address);
			const player5wins = await tournament.tournamentWins(tournamentNonce - 1, players[5].address);
			const player6wins = await tournament.tournamentWins(tournamentNonce - 1, players[6].address);
			const player7wins = await tournament.tournamentWins(tournamentNonce - 1, players[7].address);
			const player8wins = await tournament.tournamentWins(tournamentNonce - 1, players[8].address);
			const player9wins = await tournament.tournamentWins(tournamentNonce - 1, players[9].address);
			const player10wins = await tournament.tournamentWins(
				tournamentNonce - 1,
				players[10].address
			);

			expect(player0wins).to.equal(10);
			expect(player1wins).to.equal(9);
			expect(player2wins).to.equal(8);
			expect(player3wins).to.equal(7);
			expect(player4wins).to.equal(6);
			expect(player5wins).to.equal(5);
			expect(player6wins).to.equal(4);
			expect(player7wins).to.equal(3);
			expect(player8wins).to.equal(2);
			expect(player9wins).to.equal(1);
			expect(player10wins).to.equal(0);

			const scoreData = await tournament.viewTournamentScore(tournamentNonce - 1);

			expect(scoreData[1][0]).to.equal(player0wins);
			expect(scoreData[1][1]).to.equal(player1wins);
			expect(scoreData[1][2]).to.equal(player2wins);
			expect(scoreData[1][3]).to.equal(player3wins);
			expect(scoreData[1][4]).to.equal(player4wins);
			expect(scoreData[1][5]).to.equal(player5wins);
			expect(scoreData[1][6]).to.equal(player6wins);
			expect(scoreData[1][7]).to.equal(player7wins);
			expect(scoreData[1][8]).to.equal(player8wins);
			expect(scoreData[1][9]).to.equal(player9wins);
			expect(scoreData[1][10]).to.equal(player10wins);

			let isComplete = (await tournament.tournaments(tournamentNonce - 1)).isComplete;
			expect(isComplete).to.equal(true);
		});
	});
});
