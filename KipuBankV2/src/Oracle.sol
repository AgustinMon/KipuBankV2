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
        /// Oracle address for Chainlink on Sepolia
        priceFeed = AggregatorV3Interface(0x694AA1769357215DE4FAC081bf1f309aDC325306);

    }

    /// native price setter for testing purposes
    function setPrice(address asset, uint256 price) public onlyOwner {
        prices[asset] = price;
        emit PriceUpdated(asset, price);
    }

    /// native price getter for testing purposes
    function getPrice(address asset) public view returns (uint256) {
        return prices[asset];
    }

    /*
     * @notice Function to get the latest price from Chainlink Oracle
     * @dev Returns the latest price with 8 decimals
     * (
            uint80 roundId,
            int256 answer,      // ← price
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
        @returns int Latest price with 8 decimals
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