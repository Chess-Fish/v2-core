import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { expect, version } from "chai";
import { ethers } from "hardhat";
const abi = new ethers.utils.AbiCoder();

import {
	generateRandomHash,
	coordinates_array,
	bitCoordinates_array,
	pieceSymbols,
} from "../scripts/constants";

const { _TypedDataEncoder } = require("ethers/lib/utils");

describe("ChessFish Chess Game Unit Tests", function () {
	async function deploy() {
		const [signer0, signer1] = await ethers.getSigners();

		const addressZero = "0x0000000000000000000000000000000000000000";
		const dividendSplitter = "0x973C170C3BC2E7E1B3867B3B29D57865efDDa59a";

		const ERC20_token = await ethers.getContractFactory("Token");
		const token = await ERC20_token.deploy();

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

		const amount = ethers.utils.parseEther("100");
		await token.transfer(signer1.address, amount);

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

		return {
			signer0,
			signer1,
			chessGame,
			gaslessGame,
			dividendSplitter,
			chessNFT,
			token,
			domain,
			delegationTypes,
			gaslessMoveTypes,
			addressZero,
		};
	}

	describe("Gasless Staked Game Verification Unit Tests", function () {
		it("Should play game", async function () {
			const {
				signer0,
				signer1,
				chessGame,
				gaslessGame,
				token,
				domain,
				delegationTypes,
				gaslessMoveTypes,
				addressZero,
			} = await loadFixture(deploy);

			let player1 = signer1.address;
			let gameToken = token.address;
			let gameAmount = ethers.utils.parseEther("100.0");
			let timeLimit = 86400;
			let numberOfGames = 3;

			await token.approve(chessGame.address, gameAmount);

			let tx = await chessGame
				.connect(signer0)
				.createChessGame(player1, gameToken, gameAmount, timeLimit, numberOfGames);
			await tx.wait();

			let gameAddress = await chessGame.userGames(signer0.address, 0);

			const entropy0 = generateRandomHash();
			const delegatedSigner0 = ethers.Wallet.createRandom(entropy0);

			// 2) create deletation and hash it
			const delegationData0 = [signer0.address, delegatedSigner0.address, gameAddress];

			// 3 Sign Typed Data V4
			const message0 = {
				delegatorAddress: delegationData0[0],
				delegatedAddress: delegationData0[1],
				gameAddress: delegationData0[2],
			};

			// Sign the data
			const signature0 = await signer0._signTypedData(domain, delegationTypes, message0);

			const signedDelegationData0 = await gaslessGame.encodeSignedDelegation(message0, signature0);

			// Testing individual delegation
			// Internal
			// await gaslessGame.verifyDelegation([message0 ,signature0]);

			// ON THE FRONT END user 1
			// 1) Generate random public private key pair
			const entropy1 = generateRandomHash();
			const delegatedSigner1 = ethers.Wallet.createRandom(entropy1);

			// 2) create deletation and hash it
			const delegationData1 = [signer1.address, delegatedSigner1.address, gameAddress];

			// 3 Sign Typed Data V4
			const message1 = {
				delegatorAddress: delegationData1[0],
				delegatedAddress: delegationData1[1],
				gameAddress: delegationData1[2],
			};

			const signature1 = await signer1._signTypedData(domain, delegationTypes, message1);

			const signedDelegationData1 = await gaslessGame.encodeSignedDelegation(message1, signature1);

			let amount = await token.balanceOf(chessGame.address);
			expect(amount).to.equal(gameAmount);

			await token.connect(signer1).approve(chessGame.address, gameAmount);
			await chessGame.connect(signer1).acceptGame(gameAddress);

			let amount1 = await token.balanceOf(chessGame.address);
			expect(amount1).to.equal(gameAmount.mul(2));

			const moves = ["e2e4", "f7f6", "d2d4", "g7g5", "d1h5"]; // reversed fool's mate

			for (let game = 0; game < numberOfGames; game++) {
				let messageArray: any[] = [];
				let signatureArray: any[] = [];
				const hex_move_array: number[] = [];

				for (let i = 0; i < moves.length; i++) {
					const player = i % 2 === 0 ? delegatedSigner0 : delegatedSigner1;

					const hex_move = await chessGame.moveToHex(moves[i]);

					hex_move_array.push(hex_move);

					// Correctly pass the array as a single element within another array
					const movesHash = ethers.utils.keccak256(abi.encode(["uint16[]"], [hex_move_array]));

					const moveData = {
						gameAddress: gameAddress,
						gameNumber: 0,
						expiration: Math.floor(Date.now() / 1000) + 86400 * 10,
						movesHash: movesHash,
					};

					// Signing the data
					const signature = await player._signTypedData(domain, gaslessMoveTypes, moveData);

					const gaslessMoveData = await gaslessGame.encodeMoveMessage(
						moveData,
						signature,
						hex_move_array
					);

					// await gaslessGame.verifyMoveSigner(gaslessMoveData, player.address);

					signatureArray.push(signature);
					messageArray.push(gaslessMoveData);
				}
				const delegations = [signedDelegationData0, signedDelegationData1];

				const lastTwoMoves = messageArray.slice(-2);

				await gaslessGame.verifyGameViewDelegated(delegations.reverse(), lastTwoMoves);
				await chessGame.verifyGameUpdateStateDelegated(delegations, lastTwoMoves);
			}

			const wins = await chessGame.gameStatus(gameAddress);

			const winsPlayer0 = Number(wins.winsPlayer0);
			const winsPlayer1 = Number(wins.winsPlayer1);

			expect(winsPlayer0).to.equal(1);
			expect(winsPlayer1).to.equal(2);

			const gameData = await chessGame.gameData(gameAddress);
			expect(gameData.isComplete).to.equal(true);
			expect(gameData.tokenAmount).to.equal(gameAmount);

			let hasBeenPaid = await chessGame.hasBeenPaid(gameAddress);
			expect(hasBeenPaid).to.equal(false);

			let bal0 = await token.balanceOf(signer1.address);

			await chessGame.payoutGame(gameAddress);

			hasBeenPaid = await chessGame.hasBeenPaid(gameAddress);
			expect(hasBeenPaid).to.equal(true);

			let bal1 = await token.balanceOf(signer1.address);

			expect(bal1.sub(bal0)).to.equal(ethers.utils.parseEther("190"));
		});
	});
});
