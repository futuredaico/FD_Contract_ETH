pragma solidity >=0.4.22 <0.6.0;

import "../Permission/Permission.sol";
import "../Own/Own.sol";
import "../Govern/IGovernShareManager.sol";
import "../Financing/ITradeFundPool.sol";


contract AppManager is Own{

    IPermission private permission;

    ITradeFundPool private tradeFundPool;

    IGovernShareManager private governShareManager;

    constructor() public {
        permission = new Permission();
    }

    function getGovernShareManager() external view returns(address) {
        require(address(governShareManager) != address(0),"The address cannot be empty");
        return address(governShareManager);
    }

    function getTradeFundPool() external view returns(address){
        require(address(tradeFundPool) != address(0),"The address cannot be empty");
        return address(tradeFundPool);
    }

    function addPermission(address _grantor,address _app,bytes32 _vData) external isOwner(msg.sender){
        permission.addPermission(_grantor,_app,_vData);
    }

    function addPermission(address _grantor,address _app,bytes32 _vData,bytes32 _paramsHash) external isOwner(msg.sender){
        permission.addPermission(_grantor,_app,_vData,_paramsHash);
    }

    function verifyPermission(address _grantor,address _app,bytes32 _vData,bytes32 _paramsHash) external view returns (bool){
        permission.verifyPermission(_grantor,_app,_vData,_paramsHash);
    }
}