import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export default buildModule("EBolts", (m) => {
  const defaultAdmin = "0xdFdF2cdA07EaEE0AC39101e857707817Ad053d9f";
  const pauser = "0xdFdF2cdA07EaEE0AC39101e857707817Ad053d9f";
  const minter = "0xdFdF2cdA07EaEE0AC39101e857707817Ad053d9f";
  const defaultNotary = "0x1954db4217eAB240F0094c8a7FFA5Ad47857F435";

  const contract = m.contract("EBolts", [
    defaultAdmin,
    pauser,
    minter,
    defaultNotary
  ]);

  return { contract };
});