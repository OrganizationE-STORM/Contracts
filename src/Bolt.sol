// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.22;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {ERC20Pausable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC20Capped} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";
import {console} from "forge-std/console.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {IBolt} from "./interfaces/IBolt.sol";
contract Bolt is
    ERC20,
    ERC20Burnable,
    ERC20Pausable,
    Ownable,
    ERC20Permit,
    ERC20Capped,
    IBolt
{
    address stakingContract;

    uint256 public constant MAX_SUPPLY = 1e18;
    mapping(bytes32 => bool) public hashRegistry;
    address messageSigner;

    constructor(
        address _initialOwner,
        address _messageSigner
    )
        ERC20("Bolt", "BLT")
        Ownable(_initialOwner)
        ERC20Permit("Bolt")
        ERC20Capped(MAX_SUPPLY)
    {
        _mint(address(this), 15_000_000_000 * 10 ** decimals());
        messageSigner = _messageSigner;
    }
    /**
     * See {IBolt-mintWithMessage}.
     */
    function mintWithMessage(
        uint256 _amount,
        uint256 _nonce,
        bytes memory _signature
    ) public {
        bytes32 originalHash = keccak256(
            abi.encodePacked(_nonce, msg.sender, _amount)
        );
        require(
            ECDSA.recover(originalHash, _signature) == owner(),
            "This message was not signed by the owner of the contract"
        );
        require(!hashRegistry[originalHash], "Hash already used");
        
        _mint(_msgSender(), _amount);
        hashRegistry[originalHash] = true;
        emit MintWithMessage(_msgSender(), originalHash, _signature, _amount, _nonce);
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

    function decimals() public view virtual override returns (uint8) {
        return 6;
    }
    function safeEBoltTransfer(address _to, uint256 _amount) public {
        require(
            msg.sender == stakingContract,
            "Only staking contract can call this"
        );

        uint256 eBoltsBalance = balanceOf(address(this));

        if (_amount > eBoltsBalance) {
            _transfer(address(this), _to, eBoltsBalance);
        } else {
            _transfer(address(this), _to, _amount);
        }
    }

    function setStakingContract(address _addr) public onlyOwner {
        stakingContract = _addr;
    }

    // The following functions are overrides required by Solidity.

    function _update(
        address from,
        address to,
        uint256 value
    ) internal override(ERC20, ERC20Pausable, ERC20Capped) {
        super._update(from, to, value);
    }
}
