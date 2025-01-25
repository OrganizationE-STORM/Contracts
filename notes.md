This test testFuzz_balancesAfterDepositNegReward has a require that fails for the DEVADDR balance after 
two deposits with negative reward. 
With a rewardAmount of -51335273255337 the DEVADDR balance should be 51335273255337, but if our ERC20 
contract does not have that amount of tokens it just transfer the remaining tokens to the staker.
Ask Ruben how and if we should modify this behavior. As temporary fix I've update the amount of tokens
minted when the contract is deployed, from 2500000 to 15_000_000_000.


Please review how we transfer the ERC20 tokens from the withdraw function to the addresses. Try to look at how OZ does and adapt that model. Take a look especially at "safeEBoltTransfer" function.


Problem spotted for the following test "testFuzz_balancesAreCorrectAfterWithdrawWithNegativeReward". 
The tests do not pass because the third staker is trying to unstake more than the amount of tokens available
in the pool. The problem was spotted inside the function "updatePoolInfoAfterWithdraw". 
Specifically: ```pool.totalStaked -= _amount;``` causes an underflow. 