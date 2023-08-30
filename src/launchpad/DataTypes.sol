// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.19;


library DataTypes {

    struct fundingInfo {        
        address asset;     // ICO token
        bool raiseInEther; // can remove - potentially
        address currency;  // raise currency, if not raising in ether
        uint256 softCap;   // Unit in raise currency
        uint256 hardCap;   // Unit in raise currency
        uint256 totalAssetAllocation;        // Total tokens for sales
        uint256 assetDecimals;      // precision
        uint256 raiseStart;
        uint256 raiseEnd;   

        address stkTokenAddress;    // stkToken - for pledgers
        uint256 feePercent;         // platform fee In 1e18
    }

    struct raiseStructure {
        RaiseMode raiseMode;    //uint8

        // Pledge mode
        uint256 pledgeStart;
        uint256 pledgeFFAStart;
        uint256 pledgeEnd;
        
        uint256 pledgeTotalAllocation;
        uint256 pledgeMinRequiredTokens;
        uint256 pledgeAllocationPerStaked;  // calculated off-chain

        uint256 pledgeFFAMinBuyLimit;       // if 0 no limits
        uint256 pledgeFFAMaxBuyLimit;       // if 0 no limits
        
        // Public mode 
        uint256 publicStart; 
        uint256 publicEnd;   
        uint256 publicTotalAllocation;
        // per wallet limits: Unit in currency
        uint256 publicMinBuyLimit;  
        uint256 publicMaxBuyLimit;  
    }

    // live tracking
    struct raiseProgress {
        
        // pledge mode    
        uint256 allocationSoldInPledge;
        uint256 capitalRaisedInPledge;

        // public mode
        uint256 allocationSoldInPublic;
        uint256 capitalRaisedInPublic;
        
        // total
        uint256 allocationSoldInTotal;  // ico tokens sold
        uint256 capitalRaisedInTotal;   // in raise cccy
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
        PLEDGERS_THEN_PUBLIC,    // 0
        PLEDGERS_ONLY,         // 1
        PUBLIC_ONLY            // 2
    }

    // Period according to timeline
    enum Period {
        None,
        Setup,
        Pledge,
        PledgeFFA,
        Public,
        End
    }

    enum State {
        ACTIVE,
        PAUSED,
        REFUNDED,
        CANCELLED,
        ENDED
    }

}