const AppManager = artifacts.require("AppManager");
const Co = artifacts.require("Co");
const FdToken = artifacts.require("FdToken");
const TradeFundPool = artifacts.require("TradeFundPool");
const GovernShareManager = artifacts.require("GovernShareManager");
const Vote_ApplyFund = artifacts.require("Vote_ApplyFund");
const DateTime = artifacts.require("DateTime");

module.exports = function(deployer) {
    deployer.deploy(AppManager).then(function() {
        return deployer.deploy(Co,AppManager.address,1000*Math.pow(10,9),300).then(function(){
            return deployer.deploy(FdToken,AppManager.address,"Vb",8,"V").then(function(){
                deployer.deploy(GovernShareManager,AppManager.address,FdToken.address);
                deployer.deploy(Vote_ApplyFund,AppManager.address);
                deployer.deploy(DateTime);
                return deployer.deploy(TradeFundPool,AppManager.address,FdToken.address,0,0,Co.address);
            });
        });
      });
};
