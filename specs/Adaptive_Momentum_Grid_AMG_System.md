# Technical Specification: Adaptive Momentum Grid (AMG) EA

## 1. System Overview

* **Strategy Name:** Adaptive Momentum Grid (AMG).
* **Type:** Trend Following Scalper with Positive Grid (Pyramiding).
* **Target Environment:** Zero Commission Accounts (Standard/STP).
* **Timeframe:** M1 (Entry/Grid), M15 (Trend Bias - Optional filter).
* **Pairs:** GBPUSD, EURUSD, USDJPY (Low Spread/High Liquid).

## 2. Indicator Setup (Inputs)

| Indicator | Variable Name | Default | Purpose |
| :--- | :--- | :--- | :--- |
| **Fast EMA** | `InpFastEMA` | 8 | Immediate Trend Support |
| **Medium EMA** | `InpMedEMA` | 21 | Pullback Zone Boundary |
| **Slow EMA** | `InpSlowEMA` | 50 | Trend Baseline |
| **ATR** | `InpATR` | 14 | Dynamic Volatility Calculation |
| **RSI** | `InpRSI` | 14 | Momentum Filter (No divergence logic) |

## 3. Entry Logic (Signal Generation)

The system checks conditions at the **Close of Candle [1]** (Completed Bar).

### 3.1. Environment Filters (Must Pass First)

1. **Spread Filter:** `(Ask - Bid) < (ATR_Value * 0.20)`. *Rationale: Do not trade if spread eats >20% of expected volatility.*
2. **Time Filter:** GMT 08:00 to 20:00 (London/NY overlap).

### 3.2. Buy Signal (Long)

1. **Trend Alignment:** `EMA8 > EMA21 > EMA50`.
2. **Pullback Detection:** `Low[1] <= EMA8[1]` AND `Close[1] > EMA21[1]`. *(Price touched the zone between EMA 8-21)*.
3. **Momentum Check:** `RSI[1] > 50` AND `RSI[1] < 70`.
4. **Trigger:** Candle[1] is Bullish (`Close > Open`).

### 3.3. Sell Signal (Short)

1. **Trend Alignment:** `EMA8 < EMA21 < EMA50`.
2. **Pullback Detection:** `High[1] >= EMA8[1]` AND `Close[1] < EMA21[1]`.
3. **Momentum Check:** `RSI[1] < 50` AND `RSI[1] > 30`.
4. **Trigger:** Candle[1] is Bearish (`Close < Open`).

## 4. Exit & Grid Logic (Management)

### 4.1. Dynamic TP/SL (Per Order)

* **Take Profit:** `EntryPrice + (ATR_Value * 2.0)`.
* **Stop Loss:** `EntryPrice - (ATR_Value * 2.0)`.
* *Note:* TP/SL must be normalized to Broker's minimal step.

### 4.2. Positive Grid (Stacking)

* **Logic:** Allow multiple open positions in the same direction.
* **Max Orders:** Hard cap at 5 concurrent orders per symbol.
* **Trailing Stop:** If `CurrentPrice` moves in favor by `1.0 * ATR`, move SL to `Breakeven`.

## 5. Risk Management

* **Lot Sizing:** `RiskPercent` of Free Margin per trade / SL Distance.
* **Slippage Control:** Max deviation 5 points.
