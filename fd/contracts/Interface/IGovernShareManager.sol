pragma solidity >=0.4.22 <0.6.0;

interface IGovernShareManager {
    function enter(address _account,uint256 _amount) external returns(bool);
    function quit(uint256 _amount) external returns(bool);
}