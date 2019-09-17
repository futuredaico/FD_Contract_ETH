pragma solidity >=0.4.22 <0.6.0;

import "../Own/Own.sol";
import "../Interface/IPermission.sol";

contract Permission is IPermission , Own{

    bytes32 public constant EMPTY_PARAM_HASH = 0x290decd9548b62a8d60345a988386fc84ba6bc95484008f6362f93160ef3e563;

    mapping(bytes32 => bytes32) private permissions;

    event AddPermission(address indexed grantor, address indexed app, bytes32 indexed vData, bytes32 paramsHash);
    event ChangePermission(
        address indexed newGrantor,
        address indexed app,
        bytes32 indexed vData,
        bytes32 paramsHash
    );
    event DeletePermission(address indexed grantor, address indexed app, bytes32 indexed vData);

    /// @notice _app 授予 _grantor 权力，允许_grantor调用_app.
    function addPermission(address _grantor,address _app,bytes32 _vData) external isOwner(msg.sender){
        permissions[permissionHash(_grantor, _app, _vData)] = EMPTY_PARAM_HASH;
        emit AddPermission(_grantor,_app,_vData,EMPTY_PARAM_HASH);
    }

    function changePermission(address _oldGrantor,address _newGrantor,address _app,bytes32 _vData) external isOwner(msg.sender){
        require(permissions[permissionHash(_oldGrantor, _app, _vData)] == EMPTY_PARAM_HASH,"Forbidden");
        permissions[permissionHash(_newGrantor, _app, _vData)] = EMPTY_PARAM_HASH;
        delete permissions[permissionHash(_oldGrantor, _app, _vData)];
        emit ChangePermission(_newGrantor,_app,_vData,EMPTY_PARAM_HASH);
    }

    function addPermission(address _grantor,address _app,bytes32 _vData,bytes32 _paramsHash) external isOwner(msg.sender){
        permissions[permissionHash(_grantor, _app, _vData)] = _paramsHash;
        emit AddPermission(_grantor,_app,_vData,_paramsHash);
    }

    function changePermission(address _oldGrantor,address _newGrantor,address _app,bytes32 _vData,bytes32 _paramsHash)
    external
    isOwner(msg.sender)
    {
        require(permissions[permissionHash(_oldGrantor, _app, _vData)] == _paramsHash,"Forbidden");
        permissions[permissionHash(_newGrantor, _app, _vData)] = _paramsHash;
        delete permissions[permissionHash(_oldGrantor, _app, _vData)];
        emit ChangePermission(_newGrantor,_app,_vData,_paramsHash);
    }

    function deletePermission(address _grantor,address _app,bytes32 _vData) external isOwner(msg.sender){
        delete permissions[permissionHash(_grantor, _app, _vData)];
        emit DeletePermission(_grantor,_app,_vData);
    }

    function verifyPermission(address _grantor,address _app,bytes32 _vData,bytes32 _paramsHash) external view returns(bool){
        if(bytes32(permissions[permissionHash(_grantor, _app, _vData)]) == _paramsHash)
            return true;
        return false;
    }

    function permissionHash(address _grantor,address _app,bytes32 _vData) internal pure returns(bytes32){
        return keccak256(abi.encodePacked("PERMISSION",_grantor,_app,_vData));
    }
}