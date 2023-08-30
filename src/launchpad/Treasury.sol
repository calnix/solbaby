// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.19;

contract FeeVault {
/*    
    address public address1;
    address public address2;
    uint256 public constant RATIO = 30;

    event FeeSent(
        address indexed to,  
        uint amount
    );

    constructor(address _address1, address _address2) public {
        address1 = _address1;
        address2 = _address2;
    }

    /**
     * @dev Any BNB sent to this address will be transferred in ratio to the 2 addresses
     */
    /*receive() external payable {
        // send 30% to address 1
        uint256 amt1 = msg.value.mul(RATIO).div(100);
        (bool ok1, ) = address1.call{value: amt1}("");
        require(ok1, "Failed to send BNB to address 1");
        emit FeeSent(address1, amt1);

        // send remaining to address 2
        uint256 amt2 = msg.value.sub(amt1);
        (bool ok2, ) = address2.call{value: amt2}("");
        require(ok2, "Failed to send BNB to address 2");
        emit FeeSent(address2, amt2);
    }
    
*/
}