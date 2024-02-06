import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { ethers } from "hardhat";

describe("ChessFish Game Unit Tests", function () {
	// We define a fixture to reuse the same setup in every test.
	async function deploy() {
		const [deployer, otherAccount] = await ethers.getSigners();

		const ChessGame = await ethers.getContractFactory("ChessGame");
		const chessGame = await ChessGame.deploy();

		return {
			chessGame,
		};
	}
	describe("Hardhat Tests", function () {
		it("Should deploy", async function () {
			const { chessGame } = await loadFixture(deploy);

			console.log(chessGame.address);
		});
	});
});
