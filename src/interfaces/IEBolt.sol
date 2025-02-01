// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

interface IEBolt {
    /**
     * @dev Emitted when `amount` tokens are created using the function {mintWithMessage}
     */
    event MintWithMessage(
        address to,
        bytes32 hashUsed,
        bytes signatureUsed,
        uint256 amount,
        uint256 nonceUsed
    );

    /**
     * @dev Creates `_amount` tokens and give them to `msg.sender`
     * Only who can correctly build `_hash` can call this function. 
     * Once a `_hash` is rebuilt correctly we also check if it was signed by `signer`.
     * If the `_hash` is valid then it's stored in a mapping, this allows us to check if it was 
     * already used before.
     * 
     * Emits a {MintWithMessage} event.
     */
    function mintWithMessage(
        uint256 _amount,
        uint256 _nonce,
        bytes memory _signature
    ) external;
}
