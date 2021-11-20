//SPDX-License-Identifier: Unlicense
pragma solidity 0.7.0;

import "./interfaces/IBank.sol";
import "./interfaces/IPriceOracle.sol";

contract Bank is IBank {
    
    address public hak_token;
    address public eth_token;
    address public price_oracle;
    address public bank;
    //uint256 public collateral;
    
    mapping (address => mapping (address => Account)) acc;
    mapping (address => uint256) borrowed; 
    mapping (address => uint256) owedInterest; 


    constructor (address price_oracle_addr, address hak_token_addr) {
        bank=msg.sender;
        price_oracle = price_oracle_addr;
        hak_token = hak_token_addr;
        eth_token = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    }
    
    function valid_token(address token) internal view returns (bool) {
        return token == eth_token || token == hak_token;
    }
    
    function calc_interest(uint256 last_block_number, uint256 cur_block_number, uint256 percent_interest) internal pure returns (uint256) {
        uint256 interest_rate = (cur_block_number - last_block_number) * percent_interest;
        uint256 interest = account.deposit * interest_rate / 10000;
        return interest;
    }

    function deposit(address token, uint256 amount)
        payable
        external
        override
        returns (bool) {
            if (amount <= 0)
                revert("Amount should be  > 0");
            if (!valid_token(token))
                revert("token not supported");
        
            address sender = msg.sender;
            // kind of not sure about this
            if (acc[sender][token].lastInterestBlock == 0)
                // set the initial interest block number
                acc[sender][token].lastInterestBlock = block.number;
        
            // deposit
            acc[sender][token].deposit += amount;
            emit Deposit(sender, token, amount);
        
            return true;
        }

    function withdraw(address token, uint256 amount)
        external
        override
        returns (uint256) {
            if (amount < 0)
                revert("Amount should be  >= 0");
            if (!valid_token(token))
                revert("token not supported");
        
            address sender = msg.sender;

            if (token==hak_token) 
                require(amount <= acc[sender][token].deposit, "You don't have enough deposits");
            else
                require(amount <= acc[sender][token].deposit, "You don't have enough deposits");
            
            uint256 cur_block_number = block.number;
            // calculate interest
            acc[sender][token].interest += calc_interest(acc[sender][token].lastInterestBlock, cur_block_number, 3);
            acc[sender][token].lastInterestBlock = cur_block_number;

            if (amount == 0)
                amount = acc[sender][token].deposit;
            
            acc[sender][token].deposit -= amount;
            emit Withdraw(msg.sender, token, amount);
            
            uint256 return_amount = amount + acc[sender][token].interest;
            acc[sender][token].interest = 0;
            
            return return_amount;
        }

    function borrow(address token, uint256 amount)
        external
        override
        returns (uint256) {}

    function repay(address token, uint256 amount)
        payable
        external
        override
        returns (uint256) {}

    function liquidate(address token, address account)
        payable
        external
        override
        returns (bool) {}

    function getCollateralRatio(address token, address account)
        view
        public
        override
        returns (uint256) {
            require(token == hak_token, "Only HAK token is accepted.");

            if(borrowed[account]==0){
                return type(uint256).max;
            }

            // TODO: convert ETH to HAK with price oracle !!!
            uint256 collateral = (acc[account][token].deposit + acc[account][token].interest) * 10000 / (borrowed[account] + 
                owedInterest[account]);
            return collateral;
        }

    function getBalance(address token)
        view
        public
        override
        returns (uint256) {
            return acc[msg.sender][token].deposit;
        }
}
