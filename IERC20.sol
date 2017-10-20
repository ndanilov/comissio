/**
    @title ERC20 token interface  20/10/17 12:00
    @author ND
*/

pragma solidity ^0.4.16;

contract IERC20{
    /**
    @dev totalSupply interface
    @dev Returns the total token supply.
    @return uint256
    */
    function totalSupply() public constant returns (uint256);
    
    
    /**
    @dev balanceOf interface
    @dev Returns the account balance of another account with address _owner
    @param _owner address
    @return uint256
    */
    function balanceOf(address _owner) public constant returns (uint256);
    
    
    /**
    @dev transfer interface
    @dev Transfers _value amount of tokens to address _to, and MUST fire the Transfer event.
    @param _value uint256
    @param _to address
    @return bool
    */
    function transfer(address _to, uint256 _value) public returns (bool);
    
    
    /**
    @dev transferFrom interface
    @dev Transfers _value amount of tokens from address _from to 
    @dev address _to, and MUST fire the Transfer event 
    @param _from address
    @param _to address
    @param _value uint256
    @return bool
    */
    function transferFrom(address _from, address _to, uint256 _value) public returns (bool);
   
    
    /**
    @dev approve interface
    @dev Allows _spender to withdraw from your account multiple times,
    @dev up to the _value amount. If this function is called again it overwrites
    @dev the current allowance with _value 
    @param _spender address
    @param _value uint256
    @return bool
    */  
    function approve(address _spender, uint256 _value) public returns (bool);
   
   
    /**
    @dev allowance interface
    @dev Returns the amount which _spender is still allowed to withdraw from _owner   
    @param _owner address
    @param _spender address
    @return  uint256
    */
    function allowance(address _owner, address _spender) public constant returns (uint256);
    
    
    /**
    @dev Transfer interface
    @dev MUST trigger when tokens are transferred, including zero value transfers.
    @param _from address indexed
    @param _to address indexed
    @param _value uint256
    */
    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    
    
    /**
    @dev Approval interface
    @dev MUST trigger on any successful call to approve(address _spender, uint256 _value)
    @param _owner address indexed
    @param _spender address indexed
    @param _value uint256
    */
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);
}


