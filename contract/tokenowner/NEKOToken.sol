// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Ownable } from "./Ownable.sol";
import { ERC20 } from "./ERC20.sol";

contract NEKOToken is ERC20, Ownable {

    //constructor
    constructor(address owner) ERC20("NEKO", "NEKO") Ownable(owner) {
        _mint(owner, 1e22);
    }

    function mint(address user, uint256 amount) public onlyOwner {
        _mint(user, amount);
    }

    function burn(address user, uint256 amount) public onlyOwner {
        _burn(user, amount);
    }
}