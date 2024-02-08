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

import { MoveVerification } from "./../MoveVerification.sol";

import "./PieceSVG.sol";
import "./TokenSVG.sol";

import "forge-std/console.sol";

contract ChessFishNFT is ERC721 {
    uint256 private _tokenIdCounter;

    mapping(uint256 => address) public gameAddresses;

    ChessGame public immutable game;
    MoveVerification public moveVerification;

    PieceSVG public pieceSVG;
    TokenSVG public tokenSVG;

    address public deployer;

    modifier onlyChessGame() {
        require(msg.sender == address(game));
        _;
    }

    modifier onlyDeployer() {
        require(msg.sender == deployer);
        _;
    }

    constructor(address _pieceSVG, address _tokenSVG) ERC721("ChessFishNFT", "CFSH") {
        deployer = msg.sender;
        pieceSVG = PieceSVG(_pieceSVG);
        tokenSVG = TokenSVG(_tokenSVG);
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
            address(0xE2976A66E8CEF3932CDAEb935E114dCd5ce20F20), // winner
            address(0x388C818CA8B9251b393131C08a736A67ccB19297), // loser
            block.timestamp, // endtime
            address(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1), // token
            true, // wasTournament
            7 // place in tournament
        );
        // return _buildTokenURI(id);
    }

    function bytes1ToString(bytes1 _byte) public pure returns (string memory) {
        return string(abi.encodePacked(_byte));
    }

    function generateBoardSVG(
        string memory boardString,
        address player0,
        address player1,
        uint256 endTime,
        address token,
        bool isTournament,
        uint256 place
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
                uint256 x = (7 - col) * 80;
                uint256 y = (7 - row) * 80;

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
                    uint2str(x),
                    '" y="',
                    uint2str(y),
                    '" class="square ',
                    squareColor,
                    '"/>'
                );

                if (piece != bytes1(0x20)) {
                    bytes memory _pieceSVG = pieceSVG.getPieceSymbol(piece, x, y);
                    svg = abi.encodePacked(svg, _pieceSVG);
                }
            }
        }

        svg = paramsContainer(svg, player0, player1, endTime, token, isTournament, place);

        svg = abi.encodePacked(svg, "</svg>");

        return string(abi.encodePacked("data:image/svg+xml;base64,", Base64.encode(svg)));
    }

    function paramsContainer(
        bytes memory svg,
        address player0,
        address player1,
        uint256 endTime,
        address token,
        bool isTournament,
        uint256 place
    )
        internal
        view
        returns (bytes memory)
    {
        string memory dateString = timestampToDateTimeString(endTime);

        // Part 1: Initial SVG (if there's content before the black box, add it here)
        svg = abi.encodePacked(svg);

        // Part 2: Black Box under board and related text
        bytes memory blackBoxAndText = abi.encodePacked(
            '<rect x="0" y="640" width="640" height="100" fill="#000000"/>',
            '<text x="10" y="660" font-family="Courier New" font-size="18" font-weight="bold" fill="#FFFFFF">&#x1f3c6; Winner: 0x',
            toAsciiString(player0),
            "</text>",
            '<text x="10" y="680" font-family="Courier New" font-size="12" fill="#FFFFFF">Loser: 0x',
            toAsciiString(player1),
            "</text>",
            '<text x="10" y="700" font-family="Courier New" font-size="12" fill="#FFFFFF">Date: ',
            dateString,
            "</text>"
        );
        svg = abi.encodePacked(svg, blackBoxAndText);

        // Part 3: Circle Animation and Border
        string memory randomColor = getHexColor(endTime, player0, player1, token);
        bytes memory circleAnimation = abi.encodePacked(
            '<svg viewBox="0 0 640 720" xmlns="http://www.w3.org/2000/svg">',
            '<path fill="none" stroke="lightgrey" d="M0,0 H640 V720 H0 V0" />',
            '<circle r="7" fill="',
            randomColor,
            '">',
            '<animateMotion dur="10s" repeatCount="indefinite">',
            '<mpath href="#borderPath"/>',
            "</animateMotion>",
            "</circle>",
            '<path id="borderPath" fill="none" d="M0,0 H640 V720 H0 V0 z"/>'
        );
        svg = abi.encodePacked(svg, circleAnimation);

        // if tournament add tournament emoji and place
        if (isTournament) {
            // Tournament emoji
            bytes memory tournamentEmoji = abi.encodePacked(
                "<g>",
                '<text x="535" y="700" font-family="Arial" font-size="30" fill="#FFFFFF">&#x1f396;</text>',
                "</g>"
            );

            // Place SVG
            bytes memory placeSVG = abi.encodePacked(
                "<g>",
                '<text x="580" y="695" font-family="Arial" font-size="30" fill="#FFFFFF">',
                getPlaceSVG(place),
                "</text>"
            );

            // Animation
            bytes memory animation = abi.encodePacked(
                '<animateTransform attributeName="transform" attributeType="XML" type="rotate" from="0 ',
                Strings.toString(580 + 15),
                " ",
                Strings.toString(695 - 6),
                '" to="360 ',
                Strings.toString(580 + 15),
                " ",
                Strings.toString(695 - 6),
                '" dur="7s" repeatCount="indefinite"/>',
                "</g>"
            );

            // Combine all parts and append to svg
            svg = abi.encodePacked(svg, tournamentEmoji, placeSVG, animation);
        }

        // Part 5: Token
        bytes memory _tokenSVG = tokenSVG.getTokenSVG(token);
        svg = abi.encodePacked(svg, _tokenSVG);

        return svg;
    }

    function getPlaceSVG(uint256 place) internal pure returns (string memory) {
        if (place > 3) {
            return "&#x1f9a5;";
        } else if (place == 1) {
            return "&#x1f947;";
        } else if (place == 2) {
            return "&#x1f948;";
        } else if (place == 3) {
            return "&#x1f949;";
        } else {
            return "";
        }
    }

    function getHexColor(
        uint256 endTime,
        address player0,
        address player1,
        address token
    )
        public
        pure
        returns (string memory)
    {
        uint256 random = uint256(
            keccak256(abi.encodePacked(endTime, player0, player1, token))
        ) % 16_777_215;

        // Convert the pseudo-random number to a hexadecimal string
        bytes memory b = new bytes(3);
        for (uint256 i = 0; i < 3; i++) {
            b[i] = bytes1(uint8(random / (2 ** (8 * (2 - i)))));
        }
        return string(abi.encodePacked("#", toHexString(b)));
    }

    // Helper function to convert bytes to a hexadecimal string
    function toHexString(bytes memory data) internal pure returns (string memory) {
        bytes memory hexNum = "0123456789ABCDEF";
        bytes memory result = new bytes(2 * data.length);

        for (uint256 i = 0; i < data.length; i++) {
            result[2 * i] = hexNum[uint8(data[i] >> 4)];
            result[2 * i + 1] = hexNum[uint8(data[i] & 0x0f)];
        }

        return string(result);
    }

    // Helper function to convert uint to string
    function uint2str(uint256 _i) public pure returns (string memory _uintAsString) {
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

    function toAsciiString(address x) internal pure returns (string memory) {
        bytes memory s = new bytes(40);
        for (uint256 i = 0; i < 20; i++) {
            bytes1 b = bytes1(uint8(uint256(uint160(x)) / (2 ** (8 * (19 - i)))));
            bytes1 hi = bytes1(uint8(b) / 16);
            bytes1 lo = bytes1(uint8(b) - 16 * uint8(hi));
            s[2 * i] = char(hi);
            s[2 * i + 1] = char(lo);
        }
        return string(s);
    }

    function char(bytes1 b) internal pure returns (bytes1 c) {
        if (uint8(b) < 10) return bytes1(uint8(b) + 0x30);
        else return bytes1(uint8(b) + 0x57);
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
