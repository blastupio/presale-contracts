//SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "./IPresale.sol";

interface IPresaleBlast is IPresale {
    function depositUSDBTo(address to, uint256 amount, address referrer) external;
    function depositWETHTo(address to, uint256 amount, address referrer) external;

    function depositUSDB(uint256 amount, address referrer) external;
    function depositWETH(uint256 amount, address referrer) external;
}
