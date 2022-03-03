const WastedCharacter = artifacts.require("WastedCharacter");

contract("WastedCharacter", () => {
  it("...should deploy and successfully call createInstance using the method's provided gas estimate", async () => {
    const WastedCharacterInstance = await WastedCharacter.new();

    const gasEstimate = await WastedCharacterInstance.createInstance.estimateGas();

    const tx = await WastedCharacterInstance.createInstance({
      gas: gasEstimate
    });
    assert(tx);
  });
});