const fs = require('fs');
const path = require('path');

import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { ethers } from "hardhat";

import { coordinates_array, bitCoordinates_array } from "../scripts/constants";


// This function assumes `svg` is a string containing the full URI returned by `tokenURI`
async function decodeSVG(svg: string): Promise<string> {
    // Check if svg starts with the data URI scheme
    const base64Prefix = 'data:image/svg+xml;base64,';
    if (svg.startsWith(base64Prefix)) {
        // Extract the base64-encoded part
        const base64Data = svg.substring(base64Prefix.length);
        // Decode the base64 string
        const decodedSVG = Buffer.from(base64Data, 'base64').toString('utf-8');
        return decodedSVG;
    } else {
        // If not encoded in base64 or a different format, handle accordingly
        console.log('SVG data does not start with the expected base64 prefix.');
        return svg; // Or throw an error, based on your use case
    }
}


describe("ChessFish NFT Unit Tests", function () {
	// We define a fixture to reuse the same setup in every test.
	async function deploy() {
		const [deployer, otherAccount] = await ethers.getSigners();

        const MoveVerification = await ethers.getContractFactory("MoveVerification");
		const moveVerification = await MoveVerification.deploy();

        const moveVerificationAddress = await moveVerification.getAddress();

  		const ChessGame = await ethers.getContractFactory("ChessGame");
		const chessGame = await ChessGame.deploy(moveVerificationAddress, moveVerificationAddress,moveVerificationAddress,moveVerificationAddress);
 
        await chessGame.initCoordinates(coordinates_array, bitCoordinates_array);


		const ChessFishNFT = await ethers.getContractFactory("ChessFishNFT_V2");
		const chessNFT = await ChessFishNFT.deploy("0x0000000000000000000000000000000000000000");

		return {
			chessNFT
		}
    }
	describe("NFT Tests", function () {

        it("Should deploy", async function () {
            const { chessNFT } = await loadFixture(deploy);

            const svgURI = await chessNFT.tokenURI(0);

            const svgBase64 = svgURI.split(',')[1]; // Assuming the structure is "data:image/svg+xml;base64,..."
const svgContent = Buffer.from(svgBase64, 'base64').toString('utf-8');

       
    // Define the file path for the output HTML file
    const filePath = path.join(__dirname, 'NFT_SVG_output.html');

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
