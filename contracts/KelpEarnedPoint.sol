// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import { ERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import { ERC20PausableUpgradeable } from
    "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PausableUpgradeable.sol";
import { AccessControlUpgradeable } from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { ERC20PermitUpgradeable } from
    "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract KelpEarnedPoint is
    Initializable,
    ERC20Upgradeable,
    ERC20PausableUpgradeable,
    AccessControlUpgradeable,
    ERC20PermitUpgradeable
{
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    mapping(address addr => bool isExempt) public isExemptFromPause;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @dev Initialize the contract
    /// @param defaultAdmin The default admin role
    /// @param minter The minter role
    function initialize(address defaultAdmin, address minter) public initializer {
        __ERC20_init("Kelp Earned Point", "KEP");
        __ERC20Permit_init("Kelp Points");
        __ERC20Pausable_init();
        __AccessControl_init();

        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        _grantRole(MINTER_ROLE, minter);
    }

    /// @dev Mint new tokens. Only the minter can call this
    /// @param to The address to mint to
    /// @param amount The amount to mint
    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }

    /// @dev Burn tokens. Only calleable by the burner
    /// @param from The address to burn from
    /// @param amount The amount to burn
    function burn(address from, uint256 amount) public onlyRole(BURNER_ROLE) {
        _burn(from, amount);
    }

    function pause() public onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    function _beforeTokenTransfer(
        address from,
        address,
        uint256
    )
        internal
        view
        override(ERC20Upgradeable, ERC20PausableUpgradeable)
    {
        if (paused()) {
            require(isExemptFromPause[from], "Transfers are paused");
        }
    }

    function setExemptFromPause(address addr, bool exempt) public onlyRole(DEFAULT_ADMIN_ROLE) {
        isExemptFromPause[addr] = exempt;
    }
}
