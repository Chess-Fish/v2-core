import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { ethers } from "hardhat";

import { coordinates_array, bitCoordinates_array, pieceSymbols } from "../scripts/constants";
import { moveToHex } from "../scripts/utils";

describe("ChessFish Game Verification Unit Tests", function () {
	// We define a fixture to reuse the same setup in every test.
	async function deploy() {
		const [deployer, otherAccount] = await ethers.getSigners();

		const addressZero = "0x0000000000000000000000000000000000000000";
		const dividendSplitter = "0x973C170C3BC2E7E1B3867B3B29D57865efDDa59a";

		const MoveVerification = await ethers.getContractFactory("MoveVerification");
		const moveVerification = await MoveVerification.deploy();

		const ChessGame = await ethers.getContractFactory("ChessGame");
		const chessGame = await ChessGame.deploy();

		const GaslessGame = await ethers.getContractFactory("GaslessGame");
		const gaslessGame = await GaslessGame.deploy();

		const Tournament = await ethers.getContractFactory("Tournament");
		const tournament = await Tournament.deploy(await chessGame.getAddress(), addressZero);

		// NFT
		const PieceSVG = await ethers.getContractFactory("PieceSVG");
		const pieceSVG = await PieceSVG.deploy();

		const TokenSVG = await ethers.getContractFactory("TokenSVG");
		const tokenSVG = await TokenSVG.deploy();

		const ChessFishNFT = await ethers.getContractFactory("ChessFishNFT");
		const chessNFT = await ChessFishNFT.deploy(
			await chessGame.getAddress(),
			await pieceSVG.getAddress(),
			await tokenSVG.getAddress()
		);

		await pieceSVG.connect(deployer).setNFT(await chessNFT.getAddress());
		await tokenSVG.connect(deployer).setNFT(await tokenSVG.getAddress());

		// Initializing
		await chessGame.initialize(
			await moveVerification.getAddress(),
			await gaslessGame.getAddress(),
			await tournament.getAddress(),
			dividendSplitter,
			await chessNFT.getAddress()
		);

		await chessGame.initCoordinates(coordinates_array, bitCoordinates_array, pieceSymbols);

		const initalState = "0xcbaedabc99999999000000000000000000000000000000001111111143265234";
		const initialWhite = "0x000704ff";
		const initialBlack = "0x383f3cff";

		return {
			chessGame,
			moveVerification,
			owner,
			otherAccount,
			initalState,
			initialWhite,
			initialBlack,
		};
	}

	describe("Functionality Tests", function () {
		it("Should get piece at position", async function () {
			const { moveVerification } = await loadFixture(deploy);

			let initalState = "0xcbaedabc99999999000000000000000000000000000000001111111143265234";
			let result = await moveVerification.pieceAtPosition(initalState, 0);

			// expect piece on h1 to be a white rook
			expect(result).to.equal(4);
		});
	});
});
