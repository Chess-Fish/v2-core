import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { ethers } from "hardhat";

import fs from "fs";

import { Chess } from "chess.js";
import { splitSignature } from "ethers/lib/utils";

import { coordinates_array, bitCoordinates_array, pieceSymbols } from "../scripts/constants";

describe("ChessFish Intensive MoveVerification Unit Tests", function () {
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


        const initalState = "0xcbaedabc99999999000000000000000000000000000000001111111143265234";
        const initialWhite = "0x000704ff";
        const initialBlack = "0x383f3cff";

        return {
            chessGame,
            moveVerification,
            gaslessGame,
            chessNFT,
            deployer,
            otherAccount,
            initalState,
            initialWhite,
            initialBlack,
        };
    }

    describe("Functionality Tests", function () {
        let games;
        try {
            const data = fs.readFileSync("test/test_data/output_moves.json", "utf8");
            games = JSON.parse(data);
        } catch (err) {
            console.error("Error reading file:", err);
            return;
        }
        
        const maxTests = 10; // Maximum number of tests to run during code coverage
        let count = 0; 
    
        games.forEach((game, index) => {
            if (count < maxTests) { // Use maxTests to limit the number of tests
                it(`Should get outcome from checkEndgame using algebraic chess notation for game ${
                    index + 1
                }`, async function () {
                    const { chessGame, moveVerification } = await loadFixture(deploy);
    
                    const chessInstance = new Chess();
    
                    const moves = game.moves;
    
                    let hex_moves = [];
    
                    for (let i = 0; i < moves.length; i++) {
                        let fromSquare = moves[i].substring(0, 2);
                        let toSquare = moves[i].substring(2);
    
                        try {
                            chessInstance.move({
                                from: fromSquare,
                                to: toSquare,
                                promotion: "q",
                            });
                        } catch (error) {
                            console.log(fromSquare + toSquare);
                            console.log(error);
                            break;
                        }
    
                        let hex_move = await chessGame.moveToHex(moves[i]);
                        hex_moves.push(hex_move);
                    }
    
                    let outcome = await moveVerification.checkGameFromStart(hex_moves);
    
                    let winner;
                    if (chessInstance.isCheckmate()) {
                        winner = chessInstance.turn() === "w" ? 3 : 2;
    
                        let winnerColor = chessInstance.turn() === "w" ? "Black" : "White";
                        console.log(`CHECKMATE ${winnerColor} won the game`);
                    } else if (chessInstance.isStalemate()) {
                        console.log("DRAW");
                        winner = 1;
                    } else {
                        winner = 0;
                    }
    
                    expect(outcome[0]).to.equal(winner);
    
                    chessInstance.reset();
    
                });
            } else {
                return;
            }
                    count++;
        });
    });
    
});
