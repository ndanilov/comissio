/**
    @title Comiss.io token sales controller.  20/10/17 12:00
    @author ND

*/

pragma solidity ^0.4.16;

import './CMST.sol';

contract salesController {

    //!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    //DOUBLE CHECK ALL VALUES BEFORE DEPLOY !!!!!!!
    //vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv

    uint    private constant CROWDFUND_TOKENS = 700000;
    uint    private constant TEAM_TOKENS = 260000;
    uint    private constant RESERVE_TOKENS = 40000;

    uint256 private constant CAP_GAP = 400 ether;   //~100K usd. Crowdfunging will stop if minting attempt 
                                                    //will reach maximal value and buyer is paying less than this
    
    uint256 private constant TOKEN_BASE_PRICE = 240000000000000000 wei;//= 0.24 ether
    uint256 private constant PRESALE_MIN = 5 ether;
    uint256 private constant SALE_MIN = 3 ether;
    
    uint    private constant PRESALE_DURATION = 60 days;
    uint    private constant SALE_DURATION = 30 days;

    uint256 private constant PRESALE_MIN_TARGET = 4000 ether; 
    uint256 private constant SALE_MIN_TARGET = 10000 ether;     

    uint256 private constant MAX_PAYMENT_ETH = 100 ether;
  
    uint    private constant TEAM_LOCKUP = 180 days;
    
    //presale discount rule
    uint    private constant INITIAL_PRESALE_BONUS = 100; //percent
    uint    private constant PRESALE_BONUS_DAILY_DECREMENT = 1; //percent
    //sale volume discounts are hard coded in the calculateTokenAmountETH

    uint    private constant MIN_PROMO_BONUS = 1; //percent
    uint    private constant MAX_PROMO_BONUS = 100; //percent

    //Eight multi-signature accounts to store collected funds after presale and sale
    //Real addresses are hardcoded
    uint    private constant VAULTS_COUNT = 8;

    address[8] private theVault = [
          0x1,
          0x2,
          0x3,
          0x4,
          0x5,
          0x6,
          0x7,
          0x8
     ];

    //^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    //DOUBLE CHECK ALL VALUES BEFORE DEPLOY !!!!!!!
    //!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    
    /**
    @dev Promo codes and discounts
    @dev If someone redeems the promo code at the ICO website his future purchases will be rewarded with extra tokens
    @dev Some of the codes can be issued for the people in order to share them
    @dev Person sharing the code becomes the codeOwner and receives extra tokens when the person who have redeemed it makes a purchases
    @dev Codes can have limited lifespan
    */
    struct promoCode {
        uint    bonus;          //percent
        uint    expires;        //time; 0 = unlimited
        address codeOwner;      //codeOwner extra tokens from the CROWDFUND_TOKENS will be minted  
        uint    ownerBonus;     //codeOwner reward percent
    }
    
    mapping(string => promoCode) promoCodes;

    //promo codes redeemed by the buyers
    mapping(address => promoCode) redeemedCodes;

    //Sales stages
    enum    Stages {
        Idle,
        TeamMint,
        ReserveMint,
        PresaleReady,
        PresaleInProgress,
        PresaleFinished,
        SaleReady,
        SaleInProgress,
        SaleFinished,
        Success,           
        Pause,
        Refund,
        AnySale,            //technical value for code clarity
        AnySaleFinished    //technical value for code clarity 
        }
        
    Stages  private currentStage = Stages.Idle;    
    Stages  private stageBeforePause;
    uint    private creationTime;
    uint    private presaleStartTime;
    uint    private saleStartTime;

    uint256 private presaleEtherCollected = 0;
    uint256 private saleEtherCollected = 0;

    mapping (address => uint256) private etherBalances;
    
    address private owner = 0x0;
    
    modifier atStage(Stages _stage){
        require(currentStage == _stage
            || (_stage == Stages.AnySale && (currentStage == Stages.SaleInProgress || currentStage == Stages.PresaleInProgress))
            || (_stage == Stages.AnySaleFinished && (currentStage == Stages.SaleFinished || currentStage == Stages.PresaleFinished)));
        _;
    }
    
    modifier onlyOwner(){
        msg.sender == owner;
        _;
    }
    
    ////////    
    CMST    theToken;
    ///////
    
//Main sales flow

    /**
    @dev constructor
    @param _teamAddress address
    @param _reserveAddress address
    */
    function salesController(address _teamAddress, address _reserveAddress) public {
        owner = msg.sender;
        theToken = new CMST();       //Token created
        require(CROWDFUND_TOKENS + TEAM_TOKENS + RESERVE_TOKENS == theToken.MAX_TOKENS()); //Sanity check
        theToken.enableMinting();
        currentStage = Stages.TeamMint;
        mintTeamTokens(_teamAddress);
        currentStage = Stages.ReserveMint;
        mintReserveTokens(_reserveAddress);
        currentStage = Stages.PresaleReady;
    }    


    /**
    @dev mintTeamTokens
    @param _teamAddress address
    */
    function mintTeamTokens(address _teamAddress) internal onlyOwner atStage(Stages.TeamMint) { 
        theToken.setTeamAddress(_teamAddress);
        theToken.mint(_teamAddress, TEAM_TOKENS);
    }

    /**
    @dev mintReserveTokens
    @param _reserveAddress address
    */
    function mintReserveTokens(address _reserveAddress) internal onlyOwner atStage(Stages.ReserveMint) { 
        theToken.mint(_reserveAddress, RESERVE_TOKENS);
    }
        
    /**
    @dev presaleStart()
    @dev must be called from the controller UI         
    */
    function presaleStart() public onlyOwner atStage(Stages.PresaleReady) {
        presaleStartTime = now;
        theToken.enableMinting;
        currentStage = Stages.PresaleInProgress;        
    }
    
    /**
    @dev presaleEnd()
    @dev must be called from the controller UI
    @dev or can be called from the token purchase function when presale expires
    */
    function presaleEnd() public onlyOwner atStage(Stages.PresaleInProgress) {
        currentStage = Stages.PresaleFinished;        
        if(presaleEtherCollected >= PRESALE_MIN_TARGET){
            theToken.disableMinting();
            saveToVault();
        } else
            beginRefund();
    } 

    /**
    dev saleStart()
    @dev must be called from the controller UI
    */
    function saleStart() public onlyOwner atStage(Stages.SaleReady) {
        saleStartTime = now;    
        theToken.enableMinting;
        currentStage = Stages.SaleInProgress;  
    }

    /**
    @dev saleEnd()
    @dev must be called from the controller UI
    @dev or can be called from the token purchase function when presale expires
    */
    function saleEnd() public onlyOwner atStage(Stages.SaleInProgress) {
        currentStage = Stages.SaleFinished;
        if(presaleEtherCollected >= SALE_MIN_TARGET){
            theToken.disableMintingForever();
            theToken.setTeamUnfreezeTime(now + TEAM_LOCKUP);
            theToken.unfreezeForever;           //Team tokens are unaffected
            saveToVault();
            currentStage = Stages.Success;
        } else
            beginRefund();
    } 

    /**
    @dev saveToVault public onlyOwner 
    @dev transfer collected funds to multisig accounts
    */
    function saveToVault() public onlyOwner atStage(Stages.AnySaleFinished) {
        uint256 amountPerVault = this.balance/VAULTS_COUNT;

        for(uint i = 0; i < VAULTS_COUNT-1; i++ )
            theVault[i].transfer(amountPerVault);

        theVault[VAULTS_COUNT-1].transfer(this.balance);
    }

    /**
    @dev beginRefund
    @dev called automatically if crowdfunding objective is not met
    */
    function beginRefund() internal onlyOwner atStage(Stages.AnySaleFinished){
        currentStage = Stages.Refund;
        theToken.disableMintingForever();
        theToken.freezeAll();
    }

    /**
    @dev refund
    @dev must be called by the tokens buyer to get his tokens back
    */
    function refund() public atStage(Stages.Refund) returns(bool) {
        uint256 refundValue = etherBalances[msg.sender]; 
        require(refundValue > 0);
        etherBalances[msg.sender] = 0;
        msg.sender.transfer(refundValue);
        return(true);
    }

    /**
    @dev pause
    @dev can be called from controller UI if something goes wrong while presale or sale is in progress
    @dev only sales are affected.
    */
    function pause() public onlyOwner atStage(Stages.AnySale) returns(bool) {
        stageBeforePause = currentStage;
        currentStage = Stages.Pause;
        return(true);
    }

   /**
    @dev resume
    @dev can be called from controller UI ito continue crowdfunding
    */
    function resume() public onlyOwner atStage(Stages.Pause) returns(bool) {
        currentStage = stageBeforePause;
        return(true);
    }


//Purchase functions

    /**@dev fallback function to buy tokens for ETH
    */
    function () public payable {
        require(buyTokens(msg.sender, msg.value));
    }

    /**@dev insert buy for BTC function here
    /
    /
    /
    /
    /
    /
    /
    */

    /**@dev buyTokens internal
    @param buyer address
    @param etherValue uint256
    */
    function buyTokens(address buyer, uint256 etherValue) internal atStage(Stages.AnySale) returns(bool) {
        bool    success = false;
        uint256 promoBonusTokens = 0; //for the promo code distributor
        bool    hitTheCap = false;

        uint256 tokenAmount = calculateTokenAmountETH(msg.sender, msg.value);
 
        if(redeemedCodes[buyer].codeOwner != 0x0
                && (redeemedCodes[buyer].expires == 0 || redeemedCodes[buyer].expires <= now)) {
                promoBonusTokens = etherValue/TOKEN_BASE_PRICE*redeemedCodes[buyer].ownerBonus/100;
            }

        if(theToken.totalSupply() + tokenAmount + promoBonusTokens > theToken.MAX_TOKENS() && etherValue > CAP_GAP)
            hitTheCap = true;

        if(currentStage == Stages.PresaleInProgress && (now >= presaleStartTime + PRESALE_DURATION || hitTheCap))
            presaleEnd();
        else if(currentStage == Stages.SaleInProgress && (now >= saleStartTime + SALE_DURATION || hitTheCap))
            saleEnd();
        else {
            theToken.mint(buyer, tokenAmount);
            etherBalances[buyer] += etherValue;
            if(currentStage == Stages.PresaleInProgress)
                presaleEtherCollected += etherValue;
            else
                saleEtherCollected += etherValue;      

            theToken.mint(redeemedCodes[buyer].codeOwner, etherValue/TOKEN_BASE_PRICE*redeemedCodes[buyer].ownerBonus/100);
            success = true;
        }
        return(success);
    }

    /**@dev calculateTokenAmountETH internal
    @dev calculates amount of tokens to mint based on current stage, bonus policy and personal bonus promo codes
    @param buyer address
    @param amount uint256 wei
    * 
    */
    function calculateTokenAmountETH(address buyer, uint256 amount) internal view returns(uint256) {
        uint256    tokensAmount = amount/TOKEN_BASE_PRICE;
        uint256    extraTokens = 0;
        
        //Presale bonus
        if(currentStage == Stages.PresaleInProgress)
            extraTokens = tokensAmount*(INITIAL_PRESALE_BONUS-PRESALE_BONUS_DAILY_DECREMENT*(now - presaleStartTime) * 1 days)/100;
        
        //!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
        // Change before deploy
        //!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
        else if(currentStage == Stages.SaleInProgress) {
            if(amount > 4 ether && amount <= 12 ether)
                extraTokens = amount*5/100;
            else if(amount > 12 ether && amount <= 20 ether)
                extraTokens = amount*10/100;
            else if(amount > 20 ether && amount <= 40 ether)
                extraTokens = amount*15/100;
            else if(amount > 40 ether && amount <= 80 ether)
                extraTokens = amount*20/100;
            else if(amount > 80 ether && amount <= 120 ether)
                extraTokens = amount*25/100;
            else if(amount > 120 ether)
                extraTokens = amount*30/100;
        }
    
        //Promo codes
        if( redeemedCodes[buyer].expires == 0 || redeemedCodes[buyer].expires <= now )
            extraTokens += tokensAmount*redeemedCodes[buyer].bonus/100;
 
        return(tokensAmount + extraTokens);
    }

//Secondary functions
    /**
    @dev changeOwner
    @param newOwner address
    */      
    function changeOwner(address newOwner) public onlyOwner {
        require(newOwner != address(0));
        owner = newOwner;
    }


    /**
    @dev changeTokenOwner use with caution!
    @dev USE WITH CAUTION!!!
    @dev This contract will loose control of the token after execution
    @dev Must be only used after successfull completetion of all sales stages to relay token to permanent controller
    @param newOwner address
    */
    function changeTokenOwner(address newOwner) public onlyOwner atStage(Stages.Success) {
        require(newOwner != address(0));
        theToken.changeOwner(newOwner);
    }

    /**@dev createPromoCode
    @dev called from controller UI
    @param code string
    @param bonus uint
    @param expires uint
    @param codeOwner address
    @param ownerBonus uint
    */
    function createPromoCode(string code, uint bonus, uint expires, address codeOwner, uint ownerBonus) public onlyOwner {
        require( bonus >= MIN_PROMO_BONUS && bonus <= MAX_PROMO_BONUS
            && (codeOwner == 0x0 || ownerBonus >= MAX_PROMO_BONUS && ownerBonus <= MAX_PROMO_BONUS)
            && expires >= 0 );
            //existing promo code will be updated 
            promoCodes[code].bonus = bonus;
            promoCodes[code].expires = expires;
            promoCodes[code].codeOwner = codeOwner;
            promoCodes[code].ownerBonus = ownerBonus;
    }

    /**@dev redeemPromoCode
    @dev must be called from crowdsale website
    @param sender address
    @param code string
    */   
    function redeemPromoCode(address sender, string code) public returns (bool){
        require(sender != 0x0
            && (redeemedCodes[sender].expires > now || promoCodes[code].bonus >= redeemedCodes[sender].bonus)); //do not downgrade bonuses unless expired  
            
        redeemedCodes[sender].bonus = promoCodes[code].bonus;
        redeemedCodes[sender].expires = promoCodes[code].expires;
        redeemedCodes[sender].codeOwner = promoCodes[code].codeOwner;
        redeemedCodes[sender].ownerBonus = promoCodes[code].ownerBonus;
        return(true);
    }
}