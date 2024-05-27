// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

interface ITokenReceiver {
    function execute(uint256 _amount) external;
}

contract MintBurnERC20 is ERC20Upgradeable {
    address public gov;

    mapping(address => bool) public mintAllowed;
    mapping(address => bool) public burnAllowed;

    modifier onlyMintAllowed() {
        require(mintAllowed[msg.sender], "Only mint allowed");
        _;
    }

    modifier onlyBurnAllowed() {
        require(burnAllowed[msg.sender], "Only burn allowed");
        _;
    }

    function initialize(string memory name_, string memory symbol_) public initializer {
        __ERC20_init(name_, symbol_);
        gov = msg.sender;
    }

    function setMintAllowed(address _pool, bool _allowed) external {
        require(msg.sender == gov, "Only gov");
        mintAllowed[_pool] = _allowed;
    }

    function setBurnAllowed(address _pool, bool _allowed) external {
        require(msg.sender == gov, "Only gov");
        burnAllowed[_pool] = _allowed;
    }

    function mint(address to, uint256 amount) external onlyMintAllowed returns (bool) {
        _mint(to, amount);
        return true;
    }

    function burn(address account, uint256 amount) external onlyBurnAllowed returns (bool) {
        _burn(account, amount);
        return true;
    }

    function flashMint(address _receiver, uint256 _amount) external onlyMintAllowed {
        _mint(_receiver, _amount);

        ITokenReceiver(_receiver).execute(_amount);

        _burn(_receiver, _amount);
    }
}
