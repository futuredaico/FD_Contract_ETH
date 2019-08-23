pragma solidity >=0.4.22 <0.6.0;

contract Own {
    address public owner;

    constructor() public{
        owner = msg.sender;
    }

    modifier isOwner(address _addr){
        require(_addr == owner,"Permission denied");
        _;
    }

    function changeOwner(address _newOwner) public isOwner(msg.sender){
        require(msg.sender != _newOwner,"Need a new address");
        owner = _newOwner;
    }
}