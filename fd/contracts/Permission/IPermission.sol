pragma solidity >=0.4.22 <0.6.0;

interface IPermission {

    function addPermission(address _grantor,address _app,bytes32 _vData) external;

    function addPermission(address _grantor,address _app,bytes32 _vData,bytes32 _paramsHash) external;

    function verifyPermission(address _grantor,address _app,bytes32 _vData,bytes32 _paramsHash) external view returns (bool);
}