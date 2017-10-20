/**
    @title Comiss.io token implementation alpha 20/10/17 19:00
    @author ND
*/

pragma solidity ^0.4.16;

import './ERC20.sol';

contract CMST is ERC20 {
    //!!!CHANGE TO ACTUAL VALUE IN      vvvvvvvvv    PRODUCTION VERSION!!!
    uint256 public constant MAX_TOKENS = 1000000;

    string private constant version = "0.02 alpha";         //Version of the token for reference
    
    uint  private creationTime = 0;                         //Token creation time for reference
    
    address private owner;                                  //Contract owning the token. He is special

    bool private mintingEnabled = false;                    //Minting is disabled
    bool private canEnableMinting = true;                   //But can be enabled
    
    mapping (address => bool) public frozen;                //Frozen tokens
    address private teamAddress = 0x0;                      //Address for team tokens; Needed for freeze control
    
    uint private teamUnfreezeTime;                          //Team unfreeze time
    bool private globalFreeze = true;                       //No one can transfer tokens
    bool private freezingEnabled = true;                    //No new freeze is possible when false
  
    //Freeze check
    modifier notFrozen(address account) {
        require(!globalFreeze
            && !(now < teamUnfreezeTime && frozen[account]));
        _;        
    }

    //Check if freezing is permitted
    modifier canFreeze {
        require(freezingEnabled);
        _;
    }

    //Minting permission and cap check
    modifier canMint(uint256 amount) {
        require(amount > 0
            && mintingEnabled
            && _totalSupply + amount <= MAX_TOKENS);
        _;
    }
    
    //Owner permission verification
    modifier onlyOwner {
        require(msg.sender == owner);
        _;        
    }

    /**@dev Token constructor
    */       
    function CMST() public ERC20("CMST alpha token", "CMSTa", 6) {
        owner = msg.sender;
        creationTime = now;
        mintingEnabled = true;
        _totalSupply = 0; //zero
    } 

    /**@dev changeOwner
    @param newOwner address
    */      
    function changeOwner(address newOwner) public onlyOwner validAddress(newOwner) {
        owner = newOwner;
    }
    
    /**@dev enableMinting
    */      
    function enableMinting() public onlyOwner {
        require(canEnableMinting);
        mintingEnabled = true;
    }
    
    /**@dev disableMinting
    */      
    function disableMinting() public onlyOwner {
        mintingEnabled = false;
    }
    
    /**@dev disableMintingForever
    */      
    function disableMintingForever() public onlyOwner {
        mintingEnabled = false;
        canEnableMinting = false;
    }
    
    /**@dev setTeamAddress
    @param newTeamAddress address
    */
    function setTeamAddress(address newTeamAddress) public onlyOwner {
        assert(teamAddress == 0x0); //only once
        teamAddress = newTeamAddress;
    }
         
    /**@dev setTeamUnfreezeTime(uint happyHour)
    @param happyHour    uint
    */
    function setTeamUnfreezeTime(uint happyHour) public onlyOwner {
        teamUnfreezeTime = happyHour;
    }

    /**@dev unfreezeForever
    @dev Disables freezing; team tokens remain frozen if lockup is still active
    @dev This can not be reversed
    */
    function unfreezeForever() public onlyOwner {
        freezingEnabled = false;
    }

    /**@dev freezeAll
    @dev disable all token transfers
    */
    function freezeAll() public onlyOwner canFreeze {
        globalFreeze = true;
    }
        
    /**@dev unfreezeAll
    @dev enable all token transfers; team tokens remain frozen if lockup is still active
    */
    function unfreezeAll() public onlyOwner canFreeze {
        globalFreeze = true;
    }
    
    /**@dev freeze
    @dev freezes account disabling all transfers from it
    @dev there is no individual unfreeze
    @dev only used for team tokens
    @param account address
    */
    function freeze(address account) public onlyOwner canFreeze {
        frozen[account] = true;    
    }

    /**@dev mint
    @dev Mints amount number of tokens for the receiver
    @dev Transfer event must be initiated in compliance with ERC20
    @param receiver address
    @param amount uint256
    */
    function mint(address receiver, uint256 amount) public onlyOwner canMint(amount) returns (bool){
        require(receiver != address(0));
        balances[receiver] += amount;
        _totalSupply += amount;
        Transfer(address(0x0), receiver, amount);
        return(true);
    }
        
   /**@dev ERC20 transfer overriding with freeze check
    @param _to  address
    @param _value   uint256
    @return bool
    */
    function transfer(address _to, uint256 _value) public notFrozen(msg.sender) returns (bool) {
        if(msg.sender == teamAddress)
            freeze(_to);                //keep team tokens frozen
        return(super.transfer(_to, _value));
    }
    
    /**
    @dev ERC20 transferFrom overriding with freeze check
    @param _from address
    @param _to address
    @param _value uint256
    @return  bool
    */
    function transferFrom(address _from, address _to, uint256 _value) public notFrozen(_from) returns (bool) {
        if(_from == teamAddress)
            freeze(_to);                //keep team tokens frozen
        return(super.transferFrom(_from, _to, _value));
    }

    /**@dev burn
    @dev Burns amount number of tokens belonging to the owner of the contract
    @dev Burnt tokens can not be reminted
    @dev Transfer event to zero address is fire
    @param amount uint256
    */
    function burn(uint256 amount) public onlyOwner returns (bool) {
        require(!mintingEnabled && !canEnableMinting    //Can not burn and remint
                && balances[owner] >= amount
                && balances[owner] - amount < balances[owner]);
        
        balances[owner] -= amount;
        _totalSupply -= amount;
        return(true);
    }
}