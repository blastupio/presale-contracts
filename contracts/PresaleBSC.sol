//SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "./Presale.sol";

contract PresaleBSC is Presale {
  using SafeERC20 for IERC20;

  constructor(
    AggregatorV3Interface COIN_PRICE_FEED_,
    IERC20 usdcToken_,
    IERC20 usdtToken_,
    address protocolWallet_,
    address DAO,
    address operator
  ) Presale(
    COIN_PRICE_FEED_,
    usdcToken_,
    usdtToken_,
    protocolWallet_,
    DAO,
    operator
  ) {}

  function _depositChecksAndEffects(
    IERC20 token,
    address to, 
    uint256 value, 
    bool isStableToken
  ) internal override returns (uint256 chargeBack, uint256 spendedValue) {
    require(stages[stageIterator].amount != 0, "PreSale: is ended");

    (uint256 tokensToTransfer, uint256 coinPrice) = _calculateAmount(isStableToken, value);
    
    (chargeBack, spendedValue) = _purchase(token, to, coinPrice, tokensToTransfer, value);
  }

  function _depositInteractions(
    IERC20 token, 
    uint256 amount, 
    uint256 chargeBack, 
    uint256 spendedValue
  ) internal override {
    token.safeTransferFrom(msg.sender, address(this), amount);
    token.safeTransfer(protocolWallet, spendedValue);
    if(chargeBack > 0) token.safeTransfer(msg.sender, chargeBack);
  }

  function _calculateAmount(bool isStableToken, uint256 value) internal override returns (uint256 amount, uint256 price) {
    int256 coinPrice;

    if (isStableToken) {
      coinPrice = STABLETOKEN_PRICE;
    } else {
      (, coinPrice, , , ) = COIN_PRICE_FEED.latestRoundData();
    }

    uint256 expectedAmount = uint(coinPrice) * value / uint(stages[stageIterator].cost);

    emit AmountAndUSD(msg.sender, expectedAmount, coinPrice);

    return (expectedAmount / 10 ** (TOKEN_PRECISION), uint(coinPrice));
  }

  function _purchase(
    IERC20 token,
    address to, 
    uint256 coinPrice, 
    uint256 amount, 
    uint256 value
  ) internal override returns (uint256 tokensToChargeBack, uint256 spendedValue) {
    StageData storage crtStage =  stages[stageIterator];

    if (uint(crtStage.amount) <= amount) {
      spendedValue = crtStage.amount * crtStage.cost;
    } else {
      spendedValue = amount * crtStage.cost;
    }

    totalSoldInUSD += spendedValue;

    spendedValue *= (1 ether / coinPrice);

    tokensToChargeBack = value - spendedValue;

    if (uint(crtStage.amount) <= amount) {
      balances[to] += crtStage.amount;
      totalTokensSold += crtStage.amount;

      crtStage.amount = 0;
      stageIterator++;

      emit StageUpdated(stageIterator);
    } else {
      balances[to] += amount;

      totalTokensSold += amount;
      crtStage.amount -= uint160(amount);
    }
  }
}
