const AppManager = artifacts.require("AppManager");
const Co = artifacts.require("Co");
const FdToken = artifacts.require("FdToken");
const TradeFundPool = artifacts.require("TradeFundPool");
const GovernShareManager = artifacts.require("GovernShareManager");
const Vote_ApplyFund = artifacts.require("Vote_ApplyFund");

module.exports = function(deployer) {
    deployer.deploy(AppManager).then(function() {
        return deployer.deploy(Co,AppManager.address,1000*Math.pow(10,9),300).then(function(){
            return deployer.deploy(FdToken,AppManager.address,"Vb",8,"V").then(function(){
                deployer.deploy(GovernShareManager,AppManager.address,FdToken.address);
                deployer.deploy(Vote_ApplyFund,AppManager.address);
                return deployer.deploy(TradeFundPool,AppManager.address,FdToken.address,30*24*60*60,Math.pow(10,20).toString(),Co.address);
            });
        });
      });
};
