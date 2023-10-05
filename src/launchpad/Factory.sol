// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.19;

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {DataTypes} from "src/launchpad/DataTypes.sol";
import {Raise} from "src/launchpad/Raise.sol";

contract FundingFactory {
    using SafeERC20 for ERC20;

    function setStakingToken() external {}

    function getStakingToken() external view {}

    function createRaise(DataTypes.fundingInfo calldata fundingInfo) external {
        DataTypes.raiseStructure memory raiseStructure;
        
        // get raise mode
        DataTypes.RaiseMode raiseMode = fundingInfo.raiseMode;

        if (raiseMode == DataTypes.RaiseMode.WHITELIST_THEN_PUBLIC){
            
            // start & end: whitelist
            raiseStructure.whitelistStart = fundingInfo.startTime;
            raiseStructure.whitelistEnd = fundingInfo.startTime + fundingInfo.whitelistDuration;
            // define whitelist-guaranteed & whitelistFFA rounds: equal time each
            raiseStructure.whitelistFFAStart = fundingInfo.startTime + (fundingInfo.whitelistDuration / 2);

            // start & end: public
            raiseStructure.publicStart = raiseStructure.whitelistEnd;
            raiseStructure.publicEnd = fundingInfo.startTime + fundingInfo.whitelistDuration + fundingInfo.publicDuration;

            // Allocation
            //raiseStructure.whitelistRoundAllocation = fundingInfo.totalAssetAllocation 
            //raiseStructure.publicRoundAllocation =
        }

        if (raiseMode == DataTypes.RaiseMode.WHITELIST_ONLY){
            
            // start & end
            raiseStructure.whitelistStart = fundingInfo.startTime;
            raiseStructure.whitelistEnd = fundingInfo.startTime + fundingInfo.whitelistDuration;

        }

        if (raiseMode == DataTypes.RaiseMode.PUBLIC_ONLY){
            // start & end
            raiseStructure.publicStart = fundingInfo.startTime;
            raiseStructure.publicEnd = fundingInfo.startTime + fundingInfo.publicDuration;
        }

        


    }
}