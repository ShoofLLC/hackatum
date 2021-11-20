// SPDX-License-Identifier: MIT
pragma solidity 0.7.0;

interface IBank {
    struct Account { // Note that token values have an 18 decimal precision
        uint256 deposit;           // accumulated deposits made into the account
        uint256 interest;          // accumulated interest
        uint256 lastInterestBlock; // block at which interest was last computed
    }
    // Event emitted when a user makes a deposit
    event Deposit(
        address indexed _from, // account of user who deposited
        address indexed token, // token that was deposited
        uint256 amount // amount of token that was deposited
    );
    // Event emitted when a user makes a withdrawal
    event Withdraw(
        address indexed _from, // account of user who withdrew funds
        address indexed token, // token that was withdrawn
        uint256 amount // amount of token that was withdrawn
    );
    // Event emitted when a user borrows funds
    event Borrow(
        address indexed _from, // account who borrowed the funds
        address indexed token, // token that was borrowed
        uint256 amount, // amount of token that was borrowed
        uint256 newCollateralRatio // collateral ratio for the account, after the borrow
    );
    // Event emitted when a user (partially) repays a loan
    event Repay(
        address indexed _from, // accout which repaid the loan
        address indexed token, // token that was borrowed and repaid
        uint256 remainingDebt // amount that still remains to be paid (including interest)
    );
    // Event emitted when a loan is liquidated
    event Liquidate(
        address indexed liquidator, // account which performs the liquidation
        address indexed accountLiquidated, // account which is liquidated
        address indexed collateralToken, // token which was used as collateral
                                         // for the loan (not the token borrowed)
        uint256 amountOfCollateral, // amount of collateral token which is sent to the liquidator
        uint256 amountSentBack // amount of borrowed token that is sent back to the
                               // liquidator in case the amount that the liquidator
                               // sent for liquidation was higher than the debt of the liquidated account
    );
    /**
     * The purpose of this function is to allow end-users to deposit a given 
     * token amount into their bank account.
     * @param token - the address of the token to deposit. If this address is
     *                set to 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE then 
     *                the token to deposit is ETH.
     * @param amount - the amount of the given token to deposit.
     * @return - true if the deposit was successful, otherwise revert.
     */
    function deposit(address token, uint256 amount) payable external returns (bool);

    /**
     * The purpose of this function is to allow end-users to withdraw a given 
     * token amount from their bank account. Upon withdrawal, the user must
     * automatically receive a 3% interest rate per 100 blocks on their deposit.
     * @param token - the address of the token to withdraw. If this address is
     *                set to 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE then 
     *                the token to withdraw is ETH.
     * @param amount - the amount of the given token to withdraw. If this param
     *                 is set to 0, then the maximum amount available in the 
     *                 caller's account should be withdrawn.
     * @return - the amount that was withdrawn plus interest upon success, 
     *           otherwise revert.
     */
    function withdraw(address token, uint256 amount) external returns (uint256);
      
    /**
     * The purpose of this function is to allow users to borrow funds by using their 
     * deposited funds as collateral. The minimum ratio of deposited funds over 
     * borrowed funds must not be less than 150%.
     * @param token - the address of the token to borrow. This address must be
     *                set to 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE, otherwise  
     *                the transaction must revert.
     * @param amount - the amount to borrow. If this amount is set to zero (0),
     *                 then the amount borrowed should be the maximum allowed, 
     *                 while respecting the collateral ratio of 150%.
     * @return - the current collateral ratio.
     */
    function borrow(address token, uint256 amount) external returns (uint256);
     
    /**
     * The purpose of this function is to allow users to repay their loans.
     * Loans can be repaid partially or entirely. When replaying a loan, an
     * interest payment is also required. The interest on a loan is equal to
     * 5% of the amount lent per 100 blocks. If the loan is repaid earlier,
     * or later then the interest should be proportional to the number of 
     * blocks that the amount was borrowed for.
     * @param token - the address of the token to repay. If this address is
     *                set to 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE then 
     *                the token is ETH.
     * @param amount - the amount to repay including the interest.
     * @return - the amount still left to pay for this loan, excluding interest.
     */
    function repay(address token, uint256 amount) payable external returns (uint256);
     
    /**
     * The purpose of this function is to allow so called keepers to collect bad
     * debt, that is in case the collateral ratio goes below 150% for any loan. 
     * @param token - the address of the token used as collateral for the loan. 
     * @param account - the account that took out the loan that is now undercollateralized.
     * @return - true if the liquidation was successful, otherwise revert.
     */
    function liquidate(address token, address account) payable external returns (bool);
 
    /**
     * The purpose of this function is to return the collateral ratio for any account.
     * The collateral ratio is computed as the value deposited divided by the value
     * borrowed. However, if no value is borrowed then the function should return 
     * uint256 MAX_INT = type(uint256).max
     * @param token - the address of the deposited token used a collateral for the loan. 
     * @param account - the account that took out the loan.
     * @return - the value of the collateral ratio with 2 percentage decimals, e.g. 1% = 100.
     *           If the account has no deposits for the given token then return zero (0).
     *           If the account has deposited token, but has not borrowed anything then 
     *           return MAX_INT.
     */
    function getCollateralRatio(address token, address account) view external returns (uint256);

    /**
     * The purpose of this function is to return the balance that the caller 
     * has in their own account for the given token (including interest).
     * @param token - the address of the token for which the balance is computed.
     * @return - the value of the caller's balance with interest, excluding debts.
     */
    function getBalance(address token) view external returns (uint256);
}


abstract contract Bank is IBank {
    address public hak_token;
    address public eth_token;
    address public price_oracle;
    address public bank;
    //uint256 public collateral;
    
    mapping (address => mapping (address => Account)) account;
    mapping (address => uint256) borrowed; 
    mapping (address => uint256) owedInterest; 

    //we need to have a mapping of accounts to collateral values
    // map Account to the hak 
    //mapping (address => uint256) collateral;
    mapping (Account => uint256) collateral;
    
    constructor (address price_oracle_addr, address hak_token_addr) {
        bank=msg.sender;
        price_oracle = price_oracle_addr;
        hak_token = hak_token_addr;
        eth_token = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    }
    
    function valid_token(address token) internal view returns (bool) {
        return token == eth_token || token == hak_token;
    }
    
    function calc_interest(uint256 lastInterestBlock uint256 interestof, Account memory acc, uint256 cur_block_number, unint256 percent_interest) internal pure returns (uint256) {
        uint256 interest_rate = (cur_block_number - lastInterestBlock) * percent_interest;
        uint256 interest = interestof * interest_rate / 10000;
        return interest;
    }
    
    function deposit(address token, uint256 amount) payable external override returns (bool) {
        require(amount > 0, revert("Amount should be > 0"));
        require(valid_token(token), revert("Invalid token."));
        
        Account memory acc = account[msg.sender][token];
        // kind of not sure about this
        if (acc.lastInterestBlock == 0)
            // set the initial interest block number
            acc.lastInterestBlock = block.number;
        
        // deposit
        acc.deposit += amount;
        emit Deposit(msg.sender, token, amount);
        
        return true;
    }
    
    function withdraw(address token, uint256 amount) external override returns (uint256) {
        
        require(valid_token(token), revert("Invalid token."));
        require(amount >= 0, "Amount should be >= 0");
        
        Account memory acc = account[msg.sender][token];

        if (token==hak_token) 
            require(amount <= acc.deposit + collateral[acc], "You don't have enough deposits");
        else
            require(amount <= acc.deposit, "You don't have enough deposits");
        
        uint256 cur_block_number = block.number;
        // calculate interest
        acc.interest += calc_interest(acc.deposit, cur_block_number,3);
        acc.lastInterestBlock = cur_block_number;

        if (amount == 0)
            amount = acc.deposit;
        
        acc.deposit -= amount;
        emit Withdraw(msg.sender, token, amount);
        
        uint256 return_amount = amount + acc.interest;
        acc.interest = 0;
        
        return return_amount;
    }
    
    // function borrow(address token, uint256 amount) external override returns (uint256) {
    //     require(valid_token(token));
        
        
        
    // }
    
    function getBalance(address token) view external override returns (uint256) {
        require(valid_token(token));
        
        return account[msg.sender][token].deposit;
    }

    function borrow(address token, uint256 amount) external override returns (uint256) 
    {
        require(amount>=0);
        require(token==eth_token);
        //make a requirement that the deposit in ETH is more than 150% of the collateral in HAK
        // require(amount*convert_var*1.5 < HAK)


        //acc[msg.sender][token].deposit;
        //the value of hak has to be at least 150% of the borrowed amount in ETH(?)
        //collateral[acc] = 

        borrowed[msg.sender] += amount;
        emit Borrow(msg.sender, token, amount, 0);
        
        return amount;
    }

    function repay(address token, uint256 _amount, Account memory acc, uint256 cur_block_number) payable external returns (uint256)
    {
        //is _amount the value that is due for the entire debt, or is it the value that is being paid back?

        // this mapping allows us to get the total amount due on a debt from a token 
        mapping (address => uint256) amount_due;

        //Account memory acc, uint256 cur_block_number, unint256 percent_interest) internal pure returns (uint256
        uint256 interest = calc_interest(token, cur_block_number, 5);
        uint256 new_amount = amount + interest;

        withdraw(token,_amount);
        deposit(token,_amount);

        
    }

    function liquidate(address token, address account) payable external returns (bool) 
    {
        //assuming that the condition of liquidation is checked outside the function - the assumption is made because there is no input variable for the collateral 
        // amount to repay = a
        repay();
        account.withdraw(token, 0);
        
        
        return true;

    }
    
    function getCollateralRatio(address token, address account) view external returns (uint256){
        require(token == hak_token, revert("Only HAK token is accepted."));

        Account memory acc = account[msg.sender][token];
        if(borrowed[msg.sender]==0){
            return type(uint256).max;
        }

        // TODO: convert ETH to HAK with price oracle !!!
        collateral = (acc.deposit + acc.interest) * 10000 / (borrowed[acc] + owedInterest[acc]);
        return collateral;
    }


    
}
    



//    // Event emitted when a user borrows funds
//    event Borrow(
//        address indexed _from, // account who borrowed the funds
//        address indexed token, // token that was borrowed
//        uint256 amount, // amount of token that was borrowed
//        uint256 newCollateralRatio // collateral ratio for the account, after the borrow
//    );
