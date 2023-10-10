# Funding structure
    Modes: pledge then public, pledgersOnly, publicOnly
    
    Example:
     1) Pledge period: 0 - 0.5 | you get what you get
     - stakers can pledge capital to buy in advance, e.g. 3 days.
     - can pledge, cannot collect.
     - pledgers must meet min. stk Token holding.
     - pledge as per min/max buyAmounts.
     - min/max buyAmounts calc: tokenSaleQty / totalStkTokens(in cir) * userStkTokens

     2) Pledge period: 0.5 - 1 | you want more
     - if leftover, free for all mode for stkToken holders
     - no min. stk Token holding. as long you hold some, can.

     3) Public: | whatever happens, happens
     - if leftover from pledging, free for all for anyone

    Paramters: 
    - mode type
    - duration of pledge round, public round
    - mode buy limits (pledge & public)

    Calc:
    - call balanceOf(): userBalance > minRequiredBalance
    - alloc: tokenSaleQty / totalStkTokens(> minRequire) * userStkTokens
           ~ pledgeAllocationPerStaked * userStkTokens
    - admin needs to specify pledgeAllocationPerStaked: 
        for each unit of staked tokens, how much alloc?
    
     
# Participation structure
    To be a valid pledger: min stkTokens

     2) how much can they buy per round? 
        - tiers, tierReq, tierAlloc -> whitelist mode
        - minBuy, maxBuy for everyone -> public mode

        whitelisted users are token holders tt pledged capital in advance.
        can collect pledge tokens anytime after raise.
        

 # Recording
     - track each purchase in each round w/ mapping
     - to allow for refunds
     = to allow for vested calims

# Vesting & Lockup
     - VestingReleaseType

  

1. cache structs
2. get period & mode
3. validate buy against period limits
- given period/mode check if stkTokens needed and held
- check if buy is within limits
4. transfer tokens 



# Functions

- add invariant test function
- called after deployment to check global relations
whitelistStart < publicStart

- add fn to allow team to change their redemption wallet address
- this will justify the mapping


# Getter functions
- create getLinearDistribution
--> it will need to return more than releasePct