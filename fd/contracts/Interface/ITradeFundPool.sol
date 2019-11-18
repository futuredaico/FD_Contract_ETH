pragma solidity >=0.4.22 <0.6.0;

interface ITradeFundPool {
    function changeRatio(uint256 _ratio) external;
    function buy(uint256 _minBuyToken,uint256 tag) external payable;
    function sell(uint256 _amount,uint256 _maxGasValue) external;
    function revenue() external payable;
    function clearing(address payable _clearingContractAddress,uint256 _ratio) external;
}