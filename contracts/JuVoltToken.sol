// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v5.0.2/contracts/token/ERC20/ERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v5.0.2/contracts/access/Ownable.sol";

contract JuVoltToken is ERC20, Ownable {
    uint256 public immutable maxSupply;

    constructor(uint256 initialSupply, uint256 _maxSupply)
        ERC20("JuVolt Energy Token", "JUVOLT")
        Ownable(msg.sender)
    {
        require(_maxSupply > 0, "Max supply is zero");
        require(initialSupply <= _maxSupply, "Initial > max");

        uint256 scaledMax = _maxSupply * 10 ** decimals();
        uint256 scaledInitial = initialSupply * 10 ** decimals();

        maxSupply = scaledMax;
        _mint(msg.sender, scaledInitial);
    }

    function mint(address to, uint256 amount) external onlyOwner {
        require(totalSupply() + amount <= maxSupply, "Max supply reached");
        _mint(to, amount);
    }
}
