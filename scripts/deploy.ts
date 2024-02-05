import { ethers } from "hardhat";
const fs = require("fs");

import { coordinates_array, bitCoordinates_array } from "./constants";

interface ContractAddresses {
	network: string;
	chainID: number;
	deployer: string;
	chessFishToken: string;
	dividendSplitter: string;
	chessNFT: string;
	moveVerification: string;
	gaslessGame: string;
	chessWager: string;
	tournament: string;
}

async function deploy(): Promise<void> {
	const [deployer, owner] = await ethers.getSigners();

	const CFSH = "0xc218A06a17FeB66B1a730889fB9624326Fabff4b"; // CFSH.e on Arbitrum

	const SPLITTER = await ethers.getContractFactory("PaymentSplitter");
	const splitter = await SPLITTER.deploy(CFSH);
	await splitter.deployed();
	console.log("Dividend splitter contract deployed");

	const ChessNFT = await ethers.getContractFactory("ChessFishNFT");
	const chessNFT = await ChessNFT.deploy();
	await chessNFT.deployed();
	console.log("ChessNFT contract deployed");

	const MoveVerification = await ethers.getContractFactory("MoveVerification");
	const moveVerification = await MoveVerification.deploy();
	await moveVerification.deployed();
	console.log("Move verification contract deployed");

	const GaslessGame = await ethers.getContractFactory("GaslessGame");
	const gaslessGame = await GaslessGame.deploy(moveVerification.address);
	console.log("Gasless game contract deployed");

	const ChessWager = await ethers.getContractFactory("ChessWager");
	const chess = await ChessWager.deploy(
		moveVerification.address,
		gaslessGame.address,
		splitter.address,
		chessNFT.address
	);
	console.log("ChessWager contract deployed");

	const ChessTournament = await ethers.getContractFactory("ChessFishTournament");
	const tournament = await ChessTournament.deploy(chess.address, splitter.address);
	await tournament.deployed();
	console.log("Chess Tournament contract deployed");

	const tx = await chess.addTournamentHandler(tournament.address);
	await tx.wait();

	const contractAddresses: ContractAddresses = {
		network: ethers.provider._network.name,
		chainID: ethers.provider._network.chainId,
		deployer: deployer.address,
		chessFishToken: CFSH,
		dividendSplitter: splitter.address,
		chessNFT: chessNFT.address,
		moveVerification: moveVerification.address,
		gaslessGame: gaslessGame.address,
		chessWager: chess.address,
		tournament: tournament.address,
	};

	let existingAddresses: ContractAddresses[] = [];

	try {
		const data = fs.readFileSync("contractAddresses.json", "utf8");
		const parsedData = JSON.parse(data);
		existingAddresses = Array.isArray(parsedData) ? parsedData : [parsedData];
	} catch (err) {
		console.error("Error reading contractAddresses.json file:", err);
	}

	const index = existingAddresses.findIndex((addr) => addr.chainID === contractAddresses.chainID);

	if (index !== -1) {
		existingAddresses[index] = contractAddresses; // Update the existing entry
	} else {
		existingAddresses.push(contractAddresses); // Add new entry
	}

	fs.writeFileSync("contractAddresses.json", JSON.stringify(existingAddresses, null, 2));

	console.log("Network: ", contractAddresses.network);
	console.log("Deployer: ", contractAddresses.deployer);
	console.log("Chess Fish Token", contractAddresses.chessFishToken);
	console.log("Dividend Splitter", contractAddresses.dividendSplitter);
	console.log("ChessNFT address", contractAddresses.chessNFT);
	console.log("Move Verification address", contractAddresses.moveVerification);
	console.log("GaslessGame address", contractAddresses.gaslessGame);
	console.log("Chess Contract address", contractAddresses.chessWager);
	console.log("Tournament contract", contractAddresses.tournament);

	try {
		const tx1 = await chess.initCoordinates(coordinates_array, bitCoordinates_array);
		await tx1.wait();
		console.log("board coodinates initialized in chess wager contract");
	} catch (error) {
		console.log(error);
	}
	try {
		const tx2 = await chessNFT.setChessFishAddress(chess.address);
		await tx2.wait();
		console.log("Chess Wager address set in ChessNFT contract");
	} catch (error) {
		console.log(error);
	}
	try {
		const tx3 = await gaslessGame.setChessWager(chess.address);
		await tx3.wait();
		console.log("Chess Wager address set in gasless game contract");
	} catch (error) {
		console.log(error);
	}

	console.log("___________");

}

async function main(): Promise<void> {
	await deploy();
}

main();
