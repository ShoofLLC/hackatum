// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.4;

contract Bank {
    
    address public bank;
    
    mapping (address => uint) public balances;

    // Events allow clients to react to specific
    // contract changes you declare
    event Sent(address from, address to, uint amount);

    // Constructor code is only run when the contract
    // is created
    constructor() {
        bank = msg.sender;
    }

    // Sends an amount of newly created coins to an address
    // Can only be called by the contract creator
    function withdraw(uint amount) public {
        require(msg.sender != bank);
        balances[bank] -= amount;
        balances[msg.sender] += amount;
    }

    // Errors allow you to provide information about
    // why an operation failed. They are returned
    // to the caller of the function.
    error InsufficientBalance(uint requested, uint available);

    // Sends an amount of existing coins
    // from any caller to an address
    function withdraw(uint amount) public {
        if (amount > balances[bank])
            revert InsufficientBalance({
                requested: amount,
                available: balances[bank]
            });

        balances[bank] -= amount;
        balances[msg.sender] += amount;
        
        emit Sent(msg.sender, receiver, amount);
    }
}
