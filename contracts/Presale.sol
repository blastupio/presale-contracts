//SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { IERC20, SafeERC20 } from "@1inch/solidity-utils/contracts/libraries/SafeERC20.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "./interfaces/IPresale.sol";

contract Presale is IPresale, AccessControl, Pausable {
  using SafeERC20 for IERC20;

  bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

  uint256 public constant DEFAULT_DELAY = 12 hours;

  int32 public constant STABLETOKEN_PRICE = 1e8;
  uint8 public constant STABLE_TOKEN_DECIMALS = 6;
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

  mapping(bytes4 selector => uint256 timestamp) private _timestamps;

  constructor(
    AggregatorV3Interface COIN_PRICE_FEED_,
    IERC20 usdcToken_,
    IERC20 usdtToken_,
    address protocolWallet_,
    address DAO,
    address operator
  ) {
    COIN_PRICE_FEED = COIN_PRICE_FEED_;

    usdcToken = usdcToken_;
    usdtToken = usdtToken_;

    protocolWallet = protocolWallet_;

    stages.push(StageData(2e6, 25e5));
    stages.push(StageData(3e6, 25e5));
    stages.push(StageData(4e6, 625e4));
    stages.push(StageData(5e6, 275e5));
    stages.push(StageData(55e5, 375e5));
    stages.push(StageData(6e6, 4125e4));
    stages.push(StageData(65e5, 375e5));
    stages.push(StageData(7e6, 35e6));
    stages.push(StageData(8e6, 75e5));
    stages.push(StageData(9e6, 25e5));
    stages.push(StageData(0, 0));

    _grantRole(DEFAULT_ADMIN_ROLE, DAO);
    _grantRole(OPERATOR_ROLE, operator);
  }

  //NOTE function selector is: 0xe308a099
  function updateProtocolWallet(address wallet) external onlyRole(DEFAULT_ADMIN_ROLE) {
    uint256 delayedTill = _timestamps[0xe308a099];

    if(delayedTill > 0 && delayedTill <= block.timestamp) {
      protocolWallet = wallet;
    } else {
      _timestamps[0xe308a099] = block.timestamp + DEFAULT_DELAY;
    }
  }

  function setStage(uint256 stageIterator_) external onlyRole(OPERATOR_ROLE) {
    require(stageIterator_ < stages.length, "Presale: Wrong iterator");

    stageIterator = stageIterator_;

    emit StageUpdated(stageIterator);
  }

  //NOTE function selector is: 0x76aa28fc
  function updateTotalSold(uint256 amount) external onlyRole(OPERATOR_ROLE) {
    uint256 delayedTill = _timestamps[0x76aa28fc];

    if(delayedTill > 0 && delayedTill <= block.timestamp) {
      totalTokensSold = amount;
    } else {
      _timestamps[0x76aa28fc] = block.timestamp + DEFAULT_DELAY;
    }
  }

  function pause() external onlyRole(OPERATOR_ROLE) {
    _pause();
  }

  function unpause() external onlyRole(OPERATOR_ROLE) {
    _unpause();
  }

  //NOTE function selector is: 0x78e3214f
  function rescueFunds(IERC20 token, uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
    uint256 delayedTill = _timestamps[0x78e3214f];

    if(delayedTill > 0 && delayedTill <= block.timestamp) {
      if (address(token) == address(0)) {
          require(amount <= address(this).balance, "Presale: Wrong amount");
          (bool success, ) = payable(msg.sender).call{value: amount}("");

          require(success, "Payout: Transfer coin failed");
      } else {
          require(amount <= token.balanceOf(address(this)), "Presale: Wrong amount");

          token.safeTransfer(protocolWallet, amount);
      }
    } else {
      _timestamps[0x78e3214f] = block.timestamp + DEFAULT_DELAY;
    }
  }

  function depositUSDCTo(address to, uint256 amount, address referrer) external whenNotPaused {
    (uint256 chargeBack, uint256 spendedValue) = _depositChecksAndEffects(usdcToken, to, amount, true);

    _depositInteractions(usdcToken, amount, chargeBack, spendedValue);

    emit TokensBought(address(usdcToken), to, referrer, spendedValue);
  }

  function depositUSDC(uint256 amount, address referrer) external whenNotPaused {
    (uint256 chargeBack, uint256 spendedValue) = _depositChecksAndEffects(usdcToken, msg.sender, amount, true);

    _depositInteractions(usdcToken, amount, chargeBack, spendedValue);

    emit TokensBought(address(usdcToken), msg.sender, referrer, spendedValue);
  }

  function depositUSDTTo(address to, uint256 amount, address referrer) external whenNotPaused {
    (uint256 chargeBack, uint256 spendedValue) = _depositChecksAndEffects(usdtToken, to, amount, true);

    _depositInteractions(usdtToken, amount, chargeBack, spendedValue);

    emit TokensBought(address(usdtToken), to, referrer, spendedValue);
  }

  function depositUSDT(uint256 amount, address referrer) external whenNotPaused {
    (uint256 chargeBack, uint256 spendedValue) = _depositChecksAndEffects(usdtToken, msg.sender, amount, true);

    _depositInteractions(usdtToken, amount, chargeBack, spendedValue);

    emit TokensBought(address(usdtToken), msg.sender, referrer, spendedValue);
  }

  function depositCoinTo(address to, address referrer) public payable whenNotPaused {
    (uint256 chargeBack, uint256 spendedValue) = _depositChecksAndEffects(IERC20(address(0)), to, msg.value, false);

    (bool success, ) = payable(protocolWallet).call{value: spendedValue}("");
    require(success, "Presale: Coin transfer failed");

    if(chargeBack > 0) {
      (success, ) = payable(msg.sender).call{value: chargeBack}("");
      require(success, "Presale: Coin transfer failed");
    }

    emit TokensBought(address(0), to, referrer, spendedValue);
  }

  function depositCoin(address referrer) public payable whenNotPaused {
    (uint256 chargeBack, uint256 spendedValue) = _depositChecksAndEffects(IERC20(address(0)), msg.sender, msg.value, false);

    (bool success, ) = payable(protocolWallet).call{value: spendedValue}("");
    require(success, "Presale: Coin transfer failed");

    if(chargeBack > 0) {
      (success, ) = payable(msg.sender).call{value: chargeBack}("");
      require(success, "Presale: Coin transfer failed");
    }

    emit TokensBought(address(0), msg.sender, referrer, spendedValue);
  }

  function _depositChecksAndEffects(
    IERC20 token, 
    address to, 
    uint256 value, 
    bool isStableToken
  ) internal virtual returns (uint256 chargeBack, uint256 spendedValue) {
    require(stages[stageIterator].amount != 0, "PreSale: is ended");

    (uint256 tokensToTransfer, uint256 coinPrice) = _calculateAmount(isStableToken, value);
    (chargeBack, spendedValue) = _purchase(token, to, coinPrice, tokensToTransfer, value);
  }

  function _depositInteractions(
    IERC20 token, 
    uint256 amount, 
    uint256 chargeBack, 
    uint256 spendedValue
  ) internal virtual {
    token.safeTransferFrom(msg.sender, address(this), amount);
    token.safeTransfer(protocolWallet, spendedValue);
    if(chargeBack > 0) token.safeTransfer(msg.sender, chargeBack);
  }

  function _calculateAmount(bool isStableToken, uint256 value) internal virtual view returns (uint256 amount, uint256 price) {
    int256 coinPrice;
    uint256 PRECISION;

    if (isStableToken) {
      coinPrice = STABLETOKEN_PRICE;
      PRECISION = STABLE_TOKEN_DECIMALS;
    } else {
      (, coinPrice, , , ) = COIN_PRICE_FEED.latestRoundData();
      PRECISION = TOKEN_PRECISION;
    }

    uint256 expectedAmount = uint(coinPrice) * value / uint(stages[stageIterator].cost);

    return (expectedAmount / 10 ** (PRECISION), uint(coinPrice));
  }

  function _purchase(
    IERC20 token, 
    address to, 
    uint256 coinPrice, 
    uint256 amount, 
    uint256 value
  ) internal virtual returns (uint256 tokensToChargeBack, uint256 spendedValue) {
    StageData storage crtStage =  stages[stageIterator];

    if (uint(crtStage.amount) <= amount) {
      spendedValue = crtStage.amount * crtStage.cost;
    } else {
      spendedValue = amount * crtStage.cost;
    }

    totalSoldInUSD += spendedValue;

    if(address(token) == address(0)) {
      uint256 usdInEth = 1 ether / coinPrice;
      spendedValue *= usdInEth;
    } else {
      spendedValue /= 10 ** (PRICEFEED_DECIMALS - STABLE_TOKEN_DECIMALS);
    }

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
