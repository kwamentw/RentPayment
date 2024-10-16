// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {AggregatorV3Interface} from "@chainlink/contracts/shared/interfaces/AggregatorV3Interface.sol";

/**
 * @title Check Price
 * @author 4b
 * @notice A contract to check the current price of ETH in USD on sepolia
 */
contract CheckPrice{
    // Chainlink aggregator
    AggregatorV3Interface internal aggregatorV3;

    ////////////////////////////////////////////////////////////////////
    error StalePrice(uint256 timeUpdated,uint blocktime);
    ////////////////////////////////////////////////////////////////////

    constructor(address _aggregatorV3){
        aggregatorV3 = AggregatorV3Interface(_aggregatorV3);
    }

    /**
     * Checks the current ETH/USD rate from chainlink
     * And return the price in 8 dec
     */
    function currentRate() external view returns(int256){
        (,int256 price,,uint256 updatedAt,)=aggregatorV3.latestRoundData();
        //Checks staleness of price
        if(updatedAt < block.timestamp - (60*60)){
            revert StalePrice(updatedAt , block.timestamp);
        } 
        return price;
    }
}