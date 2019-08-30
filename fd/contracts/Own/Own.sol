pragma solidity >=0.4.22 <0.6.0;

contract Own {
    address public owner;

    mapping(address => bool) whiteList;

    constructor() public{
        owner = msg.sender;
        whiteList[owner] = true;
    }

    modifier isOwner(address _addr){
        require(_addr == owner,"Permission denied");
        _;
    }

    modifier inWhiteList(address _addr){
        require(whiteList[_addr] == true,"Permission denied");
        _;
    }

    function addWhiteList(address _addr) public isOwner(msg.sender){
        whiteList[_addr] = true;
    }

    function removeWhiteList(address _addr) public isOwner(msg.sender){
        whiteList[_addr] = false;
    }

    function changeOwner(address _newOwner) public isOwner(msg.sender){
        require(msg.sender != _newOwner,"Need a new address");
        owner = _newOwner;
    }
}