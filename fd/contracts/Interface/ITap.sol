pragma solidity >=0.4.22 <0.6.0;

interface ITap {

    function GetMoney() external payable;

    function GetMoneyBackToFund() external payable;
}