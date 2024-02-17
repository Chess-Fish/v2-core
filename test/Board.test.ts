import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { ethers } from "hardhat";

import {
	coordinates_array,
	bitCoordinates_array,
	pieceSymbols,
	moves_stalemate,
} from "../scripts/constants";
import { moveToHex } from "../scripts/utils";

describe("ChessFish Game Verification Unit Tests", function () {
	// We define a fixture to reuse the same setup in every test.
	async function deploy() {
		const [owner, otherAccount] = await ethers.getSigners();

		const MoveVerification = await ethers.getContractFactory("MoveVerification");
		const moveVerification = await MoveVerification.deploy();

		const ChessGame = await ethers.getContractFactory("ChessGame");
		const chessGame = await ChessGame.deploy();

		await chessGame.initialize(
			moveVerification.address,
			owner.address,
			owner.address,
			owner.address,
			owner.address
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
			moveVerification,
			owner,
			otherAccount,
			initalState,
			initialWhite,
			initialBlack,
		};
	}

	describe("Board Tests", function () {
		it("Should get piece at position", async function () {
			const { moveVerification } = await loadFixture(deploy);

			let initalState = "0xcbaedabc99999999000000000000000000000000000000001111111143265234";
			let result = await moveVerification.pieceAtPosition(initalState, 0);

			// expect piece on h1 to be a white rook
			expect(result).to.equal(4);
		});

		it("Should get all pieces on board", async function () {
			const { chessGame } = await loadFixture(deploy);

			let initalState =
				"92127013753780222654361466179409805358231942438704711313202171559978994127412";

			let result = await chessGame.getBoard(initalState);

			let row = [];
			for (let i = 0; i < 64; i++) {
				row.push(result[i]);

				if ((i + 1) % 8 === 0) {
					row = [];
				}
			}
		});

		it("Should print ascii board", async function () {
			const { chessGame } = await loadFixture(deploy);

			let gameState =
				"92127013753780222654360604150668269002455902644110213085750839854476319674932";

			let data = await chessGame.getBoard(gameState);

			let result = Object.values(data);

			let pieces = result.reverse();

			let board = "   +------------------------+\n ";

			for (let i = 0; i < 64; i++) {
				if (i % 8 === 0) {
					let row_num = 8 - i / 8;
					board += String(row_num) + "  ";
				}

				board += " " + pieces[i] + " ";

				if ((i + 1) % 8 === 0) {
					board += "\n ";
				}
			}

			board += "  +------------------------+\n";
			board += "     a  b  c  d  e  f  g  h";

			// console.log(board);
		});

		it("Should get correct board after moves", async function () {
			const { chessGame, moveVerification } = await loadFixture(deploy);

			const moves = ["f2f3", "e7e5", "g2g4", "d8h4"];

			let hex_moves = [];

			for (let i = 0; i < moves.length; i++) {
				let hex_move = await chessGame.moveToHex(moves[i]);
				hex_moves.push(hex_move);
			}

			let outcome = await moveVerification.checkGameFromStart(hex_moves);

			expect(outcome[0]).to.equal(3);
		});

		it("Should print ascii board after each move", async function () {
			const { chessGame, moveVerification } = await loadFixture(deploy);

			const moves = ["f2f3", "e7e5", "g2g4", "d8h4"];

			let hex_moves = [];

			for (let i = 0; i < moves.length; i++) {
				let hex_move = await chessGame.moveToHex(moves[i]);
				hex_moves.push(hex_move);

				let outcome = await moveVerification.checkGameFromStart(hex_moves);
				let data = await chessGame.getBoard(outcome[1]);

				let result = Object.values(data);

				let pieces = result.reverse();

				let board = "   +------------------------+\n ";

				for (let i = 0; i < 64; i++) {
					if (i % 8 === 0) {
						let row_num = 8 - i / 8;
						board += String(row_num) + "  ";
					}

					board += " " + pieces[i] + " ";

					if ((i + 1) % 8 === 0) {
						board += "\n ";
					}
				}

				board += "  +------------------------+\n";
				board += "     a  b  c  d  e  f  g  h";

				// console.log(board);
			}
		});
	});
});
