# Aderyn Analysis Report

This report was generated by [Aderyn](https://github.com/Cyfrin/aderyn), a static analysis tool built by [Cyfrin](https://cyfrin.io), a blockchain security company. This report is not a substitute for manual audit or security review. It should not be relied upon for any purpose other than to assist in the identification of potential security vulnerabilities.
# Table of Contents

- [Aderyn Analysis Report](#aderyn-analysis-report)
- [Table of Contents](#table-of-contents)
- [Summary](#summary)
	- [Files Summary](#files-summary)
	- [Files Details](#files-details)
	- [Issue Summary](#issue-summary)
- [High Issues](#high-issues)
	- [H-1: Arbitrary `from` passed to `transferFrom` (or `safeTransferFrom`)](#h-1-arbitrary-from-passed-to-transferfrom-or-safetransferfrom)
- [Low Issues](#low-issues)
	- [L-1: Centralization Risk for trusted owners](#l-1-centralization-risk-for-trusted-owners)
	- [L-2: Unsafe ERC20 Operations should not be used](#l-2-unsafe-erc20-operations-should-not-be-used)
	- [L-3: Solidity pragma should be specific, not wide](#l-3-solidity-pragma-should-be-specific-not-wide)
	- [L-4: Missing checks for `address(0)` when assigning values to address state variables](#l-4-missing-checks-for-address0-when-assigning-values-to-address-state-variables)
	- [L-5: `public` functions not used internally could be marked `external`](#l-5-public-functions-not-used-internally-could-be-marked-external)
	- [L-6: Define and use `constant` variables instead of using literals](#l-6-define-and-use-constant-variables-instead-of-using-literals)
	- [L-7: Event is missing `indexed` fields](#l-7-event-is-missing-indexed-fields)
	- [L-8: Empty `require()` / `revert()` statements](#l-8-empty-require--revert-statements)
	- [L-9: PUSH0 is not supported by all chains](#l-9-push0-is-not-supported-by-all-chains)
	- [L-10: Large literal values multiples of 10000 can be replaced with scientific notation](#l-10-large-literal-values-multiples-of-10000-can-be-replaced-with-scientific-notation)
	- [L-11: Contract still has TODOs](#l-11-contract-still-has-todos)
	- [L-12: Unused Imports](#l-12-unused-imports)
	- [L-13: State variable changes but no event is emitted.](#l-13-state-variable-changes-but-no-event-is-emitted)
	- [L-14: State variable could be declared immutable](#l-14-state-variable-could-be-declared-immutable)


# Summary

## Files Summary

| Key | Value |
| --- | --- |
| .sol Files | 3 |
| Total nSLOC | 288 |


## Files Details

| Filepath | nSLOC |
| --- | --- |
| src/Bolt.sol | 60 |
| src/EStormOracle.sol | 30 |
| src/StakingContract.sol | 198 |
| **Total** | **288** |


## Issue Summary

| Category | No. of Issues |
| --- | --- |
| High | 1 |
| Low | 14 |


# High Issues

## H-1: Arbitrary `from` passed to `transferFrom` (or `safeTransferFrom`)

Passing an arbitrary `from` address to `transferFrom` (or `safeTransferFrom`) can lead to loss of funds, because anyone can transfer tokens from the `from` address if an approval is made.  

<details><summary>1 Found Instances</summary>


- Found in src/StakingContract.sol [Line: 94](src/StakingContract.sol#L94)

	```solidity
	        SafeERC20.safeTransferFrom(
	```

</details>



# Low Issues

## L-1: Centralization Risk for trusted owners

Contracts have owners with privileged rights to perform admin tasks and need to be trusted to not perform malicious updates or drain funds.

<details><summary>16 Found Instances</summary>


- Found in src/Bolt.sol [Line: 14](src/Bolt.sol#L14)

	```solidity
	contract Bolt is ERC20, ERC20Burnable, ERC20Pausable, Ownable, ERC20Permit, ERC20Capped {
	```

- Found in src/Bolt.sol [Line: 37](src/Bolt.sol#L37)

	```solidity
	    function pause() public onlyOwner {
	```

- Found in src/Bolt.sol [Line: 41](src/Bolt.sol#L41)

	```solidity
	    function unpause() public onlyOwner {
	```

- Found in src/Bolt.sol [Line: 45](src/Bolt.sol#L45)

	```solidity
	    function mint(address to, uint256 amount) public onlyOwner {
	```

- Found in src/Bolt.sol [Line: 64](src/Bolt.sol#L64)

	```solidity
	    function setStakingContract(address _addr) public onlyOwner() {
	```

- Found in src/EStormOracle.sol [Line: 7](src/EStormOracle.sol#L7)

	```solidity
	contract EStormOracle is Ownable {
	```

- Found in src/EStormOracle.sol [Line: 22](src/EStormOracle.sol#L22)

	```solidity
	  function updatePool(bytes32 _pid, int256 _dept, bool _isActive) public onlyOwner() {
	```

- Found in src/EStormOracle.sol [Line: 35](src/EStormOracle.sol#L35)

	```solidity
	  function setStakingContract(address _addr) public onlyOwner {
	```

- Found in src/StakingContract.sol [Line: 13](src/StakingContract.sol#L13)

	```solidity
	contract StakingContract is Pausable, Ownable {
	```

- Found in src/StakingContract.sol [Line: 58](src/StakingContract.sol#L58)

	```solidity
	    ) external onlyOwner {
	```

- Found in src/StakingContract.sol [Line: 225](src/StakingContract.sol#L225)

	```solidity
	    function addGame(string memory _game) external onlyOwner {
	```

- Found in src/StakingContract.sol [Line: 229](src/StakingContract.sol#L229)

	```solidity
	    function setOracle(EStormOracle _oracle) external onlyOwner {
	```

- Found in src/StakingContract.sol [Line: 233](src/StakingContract.sol#L233)

	```solidity
	    function setDevAddress(address _addr) external onlyOwner {
	```

- Found in src/StakingContract.sol [Line: 237](src/StakingContract.sol#L237)

	```solidity
	    function setDevFee(uint8 _newFee) external onlyOwner {
	```

- Found in src/StakingContract.sol [Line: 241](src/StakingContract.sol#L241)

	```solidity
	    function pause() public onlyOwner {
	```

- Found in src/StakingContract.sol [Line: 245](src/StakingContract.sol#L245)

	```solidity
	    function unpause() public onlyOwner {
	```

</details>



## L-2: Unsafe ERC20 Operations should not be used

ERC20 functions may not behave as expected. For example: return values are not always meaningful. It is recommended to use OpenZeppelin's SafeERC20 library.

<details><summary>2 Found Instances</summary>


- Found in src/StakingContract.sol [Line: 123](src/StakingContract.sol#L123)

	```solidity
	        bolt.transfer(devaddr, fee);
	```

- Found in src/StakingContract.sol [Line: 124](src/StakingContract.sol#L124)

	```solidity
	        bolt.transfer(_msgSender(), _amount);
	```

</details>



## L-3: Solidity pragma should be specific, not wide

Consider using a specific version of Solidity in your contracts instead of a wide version. For example, instead of `pragma solidity ^0.8.0;`, use `pragma solidity 0.8.0;`

<details><summary>3 Found Instances</summary>


- Found in src/Bolt.sol [Line: 3](src/Bolt.sol#L3)

	```solidity
	pragma solidity ^0.8.22;
	```

- Found in src/EStormOracle.sol [Line: 3](src/EStormOracle.sol#L3)

	```solidity
	pragma solidity ^0.8.22;
	```

- Found in src/StakingContract.sol [Line: 3](src/StakingContract.sol#L3)

	```solidity
	pragma solidity ^0.8.22;
	```

</details>



## L-4: Missing checks for `address(0)` when assigning values to address state variables

Check for `address(0)` when assigning values to address state variables.

<details><summary>7 Found Instances</summary>


- Found in src/Bolt.sol [Line: 27](src/Bolt.sol#L27)

	```solidity
	        messageSigner = _messageSigner;
	```

- Found in src/Bolt.sol [Line: 65](src/Bolt.sol#L65)

	```solidity
	        stakingContract = _addr;
	```

- Found in src/EStormOracle.sol [Line: 36](src/EStormOracle.sol#L36)

	```solidity
	    stakingContract = _addr;
	```

- Found in src/StakingContract.sol [Line: 50](src/StakingContract.sol#L50)

	```solidity
	        oracle = _oracle;
	```

- Found in src/StakingContract.sol [Line: 51](src/StakingContract.sol#L51)

	```solidity
	        devaddr = _devaddr;
	```

- Found in src/StakingContract.sol [Line: 230](src/StakingContract.sol#L230)

	```solidity
	        oracle = _oracle;
	```

- Found in src/StakingContract.sol [Line: 234](src/StakingContract.sol#L234)

	```solidity
	        devaddr = _addr;
	```

</details>



## L-5: `public` functions not used internally could be marked `external`

Instead of marking a function as `public`, consider marking it as `external` if it is not used internally.

<details><summary>14 Found Instances</summary>


- Found in src/Bolt.sol [Line: 30](src/Bolt.sol#L30)

	```solidity
	    function mintWithMessage(bytes32 _hash, uint256 _amount, uint256 _nonce, bytes memory _signature) public {
	```

- Found in src/Bolt.sol [Line: 37](src/Bolt.sol#L37)

	```solidity
	    function pause() public onlyOwner {
	```

- Found in src/Bolt.sol [Line: 41](src/Bolt.sol#L41)

	```solidity
	    function unpause() public onlyOwner {
	```

- Found in src/Bolt.sol [Line: 45](src/Bolt.sol#L45)

	```solidity
	    function mint(address to, uint256 amount) public onlyOwner {
	```

- Found in src/Bolt.sol [Line: 52](src/Bolt.sol#L52)

	```solidity
	    function safeEBoltTransfer(address _to, uint256 _amount) public {
	```

- Found in src/Bolt.sol [Line: 64](src/Bolt.sol#L64)

	```solidity
	    function setStakingContract(address _addr) public onlyOwner() {
	```

- Found in src/EStormOracle.sol [Line: 22](src/EStormOracle.sol#L22)

	```solidity
	  function updatePool(bytes32 _pid, int256 _dept, bool _isActive) public onlyOwner() {
	```

- Found in src/EStormOracle.sol [Line: 29](src/EStormOracle.sol#L29)

	```solidity
	  function lockPool(bytes32 _pid) public {
	```

- Found in src/EStormOracle.sol [Line: 35](src/EStormOracle.sol#L35)

	```solidity
	  function setStakingContract(address _addr) public onlyOwner {
	```

- Found in src/StakingContract.sol [Line: 103](src/StakingContract.sol#L103)

	```solidity
	    function withdraw(bytes32 _pid, uint256 _amount) public {
	```

- Found in src/StakingContract.sol [Line: 129](src/StakingContract.sol#L129)

	```solidity
	    function convertToAssets(
	```

- Found in src/StakingContract.sol [Line: 221](src/StakingContract.sol#L221)

	```solidity
	    function getPool(bytes32 _pid) public view returns (PoolInfo memory) {
	```

- Found in src/StakingContract.sol [Line: 241](src/StakingContract.sol#L241)

	```solidity
	    function pause() public onlyOwner {
	```

- Found in src/StakingContract.sol [Line: 245](src/StakingContract.sol#L245)

	```solidity
	    function unpause() public onlyOwner {
	```

</details>



## L-6: Define and use `constant` variables instead of using literals

If the same constant literal value is used multiple times, create a constant state variable and reference it throughout the contract.

<details><summary>2 Found Instances</summary>


- Found in src/StakingContract.sol [Line: 147](src/StakingContract.sol#L147)

	```solidity
	                pool.totalShares + 10 ** bolt.decimals(),
	```

- Found in src/StakingContract.sol [Line: 170](src/StakingContract.sol#L170)

	```solidity
	                pool.totalShares + 10 ** bolt.decimals(),
	```

</details>



## L-7: Event is missing `indexed` fields

Index event fields make the field more quickly accessible to off-chain tools that parse events. However, note that each index field costs extra gas during emission, so it's not necessarily best to index the maximum allowed per event (three fields). Each event should use three indexed fields if there are three or more fields, and gas usage is not particularly of concern for the events in question. If there are fewer than three fields, all of the fields should be indexed.

<details><summary>5 Found Instances</summary>


- Found in src/Bolt.sol [Line: 15](src/Bolt.sol#L15)

	```solidity
	    event MintWithMessage(address to, bytes32 hashUsed, bytes signatureUsed, uint256 amountMinted, uint256 nonceUsed);
	```

- Found in src/EStormOracle.sol [Line: 8](src/EStormOracle.sol#L8)

	```solidity
	  event PoolUpdated(bytes32 pid, int256 dept, bool isActive, uint256 lastRewardUpdate);
	```

- Found in src/StakingContract.sol [Line: 16](src/StakingContract.sol#L16)

	```solidity
	    event PoolCreated(
	```

- Found in src/StakingContract.sol [Line: 23](src/StakingContract.sol#L23)

	```solidity
	    event Deposit(address staker, uint256 amount, bytes32 pid);
	```

- Found in src/StakingContract.sol [Line: 24](src/StakingContract.sol#L24)

	```solidity
	    event Withdraw(address staker, uint256 amount, uint256 fee, bytes32 pid);
	```

</details>



## L-8: Empty `require()` / `revert()` statements

Use descriptive reason strings or custom errors for revert paths.

<details><summary>1 Found Instances</summary>


- Found in src/EStormOracle.sol [Line: 30](src/EStormOracle.sol#L30)

	```solidity
	    require(msg.sender == stakingContract);
	```

</details>



## L-9: PUSH0 is not supported by all chains

Solc compiler version 0.8.20 switches the default target EVM version to Shanghai, which means that the generated bytecode will include PUSH0 opcodes. Be sure to select the appropriate EVM version in case you intend to deploy on a chain other than mainnet like L2 chains that may not support PUSH0, otherwise deployment of your contracts will fail.

<details><summary>3 Found Instances</summary>


- Found in src/Bolt.sol [Line: 3](src/Bolt.sol#L3)

	```solidity
	pragma solidity ^0.8.22;
	```

- Found in src/EStormOracle.sol [Line: 3](src/EStormOracle.sol#L3)

	```solidity
	pragma solidity ^0.8.22;
	```

- Found in src/StakingContract.sol [Line: 3](src/StakingContract.sol#L3)

	```solidity
	pragma solidity ^0.8.22;
	```

</details>



## L-10: Large literal values multiples of 10000 can be replaced with scientific notation

Use `e` notation, for example: `1e18`, instead of its full numeric value.

<details><summary>1 Found Instances</summary>


- Found in src/Bolt.sol [Line: 26](src/Bolt.sol#L26)

	```solidity
	        _mint(address(this), 15_000_000_000 * 10 ** decimals());
	```

</details>



## L-11: Contract still has TODOs

Contract contains comments with TODOS

<details><summary>1 Found Instances</summary>


- Found in src/StakingContract.sol [Line: 13](src/StakingContract.sol#L13)

	```solidity
	contract StakingContract is Pausable, Ownable {
	```

</details>



## L-12: Unused Imports

Redundant import statement. Consider removing it.

<details><summary>2 Found Instances</summary>


- Found in src/Bolt.sol [Line: 11](src/Bolt.sol#L11)

	```solidity
	import {console} from "forge-std/console.sol";
	```

- Found in src/StakingContract.sol [Line: 9](src/StakingContract.sol#L9)

	```solidity
	import {console} from "forge-std/console.sol";
	```

</details>



## L-13: State variable changes but no event is emitted.

State variable changes in this function but no event is emitted.

<details><summary>7 Found Instances</summary>


- Found in src/Bolt.sol [Line: 64](src/Bolt.sol#L64)

	```solidity
	    function setStakingContract(address _addr) public onlyOwner() {
	```

- Found in src/EStormOracle.sol [Line: 29](src/EStormOracle.sol#L29)

	```solidity
	  function lockPool(bytes32 _pid) public {
	```

- Found in src/EStormOracle.sol [Line: 35](src/EStormOracle.sol#L35)

	```solidity
	  function setStakingContract(address _addr) public onlyOwner {
	```

- Found in src/StakingContract.sol [Line: 225](src/StakingContract.sol#L225)

	```solidity
	    function addGame(string memory _game) external onlyOwner {
	```

- Found in src/StakingContract.sol [Line: 229](src/StakingContract.sol#L229)

	```solidity
	    function setOracle(EStormOracle _oracle) external onlyOwner {
	```

- Found in src/StakingContract.sol [Line: 233](src/StakingContract.sol#L233)

	```solidity
	    function setDevAddress(address _addr) external onlyOwner {
	```

- Found in src/StakingContract.sol [Line: 237](src/StakingContract.sol#L237)

	```solidity
	    function setDevFee(uint8 _newFee) external onlyOwner {
	```

</details>



## L-14: State variable could be declared immutable

State variables that are should be declared immutable to save gas. Add the `immutable` attribute to state variables that are only changed in the constructor

<details><summary>1 Found Instances</summary>


- Found in src/Bolt.sol [Line: 20](src/Bolt.sol#L20)

	```solidity
	    address messageSigner;
	```

</details>



