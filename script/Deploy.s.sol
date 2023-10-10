// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import "../src/launchpad/Raise.sol";


contract DeployAll is Script {

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        // deploy Raise
        Raise raise = new Raise();
        
        //
        vm.stopBroadcast();
    }
}

// forge script script/Deploy.s.sol:DeployAll --rpc-url "https://ethereum-goerli.publicnode.com" --broadcast --verify -vvvv --legacy