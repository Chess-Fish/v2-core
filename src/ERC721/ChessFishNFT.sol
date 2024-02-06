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
            '<svg xmlns="http://www.w3.org/2000/svg" version="1.1" width="640" height="720" viewBox="0 0 640 720">',
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

        string memory dateString = timestampToDateTimeString(block.timestamp);

        // Append the date string to the SVG
        svg = abi.encodePacked(
            svg,
            '<rect x="0" y="640" width="640" height="80" fill="#000000"/>',
            '<text x="20" y="670" font-family="Arial" font-size="18" font-weight="bold" fill="#FFFFFF">&#x1f3c6; Winner: ',
            toHexString(uint256(uint160(player0)), 20),
            "</text>",
            '<text x="20" y="690" font-family="Arial" font-size="12" fill="#FFFFFF">Loser: ',
            toHexString(uint256(uint160(player1)), 20),
            "</text>",
            '<text x="20" y="710" font-family="Arial" font-size="14" fill="#FFFFFF">Date: ',
            dateString,
            "</text>",
            // Adjusting circle animation to go around the border of the board
            '<svg viewBox="0 0 640 720" xmlns="http://www.w3.org/2000/svg">',
            '<path fill="none" stroke="lightgrey" d="M0,0 H640 V720 H0 V0" />',
            '<circle r="5" fill="#3DFF30">',
            '<animateMotion dur="10s" repeatCount="indefinite">',
            '<mpath href="#borderPath"/>',
            "</animateMotion>",
            "</circle>",
            '<path id="borderPath" fill="none" d="M0,0 H640 V720 H0 V0 z"/>',
            // Directly positioning the spinning emoji
            "<g>",
            '<text x="600" y="650" font-family="Arial" font-size="18" fill="#FFFFFF">&#x1f451;</text>',
            '<animateTransform attributeName="transform" attributeType="XML" type="rotate" from="0 600 650" to="360 600 650" dur="10s" repeatCount="indefinite"/>',
            "</g>",
            "</svg>"
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

    uint256 constant SECONDS_PER_DAY = 24 * 60 * 60;
    uint256 constant SECONDS_PER_HOUR = 60 * 60;
    uint256 constant SECONDS_PER_MINUTE = 60;
    int256 constant OFFSET19700101 = 2_440_588;

    uint256 constant DOW_MON = 1;
    uint256 constant DOW_TUE = 2;
    uint256 constant DOW_WED = 3;
    uint256 constant DOW_THU = 4;
    uint256 constant DOW_FRI = 5;
    uint256 constant DOW_SAT = 6;
    uint256 constant DOW_SUN = 7;

    function timestampToDateTimeString(uint256 timestamp)
        internal
        pure
        returns (string memory)
    {
        (
            uint256 year,
            uint256 month,
            uint256 day,
            uint256 hour,
            uint256 minute,
            uint256 second
        ) = timestampToDateTime(timestamp);

        return string(
            abi.encodePacked(
                _zeroPad(month, 2),
                "/",
                _zeroPad(day, 2),
                "/",
                _toString(year),
                " ",
                _zeroPad(hour, 2),
                ":",
                _zeroPad(minute, 2),
                ":",
                _zeroPad(second, 2)
            )
        );
    }

    function _zeroPad(
        uint256 value,
        uint256 length
    )
        internal
        pure
        returns (string memory)
    {
        // Converts a uint256 to a string and pads with leading zeros if necessary to
        // match the desired length
        string memory strValue = _toString(value);
        uint256 strLength = bytes(strValue).length;

        if (strLength >= length) {
            return strValue;
        }

        uint256 zerosToAdd = length - strLength;
        bytes memory padded = new bytes(length);
        for (uint256 i = 0; i < zerosToAdd; i++) {
            padded[i] = bytes1("0");
        }
        for (uint256 i = zerosToAdd; i < length; i++) {
            padded[i] = bytes(strValue)[i - zerosToAdd];
        }

        return string(padded);
    }

    function _toString(uint256 value) internal pure returns (string memory) {
        // Converts a uint256 to a string
        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }

    function timestampToDateTime(uint256 timestamp)
        internal
        pure
        returns (
            uint256 year,
            uint256 month,
            uint256 day,
            uint256 hour,
            uint256 minute,
            uint256 second
        )
    {
        (year, month, day) = _daysToDate(timestamp / SECONDS_PER_DAY);
        uint256 secs = timestamp % SECONDS_PER_DAY;
        hour = secs / SECONDS_PER_HOUR;
        secs = secs % SECONDS_PER_HOUR;
        minute = secs / SECONDS_PER_MINUTE;
        second = secs % SECONDS_PER_MINUTE;
    }

    function _daysToDate(uint256 _days)
        internal
        pure
        returns (uint256 year, uint256 month, uint256 day)
    {
        int256 __days = int256(_days);

        int256 L = __days + 68_569 + OFFSET19700101;
        int256 N = (4 * L) / 146_097;
        L = L - (146_097 * N + 3) / 4;
        int256 _year = (4000 * (L + 1)) / 1_461_001;
        L = L - (1461 * _year) / 4 + 31;
        int256 _month = (80 * L) / 2447;
        int256 _day = L - (2447 * _month) / 80;
        L = _month / 11;
        _month = _month + 2 - 12 * L;
        _year = 100 * (N - 49) + _year + L;

        year = uint256(_year);
        month = uint256(_month);
        day = uint256(_day);
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
