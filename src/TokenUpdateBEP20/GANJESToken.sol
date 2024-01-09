// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract GanjesToken is ERC20, Ownable {
    uint256 public transactionFeePercent;// total transaction fee
    uint256 public liquidityFeePercent; // percentage of transaction fee allocated to liquidity
    address public liquidityWallet;
    address public mockSupply;

    constructor(uint256 initialSupply, address _liquidityWallet, address _mockSupply, uint256 feePercent, uint256 liquidityPercent) ERC20("Ganjes", "GANJES") Ownable(msg.sender){
        mockSupply=_mockSupply;
        _mint(mockSupply, initialSupply * (10 ** uint256(decimals())));
        liquidityWallet = _liquidityWallet;
        liquidityFeePercent=liquidityPercent;
        transactionFeePercent=feePercent;
       
    }

    function setLiquidityWallet(address newLiquidityWallet) public onlyOwner {
        liquidityWallet = newLiquidityWallet;
    }

    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        uint256 fee = (amount * transactionFeePercent) / 100;
        uint256 liquidityFee = (fee * liquidityFeePercent) / 100;
        uint256 transferAmount = amount - fee;

        super._transfer(_msgSender(), recipient, transferAmount);
        if (liquidityFee > 0) {
            super._transfer(_msgSender(), liquidityWallet, liquidityFee);
        }
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public virtual override returns (bool) {
        uint256 fee = (amount * transactionFeePercent) / 100;
        uint256 liquidityFee = (fee * liquidityFeePercent) / 100;
        uint256 transferAmount = amount - fee;

        super.transferFrom(sender, recipient, transferAmount);
        if (liquidityFee > 0) {
            super._transfer(sender, liquidityWallet, liquidityFee);
        }
        return true;
    }
}