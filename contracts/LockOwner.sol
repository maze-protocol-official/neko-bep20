// SPDX-License-Identifier: agpl-3.0
pragma solidity ^0.8.0;

import { NEKOToken } from './NEKOToken.sol';

contract LockOwner {
    
    uint32 public constant LOCK_PERIOD = 24 hours;
    
    uint public blockTimestampLast;
    
    NEKOToken public neko;
    
    modifier onlyOwner() {
        require(msg.sender == neko.owner(), "Caller is not the owner");
        _;
    }
    
    constructor(address _neko) {
        require(_neko != address(0), "Invalid address");
        neko = NEKOToken(_neko);
    }
    
    function checkLock() external view returns (bool) {
        return (block.timestamp - blockTimestampLast) >= LOCK_PERIOD ? true : false;
    }
    
    function setLockTime() public onlyOwner {
        blockTimestampLast = block.timestamp;
    }
}