module.exports = async ({
    getNamedAccounts,
    deployments,
  }) => {
    let networkName;
    const DID_CONTRACT = "DidV2";
    const {deploy} = deployments;
    const {deployer,admin} = await getNamedAccounts();
    logic = await deployments.get(DID_CONTRACT)

    await deploy('EternalStorageProxy', {
      from: deployer,
      args: [logic.address,admin,"0x"],
      log: true,
      waitConfirmations:1,
    });
  };

  module.exports.tags = ["EXTERNAL_STORAGE"];