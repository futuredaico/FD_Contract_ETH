pragma solidity >=0.4.22 <0.6.0;

import "../Interface/IPermission.sol";

contract Permission is IPermission  {

    bytes32 public constant EMPTY_PARAM_HASH = 0x290decd9548b62a8d60345a988386fc84ba6bc95484008f6362f93160ef3e563;

    mapping(bytes32 => bytes32) private permissions;

    event AddPermission(address indexed grantor, address indexed app, bytes32 indexed vData, bytes32 paramsHash);

    /// @notice _app 授予 _grantor 权力，允许_grantor调用_app.
    function addPermission(address _grantor,address _app,bytes32 _vData) external{
        permissions[permissionHash(_grantor, _app, _vData)] = EMPTY_PARAM_HASH;
        emit AddPermission(_grantor,_app,_vData,EMPTY_PARAM_HASH);
    }

    function addPermission(address _grantor,address _app,bytes32 _vData,bytes32 _paramsHash) external{
        permissions[permissionHash(_grantor, _app, _vData)] = _paramsHash;
        emit AddPermission(_grantor,_app,_vData,_paramsHash);
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