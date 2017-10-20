/**
    @title ERC20 token implementation  20/10/17 19:00
    @author ND
*/

pragma solidity ^0.4.16;

import './IERC20.sol';

contract ERC20 is IERC20 {
    string public name = '';            
    string public symbol = '';
    uint8 public decimals = 0;
    uint256 public _totalSupply = 0;
    mapping (address => uint256) public balances;
    mapping (address => mapping (address => uint256)) public allowance;

    modifier validAddress(address _address){
        require(_address != address(0));
        _;
    }

    /**
    @dev ERC20 Constructor
    @param _name    Token name
    @param _symbol  Token symbol
    @param _decimals    Number of decimal places
    
    */
    function ERC20(string _name, string _symbol, uint8 _decimals) public {
        require(bytes(_name).length > 0
            && bytes(_symbol).length > 0);

        name = _name;
        symbol = _symbol;
        decimals = _decimals;
    
    }

    /**
    @dev totalSupply
    @dev Returns the total token supply.
    @return uint256
    */
    function totalSupply() public constant returns (uint256) {
        return(_totalSupply);
    }   

    /**
    @dev balanceOf
    @dev Returns the account balance of another account with address _owner
    @param _owner address
    @return balance uint256
    */
    function balanceOf(address _owner) public constant returns (uint256) {
        return(balances[_owner]);
    }
    
    /**
    @dev transfer
    @dev Transfers _value amount of tokens to address _to, and MUST fire the Transfer event.
    @param _value uint256
    @param _to address
    @return success bool
    */
    function transfer(address _to, uint256 _value) public validAddress(_to) returns (bool) {
        //require(_to != address(0));
        //require that sender has enough tokens on his account, _value is not zero
        //and adding does not lead to an overfolw
        require(balances[msg.sender] >= _value
            && balances[_to] + _value > balances[_to]);
        
        balances[msg.sender] -= _value;
        balances[_to] += _value;
        Transfer(msg.sender, _to, _value);
        return true;  
    }

    /**
    @dev transferFrom Transfers _value amount of tokens from address _from to 
    @dev address _to, and MUST fire the Transfer event 
    @param _from address
    @param _to address
    @param _value uint256
    @return success bool
    */
    function transferFrom(address _from, address _to, uint256 _value) validAddress(_to) public returns (bool success) {
        //require(_to != address(0));
        //require that sender has enough tokens on his account, sender is authorised
        //to send tokens, _value is not zero and adding does not lead to an overfolw
        require(balances[_from] >= _value
            && allowance[_from][msg.sender] >= _value
            && balances[_to] + _value > balances[_to]);
            
        balances[_to] += _value;
        balances[_from] -= _value;
        allowance[_from][msg.sender] -= _value; //can it owerflow here?
        Transfer(_from, _to, _value);
        return true;
    }

    /**
    @dev approve
    @dev Allows _spender to withdraw from your account multiple times,
    @dev up to the _value amount. If this function is called again it overwrites
    @dev the current allowance with _value 
    @param _spender address
    @param _value uint256
    @return bool true/false flag of success
    */  
    //Unresolved security risk
    // NOTE: To prevent attack vectors like the one described here and discussed here, clients SHOULD make sure to create user interfaces in such a way that they set the allowance first to 0 before setting it to another value for the same spender. THOUGH The contract itself shouldn't enforce it, to allow backwards compatilibilty with contracts deployed before
    //https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
    //
    function approve(address _spender, uint256 _value) public returns (bool){
        allowance[msg.sender][_spender] = _value;
        Approval(msg.sender, _spender, _value);
        return true;   
    }
    
    
    /**
    @dev allowance
    @dev Returns the amount which _spender is still allowed to withdraw from _owner   
    @param _owner address
    @param _spender address
    @return remaining uint256
    */
    function allowance(address _owner, address _spender) public constant returns (uint256 remaining){
        return allowance[_owner][_spender];
    }
    
    
    /**
    @dev Transfer
    @dev MUST trigger when tokens are transferred, including zero value transfers.
    @param _from address indexed
    @param _to address indexed
    @param _value uint256
    */
    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    
    
    /**
    @dev Approval
    @dev MUST trigger on any successful call to approve(address _spender, uint256 _value)
    @param _owner address indexed
    @param _spender address indexed
    @param _value uint256
    */
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);
}