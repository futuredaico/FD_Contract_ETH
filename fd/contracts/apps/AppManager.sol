pragma solidity >=0.4.22 <0.6.0;

import "../Permission/Permission.sol";
import "../Own/Own.sol";
import "../Interface/IGovernShareManager.sol";
import "../Interface/ITradeFundPool.sol";


contract AppManager is Own{

    IPermission private permission;

    address payable private tradeFundPool;

    address payable private governShareManager;

    address payable private fdToken;

    address public dateTime;

    bool public bool_isInit;

    bytes32 public constant EMPTY_PARAM_HASH = 0x290decd9548b62a8d60345a988386fc84ba6bc95484008f6362f93160ef3e563;

    event OnAddPermission(address indexed grantor, address indexed app, bytes32 indexed vData, bytes32 paramsHash);

    event OnChangePermission(
        address indexed newGrantor,
        address indexed app,
        bytes32 indexed vData,
        bytes32 paramsHash
    );

    event OnDeletePermission(address indexed grantor, address indexed app, bytes32 indexed vData);

    constructor() public {
        permission = new Permission();
    }

    modifier isInit() {
        require(bool_isInit == true,"");
        _;
    }

    function initialize(address payable _tradeFundPool,address payable _governShareManager,address payable _fdToken,address _dateTime)
    external isOwner(msg.sender){
        require(bool_isInit == false,"");
        tradeFundPool = _tradeFundPool;
        governShareManager = _governShareManager;
        fdToken = _fdToken;
        dateTime = _dateTime;
        bool_isInit = true;
    }

    function getGovernShareManager() external view returns(address payable) {
        require(governShareManager != address(0),"The address cannot be empty");
        return governShareManager;
    }

    function getTradeFundPool() external view returns(address payable){
        require(tradeFundPool != address(0),"The address cannot be empty");
        return tradeFundPool;
    }

    function getFdToken() external view returns(address payable){
        require(fdToken != address(0),"The address cannot be empty");
        return fdToken;
    }

    function getDateTime() external view returns(address){
        require(dateTime != address(0),"The address cannot be empty");
        return dateTime;
    }

    function addPermission(address _grantor,address _app,bytes32 _vData) external isInit() isOwner(msg.sender){
        permission.addPermission(_grantor,_app,_vData);
        emit OnAddPermission(_grantor,_app,_vData,EMPTY_PARAM_HASH);
    }

    function changePermission(address _newGrantor,address _app,bytes32 _vData) external isInit(){
        permission.changePermission(msg.sender,_newGrantor,_app,_vData);
        emit OnChangePermission(_newGrantor,_app,_vData,EMPTY_PARAM_HASH);
    }

    function addPermission(address _grantor,address _app,bytes32 _vData,bytes32 _paramsHash)
    external
    isInit()
    isOwner(msg.sender)
    {
        permission.addPermission(_grantor,_app,_vData,_paramsHash);
        emit OnAddPermission(_grantor,_app,_vData,_paramsHash);
    }

    function changePermission(address _newGrantor,address _app,bytes32 _vData,bytes32 _paramsHash) external isInit(){
        permission.changePermission(msg.sender,_newGrantor,_app,_vData,_paramsHash);
        emit OnChangePermission(_newGrantor,_app,_vData,_paramsHash);
    }

    function deletePermission(address _grantor,address _app,bytes32 _vData) external isInit() isOwner(msg.sender){
        permission.deletePermission(_grantor,_app,_vData);
        emit OnDeletePermission(_grantor,_app,_vData);
    }

    function verifyPermission(address _grantor,address _app,bytes32 _vData,bytes32 _paramsHash) external view returns (bool){
        return permission.verifyPermission(_grantor,_app,_vData,_paramsHash);
    }
}