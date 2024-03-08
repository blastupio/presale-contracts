//SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "./PresaleBSC.sol";

contract PresaleBlast is PresaleBSC {
  using SafeERC20 for IERC20;

  IERC20 public immutable usdbToken;
  IERC20 public immutable wethToken;

  constructor(
    AggregatorV3Interface COIN_PRICE_FEED_,
    IERC20 usdtToken_,
    IERC20 usdcToken_,
    IERC20 usdbToken_,
    IERC20 wethToken_,
    address protocolWallet_,
    address DAO,
    address operator
  ) PresaleBSC(
    COIN_PRICE_FEED_,
    usdcToken_,
    usdtToken_,
    protocolWallet_,
    DAO,
    operator
  ){
    usdbToken = usdbToken_;
    wethToken = wethToken_;
  }

  function depositUSDBTo(address to, uint256 amount, address referrer) external whenNotPaused {
    (uint256 chargeBack, uint256 spendedValue) = _depositChecksAndEffects(usdbToken, to, amount, true);

    _depositInteractions(usdbToken, amount, chargeBack, spendedValue);

    emit TokensBought(address(usdbToken), to, referrer, spendedValue);
  }

  function depositUSDB(uint256 amount, address referrer) external whenNotPaused {
    (uint256 chargeBack, uint256 spendedValue) = _depositChecksAndEffects(usdbToken, msg.sender, amount, true);

    _depositInteractions(usdbToken, amount, chargeBack, spendedValue);

    emit TokensBought(address(usdbToken), msg.sender, referrer, spendedValue);
  }

  function depositWETHTo(address to, uint256 amount, address referrer) external whenNotPaused {
    (uint256 chargeBack, uint256 spendedValue) = _depositChecksAndEffects(wethToken, to, amount, false);

    _depositInteractions(wethToken, amount, chargeBack, spendedValue);

    emit TokensBought(address(wethToken), to, referrer, spendedValue);
  }

  function depositWETH(uint256 amount, address referrer) external whenNotPaused {
    (uint256 chargeBack, uint256 spendedValue) = _depositChecksAndEffects(wethToken, msg.sender, amount, false);

    _depositInteractions(wethToken, amount, chargeBack, spendedValue);

    emit TokensBought(address(wethToken), msg.sender, referrer, spendedValue);
  }
}
