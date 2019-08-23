pragma solidity >=0.4.22 <0.6.0;

import "./AppManager.sol";
import "../lib/SafeMath.sol";

contract FutureDaoApp {
    using SafeMath for uint256;

    AppManager public appManager;

    bytes32 public constant EMPTY_PARAM_HASH = 0x290decd9548b62a8d60345a988386fc84ba6bc95484008f6362f93160ef3e563;

    modifier auth(bytes32 _vData){
        require(appManager.verifyPermission(msg.sender,address(this),_vData,EMPTY_PARAM_HASH),"No permission to invoke the contract");
        _;
    }
}