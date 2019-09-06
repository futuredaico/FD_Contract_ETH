pragma solidity >=0.4.22 <0.6.0;

interface IGovernShareManager {
    function getFdtInGovern(address _addr) external view returns(uint256);
    function getFdtTotalSupply() external view returns(uint256);
    function setFdtIn(uint256 amount) external returns(bool);
    function getFdtOut(uint256 amount) external returns(bool);
    function lock(address _lockAddr,uint256 _index,uint256 _expireDate,uint256 _lockAmount) external returns(bool);
    function free(address _lockAddr,uint256 _index,uint256 _expireDate) external returns(bool);
    function clearingFdt(address payable _addr_clearingFundPool,address _addr,uint256 amount) external returns(bool);
    function sendEth(address payable _addr,uint256 _value) external payable returns(bool);
    function clearing(address payable _addr_clearingFundPool,uint256 _ratio) external payable returns(bool);
}