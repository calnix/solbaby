# Modes
Launchpad allows for 3 modes:
- Public 
- Whitelist
- Whitelist then Public

Whitelist mode essentially provides a VIP experience for stakers of some specified token - it does not have to be the launchpad token.
The idea is for preferential treatment. The allocation each whitelisted address received can be defined via `whitelistAllocationPerUnitStaked`, subject to the minimum requirement of  `whitelistMinRequiredTokens`. 

Example: `whitelistMinRequiredTokens` = 100 & `whitelistAllocationPerUnitStaked` = 2
- 100 stkTokens are required to be qualified  
- user has 200 stkTokens
- user's allocation: 200 * 2  = 400 ICO Tokens 

In Whitelist mode, the following would happen:
- Whitelist guarantee round for half the duration
- Whitelist FFA round for the remaining half of the duration
- In FFA round, all the available whitelisted users are able to buy up additional allocation beyond their wallet limits.

Essentially, FFA round serves to allow whitelisted users to clear up all of the guaranteed round allocation. 
If needed, buy limits can be set on the FFA round to avoid excessive whaling.
 
# Raise Structure
- For each mode, unique start and end times can be specified. For example, having a 3 day whitelist mode, following by a 1 day public mode.
- Allocation can be uniquely defined for each mode: e.g., 70% to whitelist and 30% to public.
- Wallet min/max buy limits can be set for each round. (whitelisted-guaranteed, whitelisted-FFA, public)

# Allocation Pricing
- Differentiated pricing is possible, between whitelisted and public rounds
- I.e. Whitelisted prices could be 20% cheaper compared to public round 

# Vesting
- Vesting allows for 2 primary modes which is flexible enough to cater to all vesting schedules
- Linear: continuous drip method
- Dynamic: sequence of interval unlocks and their percentages

Essentially, as a safety feature and add-value to users, vesting is applied both ways. Fund raisers can only collect raised funds as per the token unlock schedule. This is to protect users against projects that raise and slow rug, allow for refunds, loss of confidence, etc.

# *_TO-DO_*
           
Current state is at fixing refunds
- consider half redeemed state

# Post-raise Tracking
     - track each purchase in each round w/ mapping
     - to allow for refunds
     - to allow for vested calims
  
## Generic outline
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


# Additional features
- lottery
- build secondary market to trade illiquid tokens