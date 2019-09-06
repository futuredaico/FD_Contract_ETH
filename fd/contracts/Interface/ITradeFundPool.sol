pragma solidity >=0.4.22 <0.6.0;

interface ITradeFundPool {
    function windingUp() external;
    function crowdfunding(bool needBack) external payable;
    function buy() external payable;
    function sell(uint256 amount) external;
    function revenue() external payable;
    function sendEth(address payable _who,uint256 _value) external;
    function clearing(address payable _clearingContractAddress,uint256 _ratio) external;
    function() external payable;
}