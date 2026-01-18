# MA Pullback Trading System

Expert Advisor và Indicator cho MetaTrader 5 sử dụng chiến lược MA Pullback với hệ thống scoring đa filter.

## 📁 Cấu Trúc Project

```
metatrader/
├── expert-advisor/          # Expert Advisors (.mq5)
│   └── MA_Pullback_EA.mq5
├── indicator/               # Indicators (.mq5)
│   └── MA_Pullback_Indicator.mq5
├── include/                 # Shared libraries (.mqh)
│   ├── MA_Pullback_Inputs.mqh   # Input parameters & defaults
│   ├── MA_Pullback_Core.mqh     # Core trading logic
│   ├── Filters.mqh              # Unified scoring filters
│   ├── MA_Filters.mqh           # MA-specific filters
│   ├── Utility.mqh              # Utility functions
│   └── CandlePatterns.mqh       # Candle pattern detection
├── build/                   # Compiled files (.ex5)
├── logs/                    # Compilation logs
├── build.ps1                # Windows build script
├── build.sh                 # Mac/Linux build script
└── .gitignore
```

## 🔧 Build & Install

### Windows (PowerShell)

```powershell
# Chỉ build
.\build.ps1

# Clean trước khi build
.\build.ps1 -Clean

# Build và install vào MetaTrader 5
.\build.ps1 -Install

# Clean, build và install
.\build.ps1 -Clean -Install
```

### Mac / Linux (Bash + Wine)

```bash
# Chỉ build
./build.sh

# Clean trước khi build
./build.sh -c

# Build và install vào MetaTrader 5
./build.sh -i

# Clean, build và install
./build.sh -c -i
```

### Output

- **EA**: `build/expert-advisor/MA_Pullback_EA.ex5`
- **Indicator**: `build/indicator/MA_Pullback_Indicator.ex5`
- **Logs**: `logs/ea_*.log`, `logs/indicator_*.log`

## 📊 Chiến Lược Trading

### Nguyên lý
1. Giá cắt MA50 (cut candle)
2. Chờ pullback về lại MA50 trong N nến
3. Xác nhận bằng nến đảo chiều (confirmation candle)
4. Tính điểm qua hệ thống 12 filters
5. Vào lệnh nếu score >= threshold

### Hệ Thống Filters (12 Filters)

| # | Filter | Mô tả |
|---|--------|-------|
| 1 | MA Slope | Độ dốc MA50 đủ mạnh |
| 2A | Static Momentum | RSI/MACD theo hướng trend |
| 2B | RSI Reversal | Phát hiện đảo chiều RSI |
| 2C | MACD Histogram | MACD momentum shift |
| 3 | SMA200 Trend | Price vs SMA200 |
| 4 | S/R Zone | Giá trong vùng an toàn |
| 4B | S/R Min Width | Vùng S/R đủ rộng |
| 5 | MA Noise | Tránh sideway/chop |
| 6 | ADX Strength | Trend strength |
| 7 | Body/ATR Ratio | Candle strength |
| 8 | Volume | Volume confirmation |
| 9 | Price-MA Dist | Không quá xa MA |
| 10 | Time Control | Giờ giao dịch (EA) |
| 11 | News Filter | Tránh tin tức (EA) |
| 12 | Consec Losses | Pause sau thua liên tiếp (EA) |

## ⚙️ Cấu Hình

Các tham số mặc định được định nghĩa trong `include/MA_Pullback_Inputs.mqh`:

```mql5
#define DEF_MA50_PERIOD           50
#define DEF_MA200_PERIOD          200
#define DEF_ATR_LENGTH            14
#define DEF_MIN_SCORE_TO_PASS     70.0   // 70%
#define DEF_MAX_WAIT_BARS         5
```
