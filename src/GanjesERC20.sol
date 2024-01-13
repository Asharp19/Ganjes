// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/finance/VestingWallet.sol";

contract GanjesToken is ERC20, Ownable {
    uint64 public transactionFeePercent; // total transaction fee
    address public liquidityWallet; //liquidityFee wallet
    uint64 public constant liquidityFeePercent = 50; // percentage of transaction fee allocated to liquidity
    uint64 public constant TotalTeamVestingShare = 10;
    uint64 public constant TotalAdvisorVestingShare = 5;

    uint64 private constant TEAM_CLIFF_DURATION = 365 days;
    uint64 private constant TEAM_VESTING_DURATION =3*365 days;
    uint64 private constant ADVISORS_CLIFF_DURATION = 0.5 * 365 days;
    uint64 private constant ADVISORS_VESTING_DURATION =2*365 days;

    mapping(address => VestingWallet) public teamVestingWallets;
    mapping(address => VestingWallet) public advisorsVestingWallets;

    address[] public teamMembers;
    address[] public advisors;

    constructor(
        uint256 initialSupply,
        address _liquidityWallet,
        uint64 feePercent,
        address[] memory _teamMembers,
        address[] memory _advisors
    ) ERC20("Ganjes", "GANJES") Ownable(msg.sender) {
        // All shares  split at start before minting and minted directly to vesting wallets from initial supply for reducing transaction calls later

        uint256 tokensForTeam = ((initialSupply * (10**uint256(decimals()))) *
            TotalTeamVestingShare) / 100;
        uint256 tokensForAdvisors = ((initialSupply *
            (10**uint256(decimals()))) * TotalAdvisorVestingShare) / 100;
        uint256 tokensForOwner = (initialSupply * (10**uint256(decimals()))) -
            (tokensForTeam + tokensForAdvisors);
        uint256 teamMembersLength = _teamMembers.length;
        uint256 advisorsLength = _advisors.length;

        for (uint256 i = 0; i < teamMembersLength; i++) {
            teamMembers.push(_teamMembers[i]);
            teamVestingWallets[_teamMembers[i]] = new VestingWallet(
                _teamMembers[i],
                uint64(block.timestamp + TEAM_CLIFF_DURATION),
                TEAM_VESTING_DURATION
            );
            // _mint(address(teamMembers[i]), tokensForTeam/teamMembersLength);
        }

        //Vesting wallets Filled for teamMembers

        for (uint256 i = 0; i < advisorsLength; i++) {
            advisors.push(_advisors[i]);
            advisorsVestingWallets[_advisors[i]] = new VestingWallet(
                _advisors[i],
                uint64(block.timestamp + ADVISORS_CLIFF_DURATION),
                ADVISORS_VESTING_DURATION
            );
            // _mint(address(advisors[i]), tokensForAdvisors/advisorsLength);
        }

        for (uint256 i = 0; i < teamMembersLength; i++) {
            _mint(
                address(teamVestingWallets[teamMembers[i]]),
                tokensForTeam / teamMembersLength
            );
        }
        for (uint256 i = 0; i < advisorsLength; i++) {
            _mint(
                address(advisorsVestingWallets[advisors[i]]),
                tokensForAdvisors / advisorsLength
            );
        }

        //Vesting wallets Filled for advisors

        _mint(owner(), tokensForOwner);
        liquidityWallet = _liquidityWallet;
        transactionFeePercent = feePercent;
    }

    function setLiquidityWallet(address newLiquidityWallet) public onlyOwner {
        liquidityWallet = newLiquidityWallet;
    }

    function transfer(address recipient, uint256 amount)
        public
        virtual
        override
        returns (bool)
    {
        uint256 fee = (amount * transactionFeePercent) / 100;
        uint256 liquidityFee = (fee * liquidityFeePercent) / 100;
        uint256 burnerFee = (fee * (100 - liquidityFeePercent)) / 100;
        uint256 transferAmount = amount - fee;

        super._transfer(_msgSender(), recipient, transferAmount);
        if (liquidityFee > 0) {
            super._transfer(_msgSender(), liquidityWallet, liquidityFee);
        }
        if (burnerFee > 0) {
            super._burn(_msgSender(), burnerFee);
        }
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public virtual override returns (bool) {
        uint256 fee = (amount * transactionFeePercent) / 100;
        uint256 liquidityFee = (fee * liquidityFeePercent) / 100;
        uint256 burnerFee = (fee * (100 - liquidityFeePercent)) / 100;
        uint256 transferAmount = amount - fee;

        super.transferFrom(sender, recipient, transferAmount);

        if (liquidityFee > 0) {
            super._transfer(sender, liquidityWallet, liquidityFee);
        }
        if (burnerFee > 0) {
            super._burn(sender, burnerFee);
        }
        return true;
    }

    function releaseVestedTokens() public payable {
        address caller = _msgSender();
        bool isTeamMember = address(teamVestingWallets[caller]) != address(0);
        bool isAdvisor = address(advisorsVestingWallets[caller]) != address(0);

        require(isTeamMember || isAdvisor, "Not eligible to claim");
        

        if (isTeamMember) {
            require(teamVestingWallets[caller].start()<=block.timestamp, "Vesting Hasn't Started");
            require(teamVestingWallets[caller].releasable(address(this))>0, "No Tokens Left to release");
            teamVestingWallets[caller].release(address(this));
        } 
        if (isAdvisor){
            // isAdvisor must be true here
            require(advisorsVestingWallets[caller].start()<=block.timestamp, "Vesting Hasn't Started");
            require(advisorsVestingWallets[caller].releasable(address(this))>0, "No Tokens Left to release");
            advisorsVestingWallets[caller].release(address(this));
        }
    }

    // receive() external payable {}

    // Optional: Function to withdraw Ether from the contract
    // function withdrawEther(uint256 amount) public onlyOwner {
    //     require(address(this).balance >= amount, "Insufficient balance");
    //     payable(owner()).transfer(amount);
    // }
}

