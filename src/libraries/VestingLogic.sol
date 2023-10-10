// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.19;

import { Errors } from "src/libraries/Errors.sol";
import { DataTypes } from "src/launchpad/DataTypes.sol";
import { PercentageMath } from "src/libraries/PercentageMath.sol";

import { Math } from "openzeppelin-contracts/contracts/utils/math/Math.sol";

library VestingLogic {
    /*//////////////////////////////////////////////////////////////
                           VESTING
    //////////////////////////////////////////////////////////////*/
    function configVesting() internal { }

    // change the distribution for remaninings
    function _modifyVesting() internal { }

    /*//////////////////////////////////////////////////////////////
                                 CLAIMS
    //////////////////////////////////////////////////////////////*/

    // update left to collect
    function _updateDistribution(
        mapping(address user => DataTypes.RedemptionInfo) storage _usersRedemptionInfo,
        mapping(address user => DataTypes.RedemptionInfo) storage _teamRedemptionInfo,
        DataTypes.Vesting storage _vesting,
        address user,
        bool isTokens
    )
        internal returns (uint256)
    {
        uint256 redeemablePercentage;

        // get appropriate emissionInfo + redemptionInfo
        DataTypes.EmissionInfo memory emissionInfo = isTokens ? _vesting.tokenEmissionInfo : _vesting.capitalEmissionInfo;
        DataTypes.RedemptionInfo storage redemptionInfo = isTokens ? _usersRedemptionInfo[user] : _teamRedemptionInfo[user];

        //get redeemablePercentage: if linear
        if(emissionInfo.emissionType == DataTypes.EmissionType.Linear){
            redeemablePercentage = _getLinearDistribution(emissionInfo, redemptionInfo);
            
            //update
            redemptionInfo.percentageRedeemed += redeemablePercentage;
        }

        //get redeemablePercentage + update: if dynamic
        if(emissionInfo.emissionType == DataTypes.EmissionType.Dynamic){
            uint256 startIndex;
            uint256 redeemableIndexes;
            (redeemablePercentage, redeemableIndexes, startIndex) = _getDynamicDistribution(emissionInfo, redemptionInfo);
            
            // update state for dynamic
            if(redeemableIndexes > 0){
                require(startIndex == redemptionInfo.redeemedPeriods.length, " ");
                uint256 endIndex = startIndex + redeemableIndexes - 1;   

                for(uint256 n = startIndex; n < endIndex; n++){
                    // mark as redeemed
                    redemptionInfo.redeemedPeriods.push(true);   
                }
            }
        }
                
        return redeemablePercentage;
    }

    function _getLinearDistribution(DataTypes.EmissionInfo memory emissionInfo, DataTypes.RedemptionInfo memory redemptionInfo) internal returns (uint256) {
        // pre-check
        if (
            emissionInfo.emissionType != DataTypes.EmissionType.Linear || 
            emissionInfo.periods.length == 0 ||                                  //linear's period is stored as 1st element
            emissionInfo.periods[0] == 0 || 
            block.timestamp < emissionInfo.startTime
        ) {

            return 0;
        }

        // get total claimable to date
        uint256 timeElapsed = block.timestamp - emissionInfo.startTime;
        uint256 totalClaimablePercentage = Math.min(PercentageMath.PERCENTAGE_FACTOR, (PercentageMath.PERCENTAGE_FACTOR * timeElapsed) / emissionInfo.periods[0]);

        //get claimablePercentage
        uint256 redeemablePercentage = totalClaimablePercentage - redemptionInfo.percentageRedeemed;
        return redeemablePercentage;
    }

    function _getDynamicDistribution(DataTypes.EmissionInfo memory emissionInfo, DataTypes.RedemptionInfo memory redemptionInfo) internal returns(uint256, uint256, uint256) { 
        // pre-check
        if (
            emissionInfo.emissionType != DataTypes.EmissionType.Dynamic || 
            emissionInfo.periods.length == 0 ||                                  //series of periods defining time buckets must be defined
            block.timestamp < emissionInfo.startTime
        ) {
            
            return (0, 0, 0);
        }

        // get user's remaining claimable periods
        uint256 startIndex = getFalseFlag(redemptionInfo.redeemedPeriods);
        uint256 startTime = emissionInfo.startTime;

        uint256 redeemableIndexes;
        uint256 redeemablePercentage;
        uint256 nextVestedIndex;    //vested: cannot claim presently

        uint256 len = redemptionInfo.redeemedPeriods.length;
        
        for(uint256 n = startIndex; n < len; n++) {
        
            if(block.timestamp >= startTime + emissionInfo.periods[n]) {
                redeemablePercentage += emissionInfo.percentages[n];
                ++ redeemableIndexes;
            } 
            
            else {
                nextVestedIndex = n;
                break;
            }
        }    
        return (redeemablePercentage, redeemableIndexes, startIndex);
    }

    // False: unclaimed
    function getFalseFlag(bool[] memory periods) internal view returns(uint256) {
        uint256 len = periods.length;
        
        for(uint256 n = 0; n < len; n++) {
            if(periods[n] == false) return n;
        }

        return len; //all false
    }


}
