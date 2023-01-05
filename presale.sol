//SPDX-License-Identifier: MIT
/*
An initial coin offering is a form of crowdfunding that enables new startups to
 generate funds for Its business activities. However, the ICOs being based on the blockchain 
 and cryptocurrencies, the number of investors and their capacity to invest is very speculative since there is no regulating agency which can classify the investors according to their investment potential. To overcome this uncertainty during the funding of the project many of the ICOs opt for a presale.

A presale or an ICO private sale, is a token sale event which is carried out by the blockchain 
companies before the launch of the public sale of tokens.

The major points of difference between ICO and a presale event are

A presale event consists of funding from family, friends, close associates
 and investors with large capitals while, an ICO consists of funding from the general public.
A presale event offers the tokens at a great discount than the ICO.
A presale is seen as a major incentive by the early investor since it gives the possibilities of
 very huge and quick returns when the tokens hit the exchanges for trading. The chances of such huge
  return are comparatively lesser in case of ICOs.
Often a minimum contribution amount is set in the presale, which is much more than that required in an ICO.
Strict KYC and background checks are required for most of the presale, to ensure that no manipulation 
can be done by the early investors. In comparison the number of investors in ICO are far more than the 
early investors and as a result of that, more investors may be permitted.
The liquidity of that coins being offered is least in the presale event because the actual launch of the
 tokens on the exchanges are still a long way away. In comparison, the ICO stage offers liquidity in near future.
During the pre-sale event, most of the products are only on a planning phase and the presale is done for 
funding the initial development of the blockchain. ICO is often held at testing phase of the blockchain and the working product.
In addition to these differences, the risk factor also is a critical aspect to consider for investment in an
 ICO or a presale. The popularity of the project could determine how successful the presale become in terms of reaching the softcap, which is the minimum amount of funds to be raised for the project. In some of the most popular projects, not only the softcap but the hardcap too, is raised during the presale.
*/

pragma solidity 0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

interface Aggregator {
    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        );
}

contract Presale is
    Initializable,
    ReentrancyGuardUpgradeable,
    OwnableUpgradeable,
    PausableUpgradeable
{
    uint256 public totalTokensSold;
    uint256 public startTime;
    uint256 public endTime;
    uint256 public claimStart;
    address public saleToken;
    uint256 public baseDecimals;
    uint256 public maxTokensToBuy;
    uint256 public currentStep;

    IERC20Upgradeable public USDTInterface;
    Aggregator public aggregatorInterface;
    // https://docs.chain.link/docs/ethereum-addresses/ => (ETH / USD)

    uint256[9] public token_amount;
    uint256[9] public token_price;

    mapping(address => uint256) public userDeposits;
    mapping(address => bool) public hasClaimed;

    event SaleTimeSet(uint256 _start, uint256 _end, uint256 timestamp);

    event SaleTimeUpdated(
        bytes32 indexed key,
        uint256 prevValue,
        uint256 newValue,
        uint256 timestamp
    );

    event TokensBought(
        address indexed user,
        uint256 indexed tokensBought,
        address indexed purchaseToken,
        uint256 amountPaid,
        uint256 timestamp
    );

    event TokensAdded(
        address indexed token,
        uint256 noOfTokens,
        uint256 timestamp
    );
    event TokensClaimed(
        address indexed user,
        uint256 amount,
        uint256 timestamp
    );

    event ClaimStartUpdated(
        uint256 prevValue,
        uint256 newValue,
        uint256 timestamp
    );
/*
as presale contracts are written for saling tokens before being created we need some functions to specify time.
 we use block.timestamp fo unix unit times in solidity

Claiming a token, means specifing the amount of token you are going to invest. as this is a presale contract, buyers can claim the bought tokens
afterwards. it seems like a ticket. you pay for it but you don't get the sevice immidiatly. but you can show it and get the access to it.
*/
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    /**
     * @dev Initializes the contract and sets key parameters
     * @param _oracle Oracle contract to fetch ETH/USDT price
     * @param _usdt USDT token contract address
     * @param _startTime start time of the presale
     * @param _endTime end time of the presale
     */
    function initialize(
        address _oracle,
        address _usdt,
        uint256 _startTime,
        uint256 _endTime
    ) external initializer {
        require(_oracle != address(0), "Zero aggregator address");
        require(_usdt != address(0), "Zero USDT address");
        require(
            _startTime > block.timestamp && _endTime > _startTime,
            "Invalid time"
        );
        __Pausable_init_unchained();
        __Ownable_init_unchained();
        __ReentrancyGuard_init_unchained();
        maxTokensToBuy = 50_000_000;
        baseDecimals = (10**18);
        token_amount = [
            35_000_000,
            105_000_000,
            175_000_000,
            262_500_000,
            350_000_000,
            437_500_000,
            525_000_000,
            612_500_000,
            700_000_000
        ];
        token_price = [
            47600000000000000,
            50000000000000000,
            51300000000000000,
            53300000000000000,
            55600000000000000,
            58000000000000000,
            60600000000000000,
            63500000000000000,
            66200000000000000
        ];
        aggregatorInterface = Aggregator(_oracle);
        USDTInterface = IERC20Upgradeable(_usdt);
        startTime = _startTime;
        endTime = _endTime;
        emit SaleTimeSet(startTime, endTime, block.timestamp);
    }
/*
selecting payment token you wish to receive investments in and then set the token price denominated in the currency 
of choice (e.g. ETH or USDT), followed by the token presale amount caps. 
they have two options for token to buy. USDT and ETH and they are some calculations for this exchanges.
If 1 USDC = 100 BTD with a hard cap of 10 USDC  → Number of tokens on sale = 1000 BTD
*/
    /**
     * @dev To pause the presale
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @dev To unpause the presale
     */
    function unpause() external onlyOwner {
        _unpause();
    }
/*
the proccess is pausable by owner.
*/

    /**
     * @dev To calculate the price in USD for given amount of tokens.
     * @param _amount No of tokens
     */
    function calculatePrice(uint256 _amount)
        public
        view
        returns (uint256 totalValue)
    {
        uint256 USDTAmount;
        require(_amount <= maxTokensToBuy, "Amount exceeds max tokens to buy");
        if (_amount + totalTokensSold > token_amount[currentStep]) {
            require(currentStep < 8, "Insufficient token amount.");
            uint256 tokenAmountForCurrentPrice = token_amount[currentStep] -
                totalTokensSold;
            USDTAmount =
                tokenAmountForCurrentPrice *
                token_price[currentStep] +
                (_amount - tokenAmountForCurrentPrice) *
                token_price[currentStep + 1];
        } else USDTAmount = _amount * token_price[currentStep];
        return USDTAmount;
    }
/*
this funcion checks if user Amount exceeds max tokens to buy is valid or not. there is a limitation to buy tokens at time
*/
    /**
     * @dev To update the sale times
     * @param _startTime New start time
     * @param _endTime New end time
     */
    function changeSaleTimes(uint256 _startTime, uint256 _endTime)
        external
        onlyOwner
    {
        require(_startTime > 0 || _endTime > 0, "Invalid parameters");
        if (_startTime > 0) {
            require(block.timestamp < startTime, "Sale already started");
            require(block.timestamp < _startTime, "Sale time in past");
            uint256 prevValue = startTime;
            startTime = _startTime;
            emit SaleTimeUpdated(
                bytes32("START"),
                prevValue,
                _startTime,
                block.timestamp
            );
        }
/* users can buy at the specific times so the time must be set. after the arranged time ended they shouldn't be allowed to buy
*/
        if (_endTime > 0) {
            require(block.timestamp < endTime, "Sale already ended");
            require(_endTime > startTime, "Invalid endTime");
            uint256 prevValue = endTime;
            endTime = _endTime;
            emit SaleTimeUpdated(
                bytes32("END"),
                prevValue,
                _endTime,
                block.timestamp
            );
        }
    }

    /**
     * @dev To get latest ethereum price in 10**18 format
     */
    function getLatestPrice() public view returns (uint256) {
        (, int256 price, , , ) = aggregatorInterface.latestRoundData();
        price = (price * (10**10));
        return uint256(price);
    }

    modifier checkSaleState(uint256 amount) {
        require(
            block.timestamp >= startTime && block.timestamp <= endTime,
            "Invalid time for buying"
        );
        require(amount > 0, "Invalid sale amount");
        _;
    }

    /**
     * @dev To buy into a presale using USDT
     * @param amount No of tokens to buy
     */
    function buyWithUSDT(uint256 amount)
        external
        checkSaleState(amount)
        whenNotPaused
        returns (bool)
    {
        uint256 usdPrice = calculatePrice(amount);
        usdPrice = usdPrice / (10**12);
        totalTokensSold += amount;
        if (totalTokensSold > token_amount[currentStep]) currentStep += 1;
        userDeposits[_msgSender()] += (amount * baseDecimals);
        uint256 ourAllowance = USDTInterface.allowance(
            _msgSender(),
            address(this)
        );
        require(usdPrice <= ourAllowance, "Make sure to add enough allowance");
        (bool success, ) = address(USDTInterface).call(
            abi.encodeWithSignature(
                "transferFrom(address,address,uint256)",
                _msgSender(),
                owner(),
                usdPrice
            )
        );
        require(success, "Token payment failed");
        emit TokensBought(
            _msgSender(),
            amount,
            address(USDTInterface),
            usdPrice,
            block.timestamp
        );
        return true;
    }

    /**
     * @dev To buy into a presale using ETH
     * @param amount No of tokens to buy
     */
    function buyWithEth(uint256 amount)
        external
        payable
        checkSaleState(amount)
        whenNotPaused
        nonReentrant
        returns (bool)
    {
        uint256 usdPrice = calculatePrice(amount);
        uint256 ethAmount = (usdPrice * baseDecimals) / getLatestPrice();
        require(msg.value >= ethAmount, "Less payment");
        uint256 excess = msg.value - ethAmount;
        totalTokensSold += amount;
        if (totalTokensSold > token_amount[currentStep]) currentStep += 1;
        userDeposits[_msgSender()] += (amount * baseDecimals);
        sendValue(payable(owner()), ethAmount);
        if (excess > 0) sendValue(payable(_msgSender()), excess);
        emit TokensBought(
            _msgSender(),
            amount,
            address(0),
            ethAmount,
            block.timestamp
        );
        return true;
    }

    /**
     * @dev Helper funtion to get ETH price for given amount
     * @param amount No of tokens to buy
     */
    function ethBuyHelper(uint256 amount)
        external
        view
        returns (uint256 ethAmount)
    {
        uint256 usdPrice = calculatePrice(amount);
        ethAmount = (usdPrice * baseDecimals) / getLatestPrice();
    }

    /**
     * @dev Helper funtion to get USDT price for given amount
     * @param amount No of tokens to buy
     */
    function usdtBuyHelper(uint256 amount)
        external
        view
        returns (uint256 usdPrice)
    {
        usdPrice = calculatePrice(amount);
        usdPrice = usdPrice / (10**12);
    }

    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Low balance");
        (bool success, ) = recipient.call{value: amount}("");
        require(success, "ETH Payment failed");
    }

    /**
     * @dev To set the claim start time and sale token address by the owner
     * @param _claimStart claim start time
     * @param noOfTokens no of tokens to add to the contract
     * @param _saleToken sale toke address
     */

     /*
When tokens become available, we will automatically start distributing the 
tokens to the address you used to contribute Ether. This may take some time as we iterate through everyone,
 so additionally you may also claim your XNK tokens from our Presale Smart Contract 
 (the same contract you made your contribution to) directly. To claim your tokens, simply send another transaction
  — but this time with a value of 0 Ether.
     */
    function startClaim(
        uint256 _claimStart,
        uint256 noOfTokens,
        address _saleToken
    ) external onlyOwner returns (bool) {
        require(
            _claimStart > endTime && _claimStart > block.timestamp,
            "Invalid claim start time"
        );
        require(
            noOfTokens >= (totalTokensSold * baseDecimals),
            "Tokens less than sold"
        );
        require(_saleToken != address(0), "Zero token address");
        require(claimStart == 0, "Claim already set");
        claimStart = _claimStart;
        saleToken = _saleToken;
        IERC20Upgradeable(_saleToken).transferFrom(
            _msgSender(),
            address(this),
            noOfTokens
        );
        emit TokensAdded(saleToken, noOfTokens, block.timestamp);
        return true;
    }

    /*
After taking part in and purchasing a token on presale, next you'll want to claim your tokens.
In case the soft cap/hard cap has been reached, you can claim your tokens. The amount of tokens that you can claim will also be shown. after that the amount of 
bought tokens got obvious, the owner can send tokens to yout address, using token contract.
    */

    /**
     * @dev To change the claim start time by the owner
     * @param _claimStart new claim start time
     */
    function changeClaimStart(uint256 _claimStart)
        external
        onlyOwner
        returns (bool)
    {
        require(claimStart > 0, "Initial claim data not set");
        require(_claimStart > endTime, "Sale in progress");
        require(_claimStart > block.timestamp, "Claim start in past");
        uint256 prevValue = claimStart;
        claimStart = _claimStart;
        emit ClaimStartUpdated(prevValue, _claimStart, block.timestamp);
        return true;
    }

    /**
     * @dev To claim tokens after claiming starts
     */
    function claim() external whenNotPaused returns (bool) {
        require(saleToken != address(0), "Sale token not added");
        require(block.timestamp >= claimStart, "Claim has not started yet");
        require(!hasClaimed[_msgSender()], "Already claimed");
        hasClaimed[_msgSender()] = true;
        uint256 amount = userDeposits[_msgSender()];
        require(amount > 0, "Nothing to claim");
        delete userDeposits[_msgSender()];
        IERC20Upgradeable(saleToken).transfer(_msgSender(), amount);
        emit TokensClaimed(_msgSender(), amount, block.timestamp);
        return true;
    }
}

*/
What is a crypto airdrop?
A crypto airdrop is a free crypto reward. People who get a crypto airdrop will see fungible or non-fungible tokens (NFTs) appear in their private crypto wallet address. Usually, new crypto projects use airdrops to generate social media buzz or reward early community members by literally sending free assets directly to their wallet.

However, it wouldn’t qualify as an airdrop if you were to pay an exchange, company, or Web3 project to get a token reward. Since crypto airdrops have become immensely popular over time, some projects deliberately mislead new users by claiming they're giving "airdrops" and asking for funds. By definition, crypto airdrops shouldn't cost users anything. 

How do crypto airdrops work? 
If a project wants to give a crypto airdrop, they'll usually set aside a portion of their total token supply to send to targeted cryptocurrency wallet addresses. The hope is that once individuals have the assets they’ll participate in the product. The project's leaders may announce an upcoming crypto airdrop on social media and detail how they plan to choose who can claim these tokens. 

Sometimes, people can get crypto airdrops if they used a dApp (decentralized app) in the past. Others may get a crypto airdrop for holding a specific token at a particular time. It's also common for Web3 projects to send crypto airdrops to early adopters and active community members. 

Once the crypto airdrop goes live, anyone who meets the eligibility requirements should see the tokens in their private crypto wallet. Since data is transparent on the blockchain, cryptocurrency projects can easily determine the public wallet addresses that meet their criteria. 

What’s the purpose of crypto airdrops?
Crypto airdrops are all about marketing. The competition in Web3 is fierce, and new projects need ways to stand out. Offering free tokens is a tried-and-tested marketing technique that tends to generate considerable attention.

Some Web3 developers use crypto airdrops to steal attention from more popular protocols in their target market. For example, the NFT marketplace LooksRare offered 120 million of its LOOKS tokens to people who used the competing site OpenSea in 2021. The LOOKS airdrop helped bring thousands of OpenSea traders to LooksRare when it launched in early 2022.  

However, there are other potential reasons developers might give away crypto airdrops. For instance, some dApps may want to show appreciation to early community members. Others might want to encourage people to use their tokens in DeFi (decentralized finance) or decentralized autonomous organizations (DAOs).

These factors were crucial influences on Uniswap's famous airdrop in 2020. In September, the prominent Ethereum decentralized exchange (DEX) announced it would give away 150 million UNI governance tokens to people who used its trading platform. Any Ethereum addresses that swapped tokens on Uniswap beforehand should’ve received 400 UNI tokens. Those who added tokens to Uniswap's liquidity pools could’ve received even more UNI. Because individuals interact with cryptocurrencies via a wallet, this technology is uniquely frictionless in the crypto space.

Many NFT collections have also given out crypto airdrops to encourage community members to hold their tokens. Most famously, the NFT studio Yuga Labs gave anyone holding a Bored Ape Yacht Club (BAYC) NFT a "Mutant Serum" NFT in the summer of 2021. These Mutant Serum NFTs could transform a holder's Bored Ape into a "Mutant Ape." Some of these Mutant Serum and Mutant Ape NFTs have sold for millions of dollars. 
/*