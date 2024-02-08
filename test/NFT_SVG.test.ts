const fs = require("fs");
const path = require("path");

import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { ethers } from "hardhat";

import { coordinates_array, bitCoordinates_array, pieceSymbols } from "../scripts/constants";

async function decodeSVG(svg: string): Promise<string> {
	// Check if svg starts with the data URI scheme
	const base64Prefix = "data:image/svg+xml;base64,";
	if (svg.startsWith(base64Prefix)) {
		// Extract the base64-encoded part
		const base64Data = svg.substring(base64Prefix.length);
		// Decode the base64 string
		const decodedSVG = Buffer.from(base64Data, "base64").toString("utf-8");
		return decodedSVG;
	} else {
		// If not encoded in base64 or a different format, handle accordingly
		console.log("SVG data does not start with the expected base64 prefix.");
		return svg; // Or throw an error, based on your use case
	}
}

describe("ChessFish NFT Unit Tests", function () {
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

		const Tournament = await ethers.getContractFactory("ChessFishTournament");
		const tournament = await Tournament.deploy(await chessGame.getAddress(), addressZero);
 
		// NFT
		const PieceSVG = await ethers.getContractFactory("PieceSVG");
		const pieceSVG = await PieceSVG.deploy();

		const TokenSVG = await ethers.getContractFactory("TokenSVG");
		const tokenSVG = await TokenSVG.deploy();

		const ChessFishNFT = await ethers.getContractFactory("ChessFishNFT");
		const chessNFT = await ChessFishNFT.deploy(
			await chessGame.getAddress(),
            await moveVerification.getAddress(),
			await pieceSVG.getAddress(),
			await tokenSVG.getAddress()
		);

        await pieceSVG.connect(deployer).initialize(await chessNFT.getAddress());
        await tokenSVG.connect(deployer).initialize(await chessNFT.getAddress());

		// Initializing
		await chessGame.initialize(
			await moveVerification.getAddress(),
			await gaslessGame.getAddress(),
			await tournament.getAddress(),
			await tournament.getAddress(),
			await chessNFT.getAddress()
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
            pieceSVG,
            tokenSVG,
			deployer,
			otherAccount,
			initalState,
			initialWhite,
			initialBlack, 
		};
	}
    
	describe("NFT Tests", function () {
		it("Should deploy", async function () {
			const { chessGame, gaslessGame, moveVerification, tournament, chessNFT, pieceSVG, tokenSVG } = await loadFixture(deploy);

            expect(await chessGame.getAddress()).to.equal(await chessNFT.chessGame());
            expect(await moveVerification.getAddress()).to.equal(await chessNFT.moveVerification());
            expect(await pieceSVG.getAddress()).to.equal(await chessNFT.pieceSVG());
            expect(await tokenSVG.getAddress()).to.equal(await chessNFT.tokenSVG());


            console.log(await chessNFT.getAddress());
            console.log(await chessNFT.chessGame());
            console.log(await chessNFT.moveVerification());
            console.log(await chessNFT.pieceSVG());
            console.log(await chessNFT.tokenSVG());


			const svgURI = await chessNFT.tokenURI(0);

			const svgBase64 = svgURI.split(",")[1]; // Assuming the structure is "data:image/svg+xml;base64,..."
			const svgContent = Buffer.from(svgBase64, "base64").toString("utf-8");

			// Define the file path for the output HTML file
			const filePath = path.join(__dirname, "SVG_output.html");

			// Write the SVG content to the file
			fs.writeFileSync(filePath, svgContent); 
			/*             // Step 1: Decode the JSON object from base64
            const jsonBase64 = svgURI.split(',')[1]; // Assuming the structure is always "data:application/json;base64,..."
            const jsonString = Buffer.from(jsonBase64, 'base64').toString('utf-8');
        
            // Step 2: Parse the JSON to extract the SVG
            const json = JSON.parse(jsonString);
            const svgBase64 = json.image.split(',')[1]; // Assuming the image data is always "data:image/svg+xml;base64,..."
        
            // Step 3: Decode the SVG data from base64
            const svgContent = Buffer.from(svgBase64, 'base64').toString('utf-8');
         */
			// console.log(svgContent);
		});
	});
});
