// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.19;


library DataTypes {

    struct fundingInfo {        
        RaiseMode raiseMode;        //uint8
        
        // periods
        uint256 whitelistDuration;   //ignored if public_mode
        uint256 publicDuration;
        uint256 startTime;

        // ICO token: asset
        address asset;     
        uint256 assetDecimals;        // precision
        uint256 assetAllocation;      // Total tokens for sales

        // allocation split
        uint256 whitelistRoundAllocation;
        uint256 publicRoundAllocation;
        
        // targets
        uint256 softCap;   // Unit in raise currency
        uint256 hardCap;   // Unit in raise currency
        
        // financing
        bool raiseInNative;           // can remove - potentially
        address raiseCurrency;        // raise currency, if not raising in ether
        
        // fees
        address stkTokenAddress;    // stkToken - for pledgers
        uint256 feePercent;         // platform fee In 1e18
    }

    struct raiseStructure {
        // whitelist-guaranteed
        uint256 whitelistStart;
        uint256 whitelistFFAStart;
        uint256 whitelistEnd;
        
        uint256 whitelistRoundAllocation;
        uint256 whitelistStakeRequirement;
        uint256 whitelistAllocationPerUnitStaked;  // in asset units
        
        // whitelist-FFA: units in raiseCurrency
        uint256 whitelistFFAMinBuyLimit;       // if 0 no limits
        uint256 whitelistFFAMaxBuyLimit;       // if 0 no limits
        
        // Public mode 
        uint256 publicStart; 
        uint256 publicEnd;   
        uint256 publicRoundAllocation;
        // per wallet limits: Unit in raiseCurrency
        uint256 publicMinBuyLimit;  
        uint256 publicMaxBuyLimit;  
    }

    // live tracking
    struct raiseProgress {
        
        // whitelist mode    
        uint256 whitelistRoundAllocationSold;
        uint256 whitelistRoundCapitalRaised;

        // public mode
        uint256 publicRoundAllocationSold;
        uint256 publicRoundCapitalRaised;   
        
        // total
        uint256 totalAllocationSold;  // ico tokens sold
        uint256 totalCapitalRaised;   // in raise cccy
    }

    struct PurchaseDetail {
        uint guaranteedAmount;
        uint lotteryAmount;
        uint overSubscribeAmount;
        uint liveWlFcfsAmount;
        uint livePublicAmount;
        uint total;
        bool hasReturnedFund;
    }

    enum RaiseMode {
        WHITELIST_THEN_PUBLIC,    // 0
        WHITELIST_ONLY,         // 1
        PUBLIC_ONLY            // 2
    }

    // Period according to timeline
    enum Period {
        PENDING_START,
        WHITELIST_GUARANTEED,
        WHITELIST_FFA,
        PUBLIC,
        END
    }

    enum State {
        ACTIVE,
        PAUSED,
        REFUNDED,
        CANCELLED,
        ENDED
    }

}