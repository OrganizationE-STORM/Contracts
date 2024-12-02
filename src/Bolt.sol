// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.22;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {ERC20Pausable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract Bolt is ERC20, ERC20Burnable, ERC20Pausable, Ownable, ERC20Permit {
    /*//////////////////////////////////////////////////////////////
                            STORAGE VARS
    //////////////////////////////////////////////////////////////*/
    mapping(bytes32 => bool) public hashesUsed;
    address public notary;

    /*//////////////////////////////////////////////////////////////
                            CUSTOM EVENTS
    //////////////////////////////////////////////////////////////*/
    event NotaryAddressChanged(address oldAddress, address newAddress);
    event NewHashRegistered(bytes32 hashRegistered, address signedBy, address redeemedBy);

    constructor(
        address _notary
    ) ERC20("Bolt", "BLT") Ownable(msg.sender) ERC20Permit("Bolt") {
        _mint(msg.sender, 10000000 * 10 ** decimals());
        notary = _notary;
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    /**
     * @dev This function must mint the tokens given as param only if the
     *      hashed message is correctly rebuilt and the hash was signed by
     *      the owner of the contract.
     * @notice Without using the msg.sender in the reconstruction of the
     *      signed message a miner could take that hash and use it.
     *      Using the msg.sender we're making sure that only the one who's calling
     *      this function can rebuild the original message.
     */
    function mintWithSignedMessage(
        bytes memory _signature,
        uint256 _nonce,
        uint256 _amountToMint
    ) public {
        bytes32 message = keccak256(
            abi.encodePacked(_nonce, _msgSender(), _amountToMint)
        );
        require(!hashesUsed[message], "Hash not valid");
        require(
            ECDSA.recover(message, _signature) == notary,
            "Signature does not match notary"
        );
        _mint(_msgSender(), _amountToMint);
        hashesUsed[message] = true;
        emit NewHashRegistered(message, notary, _msgSender());
    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

    function setNotary(address _notary) public onlyOwner {
        address oldNotary = notary;
        notary = _notary;
        emit NotaryAddressChanged(oldNotary, _notary);
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
