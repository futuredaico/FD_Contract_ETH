const AppManager = artifacts.require("AppManager");
const Co = artifacts.require("Co");
const Dai = artifacts.require("Dai");
const SharesB = artifacts.require("SharesB");
const TradeFundPool = artifacts.require("TradeFundPool");
const DateTime = artifacts.require("DateTime");

module.exports = function(deployer) {
    deployer.deploy(Dai,"DAI",8,"dai").then(function(){
        return  deployer.deploy(AppManager,Dai.address).then(function() {
            return deployer.deploy(Co,AppManager.address,1000*Math.pow(10,4),300).then(async function(){
                await deployer.deploy(SharesB,AppManager.address,"SB",8,"B");
                await deployer.deploy(DateTime);
                return deployer.deploy(TradeFundPool,AppManager.address,SharesB.address,Co.address,50);
            });
          });
    });

};
