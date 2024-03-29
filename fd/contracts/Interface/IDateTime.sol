pragma solidity >=0.4.22 <0.6.0;

interface IDateTime {
        function isLeapYear(uint16 year) external pure returns (bool);
        function leapYearsBefore(uint16 _year) external pure returns (uint16);
        function getDaysInMonth(uint8 month, uint16 year) external pure returns (uint8);
        function getYear(uint timestamp) external pure returns (uint16);
        function getMonth(uint timestamp) external pure returns (uint8);
        function getDay(uint timestamp) external pure returns (uint8);
        function getHour(uint timestamp) external pure returns (uint8);
        function getMinute(uint timestamp) external pure returns (uint8);
        function getSecond(uint timestamp) external pure returns (uint8);
        function getWeekday(uint timestamp) external pure returns (uint8);
        function toTimestamp(uint16 year, uint8 month, uint8 day) external pure returns (uint timestamp);
        function toTimestamp(uint16 year, uint8 month, uint8 day, uint8 hour) external pure returns (uint timestamp);
        function toTimestamp(uint16 year, uint8 month, uint8 day, uint8 hour, uint8 minute) external pure returns (uint timestamp);
        function toTimestamp(uint16 year, uint8 month, uint8 day, uint8 hour, uint8 minute, uint8 second) external pure returns (uint timestamp);
}