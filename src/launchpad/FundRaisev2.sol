// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.19;

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {MerkleProof} from "openzeppelin-contracts/contracts/utils/cryptography/MerkleProof.sol";
import "src/interfaces/IFundingFactory.sol";
import {DataTypes} from "src/launchpad/DataTypes.sol";

// merkle-proof
// https://github.com/Anish-Agnihotri/merkle-airdrop-starter/blob/master/contracts/src/MerkleClaimERC20.sol
// https://github.com/Seedifyfund/Launchpad-smart-contract/blob/main/contracts/SeedifyFund/SeedifyFundBUSDWithMerkle.sol#L194

// coin: external project's token | token: staked launchpad token

contract FundRaise {
    using SafeERC20 for ERC20;

    //external contracts
    IERC20 public token;
    IFundingFactory public factory;
    address public treasury; 
    
    // Funding + Raise + Progess
    DataTypes.fundingInfo public fundingInfo;
    DataTypes.raiseStructure public raiseStructure;
    DataTypes.raiseProgress public raiseProgress;

    // Record of user's purchases 
    mapping(address user => uint256 amount) internal pledgePurchases;     // record of sales in pledge round 
    mapping(address user => uint256 amount) internal publicPurchases;    // record of sales in publc round 


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

        // Check payment mode
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
        
        // 2. validate buy
        uint256 amountToBuy = _validateBuy(raiseStructureCached, userAmount);

        // 3. update state
         if(period == DataTypes.Period.Pledge || period == DataTypes.Period.PledgeFFA) {
            
            pledgePurchases[msg.sender] += amountToBuy;  
            raiseProgressCached.allocationSoldInPledge += amountToBuy; 

            raiseProgressCached.capitalRaisedInPledge += amountToBuy;   
            // emit
        } 
        
        if (period == DataTypes.Period.Pledge) {
            
            publicPurchases[msg.sender] += amountToBuy;
            raiseProgressCached.allocationSoldInPublic += amountToBuy;  

            raiseProgressCached.capitalRaisedInPledge += amountToBuy;   
            // emit
        }

        // 4. transfers
        _transferIn(amountToBuy, fundingInfoCached.raiseInNative, fundingInfoCached.currency);
            //raiseProgressCached.capitalRaisedInPledge += ;  

    }

    // cache structs into mem
    function _cache() internal returns(DataTypes.fundingInfo, DataTypes.raiseStructure, DataTypes.raiseProgress) {
 
        DataTypes.fundingInfo memory fundingInfoCached = fundingInfo;
        DataTypes.raiseStructure memory raiseStructureCached = raiseStructure;
        DataTypes.raiseProgress memory raiseProgressCached = raiseProgress;
        
        return (fundingInfoCached, raiseStructureCached, raiseProgressCached);
    }

    function getPeriod(DataTypes memory raiseStructureCached) public returns(DataTypes.Period) {

        DataTypes.RaiseMode raiseMode = raiseStructureCached.raiseMode;
        
        uint256 pledgeStart = raiseStructureCached.pledgeStart;
        uint256 pledgeFFAStart = raiseStructureCached.pledgeFFAStart;
        uint256 pledgeEnd = raiseStructureCached.pledgeFFAEnd;

        uint256 publicStart = raiseStructureCached.publicStart;
        uint256 publicEnd = raiseStructureCached.publicEnd;

        if (raiseMode == DataTypes.RaiseMode.PLEDGERS_THEN_PUBLIC) {
            // validate blocktime
            require(pledgeStart <= block.timestamp < publicEnd, "Raise over");

            if(block.timestamp < pledgeFFAStart) {
                // in pledgeG mode

                return DataTypes.Period.Guaranteed;
            }

            if(block.timestamp < pledgeEnd) {
                // in pledger's FFA mode
                return DataTypes.Period.GuaranteedFFA;
            }

            if(block.timestamp < publicEnd) {
                // in pledger's FFA mode
                return DataTypes.Period.Public;
            }
        }

        if(raiseMode == DataTypes.RaiseMode.PLEDGERS_ONLY) {
            // validate blocktime
            require(pledgeStart <= block.timestamp < pledgeEnd, "Raise over");

            if(block.timestamp < pledgeFFAStart) {
                // in pledgeG mode

                return DataTypes.Period.Guaranteed;
            }

            if(block.timestamp < pledgeEnd) {
                // in pledger's FFA mode

                return DataTypes.Period.GuaranteedFFA;
            }
        }

        if(raiseMode == DataTypes.RaiseMode.PUBLIC_ONLY) {               
            require(publicStart <= block.timestamp < publicEnd, "Raise over");

            // in pledger's FFA mode
            return DataTypes.Period.Public;
        }
    }

    // check if user has at least minRequiredTokens
    function checkRequiredTokens(address user, uint256 minRequiredTokens) public view returns(bool, uint256) {
        // if set to 0 during init, no requirement
        if (minRequiredTokens == 0) {
            return true;
        } 

        IERC20 stakingToken = factory.getStakingToken();
        uint256 userBalance = stakingToken.balanceOf(user);
        
        return (userBalance >= minRequiredTokens, userBalance);
    }

    //getBuyAmountBasedOnPeriod
    //make a public getter ww/o having to pass raiseStructureCached as params
    function _getBuyLimits(DataTypes.raiseStructure memory raiseStructureCached, DataTypes.Period period, uint256 userStkBalance) internal returns(uint256, uint256) {

        uint256 minBuy;
        uint256 maxBuy;

        if(period == DataTypes.Period.Pledge) {
            // calc user's allocation
            maxBuy = userStkBalance * raiseStructureCached.pledgeAllocationPerStaked;

            return (minBuy, maxBuy);
        }
        
        if(period == DataTypes.Period.PledgeFFA) {

            minBuy = raiseStructureMem.pledgeFFAMinBuyLimit;
            maxBuy = raiseStructureMem.pledgeFFAMaxBuyLimit;

            return (minBuy, maxBuy);

        }

        if(period == DataTypes.Period.Public) {

            minBuy = raiseStructureMem.publicMinBuyLimit;
            maxBuy = raiseStructureMem.publicMaxBuyLimit;

            return (minBuy, maxBuy);
        }
    }

    function _getAvailableAllocation(DataTypes.raiseProgress memory raiseProgressCached, DataTypes.Period currentPeriod) internal returns(uint256) {
        
        if(currentPeriod == DataTypes.Period.Pledge || currentPeriod == DataTypes.Period.PledgeFFA) {

            uint256 availableAllocation = raiseProgressCached.pledgeTotalAllocation - raiseProgressCached.allocationSoldInPledge;
            return availableAllocation;
        }

        if(currentPeriod == DataTypes.Period.Public){
            uint256 availableAllocation = raiseProgressCached.publicTotalAllocation - raiseProgressCached.allocationSoldInPublic;
            return availableAllocation;
        }
    }


    // based on mode, check period 
    // based on period, check if minTokens
    // based on period, check min/max buyLimits
    function _validateBuy(DataTypes memory raiseStructureCached, DataTypes.raiseProgress memory raiseProgressCached, uint256 userAmount) internal returns(uint256) {
        
        // based on mode, check period 
        DataTypes.Period currentPeriod = getPeriod(raiseStructureCached);
        
        //check available allocation for mode
        uint256 availableAllocation = _getAvailableAllocation(raiseProgressCached, currentPeriod);
        require(availableAllocation > 0, "Sold out");

        // if pledge period: user must hold minRequiredTokens
        if(currentPeriod == DataTypes.Period.Pledge || currentPeriod == DataTypes.Period.PledgeFFA) {

            (bool isUserAPledger, uint256 userBalance) = checkRequiredTokens(msg.sender, raiseStructure.pledgeMinRequiredTokens);
            require(isUserAPledger, "User ineligible");
        }

        // check min/max buyLimits
        (uint256 minBuy, uint256 maxBuy) = _getBuyLimits(raiseStructureCached, curentPeriod, userBalance);

        // minBuy check (availableAllocation is non-zero)
        minbuy = availableAllocation < minBuy ? availableAlloc : minBuy;
        require(userAmount > minBuy, "userAmount dishonors minBuy");

        // check if incoming + prior buy: has user exceeded maxBuy
        uint256 bought;

        if(period == DataTypes.Period.Pledge || period == DataTypes.Period.PledgeFFA) {
            bought = pledgePurchases[msg.sender];  
        } 
        
        if (period == DataTypes.Period.Pledge) {
            bought = publicPurchases[msg.sender];
        }

        uint256 userRemaining = maxBuy - (bought + userAmount);
        require(userRemaining > 0, "userAmount dishonors maxBuy");
        
        // rebase userAmount to remainder
        userAmount = userAmount > userRemaining ? userRemaining : userAmount;

        return userAmount;
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