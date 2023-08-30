// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.19;


interface FundingFactory {

    function setStakingToken() external view returns {address}

    function getStakingToken() external view returns {address}
}