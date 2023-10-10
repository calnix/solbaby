// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.19;

import {DataTypes} from "src/launchpad/DataTypes.sol";

library ValidationLogic {

    // based on mode, check period
    // based on period, check if minTokens
    // based on period, check min/max buyLimits
    function _validateBuy(
        DataTypes.raiseStructure memory raiseStructureCached,
        DataTypes.raiseProgress memory raiseProgressCached,
        mapping(address user => DataTypes.Sale sale) storage _sales,     
        DataTypes.Period currentPeriod,
        uint256 amount,
        uint256 userStakedBalance
    ) internal view returns (uint256) {

        //check available allocation
        uint256 availableAllocation = _getAvailableAllocation(raiseStructureCached, raiseProgressCached, currentPeriod);
        require(availableAllocation > 0, "Sold out");

        // check buyLimits
        (uint256 minBuy, uint256 maxBuy) = _getBuyLimits(raiseStructureCached, currentPeriod, userStakedBalance);

        // in case of leftover dust
        if (minBuy > 0) {
            minBuy = availableAllocation < minBuy ? availableAllocation : minBuy;
        }
        require(amount >= minBuy, "amount dishonors minBuy");

        // check if incoming + prior buy: has user exceeded maxBuy
        uint256 bought;
        if (currentPeriod == DataTypes.Period.WHITELIST_GUARANTEED || currentPeriod == DataTypes.Period.WHITELIST_FFA) {
            bought = _sales[msg.sender].whitelistAmount;
        }

        if (currentPeriod == DataTypes.Period.PUBLIC) {
            bought = _sales[msg.sender].publicAmount;
        }

        if(maxBuy > 0){
            uint256 userRemaining = maxBuy - (bought + amount);
            require(userRemaining > 0, "amount dishonors maxBuy");
            
            // rebase userAmount to remainder
            amount = amount > userRemaining ? userRemaining : amount;
        }

        return amount;
    }

    function _getAvailableAllocation(
        DataTypes.raiseStructure memory raiseStructureCached,
        DataTypes.raiseProgress memory raiseProgressCached,
        DataTypes.Period currentPeriod
    ) internal pure returns (uint256) {

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
    ) internal pure returns (uint256, uint256) {
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

}
