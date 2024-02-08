import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { ethers } from "hardhat";

import { coordinates_array, bitCoordinates_array, pieceSymbols } from "../scripts/constants";

describe("ChessFish Game Verification Unit Tests", function () {
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
		const tournament = await Tournament.deploy(chessGame.address, dividendSplitter);

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

		await pieceSVG.connect(deployer).initialize(chessNFT.address);
		await tokenSVG.connect(deployer).initialize(chessNFT.address);

		// Initializing
		await chessGame.initialize(
			moveVerification.address,
			gaslessGame.address,
			tournament.address,
			tournament.address
		);

		await chessGame.initCoordinatesAndSymbols(
			coordinates_array,
			bitCoordinates_array,
			pieceSymbols
		);

		const initalState = "0xcbaedabc99999999000000000000000000000000000000001111111143265234";
		const initialWhite = "0x000704ff";
		const initialBlack = "0x383f3cff";

		return {
			chessGame,
			gaslessGame,
			moveVerification,
			tournament,
			chessNFT,
			deployer,
			otherAccount,
			initalState,
			initialWhite,
			initialBlack,
		};
	}

	describe("Functionality Tests", function () {
		it("Should check deployement", async function () {
			const { chessGame, moveVerification, gaslessGame, tournament, chessNFT } = await loadFixture(
				deploy
			);

			const moveVerificationAddress = await chessGame.moveVerification();
			expect(moveVerificationAddress).to.equal(moveVerification.address);
		});
	});
});
