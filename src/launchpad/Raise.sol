// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.19;

import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { ERC20 } from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import { SafeERC20 } from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

import { DataTypes } from "src/launchpad/DataTypes.sol";

import { Errors } from "src/libraries/Errors.sol";
import { VestingLogic } from "src/libraries/VestingLogic.sol";
import { ValidationLogic } from "src/libraries/ValidationLogic.sol";
import { PercentageMath } from "src/libraries/PercentageMath.sol";

//import "src/interfaces/IFundingFactory.sol";

// coin: external project's token | token: staked launchpad token

contract Raise {
    using SafeERC20 for ERC20;
    using SafeERC20 for IERC20;
    using PercentageMath for uint256;

    //external contracts
    IERC20 public stakingToken;

    address public treasury; 
    //IFundingFactory public factory;  
    
    // Funding + Raise + Progess
    DataTypes.fundingInfo internal _fundingInfo;
    DataTypes.raiseStructure internal _raiseStructure;
    DataTypes.raiseProgress internal _raiseProgress;

    // Raise State
    DataTypes.State internal _raiseState;

    // Record of user's purchases:unit in ICO tokens 
    mapping(address user => DataTypes.Sale sale) internal _sales;     
    
    // Vesting & Redemptions
    DataTypes.Vesting internal _vesting;
    mapping(address user => DataTypes.RedemptionInfo) internal _usersRedemptionInfo;
    mapping(address user => DataTypes.RedemptionInfo) internal _teamRedemptionInfo; //in-case they change multisig

    //EVENTS


    // commit funding in ether or specified ccy
    // create a buy for each period
    // cache required variables based on mode, then pass into the buy()
    ///@param amount Amount of ICO Tokens to buy
    function subscribe(uint256 amount) external payable {
        //getState: fund raise must be active: not paused, not ended
        //require(_isActive(), "Not active"); 

        // 1. cache
        (DataTypes.fundingInfo memory fundingInfoCached, 
            DataTypes.raiseStructure memory raiseStructureCached, 
            DataTypes.raiseProgress memory raiseProgressCached) = _cache();

        //maybe: depending in support nativeCCY
        //_checkPayment(fundingInfoCached, amount);
        
        //2. Check period + whitelist requirements 
        // if whitelist period: user must hold minRequiredTokens
        DataTypes.Period currentPeriod = _getPeriod(raiseStructureCached);
        
        bool isUserEligible; uint256 userStakedBalance;
        if(currentPeriod == DataTypes.Period.WHITELIST_GUARANTEED || currentPeriod == DataTypes.Period.WHITELIST_FFA) {

            (isUserEligible, userStakedBalance) = _checkRequiredTokens(msg.sender, raiseStructureCached.whitelistMinRequiredTokens);
            require(isUserEligible, "User ineligible");
        }

        // 3. validate buy
        uint256 amountToBuy = ValidationLogic._validateBuy(raiseStructureCached, raiseProgressCached, _sales, currentPeriod, amount, userStakedBalance);

        //calculate payments
        uint256 amountToPay = _calculatePayment(amountToBuy, currentPeriod, fundingInfoCached, raiseStructureCached);

        // 4. update state
        _updateProgress(amountToPay, amountToBuy, currentPeriod, raiseProgressCached);

        // 5. transfers
        IERC20(fundingInfoCached.fundingToken).safeTransferFrom(msg.sender, address(this), amount);

    }

    // for users to collect their ICO tokens as per vesting
    function redeemTokens() external {
        
        uint256 redeemablePercentage = VestingLogic._updateDistribution(_usersRedemptionInfo, _teamRedemptionInfo, _vesting, msg.sender, true);
        if(redeemablePercentage == 0) revert Errors.NothingToRedeem();

        DataTypes.Sale memory sale = _sales[msg.sender];
            
        uint256 totalTokens = sale.whitelistAmount + sale.publicAmount;
        uint256 redeemableTokens = totalTokens * redeemablePercentage / PercentageMath.PERCENTAGE_FACTOR;

        // transfer
        IERC20(_fundingInfo.assetToken).safeTransfer(msg.sender, redeemableTokens);
        
        // emit TokensClaimed
    }

    // need modifier: onlyCampanginOwner
    function redeemCapital() external {
        require(_fundingInfo.fundRaiser == msg.sender, "Only Fund Raiser");

        uint256 redeemablePercentage = VestingLogic._updateDistribution(_usersRedemptionInfo, _teamRedemptionInfo, _vesting, msg.sender, true);
        if(redeemablePercentage == 0) revert Errors.NothingToRedeem();

        // get redeemableCapital
        uint256 totalRaised = _raiseProgress.totalCapitalRaised;
        uint256 redeemableCapital = totalRaised * redeemablePercentage / PercentageMath.PERCENTAGE_FACTOR;

        // transfer
        IERC20(_fundingInfo.assetToken).safeTransfer(msg.sender, redeemableCapital);
        
        // emit FundsClaimed
    }

    //Note: can only be called once
    function closeRound() external {
        //cache

        DataTypes.Period period = _getPeriod(_raiseStructure);
        uint256 capitalRaised = _raiseProgress.totalCapitalRaised;
        uint256 hardCap = _fundingInfo.hardCap;
        uint256 softCap = _fundingInfo.softCap;

        // updateState: raise must have ended || hardcap reached
        if (capitalRaised >= hardCap || period != DataTypes.Period.END) {
            _raiseState = DataTypes.State.COMPLETED;
        }
        
        // updateState: raise must exceed softCap && time exceeded
        if (capitalRaised >= softCap && period == DataTypes.Period.END) {
            _raiseState = DataTypes.State.COMPLETED;
        } 

        // failed: softCap not hit && time exceeded
        if (capitalRaised < softCap && period == DataTypes.Period.END) {
            _raiseState = DataTypes.State.FAILED;
        }

        // completed: charge fees 
        if(_raiseState == DataTypes.State.COMPLETED) {
            
            // collect fees
            uint256 feePercent = _fundingInfo.feePercent;
            uint256 feeChargeable = capitalRaised.percentMul(feePercent);

            // transfer fees
            IERC20(_fundingInfo.fundingToken).safeTransfer(treasury, feeChargeable);
        }

        // failed: no fees charged, return assetTokens
        if(_raiseState == DataTypes.State.FAILED){
            
            // return assetTokens
            IERC20(_fundingInfo.assetToken).safeTransfer(_fundingInfo.fundRaiser, _fundingInfo.assetAllocation);
        }

    }

    //failed: user to collect back capital
    function retrieveCapital() external {
        if(_raiseState != DataTypes.State.FAILED) revert Errors.RaiseFailed();

        uint256 userCapital = _sales[msg.sender].capitalCommitted;
        if(userCapital == 0) revert Errors.ZeroCapital();

        // reset
        _sales[msg.sender].capitalCommitted == 0;
        
        //transfer
        IERC20(_fundingInfo.fundingToken).safeTransfer(msg.sender, userCapital);
    }

    function refund() external {}

    // cache structs into mem
    function _cache() internal pure returns(DataTypes.fundingInfo memory fundingInfo, DataTypes.raiseStructure memory raiseStructure, DataTypes.raiseProgress memory raiseProgress) {
 
        DataTypes.fundingInfo memory fundingInfoCached = fundingInfo;
        DataTypes.raiseStructure memory raiseStructureCached = raiseStructure;
        DataTypes.raiseProgress memory raiseProgressCached = raiseProgress;
        
        return (fundingInfoCached, raiseStructureCached, raiseProgressCached);
    }

    // check what period we are in
    function _getPeriod(DataTypes.raiseStructure memory raiseStructure) internal view returns(DataTypes.Period) {
        
        // check start and end
        if (block.timestamp < raiseStructure.startTime) return DataTypes.Period.PENDING_START;
        if (block.timestamp > raiseStructure.endTime) return DataTypes.Period.END;

        //whitelist
        uint256 whitelistStart = raiseStructure.whitelistStart;
        uint256 whitelistFFAStart = raiseStructure.whitelistFFAStart;
        uint256 whitelistEnd = raiseStructure.whitelistEnd;

        //public
        uint256 publicStart = raiseStructure.publicStart;
        uint256 publicEnd = raiseStructure.publicEnd;

        if (raiseStructure.raiseMode == DataTypes.RaiseMode.WHITELIST_THEN_PUBLIC) {
            // validate blocktime
            require(whitelistStart <= block.timestamp && block.timestamp <= publicEnd, "Invalid Period");

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

        if(raiseStructure.raiseMode == DataTypes.RaiseMode.WHITELIST_ONLY) {
            // validate blocktime
            require(whitelistStart <= block.timestamp && block.timestamp <= whitelistEnd, "Invalid Period");

            if(block.timestamp < whitelistFFAStart) {
                // in guaranteed round
                return DataTypes.Period.WHITELIST_GUARANTEED;
            }

            if(block.timestamp < whitelistEnd) {
                // in whitelisted FFA round
                return DataTypes.Period.WHITELIST_FFA;
            }
        }

        if(raiseStructure.raiseMode == DataTypes.RaiseMode.PUBLIC_ONLY) {               
            require(publicStart <= block.timestamp && block.timestamp <= publicEnd, "Invalid Period");
            return DataTypes.Period.PUBLIC;
        }
    }

    // check if user has at least minRequiredTokens
    function _checkRequiredTokens(address user, uint256 whitelistMinRequiredTokens) internal view returns(bool, uint256) {
        
        uint256 userBalance = stakingToken.balanceOf(user);

        // if set to 0 during init, no requirement
        if (whitelistMinRequiredTokens == 0) {
            return (true, userBalance);
        } 
        
        return (userBalance >= whitelistMinRequiredTokens, userBalance);
    }

    // calculate payment: precision
    ///@param amount ICO Token amount
    function _calculatePayment(uint256 amount, DataTypes.Period currentPeriod, DataTypes.fundingInfo memory fundingInfo, DataTypes.raiseStructure memory raiseStructure) internal pure returns (uint256){
        
        uint256 price;
        if (currentPeriod == DataTypes.Period.WHITELIST_GUARANTEED || currentPeriod == DataTypes.Period.WHITELIST_FFA) {
            price = raiseStructure.whitelistAllocationUnitPrice;
        }

        if (currentPeriod == DataTypes.Period.PUBLIC) {
            price = raiseStructure.publicAllocationUnitPrice;
        }

        uint256 fundingTokenDecimals = fundingInfo.fundingTokenDecimals;
        uint256 amountToPay = (price * amount) / fundingTokenDecimals;

        return (amountToPay);
    }

    function _updateProgress(
        uint256 amountToPay,
        uint256 amountToBuy,
        DataTypes.Period currentPeriod,
        DataTypes.raiseProgress memory raiseProgressCached
        ) internal {
        
        // get user's sales order
        //DataTypes.SalesOrder memory userSales = _sales[msg.sender];

        if(currentPeriod == DataTypes.Period.WHITELIST_GUARANTEED || currentPeriod == DataTypes.Period.WHITELIST_FFA) {
            
            _sales[msg.sender].whitelistAmount += amountToBuy;  

            raiseProgressCached.whitelistRoundAllocationSold += amountToBuy; 
            raiseProgressCached.whitelistRoundCapitalRaised += amountToPay;   
            
            // emit
        } 
        
        if (currentPeriod == DataTypes.Period.PUBLIC) {
            
            _sales[msg.sender].publicAmount += amountToBuy;  

            raiseProgressCached.publicRoundAllocationSold += amountToBuy;  
            raiseProgressCached.publicRoundCapitalRaised += amountToPay;   
            
            // emit
        }

    }

/*
    function _checkPayment(DataTypes.fundingInfo calldata fundingInfoCached, paymentAmount) internal {
        // Check payment mode && check user's amount
        if(fundingInfoCached.raiseInNative == true) {
            // paying in native 
            require(msg.value > 0, "Invalid msg.value");
            paymentAmount = msg.value;

        } else {
            // paying in tokens
            require(paymentAmount > 0);
        }
    }

    function _dualTransfer() internal {
            
        if (raiseInNative == true){
            require(amount <= msg.value, "Insufficient msg.value");
            
            //return excess
            uint256 remainder = msg.value - amount;
            if(remainder) msg.sender.call{value: remainder}("");
        } else {    
            IERC20(currency).safeTransferFrom(msg.sender, address(this), amount);
        }
    }

*/

}