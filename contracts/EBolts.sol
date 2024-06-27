// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

contract EBolts is
    ERC20,
    ERC20Burnable,
    ERC20Pausable,
    AccessControl,
    ERC20Permit
{
    mapping(bytes32 => bool) public hashes;
    address public notary;

    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    event NotaryChanged(address newAddress, address oldAddress);
    event HashRegistered(bytes32 newHash);

    constructor(
        address defaultAdmin,
        address pauser,
        address minter,
        address defaultNotary
    ) ERC20("eBolt", "EBOLT") ERC20Permit("eBolt") {
        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        _grantRole(PAUSER_ROLE, pauser);
        _mint(msg.sender, 10000000 * 10 ** decimals());
        _grantRole(MINTER_ROLE, minter);
        notary = defaultNotary;
    }

    function generateReward(
        bytes memory _signature,
        uint256 _nonce,
        uint256 _amount
    ) public {
        bytes32 message = keccak256(
            abi.encodePacked(_nonce, msg.sender, _amount)
        );
        require(!hashes[message], "Hash already used");
        require(
            ECDSA.recover(message, _signature) == notary,
            "This message was not signed by the notary"
        );

        _mint(msg.sender, _amount);
        emit HashRegistered(message);
        hashes[message] = true;
    }

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }

    function setNotary(address newNotary) public onlyRole(DEFAULT_ADMIN_ROLE) {
        emit NotaryChanged(newNotary, notary);
        notary = newNotary;
    }

    // The following functions are overrides required by Solidity.
    function _update(
        address from,
        address to,
        uint256 value
    ) internal override(ERC20, ERC20Pausable) {
        super._update(from, to, value);
    }
}
