pragma solidity >=0.4.22 <0.6.0;

import "../apps/FutureDaoApp.sol";
import "../Interface/ICurve.sol";

contract Co is ICurve ,FutureDaoApp{

    uint256 public slope; //1000 * 10**9

    uint256 public alpha; //300

    bytes32 public constant Co_ChangeSlop = keccak256("Co_ChangeSlop");
    bytes32 public constant Co_ChangeAlpha = keccak256("Co_ChangeAlpha");

    event OnChangeSlope(uint256 _slope);
    event OnChangeAlpha(uint256 _alpha);

    constructor(AppManager _appManager,uint256 _slope,uint256 _alpha) FutureDaoApp(_appManager) public {
        slope = _slope;
        alpha = _alpha;
    }

    function changeSlop(uint256 _slope) public auth(Co_ChangeSlop) returns(bool){
        slope = _slope;
        emit OnChangeSlope(_slope);
    }

    function changeAlpha(uint256 _alpha) public auth(Co_ChangeAlpha) returns(bool){
        alpha = _alpha;
        emit OnChangeAlpha(_alpha);
    }

    function getVauleToReserve(uint256 _totalValue) external view returns(uint256){
        return alpha.mul(_totalValue).div(1000);
    }

    function getCrowdFundPrice(uint256 _crowdFundMoney) external view returns(uint256){
        uint256 _n = (_crowdFundMoney.mul(2).mul(1000)).div(slope);
        return _sqrt(_n).div(2).mul(slope).div(1000);
    }

    function getBuyAmount(uint256 _value,uint256 _totalSupply) external view returns(uint256){
        uint256 _n = (_value.mul(2).mul(1000).div(slope)).add(_totalSupply.mul(_totalSupply));
        return _sqrt(_n).sub(_totalSupply);
    }

    function getSellValue(uint256 _sellAmount,uint256 _sellReserve,uint256 _totalSupply) external view returns(uint256){
        uint256 _n = (_sellReserve.mul(_sellAmount)).mul((_totalSupply.mul(2).sub(_sellAmount))).div(_totalSupply).div(_totalSupply);
        return _n;
    }

    ///////////////
    // 内部函数
    //////////////
    function _sqrt(uint256 x) internal pure returns(uint256){
        uint256 z = x.add(1).div(2);
        uint256 y = x;
        while(z < y){
            y = z;
            z = ((x.div(z)).add(z)).div(2);
        }
        return y;
    }
}