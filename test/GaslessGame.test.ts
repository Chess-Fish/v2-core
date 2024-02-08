import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { ethers } from "hardhat";

import {
	generateRandomHash,
	coordinates_array,
	bitCoordinates_array,
	pieceSymbols,
} from "../scripts/constants";

describe("ChessFish Wager Unit Tests", function () {
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
		const tournament = await Tournament.deploy(await chessGame.address, addressZero);

		// NFT
		const PieceSVG = await ethers.getContractFactory("PieceSVG");
		const pieceSVG = await PieceSVG.deploy();

		const TokenSVG = await ethers.getContractFactory("TokenSVG");
		const tokenSVG = await TokenSVG.deploy();

		console.log(await tokenSVG.address);

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

		await chessGame.initCoordinatesAndSymbols(
			coordinates_array,
			bitCoordinates_array,
			pieceSymbols
		);

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
				{ name: "gameNumber", type: "uint" },
				{ name: "expiration", type: "uint" },
				{ name: "moves", type: "uint16[]" },
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

    interface TypedDataField {
        name: string;
        type: string;
    }
    
    interface TypedDataTypes {
        [typeName: string]: TypedDataField[];
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

			const moves = ["e2e4", "f7f6", "d2d4", "g7g5", "d1h5"]; // reversed fool's mate

			const timeNow = Date.now();
			const timeStamp = Math.floor(timeNow / 1000) + 86400;

			for (let game = 0; game < 1; game++) {
				let messageArray: any[] = [];
				let signatureArray: any[] = [];
				const hex_move_array: number[] = [];

				for (let i = 0; i < moves.length; i++) {
					const player = i % 2 === 0 ? delegatedSigner0 : delegatedSigner1;

					const hex_move = await chessGame.moveToHex(moves[i]);

					hex_move_array.push(hex_move);

					const gaslessMoveTypes = {
						GaslessMove: [
							{ name: "gameAddress", type: "address" },
							{ name: "gameNumber", type: "uint256" },
							{ name: "expiration", type: "uint256" },
							{ name: "moves", type: "uint16[]" },
						],
					};

					const messageData = {
						gameAddress: addressZero,
						gameNumber: 0,
						expiration: timeStamp,
						moves: hex_move_array,
					};

					const signature = await player._signTypedData(domain, gaslessMoveTypes, messageData);


                    const { ethers } = require("ethers");
                    
                    // Adjusted computeTypeHash function
                    function computeTypeHash(fields: TypedDataField[]): string {
                        const typeString = `GaslessMove(${fields.map(field => `${field.type} ${field.name}`).join(',')})`;
                        return ethers.utils.keccak256(ethers.utils.toUtf8Bytes(typeString));
                    }
                    
                    // Use the function with the defined types
                    const gaslessMoveTypeHash = computeTypeHash(gaslessMoveTypes["GaslessMove"]);
                    console.log("GaslessMove Type Hash:", gaslessMoveTypeHash);
                    

					const moveData = {
						move: messageData,
						signature: signature,
					};
					console.log(player.address);
					console.log("sig", moveData.signature);
					await gaslessGame.verifyMoveSigner(moveData, player.address);

					// console.log(messageData);

					const digest = ethers.utils._TypedDataEncoder.hash(domain, gaslessMoveTypes, messageData);

					console.log("Digest (hash) of the typed data:", digest);

					//  const signature = await player._signTypedData(domain, gaslessMoveTypes, messageData);
					signatureArray.push(signature);

					const message = await gaslessGame.encodeMoveMessage(messageData, signature);
					messageArray.push(message);
				}
				const delegations = [signedDelegationData0, signedDelegationData1];

				const lastTwoMoves = messageArray.slice(-2);

				console.log("signers");
				console.log(signer0.address);
				console.log(signer1.address);
				console.log(delegatedSigner0.address);
				console.log(delegatedSigner1.address);
				console.log("____");

				// await chessGame.verifyGameUpdateStateDelegated(delegations, lastTwoMoves);
			}
		});
	});
});
