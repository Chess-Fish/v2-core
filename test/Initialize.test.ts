import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { expect, should } from "chai";
import { ethers } from "hardhat";

import { coordinates_array, bitCoordinates_array, moves_stalemate } from "../scripts/constants";
import { moveToHex } from "../scripts/utils";

describe("ChessFish Game Verification Unit Tests", function () {
	// We define a fixture to reuse the same setup in every test.
	async function deploy() {
		const [owner, otherAccount] = await ethers.getSigners();

		const MoveVerification = await ethers.getContractFactory("MoveVerification");
		const moveVerification = await MoveVerification.deploy();

		const ChessWager = await ethers.getContractFactory("ChessGame");
		const chessGame = await ChessWager.deploy();

		await chessGame.initialize(
			await moveVerification.getAddress(),
			await owner.getAddress(),
			await owner.getAddress(),
			await owner.getAddress()
		);

		await chessGame.initCoordinates(coordinates_array, bitCoordinates_array);

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
		it("Should revert on reinit", async function () {
			const { chessGame, moveVerification } = await loadFixture(deploy);
			const addressZero = "0x0000000000000000000000000000000000000000";

			const tx = chessGame.initialize(addressZero, addressZero, addressZero, addressZero);

			expect(tx).to.be.reverted;

			const _moveVerification = await chessGame.moveVerification();
			expect(await moveVerification.getAddress()).to.equal(_moveVerification);
		});
	});
});
