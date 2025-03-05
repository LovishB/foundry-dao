// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import {GovernToken} from "../src/GovernToken.sol";
import {MyGovernor} from "../src/MyGovernor.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

// This is a simple target contract that will be controlled by governance
contract Box {
    uint256 private value;
    address public owner;
    
    event ValueChanged(uint256 newValue);
    
    constructor() {
        owner = msg.sender;
    }
    
    function store(uint256 newValue) public {
        require(msg.sender == owner, "Box: not owner");
        value = newValue;
        emit ValueChanged(newValue);
    }
    
    function retrieve() public view returns (uint256) {
        return value;
    }
    
    function transferOwnership(address newOwner) public {
        require(msg.sender == owner, "Box: not owner");
        owner = newOwner;
    }
}