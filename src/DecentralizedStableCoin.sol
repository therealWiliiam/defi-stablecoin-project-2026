// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;
import {ERC20, ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
//import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

/// @title DecentralizedStableCoin
/// @author Bill Henry-Nkeki
/**
 * Collateral: Exogenus(ETH & BTC)
 * Minting: Algoritmic
 * Relative Stablity: Pegged to USD
 */
/// @notice  This contract is an ERC20 implemntation of our stablecoin system
/// @dev This contract is governed by DSCEngine

contract DecentralizedStableCoin is ERC20Burnable, Ownable {
    error DecentralizedStableCoin__MustBeMoreThanZero();
    error DecentralizedStableCoin__AmountExceedsBalance();
    error DecentralizedStableCoin__NotZeroAddress();

    constructor(address initialOwner) ERC20("DecentralizedStableCoin", "$DSC") Ownable(initialOwner) {}

    function burn(uint256 amount) public override onlyOwner {
        uint256 balance = balanceOf(msg.sender);

        if (amount <= 0) {
            revert DecentralizedStableCoin__MustBeMoreThanZero();
        }

        if (amount < balance) {
            revert DecentralizedStableCoin__AmountExceedsBalance();
        }
        super.burn(amount);
    }

    function mint(address to, uint256 amount) external onlyOwner returns (bool) {
        if (to == address(0)) {
            revert DecentralizedStableCoin__NotZeroAddress();
        }

        if (amount <= 0) {
            revert DecentralizedStableCoin__MustBeMoreThanZero();
        }

        _mint(to, amount);
        return true;
    }
}
