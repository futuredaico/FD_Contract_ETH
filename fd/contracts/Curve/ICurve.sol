pragma solidity >=0.4.22 <0.6.0;
import "../apps/FutureDaoApp.sol";

interface ICurve {
    function getVauleToGovernFundPool(uint256 _totalValue) external view returns(uint256);
    function getBuyAmount(uint256 _value,uint256 _totalSupply) external view returns(uint256);
    function getSellValue(uint256 _sellAmount,uint256 _sellReserve,uint256 _totalSupply) external view returns(uint256);
    function getCrowdFundPrice(uint256 _crowdFundMoney) external view returns(uint256);
}