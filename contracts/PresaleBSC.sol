//SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { IERC20, SafeERC20 } from "@1inch/solidity-utils/contracts/libraries/SafeERC20.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "./interfaces/IPresale.sol";

contract PresaleBSC is IPresale, Ownable, Pausable {
  using SafeERC20 for IERC20;

  int32 public constant STABLETOKEN_PRICE = 1e8;
  uint8 public constant PRICEFEED_DECIMALS = 8;
  uint8 public constant TOKEN_PRECISION = 18;

  AggregatorV3Interface public immutable COIN_PRICE_FEED;

  IERC20 public immutable usdcToken;
  IERC20 public immutable usdtToken;

  address public protocolWallet;

  uint256 public totalTokensSold;
  uint256 public totalSoldInUSD; //NOTE Precision is 8 decimals

  uint256 public stageIterator;
  StageData[] public stages;

  mapping(address user => uint256 balance) public balances;

  constructor(
    AggregatorV3Interface COIN_PRICE_FEED_,
    IERC20 usdcToken_,
    IERC20 usdtToken_,
    address protocolWallet_,
    address admin
  ) Ownable(admin) {
    COIN_PRICE_FEED = COIN_PRICE_FEED_;

    usdcToken = usdcToken_;
    usdtToken = usdtToken_;

    protocolWallet = protocolWallet_;

    stages.push(StageData(2e6, 25e5)); // 0.02
    stages.push(StageData(3e6, 25e5)); // 0.03
    stages.push(StageData(4e6, 625e4)); // 0.04
    stages.push(StageData(5e6, 275e5)); // 0.05
    stages.push(StageData(55e5, 375e5)); // 0.055
    stages.push(StageData(6e6, 4125e4)); // 0.06
    stages.push(StageData(65e5, 375e5)); // 0.065
    stages.push(StageData(7e6, 35e6)); // 0.07
    stages.push(StageData(8e6, 75e5)); // 0.08
    stages.push(StageData(9e6, 25e5)); // 0.09
    stages.push(StageData(0, 0));
  }

  function updateProtocolWallet(address wallet) external onlyOwner {
      protocolWallet = wallet;
  }

  function setStage(uint256 stageIterator_) external onlyOwner {
    require(stages.length >= stageIterator_, "Presale: Wrong iterator");

    stageIterator = stageIterator_;
  }

  function updateTotalSold(uint256 amount) external onlyOwner {
    totalTokensSold = amount;
  }

  function pause() external onlyOwner {
    _pause();
  }

  function unpause() external onlyOwner {
    _unpause();
  }

  function rescueFunds(IERC20 token, uint256 amount) external onlyOwner {
      if (address(token) == address(0)) {
          require(amount <= address(this).balance, "Presale: Wrong amount");
          (bool success, ) = payable(msg.sender).call{value: amount}("");

          require(success, "Payout: Transfer coin failed");
      } else {
          require(amount <= token.balanceOf(address(this)), "Presale: Wrong amount");

          token.safeTransfer(protocolWallet, amount);
      }
  }

  function depositUSDCTo(address to, uint256 amount, address referrer) external whenNotPaused {
    (uint256 chargeBack, uint256 spendedValue) = _depositChecksAndEffects(to, amount, true);

    _depositInteractions(usdcToken, amount, chargeBack, spendedValue);

    emit TokensBought(address(usdcToken), to, referrer, spendedValue);
  }

  function depositUSDC(uint256 amount, address referrer) external whenNotPaused {
    (uint256 chargeBack, uint256 spendedValue) = _depositChecksAndEffects(msg.sender, amount, true);

    _depositInteractions(usdcToken, amount, chargeBack, spendedValue);

    emit TokensBought(address(usdcToken), msg.sender, referrer, spendedValue);
  }

  function depositUSDTTo(address to, uint256 amount, address referrer) external whenNotPaused {
    (uint256 chargeBack, uint256 spendedValue) = _depositChecksAndEffects(to, amount, true);

    _depositInteractions(usdtToken, amount, chargeBack, spendedValue);

    emit TokensBought(address(usdtToken), to, referrer, spendedValue);
  }

  function depositUSDT(uint256 amount, address referrer) external whenNotPaused {
    (uint256 chargeBack, uint256 spendedValue) = _depositChecksAndEffects(msg.sender, amount, true);

    _depositInteractions(usdtToken, amount, chargeBack, spendedValue);

    emit TokensBought(address(usdtToken), msg.sender, referrer, spendedValue);
  }

  function depositCoinTo(address to, address referrer) public payable whenNotPaused {
    (uint256 chargeBack, uint256 spendedValue) = _depositChecksAndEffects(to, msg.value, false);

    (bool success, ) = payable(protocolWallet).call{value: spendedValue}("");
    require(success, "Presale: Coin transfer failed");

    if(chargeBack > 0) {
      (success, ) = payable(msg.sender).call{value: chargeBack}("");
      require(success, "Presale: Coin transfer failed");
    }

    emit TokensBought(address(0), to, referrer, spendedValue);
  }

  function depositCoin(address referrer) public payable whenNotPaused {
    (uint256 chargeBack, uint256 spendedValue) = _depositChecksAndEffects(msg.sender, msg.value, false);

    (bool success, ) = payable(protocolWallet).call{value: spendedValue}("");
    require(success, "Presale: Coin transfer failed");

    if(chargeBack > 0) {
      (success, ) = payable(msg.sender).call{value: chargeBack}("");
      require(success, "Presale: Coin transfer failed");
    }

    emit TokensBought(address(0), msg.sender, referrer, spendedValue);
  }

  function _depositChecksAndEffects(
    address to,
    uint256 value,
    bool isStableToken
  ) internal returns (uint256 chargeBack, uint256 spendedValue) {
    require(stages[stageIterator].amount != 0, "PreSale: is ended");

    (uint256 tokensToTransfer, uint256 coinPrice) = _calculateAmount(isStableToken, value);
    (chargeBack, spendedValue) = _purchase(to, coinPrice, tokensToTransfer, value);
  }

  function _depositInteractions(
    IERC20 token,
    uint256 amount,
    uint256 chargeBack,
    uint256 spendedValue
  ) private {
    token.safeTransferFrom(msg.sender, address(this), amount);
    token.safeTransfer(protocolWallet, spendedValue);
    if(chargeBack > 0) token.safeTransfer(msg.sender, chargeBack);
  }

  function _calculateAmount(bool isStableToken, uint256 value) private view returns (uint256 amount, uint256 price) {
    int256 coinPrice;

    if (isStableToken) {
      coinPrice = STABLETOKEN_PRICE;
    } else {
      (, coinPrice, , , ) = COIN_PRICE_FEED.latestRoundData();
    }

    uint256 expectedAmount = uint(coinPrice) * value / uint(stages[stageIterator].cost);

    return (expectedAmount / 10 ** (TOKEN_PRECISION), uint(coinPrice));
  }

  function _purchase(
    address to,
    uint256 coinPrice,
    uint256 amount,
    uint256 value
  ) private returns (uint256 tokensToChargeBack, uint256 spendedValue) {
    StageData storage crtStage =  stages[stageIterator];

    if (uint(crtStage.amount) < amount) {
      spendedValue = crtStage.amount * crtStage.cost;
    } else {
      spendedValue = amount * crtStage.cost;
    }

    totalSoldInUSD += spendedValue;

    spendedValue *= (1 ether / coinPrice);

    if (uint(crtStage.amount) < amount) {
      balances[to] += crtStage.amount;
      totalTokensSold += crtStage.amount;

      tokensToChargeBack = value - spendedValue;

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
