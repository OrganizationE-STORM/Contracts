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
import {IEBolt} from "./interfaces/IEBolt.sol";
contract EBolt is
    ERC20,
    ERC20Burnable,
    Ownable,
    ERC20Permit,
    ERC20Capped,
    IEBolt
{
    address stakingContract;

    uint256 public constant MAX_SUPPLY = 1e18;
    mapping(bytes32 => bool) public hashRegistry;
    address messageSigner;

    constructor(
        address _initialOwner,
        address _messageSigner,
        address _treasury
    )
        ERC20("eBolt", "EBOLT")
        Ownable(_initialOwner)
        ERC20Permit("eBolt")
        ERC20Capped(MAX_SUPPLY)
    {
        _mint(_treasury, 15_000_000_000 * 10 ** decimals());
        messageSigner = _messageSigner;
    }
    /**
     * See {IBolt-mintWithMessage}.
     */
    function mintWithMessage(
        uint256 _amount,
        uint256 _nonce,
        bytes memory _signature
    ) external {
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

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

    function decimals() public view virtual override returns (uint8) {
        return 6;
    }

    function setStakingContract(address _addr) external onlyOwner {
        stakingContract = _addr;
    }

    // The following functions are overrides required by Solidity.

    function _update(
        address from,
        address to,
        uint256 value
    ) internal override(ERC20, ERC20Capped) {
        super._update(from, to, value);
    }
}
