const AppManager = artifacts.require("AppManager");
const Co = artifacts.require("Co");
const FdToken = artifacts.require("FdToken");
const TradeFundPool = artifacts.require("TradeFundPool");

module.exports = function(deployer) {
    deployer.deploy(AppManager).then(function() {
        return deployer.deploy(Co,AppManager.address,1000*Math.pow(10,9),300).then(function(){
            return deployer.deploy(FdToken,AppManager.address,"Vb",8,"V").then(function(){
                return deployer.deploy(TradeFundPool,AppManager.address,FdToken.address,30*24*60*60,Math.pow(10,20).toString(),Co.address);
            });
        });
      });
};
