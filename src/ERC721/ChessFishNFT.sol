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

    mapping(uint256 => address) public wagerAddresses;

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
        address wagerAddress
    )
        external
        onlyChessGame
        returns (uint256)
    {
        uint256 tokenId = _tokenIdCounter;
        _mint(player, tokenId);
        wagerAddresses[tokenId] = wagerAddress;

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
            "R,N,.,.,.,K,.,.,P,.,P,Q,.,P,P,.,B,.,.,.,.,.,.,P,.,.,.,.,.,.,.,.,.,.,.,.,N,n,.,.,p,.,p,.,.,.,.,.,.,p,.,.,.,.,p,p,r,n,.,.,Q,.,k,.",
			address(5),
			address(4)
        );
        // return _buildTokenURI(id);
    }

    function bytes1ToString(bytes1 _byte) public pure returns (string memory) {
        return string(abi.encodePacked(_byte));
    }

    function getPieceSymbol(bytes1 piece)
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
    }

    function generateBoardSVG(string memory boardString, address player0, address player1)
        public
        pure
        returns (string memory)
    {
        bytes memory boardBytes = bytes(boardString);
        bytes memory svg = abi.encodePacked(
            '<?xml version="1.0" encoding="UTF-8"?>',
            '<svg xmlns="http://www.w3.org/2000/svg" version="1.1" width="320" height="320" viewBox="0 0 320 320">',
            '<style type="text/css"><![CDATA[.square { width: 40px; height: 40px; } .light { fill: #f0d9b5; } .dark { fill: #b58863; } .piece { font-family: Arial; font-size: 36px; text-anchor: middle; dominant-baseline: middle; }]]></style>'
        );

        uint256 index = 0; // Initialize index to start at the beginning of the
            // boardBytes
        for (uint256 row = 0; row < 8; row++) {
            for (uint256 col = 0; col < 8; col++) {
                // Adjust the x and y positions to start from the bottom right
                // corner
                uint256 x = (7 - col) * 40; // Adjusted to start from the right
                uint256 y = (7 - row) * 40; // Adjusted to start from the bottom

                // Determine if the square should be dark or light
                bool isDark = (row + col) % 2 == 1; // Adjusted the calculation
                    // for the board pattern
                string memory squareColor = isDark ? "dark" : "light";

                // Skip commas in the boardString
                while (index < boardBytes.length && boardBytes[index] == ",") {
                    index++;
                }

                // Ensure we do not exceed the boardBytes length
                if (index >= boardBytes.length) {
                    break;
                }

                // Replace '.' with a space for SVG display
                bytes1 piece =
                    boardBytes[index] == "." ? bytes1(0x20) : boardBytes[index];

                // Correctly increment index after processing a character
                index++;

                // Generate SVG elements for the square and the piece
                svg = abi.encodePacked(
                    svg,
                    '<rect x="',
                    uint2str(x),
                    '" y="',
                    uint2str(y),
                    '" class="square ',
                    squareColor,
                    '"/>',
                    '<text x="',
                    uint2str(x + 20),
                    '" y="',
                    uint2str(y + 20),
                    '" class="piece">',
                    piece != bytes1(0x20)
                        ? string(abi.encodePacked(getPieceSymbol(piece)))
                        : " ", // Correctly display space for '.' characters
                    "</text>"
                );
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
