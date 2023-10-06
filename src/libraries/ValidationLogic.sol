// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.19;

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

import {DataTypes} from "src/launchpad/DataTypes.sol";

library ValidationLogic {

    // based on mode, check period
    // based on period, check if minTokens
    // based on period, check min/max buyLimits
    function _validateBuy(
        DataTypes.raiseStructure memory raiseStructureCached,
        DataTypes.raiseProgress memory raiseProgressCached,
        mapping(address user => uint256 amount) storage _whitelistPurchases,
        mapping(address user => uint256 amount) storage _publicPurchases,
        DataTypes.Period currentPeriod,
        uint256 userAmount,
        uint256 userStakedBalance
    ) internal returns (uint256) {

        //check available allocation
        uint256 availableAllocation = _getAvailableAllocation(raiseStructureCached, raiseProgressCached, currentPeriod);
        require(availableAllocation > 0, "Sold out");

        // check buyLimits
        (uint256 minBuy, uint256 maxBuy) = _getBuyLimits(raiseStructureCached, currentPeriod, userStakedBalance);

        // in case of dust
        if (minBuy > 0) {
            minBuy = availableAllocation < minBuy ? availableAllocation : minBuy;
        }
        require(userAmount >= minBuy, "userAmount dishonors minBuy");

        // check if incoming + prior buy: has user exceeded maxBuy
        uint256 bought;
        if (currentPeriod == DataTypes.Period.WHITELIST_GUARANTEED || currentPeriod == DataTypes.Period.WHITELIST_FFA) {
            bought = _whitelistPurchases[msg.sender];
        }

        if (currentPeriod == DataTypes.Period.PUBLIC) {
            bought = _publicPurchases[msg.sender];
        }

        if(maxBuy > 0){
            uint256 userRemaining = maxBuy - (bought + userAmount);
            require(userRemaining > 0, "userAmount dishonors maxBuy");
            
            // rebase userAmount to remainder
            userAmount = userAmount > userRemaining ? userRemaining : userAmount;
        }

        return userAmount;
    }

    function _getAvailableAllocation(
        DataTypes.raiseStructure memory raiseStructureCached,
        DataTypes.raiseProgress memory raiseProgressCached,
        DataTypes.Period currentPeriod
    ) internal returns (uint256) {

        uint256 availableAllocation;

        if (currentPeriod == DataTypes.Period.WHITELIST_GUARANTEED || currentPeriod == DataTypes.Period.WHITELIST_FFA) {
            availableAllocation =
                raiseStructureCached.whitelistRoundAllocation - raiseProgressCached.whitelistRoundAllocationSold;
            return availableAllocation;
        }

        if (currentPeriod == DataTypes.Period.PUBLIC) {
            availableAllocation =
                raiseStructureCached.publicRoundAllocation - raiseProgressCached.publicRoundAllocationSold;
            return availableAllocation;
        }
    }

    //getBuyAmountBasedOnPeriod
    //make a public getter ww/o having to pass raiseStructureCached as params
    function _getBuyLimits(
        DataTypes.raiseStructure memory raiseStructureCached,
        DataTypes.Period period,
        uint256 userStakedBalance
    ) internal returns (uint256, uint256) {
        uint256 minBuy;
        uint256 maxBuy;

        if (period == DataTypes.Period.WHITELIST_GUARANTEED) {
            // calc user's allocation
            maxBuy = userStakedBalance * raiseStructureCached.whitelistAllocationPerUnitStaked;

            return (0, maxBuy);
        }

        if (period == DataTypes.Period.WHITELIST_FFA) {
            // may be 0 values
            minBuy = raiseStructureCached.whitelistFFAMinBuyLimit;
            maxBuy = raiseStructureCached.whitelistFFAMaxBuyLimit;

            return (minBuy, maxBuy);
        }

        if (period == DataTypes.Period.PUBLIC) {
            minBuy = raiseStructureCached.publicMinBuyLimit;
            maxBuy = raiseStructureCached.publicMaxBuyLimit;

            return (minBuy, maxBuy);
        }
    }

    function _updateState(
        uint256 amountToBuy,
        DataTypes.Period currentPeriod, 
        mapping(address user => uint256 amount) storage _whitelistPurchases,
        mapping(address user => uint256 amount) storage _publicPurchases
    ) internal {

        if(currentPeriod == DataTypes.Period.WHITELIST_GUARANTEED || currentPeriod == DataTypes.Period.WHITELIST_FFA) {
            
            _whitelistPurchases[msg.sender] += amountToBuy;  
            raiseProgressCached.whitelistRoundAllocationSold += amountToBuy; 

            raiseProgressCached.whitelistRoundCapitalRaised += amountToBuy;   
            // emit
        } 
        
        if (currentPeriod == DataTypes.Period.PUBLIC) {
            
            _publicPurchases[msg.sender] += amountToBuy;
            raiseProgressCached.publicRoundAllocationSold += amountToBuy;  

            raiseProgressCached.publicRoundCapitalRaised += amountToBuy;   
            // emit
        }

    }
}
