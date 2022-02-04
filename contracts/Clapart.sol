// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "./Ownable.sol";
import "./Stakeable.sol";
import "./Lockable.sol";
import "./SafeMath.sol";

/*
Clapart functions:
    - burn
    - mint
    - transfer
    - lock
    - unlock
    - stake
    - unstake
    - mint subtoken
    - burn subtoken
    - transfer subtoken
    - convert subtoken to subtoken
    - convert token to subtoken
    - convert subtoken to token

*/
contract Clapart is Ownable, Stakeable, Lockable {

// Types

// Global vars
    /**
    * @notice Our Tokens required variables that are needed to operate everything
    */

    uint256 private totalSupply_;
    uint8   private decimals_;
    string  private symbol_;
    string  private name_;

    // balances of clappers for the main coin
    mapping(address => uint256) balances;

    // allowance
    mapping(address => mapping (address => uint256)) allowed;

    // we don't want to have any security issues
    using SafeMath for uint256;


// events
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed tokenOwner, address indexed spender, uint tokens);

// modifiers


// implementation
    constructor (uint256 total) {
        totalSupply_          = total;
        balances[msg.sender]  = totalSupply_;
        decimals_             = 18;
        symbol_               = "CLPX"; // we need to decide this
        name_                 = "Clap Art";
    }

    // retuns the total supply
    function totalSupply() public view returns (uint256) {
        return totalSupply_;
    }

    // return the balance for a specific address
    function balanceOf(address tokenOwner) public view returns (uint256) {
        return balances[tokenOwner];
    }

    // standard transfer
    function transfer(address receiver, uint256 numTokens) public returns (bool) {
        require(numTokens <= balances[msg.sender]);
        balances[msg.sender] = balances[msg.sender].sub(numTokens);
        balances[receiver] = balances[receiver].add(numTokens);
        emit Transfer(msg.sender, receiver, numTokens);
        return true;
    }

    // approve a delegated transaction
    function approve(address delegate, uint256 numTokens) public returns (bool) {
        allowed[msg.sender][delegate] = numTokens;
        emit Approval(msg.sender, delegate, numTokens);
        return true;
    }

    // check the allowance
    function allowance(address owner, address delegate) public view returns (uint) {
        return allowed[owner][delegate];
    }

    // transfer from owner to buyer
    function transferFrom(address owner, address buyer, uint256 numTokens) public returns (bool) {
        require(numTokens <= balances[owner]);
        require(numTokens <= allowed[owner][msg.sender]);

        balances[owner] = balances[owner].sub(numTokens);
        allowed[owner][msg.sender] = allowed[owner][msg.sender].sub(numTokens);
        balances[buyer] = balances[buyer].add(numTokens);
        emit Transfer(owner, buyer, numTokens);
        return true;
    }

}