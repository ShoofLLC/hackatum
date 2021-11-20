// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.4;

contract Bank {
    
    address public bank;
    uint public daily_withdrawal_limit;
    
    mapping (address => uint) balances;
    mapping (address => uint) withdrawn_today;
    mapping (address => uint) last_withdraw;

    event TransactionComplete(address to, uint amount);

    constructor(uint32 withdrawal_limit) {
        bank = msg.sender;
        daily_withdrawal_limit = withdrawal_limit;
    }

    error InsufficientBalance(uint requested, uint available);

    function withdraw(uint amount) public {
        bool reset = false;
        if (block.timestamp-last_withdraw[msg.sender] > 1 days){
            reset=true;
        }
        if (amount > balances[bank] || withdrawn_today[msg.sender]+amount>daily_withdrawal_limit)
            revert InsufficientBalance({
                requested: amount,
                available: balances[bank]
            });

        if(reset) withdrawn_today[msg.sender]=0;
        last_withdraw[msg.sender]=block.timestamp;
        withdrawn_today[msg.sender] += amount;
        balances[bank] -= amount;
        balances[msg.sender] += amount;
        
        emit TransactionComplete(msg.sender, amount);
    }
    
    
    function check_balance() view public returns (uint){
        return balances[msg.sender];
    }
    
    function deposit(uint amount) public {
        if (amount > balances[msg.sender])
            revert InsufficientBalance({
                requested: amount,
                available: balances[msg.sender]
            });

        balances[bank] += amount;
        balances[msg.sender] -= amount;
        
        emit TransactionComplete(msg.sender, amount);
    }
}
