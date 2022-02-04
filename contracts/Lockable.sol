// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "./Ownable.sol";

contract Lockable is Ownable{

    struct Lock {
        uint256 amount; // locked amount
        uint    period; // this represent the lock interval - values 0 - 1 month, 1 - 3 months, 2 - 6 months, 3 - 12 months
        uint256 since;  // locking date
    }

    struct Locks {
        Lock[] locks;
    }

    // balances of clappers for the main coin
    mapping(address => uint256) lockedBalance;

    // userLocks all locks for a clappers
    mapping(address => Locks) userLocks;

    // events
    event LokedSuccesfull(address tokenContract, uint256 amount, uint period);
    event UnlokedSuccesfull(address tokenContract, uint256 amount, uint period);


    // implementation

    // user can lock founds
    function LockFounds(uint256 amount, uint period) public{
        require(balance[msg.sender]>amount, "You cannot lock more than you have");
        balance[msg.sender].sub(amount);
        lockedBalance[msg.sender].add(amount);
        userLocks[msg.sender].Push(Lock(amount, period, block.timestamp));
        emit LokedSuccesfull(msg.sender, amount, period);
    }

    // user cand unlock founds
    function UnlockFounds(uint index) public {
        Lock user_lock = userLocks[msg.sender].locks[index];
        require (user_lock.amount>0, "Nothing to unlock");

        // now checking the periods
        // check to see if the stake is locked
        uint stakeAge = (block.timestamp - user_lock.since)/(3600*24); // number of days
        uint period = user_lock.period * 30; // number of days for lock

        require (stakeAge >= period, "You can't unlock now.");

        balance[msg.sender].add(user_lock.amount);
        userLocks[msg.sender].locks[index] = 0;
        
        emit LokedSuccesfull(msg.sender, user_lock.amount, period);
    }

    // owner cand unlock founds for user
    function UnlockFoundsTo(address to, uint index) public onlyOwner{
        Lock user_lock = userLocks[to].locks[index];
        require (user_lock.amount>0, "Nothing to unlock");

        // now checking the periods
        // check to see if the stake is locked
        uint stakeAge = (block.timestamp - user_lock.since)/(3600*24); // number of days
        uint period = user_lock.period * 30; // number of days for lock

        require (stakeAge >= period, "You can't unlock now.");

        balance[to].add(user_lock.amount);
        userLocks[to].locks[index] = 0;
        
        emit LokedSuccesfull(to, user_lock.amount, period);
    }

}