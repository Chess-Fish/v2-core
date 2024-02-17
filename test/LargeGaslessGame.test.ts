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

		return {
			signer0,
			signer1,
			chessGame,
			gaslessGame,
			dividendSplitter,
			chessNFT,
			domain,
			delegationTypes,
			gaslessMoveTypes,
			addressZero,
		};
	}

	describe("Gasless Game Verification Unit Tests", function () {
		it("Should play game", async function () {
			const {
				signer0,
				signer1,
				chessGame,
				gaslessGame,
				domain,
				delegationTypes,
				gaslessMoveTypes,
				addressZero,
			} = await loadFixture(deploy);

			const entropy0 = generateRandomHash();
			const delegatedSigner0 = ethers.Wallet.createRandom(entropy0);

			// 2) create deletation and hash it
			const delegationData0 = [signer0.address, delegatedSigner0.address, addressZero];

			// 3 Sign Typed Data V4
			const message0 = {
				delegatorAddress: delegationData0[0],
				delegatedAddress: delegationData0[1],
				gameAddress: delegationData0[2],
			};

			// Sign the data
			const signature0 = await signer0._signTypedData(domain, delegationTypes, message0);

			const signedDelegationData0 = await gaslessGame.encodeSignedDelegation(message0, signature0);

			// ON THE FRONT END user 1
			// 1) Generate random public private key pair
			const entropy1 = generateRandomHash();
			const delegatedSigner1 = ethers.Wallet.createRandom(entropy1);

			// 2) create deletation and hash it
			const delegationData1 = [signer1.address, delegatedSigner1.address, addressZero];

			// 3 Sign Typed Data V4
			const message1 = {
				delegatorAddress: delegationData1[0],
				delegatedAddress: delegationData1[1],
				gameAddress: delegationData1[2],
			};

			const signature1 = await signer1._signTypedData(domain, delegationTypes, message1);

			const signedDelegationData1 = await gaslessGame.encodeSignedDelegation(message1, signature1);

            const moves = 
            ['d2d4', 'g8f6', 'c2c4', 'g7g6', 'g2g3', 'c7c6', 'f1g2', 'd7d5', 'c4d5', 'c6d5', 'b1c3', 'f8g7',
            'e2e3', 'e8g8', 'g1e2', 'b8c6', 'e1g1', 'b7b6', 'b2b3', 'c8a6', 'c1a3', 'f8e8', 'd1d2', 'e7e5',
            'd4e5', 'c6e5', 'f1d1', 'e5d3', 'd2c2', 'd3f2', 'g1f2', 'f6g4', 'f2g1', 'g4e3', 'c2d2', 'e3g2',
            'g1g2', 'd5d4', 'e2d4', 'a6b7', 'g2f1', 'd8d7', 'd2f2', 'd7h3', 'f1g1', 'e8e1', 'd1e1', 'g7d4',
            'f2d4', 'h3g2'];		

			for (let game = 0; game < 1; game++) {
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
						gameAddress: addressZero,
						gameNumber: 0,
						expiration: Math.floor(Date.now() / 1000) + 3600,
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

				console.log("signers");
				console.log(signer0.address);
				console.log(signer1.address);
				console.log(delegatedSigner0.address);
				console.log(delegatedSigner1.address);
				console.log("____");

				console.log("Hash");
				const movesHash = ethers.utils.keccak256(abi.encode(["uint16[]"], [hex_move_array]));
				console.log(movesHash);

				console.log("MOVES", hex_move_array);
				await gaslessGame.verifyGameViewDelegated(delegations, lastTwoMoves);
				await chessGame.verifyGameUpdateStateDelegated(delegations, lastTwoMoves);
			}
		});

	});
});
