// SPDX-License-Identifier: MIT

/* 
   _____ _                   ______ _     _     
  / ____| |                 |  ____(_)   | |    
 | |    | |__   ___  ___ ___| |__   _ ___| |__  
 | |    | '_ \ / _ \/ __/ __|  __| | / __| '_ \ 
 | |____| | | |  __/\__ \__ \ |    | \__ \ | | |
  \_____|_| |_|\___||___/___/_|    |_|___/_| |_|
                             
*/

/// @title ChessFish ChessFishNFT Init
/// @author ChessFish
/// @notice https://github.com/Chess-Fish

pragma solidity ^0.8.24;

import { ChessGame } from "./../ChessGame.sol";

interface IChessFishNFT {
    function uint2str(uint256 _i) external view returns (string memory);
}

contract Init {
    IChessFishNFT internal NFT;
    ChessGame internal game;

    address private deployer;
    bool private isSet;

    modifier onlyDeployer() {
        require(msg.sender == deployer);
        _;
    }

    modifier checkIsSet() {
        require(isSet == false);
        _;
    }

    constructor() {
        deployer = msg.sender;
    }

    function initialize(
        address _NFT,
        address _chessGame
    )
        external
        onlyDeployer
        checkIsSet
    {
        NFT = IChessFishNFT(_NFT);
        game = ChessGame(_chessGame);
        isSet = true;
    }
}
