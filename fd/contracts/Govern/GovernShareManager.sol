pragma solidity >=0.4.22 <0.6.0;

import "../Interface/IGovernShareManager.sol";
import "../apps/FutureDaoApp.sol";
import "../Interface/IERC20.sol";
import "../Interface/ITradeFundPool.sol";
import "../clearing/ClearingFundPool.sol";


/// @title 自治管钱的合约
/// @author viko
/// @notice 只允许白名单中的合约调用，不允许其他地址调用
contract GovernShareManager is FutureDaoApp , IGovernShareManager{

    /// @notice 发行的股份币的合约地址
    address public token;

    bytes32 public constant GovernShareManager_Enter = keccak256("GovernShareManager_Enter");
    bytes32 public constant GovernShareManager_Quit = keccak256("GovernShareManager_Quit");


    constructor(AppManager _appManager,address _token)  FutureDaoApp(_appManager) public {
        token = _token;
        assetAddress = _appManager.assetAddress();
    }

    function enter(address _account,uint256 _amount) public auth(GovernShareManager_Enter) returns(bool){
        bool r = IERC20(token).mint(_account,_amount);
        require(r,"mint error");
        return true;
    }

    function quit(uint256 _amount) public returns(bool) {
        //计算退出的部分 可以分到多少asset
        uint256 _v = _amount.mul(balance(address(this))).div(IERC20(token).totalSupply());
        IERC20(token).burn(_amount);
        transfer(msg.sender, _v);
        return true;
    }


    function() external payable{
    }
}