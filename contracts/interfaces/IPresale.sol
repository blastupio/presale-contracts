//SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

interface IPresale {
    struct StageData {
        uint96 cost;
        uint160 amount;
    }

    event TokensBought(address indexed token, address indexed user, address indexed referrer, uint256 amount);
    event AmountAndUSD(address indexed user, uint256 amount, int256 usd);
    event StageUpdated(uint256 currentStage);

    function updateProtocolWallet(address wallet) external;
    function setStage(uint256 stageIterator_) external;
    function updateTotalSold(uint256 amount) external;
    function pause() external;
    function unpause() external;

    function depositUSDCTo(address to, uint256 amount, address referrer) external;
    function depositUSDTTo(address to, uint256 amount, address referrer) external;

    function depositUSDC(uint256 amount, address referrer) external;
    function depositUSDT(uint256 amount, address referrer) external;
}