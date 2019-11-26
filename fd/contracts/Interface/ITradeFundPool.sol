pragma solidity >=0.4.22 <0.6.0;

interface ITradeFundPool {
    function changeRatio(uint256 _ratio,uint256 _minValue,uint256 _maxValue) external;
    function buy(uint256 _assetValue,uint256 _minBuyToken,string calldata tag) external payable;
    function sell(uint256 _amount,uint256 _minGasValue) external;
    function revenue(uint256 _assetValue) external payable;
    function clearing(address payable _clearingContractAddress,uint256 _ratio) external;
}