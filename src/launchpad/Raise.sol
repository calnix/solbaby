// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.19;

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "src/interfaces/IFundingFactory.sol";

import {DataTypes} from "src/launchpad/DataTypes.sol";
import {ValidationLogic} from "src/libraries/ValidationLogic.sol";
import {Errors} from "src/libraries/Error.sol";

// coin: external project's token | token: staked launchpad token

contract Raise {
    using SafeERC20 for ERC20;

    //external contracts
    IERC20 public assetToken;
    IERC20 public stakingToken;

    address public treasury; 
    IFundingFactory public factory;
    
    // Funding + Raise + Progess
    DataTypes.fundingInfo internal _fundingInfo;
    DataTypes.raiseStructure internal _raiseStructure;
    DataTypes.raiseProgress internal _raiseProgress;

    // Record of user's purchases 
    mapping(address user => uint256 amount) internal _whitelistPurchases;     // record of sales in whitelist round 
    mapping(address user => uint256 amount) internal _publicPurchases;        // record of sales in publc round 

    // commit funding in ether or specified ccy
    // create a buy for each period
    // cache required variables based on mode, then pass into the buy()
    function commit(uint256 amount) external payable {
        //getState: fund raise must be active: not paused, not ended
        //require(_isActive(), "Not active"); 

        // 1. cache
        (DataTypes.fundingInfo memory fundingInfoCached, 
            DataTypes.raiseStructure memory raiseStructureCached, 
            DataTypes.raiseProgress memory raiseProgressCached) = _cache();

        // Check payment mode && check user's amount
        uint256 userAmount;
        if(fundingInfoCached.raiseInNative == true) {
            // paying in native 
            require(msg.value > 0, "Invalid msg.value");
            userAmount = msg.value;

        } else {
            // paying in tokens
            require(amount > 0);
            userAmount = amount;
        }
        
        // Check period + whitelist requirements 
        // if whitelist period: user must hold minRequiredTokens
        bool isUserEligible;
        uint256 userStakedBalance;
        DataTypes.Period currentPeriod = _getPeriod(raiseStructureCached);
        if(currentPeriod == DataTypes.Period.WHITELIST_GUARANTEED || currentPeriod == DataTypes.Period.WHITELIST_FFA) {

            (isUserEligible, userStakedBalance) = _checkRequiredTokens(msg.sender, raiseStructureCached.pledgeMinRequiredTokens);
            require(isUserEligible, "User ineligible");
        }

        // 2. validate buy
        uint256 amountToBuy = ValidationLogic._validateBuy(raiseStructureCached, raiseProgressCached, _whitelistPurchases, _publicPurchases, currentPeriod, userAmount, userStakedBalance);

        // 3. update state
         if(currentPeriod == DataTypes.Period.WHITELIST_GUARANTEED || currentPeriod == DataTypes.Period.WHITELIST_FFA) {
            
            _whitelistPurchases[msg.sender] += amountToBuy;  
            raiseProgressCached.allocationSoldInPledge += amountToBuy; 

            raiseProgressCached.capitalRaisedInPledge += amountToBuy;   
            // emit
        } 
        
        if (currentPeriod == DataTypes.Period.PUBLIC) {
            
            _publicPurchases[msg.sender] += amountToBuy;
            raiseProgressCached.allocationSoldInPublic += amountToBuy;  

            raiseProgressCached.capitalRaisedInPledge += amountToBuy;   
            // emit
        }

        // 4. transfers
        _transferIn(amountToBuy, fundingInfoCached.raiseInNative, fundingInfoCached.currency);
            //raiseProgressCached.capitalRaisedInPledge += ;  

    }

    // for users to collect their ICO tokens as per vesting
    function claim() external {}

    // cache structs into mem
    function _cache() internal returns(DataTypes.fundingInfo fundingInfo, DataTypes.raiseStructure raiseStructure, DataTypes.raiseProgress raiseProgress) {
 
        DataTypes.fundingInfo memory fundingInfoCached = fundingInfo;
        DataTypes.raiseStructure memory raiseStructureCached = raiseStructure;
        DataTypes.raiseProgress memory raiseProgressCached = raiseProgress;
        
        return (fundingInfoCached, raiseStructureCached, raiseProgressCached);
    }

    // check what period we are in
    function _getPeriod(DataTypes memory raiseStructureCached) internal returns(DataTypes.Period) {

        DataTypes.RaiseMode raiseMode = raiseStructureCached.raiseMode;
        
        //whitelist
        uint256 whitelistStart = raiseStructureCached.whitelistStart;
        uint256 whitelistFFAStart = raiseStructureCached.whitelistFFAStart;
        uint256 whitelistEnd = raiseStructureCached.whitelistEnd;

        //public
        uint256 publicStart = raiseStructureCached.publicStart;
        uint256 publicEnd = raiseStructureCached.publicEnd;

        if (raiseMode == DataTypes.RaiseMode.WHITELIST_THEN_PUBLIC) {
            // validate blocktime
            require(whitelistStart <= block.timestamp <= publicEnd, "Raise over");

            if(block.timestamp < whitelistFFAStart) {
                // in guaranteed round
                return DataTypes.Period.WHITELIST_GUARANTEED;
            }

            if(block.timestamp < whitelistEnd) {
                // in whitelisted FFA round
                return DataTypes.Period.WHITELIST_FFA;
            }

            if(block.timestamp < publicEnd) {
                // in public round
                return DataTypes.Period.PUBLIC;
            }
        }

        if(raiseMode == DataTypes.RaiseMode.WHITELIST_ONLY) {
            // validate blocktime
            require(whitelistStart <= block.timestamp <= publicEnd, "Raise over");

            if(block.timestamp < whitelistFFAStart) {
                // in pledgeG mode

                return DataTypes.Period.WHITELIST_GUARANTEED;
            }

            if(block.timestamp < whitelistEnd) {
                // in pledger's FFA mode

                return DataTypes.Period.WHITELIST_FFA;
            }
        }

        if(raiseMode == DataTypes.RaiseMode.PUBLIC_ONLY) {               
            require(publicStart <= block.timestamp < publicEnd, "Raise over");

            // in pledger's FFA mode
            return DataTypes.Period.PUBLIC;
        }
    }

    // check if user has at least minRequiredTokens
    function _checkRequiredTokens(address user, uint256 minRequiredTokens) public view returns(bool, uint256) {
        // if set to 0 during init, no requirement
        if (minRequiredTokens == 0) {
            return true;
        } 

        uint256 userBalance = stakingToken.balanceOf(user);
        
        return (userBalance >= minRequiredTokens, userBalance);
    }

        // get payment
    function _transferIn(uint256 amount, bool raiseInNative, address currency) internal {
        
        if (raiseInNative == true){
            require(amount <= msg.value, "Insufficient msg.value");
            
            //return excess
            remainder = msg.value - amount;
            if(remainder) msg.sender.call{value: remainder}("");

        } else {

            IERC20(currency).safeTransferFrom(msg.sender, address(this), amount);
        }

    }
}