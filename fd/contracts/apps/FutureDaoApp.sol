pragma solidity >=0.4.22 <0.6.0;

import "./AppManager.sol";
import "../lib/SafeMath.sol";
import "../Interface/IERC20.sol";

contract FutureDaoApp {
    using SafeMath for uint256;

    AppManager public appManager;

    address public assetAddress;

    bytes32 public constant EMPTY_PARAM_HASH = 0x290decd9548b62a8d60345a988386fc84ba6bc95484008f6362f93160ef3e563;

    constructor(AppManager _appManager) public{
        appManager = _appManager;
    }

    modifier auth(bytes32 _vData){
        require(appManager.verifyPermission(msg.sender,address(this),_vData,EMPTY_PARAM_HASH),"No permission to invoke the Contract");
        _;
    }
    function getAppManagerAddress() public view returns(address){
        return address(appManager);
    }

    function balance(address _addr) public view returns(uint256){
        return IERC20(assetAddress).balanceOf(_addr);
    }

    function transferF(address from,address to,uint256 amount) internal {
        bool r = IERC20(assetAddress).transferFrom(from,to,amount);
        require(r,"asset transferFrom error");
    }

    function transferM(address to,uint256 amount) internal {
        bool r = IERC20(assetAddress).transfer(to,amount);
        require(r,"asset transferFrom error");
    }
}