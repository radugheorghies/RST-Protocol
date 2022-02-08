// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "./Ownable.sol";
import "./Stakeable.sol";
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

contract Clapart is Ownable, Stakeable {

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

    // SUBTOKEN
    // admins
    mapping(address=>bool) private admins; // only admins can add to whitelist

    // who can create subtokens
    mapping(address=>bool) whitelist; // only addresses validated here can create subtokens

    // subtoken
    mapping(string=>bool) subtokens; // we defining the token name here only to check if token exist

    // who defined the subtokens
    mapping(address=>string[]) tokenowners; // a whitelisted address can have multiple tokens

    // orderbook for main token
    mapping(string => mapping(uint256=>uint256)) mainTokenOrderbook; // token -> value -> volume. If volume is 0 the position will be replaced

    // userOrders
    mapping(address => mapping(string => mapping(uint256=>uint256))) userOrders; // user -> subtoken -> price -> volume

    // orderHistory
    mapping(address => mapping(string => mapping(uint256=>uint256))) orderHistory; // user -> subtoken -> price -> volume

    // userBalance
    mapping(address => mapping(string => uint256)) subtokenBalances; // user -> subtoken -> volume
    // SUBTOKEN

    // LOCKABLE
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
    // LOCKABLE

    // we don't want to have any security issues
    using SafeMath for uint256;


// events
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed tokenOwner, address indexed spender, uint tokens);

    // LOCKABLE
    event LokedSuccesfull(address tokenContract, uint256 amount, uint period);
    event UnlokedSuccesfull(address tokenContract, uint256 amount, uint period);
    // LOCKABLE

// modifiers
    /**
    * Modifier
    * We create our own function modifier called onlyArtist, it will Require the current owner to be 
    * the same as msg.sender
     */
    modifier onlyArtist() {
        require(whitelist[msg.sender], "Ownable: only artist can call this function");
        _;
    }

// implementation
    constructor (uint256 total) {
        totalSupply_          = total;
        balances[msg.sender]  = totalSupply_;
        decimals_             = 18;
        symbol_               = "CLPX"; // we need to decide this
        name_                 = "Clap Art Token";
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

    // SUBTOKEN
    // create a new admin
    function createAdmin(address adminAddress) external onlyOwner {
        admins[adminAddress] = true;
    }

    // create a new admin
    function deleteAdmin(address adminAddress) external onlyOwner {
        admins[adminAddress] = false;
    }

    // add to white list
    function addToWhiteList(address artistAddress) external {
        require(admins[msg.sender], "Only admins can add to whitelist");
        whitelist[artistAddress] = true;
    }

    // delete from white list
    function deleteFromWhiteList(address artistAddress) external {
        require(admins[msg.sender], "Only admins can add to whitelist");
        whitelist[artistAddress] = false;
    }

    // create subtoken
    function createSubtoken(string calldata name) external onlyArtist {
        subtokens[name] = true;
        tokenowners[msg.sender].push(name);
    }

    // create order
    function createOrder(string calldata subtoken, uint256 price, uint256 volume) external {
        require(subtokenBalances[msg.sender][subtoken]>=volume, "balance to low, you don't have this amount of tokens");
        mainTokenOrderbook[subtoken][price].add(volume);
        userOrders[msg.sender][subtoken][price] = volume;
        subtokenBalances[msg.sender][subtoken].sub(volume);
        mainTokenOrderbook[subtoken][price].add(volume);
    }

    // cancel order
    function cancelOrder(string calldata subtoken, uint256 price, uint256 volume) external {
        require(userOrders[msg.sender][subtoken][price]>0, "This order is invalid");
        require(userOrders[msg.sender][subtoken][price]>=volume, "This order is invalid");
        subtokenBalances[msg.sender][subtoken].add(volume);
        userOrders[msg.sender][subtoken][price].sub(volume);
        mainTokenOrderbook[subtoken][price].sub(volume);
    }

    // buy order
    function buy(string calldata subtoken, uint256 price, uint256 volume) external {
        require(mainTokenOrderbook[subtoken][price]>volume, "You cannot buy that much.");
        require(balances[msg.sender]>price*volume, "You don't have enougth tokens");
        mainTokenOrderbook[subtoken][price].sub(volume);
        balances[msg.sender].sub(price*volume);
        subtokenBalances[msg.sender][subtoken].add(volume);
    }

    // buy order - market makers
    function buyMarketMakers(address marketMaker, uint256 price, uint256 volume) external onlyOwner{
        balances[marketMaker].add(price*volume);
    }

    // sell order
    function sell(string calldata subtoken, uint256 price, uint256 volume) external {
        require(subtokenBalances[msg.sender][subtoken]>volume, "You cannot sell that much.");
        mainTokenOrderbook[subtoken][price].add(volume);
        balances[msg.sender].add(price*volume);
        subtokenBalances[msg.sender][subtoken].sub(volume);
    }

    // sell order - market makers
    function sellMarketMakers(address marketMaker, uint256 price, uint256 volume) external onlyOwner{
        balances[marketMaker].add(price*volume);
    }
    // SUBTOKEN

    // LOCKABLE
        // user can lock founds
    function LockFounds(uint256 amount, uint period) public{
        require(balances[msg.sender]>amount, "You cannot lock more than you have");
        balances[msg.sender].sub(amount);
        lockedBalance[msg.sender].add(amount);
        userLocks[msg.sender].Push(Lock(amount, period, block.timestamp));
        emit LokedSuccesfull(msg.sender, amount, period);
    }

    // user cand unlock founds
    function UnlockFounds(uint index) public {
        Lock memory user_lock = userLocks[msg.sender].locks[index];
        require (user_lock.amount>0, "Nothing to unlock");

        // now checking the periods
        // check to see if the stake is locked
        uint stakeAge = (block.timestamp - user_lock.since)/(3600*24); // number of days
        uint period = user_lock.period * 30; // number of days for lock

        require (stakeAge >= period, "You can't unlock now.");

        balances[msg.sender].add(user_lock.amount);
        userLocks[msg.sender].locks[index] = 0;
        
        emit UnlokedSuccesfull(msg.sender, user_lock.amount, period);
    }

    // owner cand unlock founds for user
    function UnlockFoundsTo(address to, uint index) public onlyOwner{
        Lock memory user_lock = userLocks[to].locks[index];
        require (user_lock.amount>0, "Nothing to unlock");

        // now checking the periods
        // check to see if the stake is locked
        uint stakeAge = (block.timestamp - user_lock.since)/(3600*24); // number of days
        uint period = user_lock.period * 30; // number of days for lock

        require (stakeAge >= period, "You can't unlock now.");

        balances[to].add(user_lock.amount);
        userLocks[to].locks[index] = 0;
        
        emit UnlokedSuccesfull(to, user_lock.amount, period);
    }
    // LOCKABLE

}