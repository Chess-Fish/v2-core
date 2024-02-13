import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { ethers } from "hardhat";

import { coordinates_array, bitCoordinates_array, pieceSymbols } from "../scripts/constants";

describe("ChessFish Game Verification Unit Tests", function () {
	async function deploy() {
		const [deployer, otherAccount] = await ethers.getSigners();

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

		return {
			chessGame,
			gaslessGame,
			moveVerification,
			tournament,
			chessNFT,
			deployer,
			otherAccount,
		};
	}

	describe("Functionality Tests", function () {
		it("Should check deployement", async function () {
			const { chessGame, moveVerification } = await loadFixture(deploy);

			const moveVerificationAddress = await chessGame.moveVerification();
			expect(moveVerificationAddress).to.equal(moveVerification.address);
		});
	});
});
