// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./Ownable.sol";
import "./SafeMath.sol";

/**
* @notice Stakeable is a contract who is ment to be inherited by other contract that wants Staking capabilities
*/
contract Stakeable is Ownable{
    // we don't want to have any security issues
    using SafeMath for uint256;

    /**
    * @notice Constructor since this contract is not ment to be used without inheritance
    * push once to stakeholders for it to work proplerly
     */
    constructor() {
        // This push is needed so we avoid index 0 causing bug of index-1
        stakeholders.push();

        // populate rewards
        _rewards.push(uint(200)); // 2.00% per month
        _rewards.push(uint(300)); // 3.00% per month
        _rewards.push(uint(500)); // 5.00% per month
        _rewards.push(uint(700)); // 7.00% per month
        _rewards.push(uint(900)); // 8.00%s per month

        // populate periods with monts
        _periods.push(uint(1));
        _periods.push(uint(3));
        _periods.push(uint(6));
        _periods.push(uint(12));
    }
    /**
     * @notice
     * A stake struct is used to represent the way we store stakes, 
     * A Stake will contain the users address, the amount staked and a timestamp, 
     * Since which is when the stake was made
     */
    struct Stake{
        address user;
        uint256 amount;
        uint256 since;
        uint8 period;    // this represent the stake interval 
                        // values 0 - 1 month, 1 - 3 months, 2 - 6 months, 3 - 12 months
        // This claimable field is new and used to tell how big of a reward is currently available
        uint256 claimable;
    }
    /**
    * @notice Stakeholder is a staker that has active stakes
     */
    struct Stakeholder{
        address user;
        Stake[] address_stakes;
        
    }
    
    /*
    * StakingSummary is a struct that is used to contain all stakes performed by a certain account
    */ 
    struct StakingSummary{
        uint256 total_amount;
        Stake[] stakes;
    }

    uint[] private _rewards;
    uint[] private _periods;

    /**
    * @notice 
    *   This is a array where we store all Stakes that are performed on the Contract
    *   The stakes for each address are stored at a certain index, the index can be found using the stakes mapping
    */
    Stakeholder[] internal stakeholders;
    /**
    * @notice 
    * stakes is used to keep track of the INDEX for the stakers in the stakes array
     */
    mapping(address => uint256) internal stakes;
    /**
    * @notice Staked event is triggered whenever a user stakes tokens, address is indexed to make it filterable
     */
    event Staked(address indexed user, uint256 amount, uint256 index, uint256 timestamp);

    /**
    * @notice getReward will get the reward value for a specific period
     */
    function getReward(uint8 index) public view returns (uint) {
        return _rewards[index];
    }

    /**
    * @notice setReward will set a specific value for index
     */
    function setReward(uint8 index, uint value) external onlyOwner{
        _rewards[index] = value;
    }

    /**
    * @notice getRewards will get the reward value for a specific period
     */
    function getRewards() public view returns (uint[] memory) {
        return _rewards;
    }

    /**
    * @notice getPeriod will get the period in months for a specific index
     */
    function getPeriod(uint8 index) public view returns (uint) {
        return _periods[index];
    }

    /**
    * @notice setPeriod will get the period in months for a specific index
     */
    function setPeriod(uint8 index, uint value) external onlyOwner{
        _periods[index] = value;
    }

    /**
    * @notice getPeriods willreturn all periods
     */
    function getPeriods() public view returns (uint[] memory) {
        return _periods;
    }

    /**
    * @notice _addStakeholder takes care of adding a stakeholder to the stakeholders array
     */
    function _addStakeholder(address staker) internal returns (uint256){
        // Push a empty item to the Array to make space for our new stakeholder
        stakeholders.push();
        // Calculate the index of the last item in the array by Len-1
        uint256 userIndex = stakeholders.length - 1;
        // Assign the address to the new index
        stakeholders[userIndex].user = staker;
        // Add index to the stakeHolders
        stakes[staker] = userIndex;
        return userIndex; 
    }

    /**
    * @notice
    * _Stake is used to make a stake for an sender. It will remove the amount staked from the stakers account and place those tokens inside a stake container
    * StakeID 
    */
    function _stake(uint256 _amount, uint8 _period) internal{
        // Simple check so that user does not stake 0 
        require(_amount > 0, "Cannot stake nothing");
        
        // Mappings in solidity creates all values, but empty, so we can just check the address
        uint256 index = stakes[msg.sender];
        
        // block.timestamp = timestamp of the current block in seconds since the epoch
        uint256 timestamp = block.timestamp;
        
        // See if the staker already has a staked index or if its the first time
        if(index == 0){
            // This stakeholder stakes for the first time
            // We need to add him to the stakeHolders and also map it into the Index of the stakes
            // The index returned will be the index of the stakeholder in the stakeholders array
            index = _addStakeholder(msg.sender);
        }

        // Use the index to push a new Stake
        // push a newly created Stake with the current block timestamp.
        stakeholders[index].address_stakes.push(Stake(msg.sender, _amount, timestamp, _period, 0));
        // Emit an event that the stake has occured
        emit Staked(msg.sender, _amount, index,timestamp);
    }

    /**
      * @notice
      * calculateStakeReward is used to calculate how much a user should be rewarded for their stakes
      * for the duration of the stake
     */
    function calculateStakeReward(Stake memory _current_stake) internal view returns(uint256){
        // first we check if we have the right to withdraw the stake by period
        
        uint8 periodIndex = _current_stake.period;
        uint reward = getReward(periodIndex);
        uint period = getPeriod(periodIndex);

        require (period>0, "We cannot stake for a 0 period");
        require (reward>0, "We cannot stake for 0 reward");

        uint256 divStake = _current_stake.amount.div(100);
        uint256 divReward = reward.div(100);

        uint256 stakeReward = divStake.mul(divReward).mul(period);

        require (stakeReward>0, "The reward is 0 (not ok)");

        return stakeReward;
    }

    /**
     * @notice
     * withdrawStake takes in an amount and a index of the stake and will remove tokens from that stake
     * Notice index of the stake is the users stake counter, starting at 0 for the first stake
     * Will return the amount to MINT onto the acount
     * Will also calculateStakeReward and reset timer
    */
    function _withdrawStake(uint256 amount, uint256 index) internal returns(uint256){
        // Grab user_index which is the index to use to grab the Stake[]
        uint256 user_index = stakes[msg.sender];

        Stake memory current_stake = stakeholders[user_index].address_stakes[index];
        require(current_stake.amount >= amount, "Staking: Cannot withdraw more than you have staked");
        // check to see if the stake is locked
        uint stakeAge = (block.timestamp - current_stake.since)/(3600*24*30); // number of months
        uint period = getPeriod(current_stake.period);
        require (stakeAge >= period, "Stake is locked for the initial defined period");

        // Calculate available Reward first before we start modifying data
        uint256 reward = calculateStakeReward(current_stake);
        
        // Remove by subtracting the money unstaked 
        current_stake.amount = current_stake.amount - amount;
        
        // If stake is empty, 0, then remove it from the array of stakes
        if (current_stake.amount == 0){
            delete stakeholders[user_index].address_stakes[index];
        } else {
            // If not empty then replace the value of it
            stakeholders[user_index].address_stakes[index].amount = current_stake.amount;
            // Reset timer of stake
            stakeholders[user_index].address_stakes[index].since = block.timestamp;    
        }

        return amount+reward;
    }

     /**
     * @notice
     * hasStake is used to check if a account has stakes and the total amount along with all the seperate stakes
     */
    function hasStake(address _staker) public view returns(StakingSummary memory){
        // totalStakeAmount is used to count total staked amount of the address
        uint256 totalStakeAmount; 
        // Keep a summary in memory since we need to calculate this
        StakingSummary memory summary = StakingSummary(0, stakeholders[stakes[_staker]].address_stakes);
        // Itterate all stakes and grab amount of stakes
        for (uint256 s = 0; s < summary.stakes.length; s += 1){
           uint256 availableReward = calculateStakeReward(summary.stakes[s]);
           summary.stakes[s].claimable = availableReward;
           totalStakeAmount = totalStakeAmount+summary.stakes[s].amount;
        }
        // Assign calculate amount to summary
        summary.total_amount = totalStakeAmount;
        return summary;
    }

}