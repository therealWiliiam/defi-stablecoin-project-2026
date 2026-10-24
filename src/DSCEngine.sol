// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {DecentralizedStableCoin} from "./DecentralizedStableCoin.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {OracleLib} from "./libraries/OraclesLib.sol";

/// @title DSC Engine
/// @author Bill Henry-Nkeki
/// @notice Explain to an end user what this does
/// @dev The system is designed to be as minimal as possible, and have the tokens maintain a 1 token == $1 peg at all This is a stablecoin with the properties:
/**
 * * - Exogenously Collateralized
 * - Dollar Pegged
 * - Algorithmically Stable
 *
 * It is similar to DAI if DAI had no governance, no fees, and was backed by only WETH and WBTC.
 *
 * Our DSC system should always be "overcollateralized". At no point, should the value of
 * all collateral < the $ backed value of all the DSC.
 *
 * @notice This contract is the core of the Decentralized Stablecoin system. It handles all the logic
 * for minting and redeeming DSC, as well as depositing and withdrawing collateral.
 * @notice This contract is based on the MakerDAO DSS system
 */

contract DSCEngine is ReentrancyGuard {
    /**
     * error(Start)
     */
    error DSCEngine__MustBeMoreThanZero();
    error DSCEngine__TokenNotAllowed(address token);
    error DSCEngine_TokenAddressAndPriceFeedAddressMustMatch();
    error DSCEngine__TransferFailed();
    error DSCEngine__HealthFactorOk();
    error DSCEngine__MintFailed();
    error DSCEngine__HealthFactorNotImproved();
    /**
     * error(Stop)
     */

    /*modifiers (End)*/
    modifier moreThanZero(uint256 amount) {
        if (amount <= 0) {
            revert DSCEngine__MustBeMoreThanZero();
        }
        _;
    }

    modifier isAllowedToken(address token) {
    if (s_priceFeed[token] == address(0)) {
        revert DSCEngine__TokenNotAllowed(token);
    }
    _;
}
    /*modifiers (End)*/
    using OracleLib for AggregatorV3Interface;
    /*state variable (Start)*/

    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant LIQUIDATION_THRESHOLD = 50;
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant MIN_HEALTH_FACTOR = 1;
    uint256 private constant LIQUIDATION_BONUS = 10; 

    mapping(address tokenAddress => address priceFeedAddress) private s_priceFeed;
    mapping(address user => mapping(address token => uint256 amount)) private s_collateralDeposited;
    mapping(address user => uint256 amount) private s_DSCMinted;
    address[] private s_collateralTokens;
    DecentralizedStableCoin private i_dsc;
    /*state variable (End)*/

    /**
     * events
     */
    event CollateralDeposited(address indexed user, address indexed token, uint256 indexed amount);
    event CollateralReedemed(address indexed reedemedFrom, address indexed reedemedTo, address indexed token, uint256 amount);
    /**
     * events
     */

    constructor(address[] memory tokenAddresses, address[] memory priceFeedAddresses, address dscAddress) {
        if (tokenAddresses.length != priceFeedAddresses.length) {
            revert DSCEngine_TokenAddressAndPriceFeedAddressMustMatch();
        }

        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            s_priceFeed[tokenAddresses[i]] = priceFeedAddresses[i];
            s_collateralTokens.push(tokenAddresses[i]);
        }

        i_dsc = DecentralizedStableCoin(dscAddress);
    }

    // / @param tokenCollateralAddress the address of the token to deposit te collateral
    // / @param amountCollateral the amount of collateral to deposit
    function depositCollateral(address tokenCollateralAddress, uint256 amountCollateral)
        public
        moreThanZero(amountCollateral)
        isAllowedToken(tokenCollateralAddress)
        nonReentrant
    {
        s_collateralDeposited[msg.sender][tokenCollateralAddress] += amountCollateral;
        emit CollateralDeposited(msg.sender, tokenCollateralAddress, amountCollateral);
        bool success = IERC20(tokenCollateralAddress).transferFrom(msg.sender, address(this), amountCollateral);

        if (!success) {
            revert DSCEngine__TransferFailed();
        }
    }

    /// @param tokenCollateralAddress the address of the token to deposit te collateral
    /// @param amountCollateral the amount of collateral to deposit
    /// @param amountDscToMint the amount of $DSC(Decentralized StableCoin) to mint
    /// @notice this function is a combination of depositCollateral and mintDSC
    function depositCollateralAndMintDSC(
        address tokenCollateralAddress,
        uint256 amountCollateral,
        uint256 amountDscToMint
    ) external {
        depositCollateral(tokenCollateralAddress, amountCollateral);
        mintDSC(amountDscToMint);
    }


    function reedemCollateral(address tokenCollateralAddress, uint256 amountCollateral)
        public
        moreThanZero(amountCollateral)
        nonReentrant()
    {
        _reedemCollateral(msg.sender,msg.sender,tokenCollateralAddress,amountCollateral);
        _revertIfHealthFactorIsBroken(msg.sender);
    }


    
    
    /// @param tokenCollateralAddress the address of the token to deposit te collateral
    /// @param amountCollateral the amount of collateral to deposit
    /// @param amountDscToBurn the amount of $DSC(Decentralized StableCoin) to burn
    /// @notice this function is a combination of reedemCollateral and burnDSC
    function reedemCollateralForDSC(address tokenCollateralAddress, uint256 amountCollateral, uint256 amountDscToBurn) external moreThanZero(amountCollateral) {
        burnDSC(amountDscToBurn);
        reedemCollateral(tokenCollateralAddress, amountCollateral);
    }


    /**
     * Requirments
     * 1. check if the collateral value is more than the DSC minted
     */
    /// @param amountDscToMint the amount of $DSC(Decentralized StableCoin) to mint
    /// @notice they must have more collateral value than the minimum threshold
    function mintDSC(uint256 amountDscToMint) public moreThanZero(amountDscToMint) nonReentrant {
        s_DSCMinted[msg.sender] += amountDscToMint;
        _revertIfHealthFactorIsBroken(msg.sender);
        bool minted = i_dsc.mint(msg.sender, amountDscToMint);
        if (!minted) {
            revert DSCEngine__MintFailed();
        }
    }

    function burnDSC(uint256 amount) public moreThanZero(amount) {
        _burnDsc(msg.sender, msg.sender, amount);
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    /// @param collateral the address of the token to deposit the collateral
    /// @param user the address of the user to liquidate
    /// @param debtToCover the amount of $DSC(Decentralized StableCoin) to cover
    /// @notice this function is used to liquidate a user if their health factor is below MIN_HEALTH_FACTOR
    /// @notice you can partially liquidate a user, you don't have to cover all their debt
    /// @notice you will get a liquidation bonus for taking the risk of liquidating a user
    /// @notice this function working assumes te protocol is 200% overcollateralized, meaning for every $1 of DSC minted, there is at least $2 of collateral in the system
    function liquidate(address collateral, address user, uint256 debtToCover) external moreThanZero(debtToCover) nonReentrant {
        uint256 startingUserHealthFactor = _healthFactor(user);
        if(startingUserHealthFactor >= MIN_HEALTH_FACTOR){
            revert DSCEngine__HealthFactorOk();
        }

        uint256 tokenAmountFromDebtCovered = getTokenAmountFromUsd(collateral, debtToCover);
        uint256 bonusCollateral = (tokenAmountFromDebtCovered * LIQUIDATION_BONUS) / LIQUIDATION_PRECISION;
        uint256 totalCollateralToReedem = tokenAmountFromDebtCovered + bonusCollateral;
        _reedemCollateral(user, msg.sender, collateral, totalCollateralToReedem);
        _burnDsc(user, msg.sender, debtToCover);

        uint256 endingUserHealthFactor = _healthFactor(user);
        if(endingUserHealthFactor <= startingUserHealthFactor){
            revert DSCEngine__HealthFactorNotImproved();
        }
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    function getHealthFactor() external view {}

    /**
     * Private & Internal Functions(Start)
     */
    function _getAccountInformation(address user)
        private
        view
        returns (uint256 totalDscMinted, uint256 collateralValueInUsd)
    {
        totalDscMinted = s_DSCMinted[user];
        collateralValueInUsd = getAccountCollateralValue(user);
    }

    function _burnDsc(address onBehalfOf, address dscFrom, uint256 amountDscToBurn) private {
        s_DSCMinted[onBehalfOf] -= amountDscToBurn;
        bool success = i_dsc.transferFrom(dscFrom,address(this), amountDscToBurn);
        if(!success) {
            revert DSCEngine__TransferFailed();
        }
        i_dsc.burn(amountDscToBurn);
    }   

    function _reedemCollateral(address from, address to,address tokenCollateralAddress, uint256 amountCollateral) private {
        s_collateralDeposited[from][tokenCollateralAddress] -= amountCollateral;
        emit CollateralReedemed(from,to,tokenCollateralAddress,amountCollateral);
        bool success = IERC20(tokenCollateralAddress).transfer(msg.sender, amountCollateral);
        if(!success){
            revert DSCEngine__TransferFailed();
        }
    } 

    /**
     * Returns how close to liquidation a user is
     * if a user goes below 1 they can get liquidated
     */
    function _healthFactor(address user) private view returns (uint256) {
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = _getAccountInformation(user);
        uint256 collateralAdjustedForThreshold = (collateralValueInUsd * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;
        return (collateralAdjustedForThreshold * PRECISION) / totalDscMinted;
    }

    function _revertIfHealthFactorIsBroken(address user) internal view {
        uint256 userHealthFactor = _healthFactor(user);
        if (userHealthFactor < MIN_HEALTH_FACTOR) {
            revert DSCEngine__HealthFactorOk();
        }
    }

    /**
     * Private & Internal Functions(END)
     */



    /**
     * Public and external view functions
     */
    function getAccountCollateralValue(address user) public view returns (uint256 totalCollateralValueInUsd) {
        for (uint256 i = 0; i < s_collateralTokens.length ; i++) {
            address token = s_collateralTokens[i];
            uint256 amount = s_collateralDeposited[user][token];
            totalCollateralValueInUsd += getUsdValue(token, amount);
        }
        return totalCollateralValueInUsd;
    }

    function getUsdValue(address token, uint256 amount) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeed[token]);
        (, int256 price,,,) = priceFeed.latestRoundData();

        return ((uint256(price) * ADDITIONAL_FEED_PRECISION) * amount) / PRECISION;
    }

    function getTokenAmountFromUsd(address token, uint256 usdAmountInWei) public view returns(uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeed[token]);
        (,int256 price,,,) = priceFeed.latestRoundData();
        return(usdAmountInWei * PRECISION) / (uint256 (price) * ADDITIONAL_FEED_PRECISION);
    } 

    function getAccountInformation(address user) external view returns(uint256 totalDscMinted, uint256 collateralValueInUsd) {
        (totalDscMinted, collateralValueInUsd) = _getAccountInformation(user);
    }

    function getCollateralTokens() external view returns (address[] memory){
        return s_collateralTokens;
    }

    function getCollateralBalanceOfUser(address user, address token) external view returns(uint256) {
        return s_collateralDeposited[user][token];
    }

    function getLiquidationBonus() public returns(uint256) {
        return LIQUIDATION_BONUS;
    }

    function getPrecision() public returns(uint256) {
        return PRECISION;
    }

    function getCollateralTokenPriceFeed(address token) 
    external 
    view 
    returns (address) 
{
    return s_priceFeed[token];
}
}
