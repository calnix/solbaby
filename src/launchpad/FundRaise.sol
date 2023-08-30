// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.19;

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {MerkleProof} from "openzeppelin-contracts/contracts/utils/cryptography/MerkleProof.sol";

import {DataTypes} from "src/launchpad/DataTypes.sol";

// merkle-proof
// https://github.com/Anish-Agnihotri/merkle-airdrop-starter/blob/master/contracts/src/MerkleClaimERC20.sol
// https://github.com/Seedifyfund/Launchpad-smart-contract/blob/main/contracts/SeedifyFund/SeedifyFundBUSDWithMerkle.sol#L194

// coin: external project's token | token: staked launchpad token

contract FundRaise {
    using SafeERC20 for ERC20;

    //external contracts
    IERC20 public token;
    //IFundingFactory public factory;
    address public treasury; 
    
    // Funding + Raise
    DataTypes public fundingInfo;
    DataTypes public raiseStructure;

    // track progress
    uint256 public allocationCommitted;    
    uint256 public allocationSold;
    uint256 public capitalRaised;

    // Record of user's purchases 
    mapping(address user =>uint256 amount) internal pledgePurchases;     // record of sales in pledge round 
    mapping(address user =>uint256 amount) internal publicPurchases;    // record of sales in publc round 

    // States
    bool public isCancelled;  
    bool public isTokensFunded;        
    bool public finishUpSuccess; 


    function initialize() external  {}

    function getState() external {

        /**
        Period: Deployed, Setup, Pledge, Public, Ended
        State: Inactive, Active, Ended, Paused, Refunded,  
         */
    }

    function _cache() internal returns(DataTypes.fundingInfo, DataTypes.raiseStructure) {
 
        DataTypes memory fundingInfoMem = fundingInfo;
        DataTypes memory raiseStructureMem = raiseStructure;
        
        return (fundingInfoMem, raiseStructureMem);
    }

    function getPeriod(DataTypes memory raiseStructureMem) public returns(DataTypes.Period) {

        DataTypes.RaiseMode raiseMode = raiseStructureMem.raiseMode;
        
        uint256 pledgeStart = raiseStructureMem.pledgeStart;
        uint256 pledgeFFAStart = raiseStructureMem.pledgeFFAStart;
        uint256 pledgeEnd = raiseStructureMem.pledgeFFAEnd;

        uint256 publicStart = raiseStructureMem.publicStart;
        uint256 publicEnd = raiseStructureMem.publicEnd;

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

    function getBuyAmountBasedOnPeriod(DataTypes.Period period, uint256 userStkBalance) public returns(uint256, uint256) {

        uint256 minBuy = 0;
        uint256 maxBuy = 0;

        if(period == DataTypes.Period.Pledge) {
            // get user's allocation
            maxBuy = userStkBalance * pledgeAllocationPerStaked;

            return (minBuy, maxBuy);
        }
        
        if(period == DataTypes.Period.PledgeFFA){

            minBuy = raiseStructureMem.pledgeFFAMinBuyLimit;
            maxBuy = raiseStructureMem.pledgeFFAMaxBuyLimit == 0 ? type(uint256).max : raiseStructureMem.pledgeFFAMaxBuyLimit;

            return (minBuy, maxBuy);

        }

        if(period == DataTypes.Period.Public){

            minBuy = raiseStructureMem.publicMinBuyLimit;
            maxBuy = raiseStructureMem.publicMaxBuyLimit == 0 ? type(uint256).max : raiseStructureMem.publicMaxBuyLimit;

            // in pledger's FFA mode
            return (minBuy, maxBuy);
        }
    }

    // commit funding in ether or specified ccy
    // create a buy for each mode
    // cache required variables based on mode, then pass into the buy()
    function commit(uint256 amount) external payable {
        //getState: fund raise must be active: not paused, not ended
        require(_isActive(), "Not active"); 

        // payment mode
        if(fundingInfoMem.currency == address(0)) {
            require(msg.value > 0);
            amount = msg.value;
        } else{
            require(amount > 0);
        }
        
        // get data
        (DataTypes memory fundingInfoMem, DataTypes memory raiseStructureMem) = _cache();

        // get mode
        DataTypes.Period period = getPeriod(raiseStructureMem);

        // user must hold minRequiredTokens
        if(period == DataTypes.Period.Pledge || period == DataTypes.Period.PledgeFFA) {
            (bool isUserAPledger, uint256 userBalance) = checkRequiredTokens(msg.sender, raiseStructure.pledgeMinRequiredTokens);
            require(isUserAPledger, "User ineligible");
        }
        
        // get period min/max
        (uint256 minBuy, uint256 maxBuy) = getBuyAmountBasedOnPeriod(period, userBalance);
        
        // if availableAlloc
        uint256 availableAlloc = allocationCommitted - allocationSold;
        require(availableAlloc > 0, "Sold out");

        // min purchase amount
        minbuy = availableAlloc < minBuy ? availableAlloc : minbuy;
        require(amount > minbuy, "minBuy Exceeded");
        // max purchase amount
        uint256 amountToBuy = amount > maxBuy ? maxbuy : amount;

        // previously bought
        if(period == DataTypes.Period.Pledge || period == DataTypes.Period.PledgeFFA) {
            uint256 bought = pledgePurchases[msg.sender];  
        } 
        
        if (period == DataTypes.Period.Pledge) {
            uint256 bought = publicPurchases[msg.sender];
        }

        // 
    }

    function _validateBuy(DataTypes.Period period, uint256 maxBuy, uint256 amountToBuy) internal {
        uint256 bought;

        if (period == DataTypes.Period.PledgeFFA) {
            // ensure m
            bought = pledgePurchases[msg.sender];
            
            uint256 total = bought + amountToBuy;
            require(total < maxBuy, "max exeeded");
        }

        if (period == DataTypes.Period.Public) {
            // ensure max no exceeded
            bought = publicPurchases[msg.sender];
            
            uint256 total = bought + amountToBuy;
            require(total < maxBuy, "max exeeded");
        }

    }

    function buy() external {}

    // claim tokens on successful fundraise
    function claim() external {}

    function refund() external {}


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

    /**
     * @notice Check if fund raise is active 
     * @dev 
     * @return - Bool value
     */
    function _isActive() internal view returns(bool) {

        if (!isTokensFunded || isCancelled) return false;
        if (block.timestamp < startTime) return false;
        if (block.timestamp >= endTime) return false;
        if (collectedFunds >= hardCap) return false;

        return true;
    }



    /*//////////////////////////////////////////////////////////////
                                GETTERS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Gets active state of fund raise
     * @return If true, raise is active
     */
    function isActive() public view returns(bool) {
        return _isActive;
    }

    function isUserEligible() external view returns(bool) {}


}


    /**
     Funding structure
     1) whitelist then public 
     2) whitelistOnly, publicOnly
     - able to modify duration of each, buy limits of each
     - 
     Participation structure
     1) whiteList -> meet minRequired tokens staked
     2) how much can they buy per round? 
        - tiers, tierReq, tierAlloc -> whitelist mode
        - minBuy, maxBuy for everyone -> public mode

        whitelisted users are token holders tt pledged capital in advance.
        can collect pledge tokens anytime after raise.
        

     Recording
     - track each purchase in each round w/ mapping
     - to allow for refunds
     = to allow for vested calims

     Vesting & Lockup
     - VestingReleaseType

     */


