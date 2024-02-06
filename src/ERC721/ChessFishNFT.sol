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

import "./SVGContainer.sol";

contract ChessFishNFT_V2 is ERC721 {
    uint256 private _tokenIdCounter;

    mapping(uint256 => address) public gameAddresses;

    ChessGame public immutable game;
    MoveVerification public moveVerification;
    SVG_Container public svg_container;

    address public deployer;

    modifier onlyChessGame() {
        require(msg.sender == address(game));
        _;
    }

    modifier onlyDeployer() {
        require(msg.sender == deployer);
        _;
    }

    constructor(address _chessFish, address _svg) ERC721("ChessFishNFT", "CFSH") {
        deployer = msg.sender;
        game = ChessGame(_chessFish);

        svg_container = SVG_Container(_svg);
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

    function tokenURI(uint256 id) public view override returns (string memory) {
        return generateBoardSVG(
            // "R,N,B,K,Q,B,N,R,P,P,P,P,P,P,P,P,.,.,.,.,.,.,.,.,.,.,.,.,.,.,.,.,.,.,.,.,.,.,.,.,.,.,.,.,.,.,.,.,p,p,p,p,p,p,p,p,r,n,b,k,q,b,n,r",
            "R,N,.,.,.,K,.,.,P,.,P,Q,.,P,P,.,B,.,.,.,.,.,.,P,.,.,.,.,.,.,.,.,.,.,.,.,N,n,.,.,p,.,p,.,.,.,.,.,.,p,.,.,.,.,p,p,r,n,.,.,Q,.,k,.",
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
    function generateBoardSVG(
        string memory boardString,
        address player0,
        address player1
    )
        public
        view
        returns (string memory)
    {
        bytes memory boardBytes = bytes(boardString);
        // Double the size of the board and add extra space for the rectangle
        bytes memory svg = abi.encodePacked(
            '<?xml version="1.0" encoding="UTF-8"?>',
            '<svg xmlns="http://www.w3.org/2000/svg" version="1.1" width="640" height="720" viewBox="0 0 640 720">', // Adjusted
                // dimensions
            '<style type="text/css"><![CDATA[.square { width: 80px; height: 80px; } .light { fill: #f0d9b5; } .dark { fill: #b58863; }]]></style>'
        );

        uint256 index = 0;
        for (uint256 row = 0; row < 8; row++) {
            for (uint256 col = 0; col < 8; col++) {
                uint256 x = (7 - col) * 80; // Adjusted to start from the right,
                    // size doubled
                uint256 y = (7 - row) * 80; // Adjusted to start from the
                    // bottom, size doubled

                bool isDark = (row + col) % 2 == 1;
                string memory squareColor = isDark ? "dark" : "light";

                while (index < boardBytes.length && boardBytes[index] == ",") {
                    index++;
                }

                if (index >= boardBytes.length) {
                    break;
                }

                bytes1 piece = boardBytes[index] == "." ? bytes1(0x20) : boardBytes[index];
                index++;

                svg = abi.encodePacked(
                    svg,
                    '<rect x="',
                    svg_container.uint2str(x),
                    '" y="',
                    svg_container.uint2str(y),
                    '" class="square ',
                    squareColor,
                    '"/>'
                );

                if (piece != bytes1(0x20)) {
                    bytes memory pieceSVG = svg_container.getPieceSymbol(piece, x, y);
                    svg = abi.encodePacked(svg, pieceSVG);
                }
            }
        }

        string memory dateString = timestampToDate(block.timestamp);

        // Append the date string to the SVG
        svg = abi.encodePacked(
            svg,
            '<rect x="0" y="640" width="640" height="80" fill="#000000"/>',
            '<text x="30" y="670" font-family="Arial" font-size="18" font-weight="bold" fill="#FFFFFF">&#x1f3c6; Winner: ',
            toHexString(uint256(uint160(player0)), 20),
            "</text>",
            '<text x="10" y="690" font-family="Arial" font-size="12" fill="#FFFFFF">Loser: ',
            toHexString(uint256(uint160(player1)), 20),
            "</text>",
            '<text x="10" y="710" font-family="Arial" font-size="14" fill="#FFFFFF">Date: ',
            dateString,
            "</text>"
        );

        svg = abi.encodePacked(svg, "</svg>");

        return string(abi.encodePacked("data:image/svg+xml;base64,", Base64.encode(svg)));
    }

    function toHexString(
        uint256 value,
        uint256 length
    )
        internal
        pure
        returns (string memory)
    {
        bytes memory buffer = new bytes(2 * length);

        for (uint256 i = 2 * length; i > 0; --i) {
            buffer[i - 1] = bytes1(uint8(48 + (value & 0xf))); 
            if (buffer[i - 1] >= bytes1(uint8(58))) {
                buffer[i - 1] = bytes1(uint8(87 + (uint8(buffer[i - 1]) - 58)));
            }
            value >>= 4;
		} 

        return string(buffer);
    }

    uint256[12] monthDays = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];

    function timestampToDate(uint256 timestamp) public view returns (string memory) {
        uint256 secondsInADay = 24 * 60 * 60;
        uint256 year = 1970;
        uint256 month;
        uint256 day;

        // Days per month (ignoring leap years for February)
        // Calculate elapsed days since 1970
        uint256 daysSince1970 = timestamp / secondsInADay;

        // Leap year calculation
        uint256 daysInYear;
        while (daysSince1970 >= (daysInYear = (isLeapYear(year) ? 366 : 365))) {
            daysSince1970 -= daysInYear;
            year += 1;
        }

        // Calculate the month and day
        for (uint256 i = 0; i < monthDays.length; i++) {
            uint256 daysInMonth = monthDays[i];
            // Adjust for leap year February
            if (i == 1 && isLeapYear(year)) {
                daysInMonth += 1;
            }

            if (daysSince1970 < daysInMonth) {
                month = i + 1;
                day = daysSince1970 + 1; 
                break;
            } else {
                daysSince1970 -= daysInMonth;
            }
        }

        return string(
            abi.encodePacked(
                svg_container.uint2str(month),
                "/",
                svg_container.uint2str(day),
                "/",
                svg_container.uint2str(year)
            )
        );
    }

    function isLeapYear(uint256 year) internal pure returns (bool) {
        if (year % 4 != 0) {
            return false;
        } else if (year % 100 != 0) {
            return true;
        } else if (year % 400 == 0) {
            return true;
        }
        return false;
    }
}
