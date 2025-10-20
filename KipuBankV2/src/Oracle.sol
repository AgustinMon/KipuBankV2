// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity > 0.8.0;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

/**
     * Network: Sepolia (por ejemplo)
     * Aggregator: ETH/USD
     * Address: 0x694AA1769357215DE4FAC081bf1f309aDC325306
     */
contract Oracle is Ownable {

    AggregatorV3Interface internal priceFeed;

    mapping(address => uint256) public prices;

    event PriceUpdated(address indexed asset, uint256 price);

    constructor() Ownable(msg.sender) {
        // Dirección del oráculo de Chainlink para ETH/USD en Sepolia
        priceFeed = AggregatorV3Interface(0x694AA1769357215DE4FAC081bf1f309aDC325306);

    }

    function setPrice(address asset, uint256 price) public onlyOwner {
        prices[asset] = price;
        emit PriceUpdated(asset, price);
    }

    function getPrice(address asset) public view returns (uint256) {
        return prices[asset];
    }

    /**
     * Devuelve el precio más reciente de ETH/USD
     * (
            uint80 roundId,
            int256 answer,      // ← ESTE es el precio
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
     */
    function getLatestPrice() public view returns (int) {
        (
            , 
            int price,
            ,
            ,
            
        ) = priceFeed.latestRoundData();
        return price;
    }
}