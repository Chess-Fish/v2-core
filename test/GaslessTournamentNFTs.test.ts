const fs = require("fs");
const path = require("path");

import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { ethers, network } from "hardhat";

import { coordinates_array, bitCoordinates_array, pieceSymbols } from "../scripts/constants";

describe("ChessFish Large Gasless Tournament Unit Tests", function () {
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

		const addressZero = ethers.constants.AddressZero;
		const ERC20_token = await ethers.getContractFactory("Token");
		const token = await ERC20_token.deploy();

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

		// Initializing NFT
		await pieceSVG.initialize(chessNFT.address);
		await tokenSVG.initialize(chessNFT.address);

		// Initializing Tournament
		await tournament.initialize(chessGame.address, dividendSplitter, chessNFT.address);

		// Initializing Contracts
		await chessGame.initialize(
			moveVerification.address,
			gaslessGame.address,
			tournament.address,
			tournament.address,
			chessNFT.address
		);

		await chessGame.initCoordinatesAndSymbols(
			coordinates_array,
			bitCoordinates_array,
			pieceSymbols
		);

		await gaslessGame.initialize(moveVerification.address, chessGame.address);
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

		// typed signature data
		const domain = {
			chainId: 1, // replace with the chain ID on frontend
			name: "ChessFish", // Contract Name
			verifyingContract: gaslessGame.address, // for testing
			version: "1", // version
		};

		const walletGenerationTypes = {
			WalletGeneration: [{ name: "gameAddress", type: "address" }],
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

		return {
			chessGame,
			gaslessGame,
			dividendSplitter,
			chessNFT,
			tournament,
			players,
			otherAccount,
			token,
			domain,
			walletGenerationTypes,
			delegationTypes,
			gaslessMoveTypes,
			addressZero,
		};
	}

	describe("Tournament Unit Tests", function () {
		it("Should start gasless authenticated tournament and play games 11 players", async function () {
			this.timeout(100000); // sets the timeout to 100 seconds

			const {
				chessGame,
				gaslessGame,
				tournament,
				players,
				chessNFT,
				domain,
				walletGenerationTypes,
				delegationTypes,
				gaslessMoveTypes,
				addressZero,
			} = await loadFixture(deploy);

			// let numberOfPlayers = 11;
			let gameToken = addressZero;
			let gameAmount = ethers.utils.parseEther("0");
			let numberOfGames = 1;
			let timeLimit = 86400;

			let playerAddresses = players.map((player) => player.address);

			let tx = await tournament
				.connect(players[0])
				.createTournamentWithSpecificPlayers(
					playerAddresses,
					numberOfGames,
					gameToken,
					gameAmount,
					timeLimit
				);

			await tx.wait();

			const tournamentNonce = await tournament.tournamentNonce();

			const playerAddressesContract = await tournament.getTournamentPlayers(tournamentNonce - 1);
			expect(playerAddressesContract.length).to.equal(11);

			console.log("TOURNAMENT STARTED");

			const gameAddresses = await tournament.getTournamentGameAddresses(tournamentNonce - 1);
			expect(gameAddresses.length).to.equal(55); // 11 players

			const moves = ["f2f3", "e7e5", "g2g4", "d8h4"]; // fool's mate // this test only works if this is used since the logic is based on black winning
			// const moves = ["e2e4", "f7f6", "d2d4", "g7g5", "d1h5"]; // reversed fool's mate

			for (let i = 0; i < gameAddresses.length; i++) {
				for (let j = 0; j < numberOfGames; j++) {
					let messageArray: any[] = [];

					let data = await chessGame.gameData(gameAddresses[i]);

					let player0 = await ethers.getSigner(data.player0);
					let player1 = await ethers.getSigner(data.player1);

					// Deterministic wallet & delegation 1
					const seed0 = {
						gameAddress: gameAddresses[i],
					};
					const delegationSig0 = await player0._signTypedData(domain, walletGenerationTypes, seed0);
					const hashedSig0 = ethers.utils.keccak256(delegationSig0);
					const mnemonic0 = ethers.utils.entropyToMnemonic(hashedSig0);
					const delegatedSigner0 = ethers.Wallet.fromMnemonic(mnemonic0);
					const message0 = {
						delegatorAddress: player0.address,
						delegatedAddress: delegatedSigner0.address,
						gameAddress: gameAddresses[i],
					};
					const signature0 = await player0._signTypedData(domain, delegationTypes, message0);

					// Deterministic wallet & delegation 2
					const seed1 = {
						gameAddress: gameAddresses[i],
					};
					const delegationSig1 = await player1._signTypedData(domain, walletGenerationTypes, seed1);
					const hashedSig1 = ethers.utils.keccak256(delegationSig1);
					const mnemonic1 = ethers.utils.entropyToMnemonic(hashedSig1);
					const delegatedSigner1 = ethers.Wallet.fromMnemonic(mnemonic1);
					const message1 = {
						delegatorAddress: player1.address,
						delegatedAddress: delegatedSigner1.address,
						gameAddress: gameAddresses[i],
					};
					const signature1 = await player1._signTypedData(domain, delegationTypes, message1);

					// Delegation Data
					const signedDelegationData0 = await gaslessGame.encodeSignedDelegation(
						message0,
						signature0
					);
					const signedDelegationData1 = await gaslessGame.encodeSignedDelegation(
						message1,
						signature1
					);

					let playerAddress = await chessGame.getPlayerMove(gameAddresses[i]);
					let startingPlayer =
						playerAddress === player1.address ? delegatedSigner1 : delegatedSigner0;

					const hex_move_array: number[] = [];
					for (let k = 0; k < moves.length; k++) {
						let player;
						if (k % 2 == 0) {
							player = startingPlayer; // First move of the game by starting player
						} else {
							player =
								startingPlayer.address === delegatedSigner1.address
									? delegatedSigner0
									: delegatedSigner1; // Alternate for subsequent moves using address for comparison
						}
						console.log(`Playing game ${i} of ${gameAddresses.length}`);

						const hex_move = await chessGame.moveToHex(moves[k]);
						hex_move_array.push(hex_move);
						const movesHash = ethers.utils.keccak256(
							ethers.utils.defaultAbiCoder.encode(["uint16[]"], [hex_move_array])
						);

						const moveData = {
							gameAddress: gameAddresses[i],
							gameNumber: j,
							expiration: Math.floor(Date.now() / 1000) + 86400,
							movesHash: movesHash,
						};

						const signature = await player._signTypedData(domain, gaslessMoveTypes, moveData);

						const gaslessMoveData = await gaslessGame.encodeMoveMessage(
							moveData,
							signature,
							hex_move_array
						);

						messageArray.push(gaslessMoveData);
					}
                    console.log(hex_move_array);
					const delegations = [signedDelegationData0, signedDelegationData1];
					const lastTwoMoves = messageArray.slice(-2);
					await chessGame.verifyGameUpdateStateDelegated(delegations.reverse(), lastTwoMoves);
				}
			}

			await ethers.provider.send("evm_increaseTime", [86400 * 2]);
			await ethers.provider.send("evm_mine");

			await tournament.payoutTournament(tournamentNonce - 1);

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

			// Tournament of 3 games
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

			const data = await tournament.viewTournamentScore(tournamentNonce - 1);

			let sum = 0;
			for (let i = 0; i < data[1].length; i++) {
				sum += Number(data[1][i]);
			}
			expect(sum).to.equal(gameAddresses.length * numberOfGames);

			expect(data[1][0]).to.equal(player0wins);
			expect(data[1][1]).to.equal(player1wins);
			expect(data[1][2]).to.equal(player2wins);
			expect(data[1][3]).to.equal(player3wins);
			expect(data[1][4]).to.equal(player4wins);
			expect(data[1][5]).to.equal(player5wins);
			expect(data[1][6]).to.equal(player6wins);
			expect(data[1][7]).to.equal(player7wins);
			expect(data[1][8]).to.equal(player8wins);
			expect(data[1][9]).to.equal(player9wins);
			expect(data[1][10]).to.equal(player10wins);

			let isComplete = (await tournament.tournaments(tournamentNonce - 1)).isComplete;
			expect(isComplete).to.equal(true);

			// console.log(players[1].address);

			let balance = await chessNFT.balanceOf(players[1].address);
			expect(balance).to.equal(9);

			let ownerOf = await chessNFT.ownerOf(0);
			console.log("owner", ownerOf);

			const svgURI = await chessNFT.tokenURI(0);

			// Step 1: Decode the JSON object from base64
			const jsonBase64 = svgURI.split(",")[1]; // Assuming the structure is "data:application/json;base64,..."
			const jsonString = Buffer.from(jsonBase64, "base64").toString("utf-8");

			// Step 2: Parse the JSON to extract the SVG
			const json = JSON.parse(jsonString);
			const svgBase64 = json.image.split(",")[1]; // Assuming the image data starts with "data:image/svg+xml;base64,"

			// Step 3: Decode the SVG data from base64
			const svgContent = Buffer.from(svgBase64, "base64").toString("utf-8");

			// Define the file path for the output HTML file
			const filePath = path.join(__dirname, "SVG_outputTournament.html");

			// Write the SVG content to the file
			fs.writeFileSync(filePath, svgContent);

			console.log(json.name);
			console.log(json.description);
			console.log(json.attributes);
		});
	});
});
