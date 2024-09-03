// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {AggregatorV3Interface} from "@chainlink/contracts/shared/interfaces/AggregatorV3Interface.sol";

/**
 * @title Check Price
 * @author 4b
 * @notice A contract to check the current price of ETH in USD on sepolia
 */
contract CheckPrice{
    AggregatorV3Interface internal aggregatorV3;

    error StalePrice(uint256 timeUpdated,uint blocktime);

    constructor(address _aggregatorV3){
        aggregatorV3 = AggregatorV3Interface(_aggregatorV3);
    }

    /**
     * ETH/USD rate 
     */
    function currentRate() external view returns(int256){
        (,int256 price,,uint256 updatedAt,)=aggregatorV3.latestRoundData();
        if(updatedAt < block.timestamp - (60*60)){
            revert StalePrice(updatedAt , block.timestamp);
        } 
        return price;
    }
}