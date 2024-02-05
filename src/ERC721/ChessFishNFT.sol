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

import {ChessGame} from './../ChessGame.sol';

contract ChessFishNFT_V2 is ERC721 {
    uint256 private _tokenIdCounter;

    mapping(uint256 => address) public wagerAddresses;

    ChessGame public immutable game;

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
        return _buildTokenURI(id);
    }

    // Constructs the encoded svg string to be returned by tokenURI()
    function _buildTokenURI(uint256 id) internal view returns (string memory) {
        // bool minted = id <= _tokenIdCounter;
        bool minted = true; // dev testing

        string memory streamBalance = "";
        // Don't include stream in URI until token is minted
        if (minted) {
            // Get stream address, to check it's current balance
            streamBalance = string(
                abi.encodePacked(
                    unicode'<text x="20" y="305">Stream Ξ', "</text>"
                )
            );
        }

        bytes memory image = abi.encodePacked(
            "data:image/svg+xml;base64,",
            Base64.encode(
                bytes(
                    abi.encodePacked(
                        '<?xml version="1.0" encoding="UTF-8"?>',
                        '<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" version="1.1" viewBox="0 0 400 400" preserveAspectRatio="xMidYMid meet">',
                        '<style type="text/css"><![CDATA[text { font-family: monospace; font-size: 21px;} .h1 {font-size: 40px; font-weight: 600;}]]></style>',
                        '<rect width="400" height="400" fill="#ffffff" />',
                        '<text class="h1" x="50" y="70">Knight of the</text>',
                        '<text class="h1" x="80" y="120" >BuidlGuidl</text>',
                        unicode'<text x="70" y="240" style="font-size:100px;">🏗️ 🏰</text>',
                        streamBalance,
                        unicode'<text x="210" y="305">Wallet Ξ',
                        "</text>",
                        '<text x="20" y="350" style="font-size:28px;"> ',
                        "</text>",
                        '<text x="20" y="380" style="font-size:14px;">0x',
                        "</text>",
                        "</svg>"
                    )
                )
            )
        );
        return string(
            abi.encodePacked(
                "data:application/json;base64,",
                Base64.encode(
                    bytes(
                        abi.encodePacked(
                            '{"name":"BuidlGuidl Tabard", "image":"',
                            image,
                            unicode'", "description": "This NFT marks the bound address as a member of the BuidlGuidl. The image is a fully-onchain dynamic SVG reflecting current balances of the bound wallet and builder work stream."}'
                        )
                    )
                )
            )
        );
    }
}
