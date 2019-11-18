pragma solidity >=0.4.22 <0.6.0;

import "../lib/SafeMath.sol";
import "../Own/Own.sol";


contract Tap is Own{
    using SafeMath for uint256;
    uint256 startTime;
    uint256 endTime;
    uint256 allMoney;
    address payable fundAddress;
    address payable recipient;

    constructor(
        address payable _owner,
        address payable _fundAddress,
        address payable _recipient,
        uint256 _startTime,
        uint256 _endTime,
        uint256 _allMoney)
    public
    {
        owner = _owner;
        fundAddress = _fundAddress;
        recipient = _recipient;
        startTime = _startTime;
        endTime = _endTime;
        allMoney = _allMoney;
    }

    function GetMoney() public payable{
        uint256 times = now.sub(startTime).div(1 days);
        uint256 allTimes = endTime.sub(startTime).div(1 days);
        uint256 canGetMoney = allTimes == 0 ? address(this).balance : address(this).balance.mul(times).div(allTimes);
        recipient.transfer(canGetMoney);
    }

    function GetMoneyBackToFund() public payable isOwner(msg.sender){
        fundAddress.transfer(address(this).balance);
    }

    function() external payable{
    }
}