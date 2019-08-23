pragma solidity >=0.4.22 <0.6.0;

import "../lib/SafeMath.sol";

contract Tap {
    using SafeMath for uint256;
    uint256 startTime;
    uint256 endTime;
    uint256 allMoney;
    address payable owner;

    constructor(address payable _owner,uint256 _startTime,uint256 _endTime,uint256 _allMoney) public{
        owner = _owner;
        startTime = _startTime;
        endTime = _endTime;
        allMoney = _allMoney;
    }

    function GetMoney() public payable{
        uint256 times = now.sub(startTime).div(1 days);
        uint256 allTimes = endTime.sub(startTime).div(1 days);
        uint256 canGetMoney = allTimes == 0 ? address(this).balance : address(this).balance.mul(times).div(allTimes);
        owner.transfer(canGetMoney);
    }

    function() external payable{
    }
}