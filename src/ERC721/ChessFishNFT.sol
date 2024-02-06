// SPDX-License-Identifier: MIT

/* 
   _____ _                   ______ _     _     
  / ____| |                 |  ____(_)   | |    
 | |    | |__   ___  ___ ___| |__   _ ___| |__  
 | |    | '_ \ / _ \/ __/ __|  __| | / __| '_ \ 
 | |____| | | |  __/\__ \__ \ |    | \__ \ | | |
  \_____|_| |_|\___||___/___/_|    |_|___/_| |_|
                             
*/

/// @title ChessFish ChessFishNFT Contract
/// @author ChessFish
/// @notice https://github.com/Chess-Fish

pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Base64.sol";

import { ChessGame } from "./../ChessGame.sol";
import { MoveVerification } from "./../MoveVerification.sol";

import "forge-std/console.sol";

contract ChessFishNFT_V2 is ERC721 {
    uint256 private _tokenIdCounter;

    mapping(uint256 => address) public gameAddresses;

    ChessGame public immutable game;
    MoveVerification public moveVerification;

    address public deployer;

    modifier onlyChessGame() {
        require(msg.sender == address(game));
        _;
    }

    modifier onlyDeployer() {
        require(msg.sender == deployer);
        _;
    }

    constructor(address _chessFish) ERC721("ChessFishNFT", "CFSH") {
        deployer = msg.sender;
        game = ChessGame(_chessFish);
    }

    function awardWinner(
        address player,
        address gameAddress
    )
        external
        onlyChessGame
        returns (uint256)
    {
        uint256 tokenId = _tokenIdCounter;
        _mint(player, tokenId);
        gameAddresses[tokenId] = gameAddress;

        _tokenIdCounter += 1;

        return tokenId;
    }

    function tokenURI(uint256 id)
        public
        view
        override
        returns (string memory)
    {
        return generateBoardSVG(
            "R,N,B,K,Q,B,N,R,P,P,P,P,P,P,P,P,.,.,.,.,.,.,.,.,.,.,.,.,.,.,.,.,.,.,.,.,.,.,.,.,.,.,.,.,.,.,.,.,p,p,p,p,p,p,p,p,r,n,b,k,q,b,n,r",
            address(5),
            address(4)
        );
        // return _buildTokenURI(id);
    }

    function bytes1ToString(bytes1 _byte) public pure returns (string memory) {
        return string(abi.encodePacked(_byte));
    }

    /*     function getPieceSymbol(bytes1 piece)
        private
        pure
        returns (string memory)
    {
        // Mapping of piece codes to Unicode symbols for chess pieces
        if (piece == "K") {
            return "&#9812;";
        }
        if (piece == "Q") return "&#9813;"; // White Queen
        if (piece == "R") return "&#9814;"; // White Rook
        if (piece == "B") return "&#9815;"; // White Bishop
        if (piece == "N") return "&#9816;"; // White Knight
        if (piece == "P") return "&#9817;"; // White Pawn
        if (piece == "k") return "&#9818;"; // Black King
        if (piece == "q") return "&#9819;"; // Black Queen
        if (piece == "r") return "&#9820;"; // Black Rook
        if (piece == "b") return "&#9821;"; // Black Bishop
        if (piece == "n") return "&#9822;"; // Black Knight
        if (piece == "p") return "&#9823;"; // Black Pawn

    if (piece == bytes1(0x20)) return " "; // Return space for empty squares
        return " "; // Fallback to a space for unrecognized characters
    } */

    function getPieceSymbol(
        bytes1 piece,
        uint256 x,
        uint256 y
    )
        private
        pure
        returns (bytes memory)
    {
        // Black Pawn
        if (piece == "p") {
            return abi.encodePacked(
                '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 45 45" x="',
                uint2str(x),
                '" y="',
                uint2str(y),
                '" width="40" height="40">',
                "<g transform='translate(0, 0) scale(1)'>",
                '<path d="M 22,9 C 19.79,9 18,10.79 18,13 C 18,13.89 18.29,14.71 18.78,15.38 C 16.83,16.5 15.5,18.59 15.5,21 C 15.5,23.03 16.44,24.84 17.91,26.03 C 14.91,27.09 10.5,31.58 10.5,39.5 L 33.5,39.5 C 33.5,31.58 29.09,27.09 26.09,26.03 C 27.56,24.84 28.5,23.03 28.5,21 C 28.5,18.59 27.17,16.5 25.22,15.38 C 25.71,14.71 26,13.89 26,13 C 26,10.79 24.21,9 22,9 z " style="opacity: 1; fill: #ffffff; fill-opacity: 1; fill-rule: nonzero; stroke: #000000; stroke-width: 1.5; stroke-linecap: round; stroke-linejoin: miter; stroke-miterlimit: 4; stroke-dasharray: none; stroke-opacity: 1"/>',
                "</g>",
                "</svg>"
            );
        }
        // White Pawn
        if (piece == "P") {
            return abi.encodePacked(
                '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 45 45" x="',
                uint2str(x),
                '" y="',
                uint2str(y),
                '" width="40" height="40">',
                "<g transform='translate(0, 0) scale(1)'>",
                '<path d="M 22,9 C 19.79,9 18,10.79 18,13 C 18,13.89 18.29,14.71 18.78,15.38 C 16.83,16.5 15.5,18.59 15.5,21 C 15.5,23.03 16.44,24.84 17.91,26.03 C 14.91,27.09 10.5,31.58 10.5,39.5 L 33.5,39.5 C 33.5,31.58 29.09,27.09 26.09,26.03 C 27.56,24.84 28.5,23.03 28.5,21 C 28.5,18.59 27.17,16.5 25.22,15.38 C 25.71,14.71 26,13.89 26,13 C 26,10.79 24.21,9 22,9 z " style="opacity: 1; fill: #000000; fill-opacity: 1; fill-rule: nonzero; stroke: #000000; stroke-width: 1.5; stroke-linecap: round; stroke-linejoin: miter; stroke-miterlimit: 4; stroke-dasharray: none; stroke-opacity: 1"/>'
                "</g>",
                "</svg>"
            );
        }
        // White Rook
        if (piece == "R") {
            return abi.encodePacked(
                '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 45 45" x="',
                uint2str(x),
                '" y="',
                uint2str(y),
                '" width="40" height="40">',
                '<g style="opacity: 1; fill: #000000; fill-opacity: 1; fill-rule: evenodd; stroke: #000000; stroke-width: 1.5; stroke-linecap: round; stroke-linejoin: round; stroke-miterlimit: 4; stroke-dasharray: none; stroke-opacity: 1">'
                '<path d="M 9,39 L 36,39 L 36,36 L 9,36 L 9,39 z " style="stroke-linecap: butt" />',
                '<path d="M 12.5,32 L 14,29.5 L 31,29.5 L 32.5,32 L 12.5,32 z " style="stroke-linecap: butt" />',
                '<path d="M 12,36 L 12,32 L 33,32 L 33,36 L 12,36 z " style="stroke-linecap: butt" />',
                '<path d="M 14,29.5 L 14,16.5 L 31,16.5 L 31,29.5 L 14,29.5 z " style="stroke-linecap: butt; stroke-linejoin: miter" />',
                '<path d="M 14,16.5 L 11,14 L 34,14 L 31,16.5 L 14,16.5 z " style="stroke-linecap: butt" />',
                '<path d="M 11,14 L 11,9 L 15,9 L 15,11 L 20,11 L 20,9 L 25,9 L 25,11 L 30,11 L 30,9 L 34,9 L 34,14 L 11,14 z " style="stroke-linecap: butt" />',
                '<path d="M 12,35.5 L 33,35.5 L 33,35.5" style="fill: none; stroke: #ffffff; stroke-width: 1; stroke-linejoin: miter" />',
                '<path d="M 13,31.5 L 32,31.5" style="fill: none; stroke: #ffffff; stroke-width: 1; stroke-linejoin: miter" />',
                '<path d="M 14,29.5 L 31,29.5" style="fill: none; stroke: #ffffff; stroke-width: 1; stroke-linejoin: miter" />',
                '<path d="M 14,16.5 L 31,16.5" style="fill: none; stroke: #ffffff; stroke-width: 1; stroke-linejoin: miter" />',
                '<path d="M 11,14 L 34,14" style="fill: none; stroke: #ffffff; stroke-width: 1; stroke-linejoin: miter" />',
                "</g>",
                "</svg>"
            );
        }
        // Black Rook
        if (piece == "r") {
            return abi.encodePacked(
                '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 45 45" x="',
                uint2str(x),
                '" y="',
                uint2str(y),
                '" width="40" height="40">',
                '<g style="opacity: 1; fill: #ffffff; fill-opacity: 1; fill-rule: evenodd; stroke: #000000; stroke-width: 1.5; stroke-linecap: round; stroke-linejoin: round; stroke-miterlimit: 4; stroke-dasharray: none; stroke-opacity: 1">'
                '<path d="M 9,39 L 36,39 L 36,36 L 9,36 L 9,39 z " style="stroke-linecap: butt" />'
                '<path d="M 12,36 L 12,32 L 33,32 L 33,36 L 12,36 z " style="stroke-linecap: butt" />'
                '<path d="M 11,14 L 11,9 L 15,9 L 15,11 L 20,11 L 20,9 L 25,9 L 25,11 L 30,11 L 30,9 L 34,9 L 34,14" style="stroke-linecap: butt" />'
                '<path d="M 34,14 L 31,17 L 14,17 L 11,14" />'
                '<path d="M 31,17 L 31,29.5 L 14,29.5 L 14,17" style="strokeL-linecap: butt; stroke-linejoin: miter" />'
                '<path d="M 31,29.5 L 32.5,32 L 12.5,32 L 14,29.5" />'
                '<path d="M 11,14 L 34,14" style="fill: none; stroke: #000000; stroke-linejoin: miter" />'
                "</g>" "</svg>"
            );
        }
        if (piece == "p") {
            // More aggressively scale down the piece and adjust positioning
            return abi.encodePacked(
                '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 45 45" x="',
                uint2str(x),
                '" y="',
                uint2str(y),
                '" width="40" height="40">',
                "<g transform='translate(0, 0) scale(1)'>",
                '<path d="M 22,9 C 19.79,9 18,10.79 18,13 C 18,13.89 18.29,14.71 18.78,15.38 C 16.83,16.5 15.5,18.59 15.5,21 C 15.5,23.03 16.44,24.84 17.91,26.03 C 14.91,27.09 10.5,31.58 10.5,39.5 L 33.5,39.5 C 33.5,31.58 29.09,27.09 26.09,26.03 C 27.56,24.84 28.5,23.03 28.5,21 C 28.5,18.59 27.17,16.5 25.22,15.38 C 25.71,14.71 26,13.89 26,13 C 26,10.79 24.21,9 22,9 z " style="opacity: 1; fill: #000000; fill-opacity: 1; fill-rule: nonzero; stroke: #000000; stroke-width: 1.5; stroke-linecap: round; stroke-linejoin: miter; stroke-miterlimit: 4; stroke-dasharray: none; stroke-opacity: 1"/>'
                "</g>",
                "</svg>"
            );
        }
        if (piece == "p") {
            // More aggressively scale down the piece and adjust positioning
            return abi.encodePacked(
                '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 45 45" x="',
                uint2str(x),
                '" y="',
                uint2str(y),
                '" width="40" height="40">',
                "<g transform='translate(0, 0) scale(1)'>",
                '<path d="M 22,9 C 19.79,9 18,10.79 18,13 C 18,13.89 18.29,14.71 18.78,15.38 C 16.83,16.5 15.5,18.59 15.5,21 C 15.5,23.03 16.44,24.84 17.91,26.03 C 14.91,27.09 10.5,31.58 10.5,39.5 L 33.5,39.5 C 33.5,31.58 29.09,27.09 26.09,26.03 C 27.56,24.84 28.5,23.03 28.5,21 C 28.5,18.59 27.17,16.5 25.22,15.38 C 25.71,14.71 26,13.89 26,13 C 26,10.79 24.21,9 22,9 z " style="opacity: 1; fill: #000000; fill-opacity: 1; fill-rule: nonzero; stroke: #000000; stroke-width: 1.5; stroke-linecap: round; stroke-linejoin: miter; stroke-miterlimit: 4; stroke-dasharray: none; stroke-opacity: 1"/>'
                "</g>",
                "</svg>"
            );
        }
        if (piece == "p") {
            // More aggressively scale down the piece and adjust positioning
            return abi.encodePacked(
                '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 45 45" x="',
                uint2str(x),
                '" y="',
                uint2str(y),
                '" width="40" height="40">',
                "<g transform='translate(0, 0) scale(1)'>",
                '<path d="M 22,9 C 19.79,9 18,10.79 18,13 C 18,13.89 18.29,14.71 18.78,15.38 C 16.83,16.5 15.5,18.59 15.5,21 C 15.5,23.03 16.44,24.84 17.91,26.03 C 14.91,27.09 10.5,31.58 10.5,39.5 L 33.5,39.5 C 33.5,31.58 29.09,27.09 26.09,26.03 C 27.56,24.84 28.5,23.03 28.5,21 C 28.5,18.59 27.17,16.5 25.22,15.38 C 25.71,14.71 26,13.89 26,13 C 26,10.79 24.21,9 22,9 z " style="opacity: 1; fill: #000000; fill-opacity: 1; fill-rule: nonzero; stroke: #000000; stroke-width: 1.5; stroke-linecap: round; stroke-linejoin: miter; stroke-miterlimit: 4; stroke-dasharray: none; stroke-opacity: 1"/>'
                "</g>",
                "</svg>"
            );
        }
        if (piece == "p") {
            // More aggressively scale down the piece and adjust positioning
            return abi.encodePacked(
                '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 45 45" x="',
                uint2str(x),
                '" y="',
                uint2str(y),
                '" width="40" height="40">',
                "<g transform='translate(0, 0) scale(1)'>",
                '<path d="M 22,9 C 19.79,9 18,10.79 18,13 C 18,13.89 18.29,14.71 18.78,15.38 C 16.83,16.5 15.5,18.59 15.5,21 C 15.5,23.03 16.44,24.84 17.91,26.03 C 14.91,27.09 10.5,31.58 10.5,39.5 L 33.5,39.5 C 33.5,31.58 29.09,27.09 26.09,26.03 C 27.56,24.84 28.5,23.03 28.5,21 C 28.5,18.59 27.17,16.5 25.22,15.38 C 25.71,14.71 26,13.89 26,13 C 26,10.79 24.21,9 22,9 z " style="opacity: 1; fill: #000000; fill-opacity: 1; fill-rule: nonzero; stroke: #000000; stroke-width: 1.5; stroke-linecap: round; stroke-linejoin: miter; stroke-miterlimit: 4; stroke-dasharray: none; stroke-opacity: 1"/>'
                "</g>",
                "</svg>"
            );
        }
        if (piece == "p") {
            // More aggressively scale down the piece and adjust positioning
            return abi.encodePacked(
                '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 45 45" x="',
                uint2str(x),
                '" y="',
                uint2str(y),
                '" width="40" height="40">',
                "<g transform='translate(0, 0) scale(1)'>",
                '<path d="M 22,9 C 19.79,9 18,10.79 18,13 C 18,13.89 18.29,14.71 18.78,15.38 C 16.83,16.5 15.5,18.59 15.5,21 C 15.5,23.03 16.44,24.84 17.91,26.03 C 14.91,27.09 10.5,31.58 10.5,39.5 L 33.5,39.5 C 33.5,31.58 29.09,27.09 26.09,26.03 C 27.56,24.84 28.5,23.03 28.5,21 C 28.5,18.59 27.17,16.5 25.22,15.38 C 25.71,14.71 26,13.89 26,13 C 26,10.79 24.21,9 22,9 z " style="opacity: 1; fill: #000000; fill-opacity: 1; fill-rule: nonzero; stroke: #000000; stroke-width: 1.5; stroke-linecap: round; stroke-linejoin: miter; stroke-miterlimit: 4; stroke-dasharray: none; stroke-opacity: 1"/>'
                "</g>",
                "</svg>"
            );
        }
        if (piece == "p") {
            // More aggressively scale down the piece and adjust positioning
            return abi.encodePacked(
                '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 45 45" x="',
                uint2str(x),
                '" y="',
                uint2str(y),
                '" width="40" height="40">',
                "<g transform='translate(0, 0) scale(1)'>",
                '<path d="M 22,9 C 19.79,9 18,10.79 18,13 C 18,13.89 18.29,14.71 18.78,15.38 C 16.83,16.5 15.5,18.59 15.5,21 C 15.5,23.03 16.44,24.84 17.91,26.03 C 14.91,27.09 10.5,31.58 10.5,39.5 L 33.5,39.5 C 33.5,31.58 29.09,27.09 26.09,26.03 C 27.56,24.84 28.5,23.03 28.5,21 C 28.5,18.59 27.17,16.5 25.22,15.38 C 25.71,14.71 26,13.89 26,13 C 26,10.79 24.21,9 22,9 z " style="opacity: 1; fill: #000000; fill-opacity: 1; fill-rule: nonzero; stroke: #000000; stroke-width: 1.5; stroke-linecap: round; stroke-linejoin: miter; stroke-miterlimit: 4; stroke-dasharray: none; stroke-opacity: 1"/>'
                "</g>",
                "</svg>"
            );
        }
        if (piece == "p") {
            // More aggressively scale down the piece and adjust positioning
            return abi.encodePacked(
                '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 45 45" x="',
                uint2str(x),
                '" y="',
                uint2str(y),
                '" width="40" height="40">',
                "<g transform='translate(0, 0) scale(1)'>",
                '<path d="M 22,9 C 19.79,9 18,10.79 18,13 C 18,13.89 18.29,14.71 18.78,15.38 C 16.83,16.5 15.5,18.59 15.5,21 C 15.5,23.03 16.44,24.84 17.91,26.03 C 14.91,27.09 10.5,31.58 10.5,39.5 L 33.5,39.5 C 33.5,31.58 29.09,27.09 26.09,26.03 C 27.56,24.84 28.5,23.03 28.5,21 C 28.5,18.59 27.17,16.5 25.22,15.38 C 25.71,14.71 26,13.89 26,13 C 26,10.79 24.21,9 22,9 z " style="opacity: 1; fill: #000000; fill-opacity: 1; fill-rule: nonzero; stroke: #000000; stroke-width: 1.5; stroke-linecap: round; stroke-linejoin: miter; stroke-miterlimit: 4; stroke-dasharray: none; stroke-opacity: 1"/>'
                "</g>",
                "</svg>"
            );
        }

        if (piece == "p") {
            // More aggressively scale down the piece and adjust positioning
            return abi.encodePacked(
                '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 45 45" x="',
                uint2str(x),
                '" y="',
                uint2str(y),
                '" width="40" height="40">',
                "<g transform='translate(0, 0) scale(1)'>",
                '<path d="M 22,9 C 19.79,9 18,10.79 18,13 C 18,13.89 18.29,14.71 18.78,15.38 C 16.83,16.5 15.5,18.59 15.5,21 C 15.5,23.03 16.44,24.84 17.91,26.03 C 14.91,27.09 10.5,31.58 10.5,39.5 L 33.5,39.5 C 33.5,31.58 29.09,27.09 26.09,26.03 C 27.56,24.84 28.5,23.03 28.5,21 C 28.5,18.59 27.17,16.5 25.22,15.38 C 25.71,14.71 26,13.89 26,13 C 26,10.79 24.21,9 22,9 z " style="opacity: 1; fill: #000000; fill-opacity: 1; fill-rule: nonzero; stroke: #000000; stroke-width: 1.5; stroke-linecap: round; stroke-linejoin: miter; stroke-miterlimit: 4; stroke-dasharray: none; stroke-opacity: 1"/>'
                "</g>",
                "</svg>"
            );
        }

        if (piece == "p") {
            // More aggressively scale down the piece and adjust positioning
            return abi.encodePacked(
                '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 45 45" x="',
                uint2str(x),
                '" y="',
                uint2str(y),
                '" width="40" height="40">',
                "<g transform='translate(0, 0) scale(1)'>",
                '<path d="M 22,9 C 19.79,9 18,10.79 18,13 C 18,13.89 18.29,14.71 18.78,15.38 C 16.83,16.5 15.5,18.59 15.5,21 C 15.5,23.03 16.44,24.84 17.91,26.03 C 14.91,27.09 10.5,31.58 10.5,39.5 L 33.5,39.5 C 33.5,31.58 29.09,27.09 26.09,26.03 C 27.56,24.84 28.5,23.03 28.5,21 C 28.5,18.59 27.17,16.5 25.22,15.38 C 25.71,14.71 26,13.89 26,13 C 26,10.79 24.21,9 22,9 z " style="opacity: 1; fill: #000000; fill-opacity: 1; fill-rule: nonzero; stroke: #000000; stroke-width: 1.5; stroke-linecap: round; stroke-linejoin: miter; stroke-miterlimit: 4; stroke-dasharray: none; stroke-opacity: 1"/>'
                "</g>",
                "</svg>"
            );
        }

        // Handle other pieces similarly
        if (piece == bytes1(0x20)) return abi.encodePacked("");
        return abi.encodePacked("");
    }

    function generateBoardSVG(
        string memory boardString,
        address player0,
        address player1
    )
        public
        pure
        returns (string memory)
    {
        bytes memory boardBytes = bytes(boardString);
        bytes memory svg = abi.encodePacked(
            '<?xml version="1.0" encoding="UTF-8"?>',
            '<svg xmlns="http://www.w3.org/2000/svg" version="1.1" width="320" height="320" viewBox="0 0 320 320">',
            '<style type="text/css"><![CDATA[.square { width: 40px; height: 40px; } .light { fill: #f0d9b5; } .dark { fill: #b58863; }]]></style>'
        );

        uint256 index = 0;
        for (uint256 row = 0; row < 8; row++) {
            for (uint256 col = 0; col < 8; col++) {
                uint256 x = col * 40;
                uint256 y = row * 40;

                bool isDark = (row + col) % 2 == 1;
                string memory squareColor = isDark ? "dark" : "light";

                while (index < boardBytes.length && boardBytes[index] == ",") {
                    index++;
                }

                if (index >= boardBytes.length) {
                    break;
                }

                bytes1 piece =
                    boardBytes[index] == "." ? bytes1(0x20) : boardBytes[index];
                index++;

                svg = abi.encodePacked(
                    svg,
                    '<rect x="',
                    uint2str(x),
                    '" y="',
                    uint2str(y),
                    '" class="square ',
                    squareColor,
                    '"/>'
                );

                // Add piece SVG if not an empty square, ensuring it's added
                // after squares
                if (piece != bytes1(0x20)) {
                    bytes memory pieceSVG = getPieceSymbol(piece, x, y);
                    svg = abi.encodePacked(svg, pieceSVG);
                }
            }
        }
        svg = abi.encodePacked(svg, "</svg>");

        return string(
            abi.encodePacked("data:image/svg+xml;base64,", Base64.encode(svg))
        );
    }

    // Helper function to convert uint to string
    function uint2str(uint256 _i)
        internal
        pure
        returns (string memory _uintAsString)
    {
        if (_i == 0) {
            return "0";
        }
        uint256 j = _i;
        uint256 len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint256 k = len;
        while (_i != 0) {
            k = k - 1;
            uint8 temp = (48 + uint8(_i - _i / 10 * 10));
            bytes1 b1 = bytes1(temp);
            bstr[k] = b1;
            _i /= 10;
        }
        return string(bstr);
    }
}
