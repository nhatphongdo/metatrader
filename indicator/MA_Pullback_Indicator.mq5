//+------------------------------------------------------------------+
//|                                           SMA Pullback indicator |
//|                                    Copyright 2026, Do Nhat Phong |
//|                                   https://github.com/nhatphongdo |
//+------------------------------------------------------------------+
#property indicator_chart_window
#property indicator_plots 0

#include <MA_Pullback_Core.mqh>

// ==================================================
// ===================== ENUM ========================
// ==================================================
enum ENUM_MA_TYPE_MODE
  {
   MA_TYPE_SMA = MODE_SMA,  // SMA (Simple Moving Average)
   MA_TYPE_EMA = MODE_EMA   // EMA (Exponential Moving Average)
  };

// ==================================================
// ===================== INPUT =======================
// ==================================================

// --- TRADE LIMITS ---
input double   InpMinStopLoss     = 30.0;           // Số points StopLoss tối thiểu
input double   InpRiskRewardRate  = 2.0;            // Tỷ lệ Reward / Risk

// --- INDICATOR SETTINGS ---
input ENUM_MA_TYPE_MODE InpMAType = MA_TYPE_SMA;    // Loại Moving Average
input int      InpMA50Period      = 50;             // Chu kỳ MA 50
input int      InpMA200Period     = 200;            // Chu kỳ MA 200
input int      InpRSIPeriod       = 14;             // Chu kỳ RSI
input int      InpMACDSlow        = 12;             // Chu kỳ MACD Slow
input int      InpMACDFast        = 26;             // Chu kỳ MACD Fast
input int      InpMACDSignal      = 9;              // Chu kỳ MACD Signal

// --- STRATEGY SETTINGS ---
input int      InpMaxWaitBars     = 10;             // Số nến tối đa chờ pullback
input int      InpATRLength       = 10;             // Số nến tính ATR
input double   InpWickBodyRatio   = 2.0;            // Tỷ lệ Bóng/Thân nến

// ==================================================
// ============== FILTER SETTINGS ===================
// ==================================================
input double   InpMinScoreToPass  = 50.0;           // Điểm Threshold để signal Valid (Vẽ lên chart)

// --- FILTER 1: MA SLOPE ---
input bool     InpEnableMASlopeFilter = true;       // [Filter] Bật MA Slope
input double   InpMA50SlopeThreshold  = 20.0;       // [Filter] MA Slope Threshold (độ)
input int      InpSlopeSmoothBars     = 5;          // [Filter] Số nến tính Slope Smooth
input double   InpMASlopeWeight       = 10.0;       // [Weight] MA Slope

// --- FILTER 2: MOMENTUM (RSI + MACD) ---
input bool     InpEnableMomentumFilter = true;      // [Filter] Bật Momentum
input double   InpMomentumWeight       = 30.0;      // [Weight] Momentum

// --- FILTER 3: SMA200 TREND ---
input bool     InpEnableSMA200Filter   = true;      // [Filter] Bật SMA200 Trend
input double   InpSMA200Weight         = 10.0;      // [Weight] SMA200 Trend

// --- FILTER 4: S/R ZONE ---
input bool     InpEnableSRZoneFilter   = true;      // [Filter] Bật S/R Zone
input int      InpSRLookback           = 20;        // [Filter] S/R Lookback Bars
input double   InpSRZonePercent        = 50.0;      // [Filter] % Zone Width
input double   InpSRZoneWeight         = 20.0;      // [Weight] S/R Zone

// --- FILTER 5: MA NOISE (Cut Interval, Max Cuts, Peak Dist) ---
input int      InpMinCutInterval          = 2;      // [Filter] Min Cut Interval (0=Off)
input double   InpCutIntervalWeight       = 10.0;   // [Weight] Cut Interval
input int      InpMaxCutsInLookback       = 3;      // [Filter] Max Cuts in Lookback (0=Off)
input int      InpCutsLookbackBars        = 20;     // [Filter] Cuts Lookback Bars
input double   InpMaxCutsWeight           = 10.0;   // [Weight] Max Cuts
input double   InpPeakMADistanceThreshold = 50.0;   // [Filter] Peak-MA Dist Threshold (0=Off)
input double   InpPeakMADistWeight        = 10.0;   // [Weight] Peak-MA Dist

// --- FILTER 6: ADX TREND STRENGTH ---
input bool     InpEnableADXFilter       = false;    // [Filter] Bật ADX
input int      InpADXPeriod             = 14;       // [Filter] Chu kỳ ADX
input double   InpMinADXThreshold       = 25.0;     // [Filter] Min ADX Threshold
input bool     InpADXDirectionalConfirm = true;     // [Filter] Check +DI/-DI

// --- FILTER 7: BODY/ATR RATIO ---
input bool     InpEnableBodyATRFilter = false;      // [Filter] Bật Body/ATR
input double   InpMinBodyATRRatio     = 0.3;        // [Filter] Min Body/ATR Ratio

// --- FILTER 8: VOLUME ---
input bool     InpEnableVolumeFilter = false;       // [Filter] Bật Volume
input int      InpVolumeAvgPeriod    = 20;          // [Filter] Chu kỳ Volume TB
input double   InpMinVolumeRatio     = 1.0;         // [Filter] Min Volume Ratio

// --- FILTER 9: PRICE-MA DISTANCE ---
input bool     InpEnablePriceMADistFilter = false;  // [Filter] Bật Price-MA Dist
input double   InpMaxPriceMADistATR       = 2.0;    // [Filter] Max Dist (ATR)

// ==================================================
// ============== DISPLAY SETTINGS ==================
// ==================================================

input int      InpLineLengthBars = 10;              // Độ dài đường SL / TP (số nến)

// --- COLORS ---
input color    InpBuyColor     = clrLime;           // Màu tín hiệu BUY
input color    InpSellColor    = clrRed;            // Màu tín hiệu SELL
input color    InpSLColor      = clrOrange;         // Màu đường Stoploss
input color    InpTPColor      = clrAqua;           // Màu đường Take profit
input color    InpStrongColor  = clrWhite;          // Màu label tín hiệu mạnh
input color    InpWeakColor    = clrYellow;         // Màu label tín hiệu yếu
input color    InpSupportColor = C'0,100,0';        // Màu vùng Support (xanh đậm)
input color    InpResistColor  = C'139,0,0';        // Màu vùng Resistance (đỏ đậm)
input color    InpCancelColor  = clrGray;           // Màu tín hiệu bị hủy

// --- ALERTS ---
input bool     InpAlertEnabled = false;             // Bật/tắt Alert popup
input bool     InpPushEnabled  = false;             // Bật/tắt Push Notification

// --- AUTO SETUP ---
input bool     InpAutoAddIndicators = true;         // Tự động thêm SMA/RSI/MACD lên chart

// ==================================================
// ================= BIẾN TOÀN CỤC ===================
// ==================================================

datetime g_lastProcessedBarTime = 0;
string   OBJ_PREFIX = "SIG_";
int      hSMA50;
int      hSMA200;
int      hRSI;
int      hMACD;
int      hADX;
int      g_nextAllowedCutIdx = -1;
double   g_tickSize;
double   g_pointValue;
SMAPullbackConfig g_config;


// ==================================================
// ===================== INIT ========================
// ==================================================
int OnInit()
  {
   hSMA50 = iMA(_Symbol, _Period, InpMA50Period, 0, (ENUM_MA_METHOD)InpMAType, PRICE_CLOSE);
   if(hSMA50 == INVALID_HANDLE)
      return INIT_FAILED;

   hSMA200 = iMA(_Symbol, _Period, InpMA200Period, 0, (ENUM_MA_METHOD)InpMAType, PRICE_CLOSE);
   if(hSMA200 == INVALID_HANDLE)
      return INIT_FAILED;

   hRSI = iRSI(_Symbol, _Period, InpRSIPeriod, PRICE_CLOSE);
   if(hRSI == INVALID_HANDLE)
      return INIT_FAILED;

   hMACD = iMACD(_Symbol, _Period, InpMACDSlow, InpMACDFast, InpMACDSignal, PRICE_CLOSE);
   if(hMACD == INVALID_HANDLE)
      return INIT_FAILED;

// ADX indicator for trend strength filter
   hADX = iADX(_Symbol, _Period, InpADXPeriod);
   if(hADX == INVALID_HANDLE)
      return INIT_FAILED;

// --- CONFIG INITIALIZATION ---

// 1. Core / Limits
   g_config.minStopLoss = InpMinStopLoss;
   g_config.riskRewardRate = InpRiskRewardRate;

// 2. Indicators
   g_config.sma50Period = InpMA50Period;
   g_config.ma50SlopeThreshold = InpMA50SlopeThreshold;
   g_config.sma200Period = InpMA200Period;
   g_config.rsiPeriod = InpRSIPeriod;
   g_config.macdSlow = InpMACDSlow;
   g_config.macdFast = InpMACDFast;
   g_config.macdSignal = InpMACDSignal;

// 3. Strategy
   g_config.maxWaitBars = InpMaxWaitBars;
   g_config.atrLength = InpATRLength;
   g_config.wickBodyRatio = InpWickBodyRatio;
   g_config.minScoreToPass = InpMinScoreToPass;

// 4. Filters Configuration

// MA Slope
   g_config.enableMASlopeFilter = InpEnableMASlopeFilter;
   g_config.maSlopeWeight = InpMASlopeWeight;
   g_config.slopeSmoothBars = InpSlopeSmoothBars;

// Momentum
   g_config.enableMomentumFilter = InpEnableMomentumFilter;
   g_config.momentumWeight = InpMomentumWeight;

// SMA200
   g_config.enableSMA200Filter = InpEnableSMA200Filter;
   g_config.sma200Weight = InpSMA200Weight;

// S/R Zone
   g_config.enableSRZoneFilter = InpEnableSRZoneFilter;
   g_config.srZoneWeight = InpSRZoneWeight;
   g_config.srLookback = InpSRLookback;
   g_config.srZonePercent = InpSRZonePercent;

// MA Noise Filters
   g_config.minCutInterval = InpMinCutInterval;
   g_config.cutIntervalWeight = InpCutIntervalWeight;

   g_config.maxCutsInLookback = InpMaxCutsInLookback;
   g_config.cutsLookbackBars = InpCutsLookbackBars;
   g_config.maxCutsWeight = InpMaxCutsWeight;

   g_config.peakMaDistanceThreshold = InpPeakMADistanceThreshold;
   g_config.peakMADistWeight = InpPeakMADistWeight;

// ADX
   g_config.enableADXFilter = InpEnableADXFilter;
   g_config.adxPeriod = InpADXPeriod;
   g_config.minADXThreshold = InpMinADXThreshold;
   g_config.useADXDirectionalConfirm = InpADXDirectionalConfirm;
   g_config.adxWeight = 10.0; // Default

// Body/ATR
   g_config.enableBodyATRFilter = InpEnableBodyATRFilter;
   g_config.minBodyATRRatio = InpMinBodyATRRatio;
   g_config.bodyATRWeight = 5.0; // Default

// Volume
   g_config.enableVolumeFilter = InpEnableVolumeFilter;
   g_config.volumeAvgPeriod = InpVolumeAvgPeriod;
   g_config.minVolumeRatio = InpMinVolumeRatio;
   g_config.volumeWeight = 5.0; // Default

// Price-MA Dist
   g_config.enablePriceMADistanceFilter = InpEnablePriceMADistFilter;
   g_config.maxPriceMADistanceATR = InpMaxPriceMADistATR;
   g_config.priceMADistWeight = 5.0; // Default

// Time/News/ConsecLoss: Disabled for Indicator
   g_config.enableTimeFilter = false;
   g_config.enableNewsFilter = false;
   g_config.enableConsecutiveLossFilter = false;

   g_tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   g_pointValue = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   g_nextAllowedCutIdx = -1;

// Tự động thêm indicators lên chart
   if(InpAutoAddIndicators)
      AddIndicatorsToChart();

   return INIT_SUCCEEDED;
  }

// ==================================================
void OnDeinit(const int reason)
  {
   ObjectsDeleteAll(0, OBJ_PREFIX);
   IndicatorRelease(hSMA50);
   IndicatorRelease(hSMA200);
   IndicatorRelease(hRSI);
   IndicatorRelease(hMACD);
   IndicatorRelease(hADX);

// Xóa chart indicators nếu đã thêm
   RemoveIndicatorsFromChart();
  }

// ==================================================
// ========== AUTO ADD INDICATORS TO CHART ==========
// ==================================================
void AddIndicatorsToChart()
  {
   long chartId = ChartID();

// Thêm SMA 50 (dùng lại handle đã có)
   if(hSMA50 != INVALID_HANDLE)
     {
      if(!ChartIndicatorAdd(chartId, 0, hSMA50))
         Print("Lỗi thêm SMA50");
     }

// Thêm SMA 200 (dùng lại handle đã có)
   if(hSMA200 != INVALID_HANDLE)
     {
      if(!ChartIndicatorAdd(chartId, 0, hSMA200))
         Print("Lỗi thêm SMA200");
     }

// Thêm RSI (subwindow mới, dùng lại handle đã có)
   if(hRSI != INVALID_HANDLE)
     {
      int rsiWindow = (int)ChartGetInteger(chartId, CHART_WINDOWS_TOTAL);
      if(!ChartIndicatorAdd(chartId, rsiWindow, hRSI))
         Print("Lỗi thêm RSI");
     }

// Thêm MACD (subwindow mới, dùng lại handle đã có)
   if(hMACD != INVALID_HANDLE)
     {
      int macdWindow = (int)ChartGetInteger(chartId, CHART_WINDOWS_TOTAL);
      if(!ChartIndicatorAdd(chartId, macdWindow, hMACD))
         Print("Lỗi thêm MACD");
     }
  }

// ==================================================
void RemoveIndicatorsFromChart()
  {
   long chartId = ChartID();

// Xóa SMA 50 (chỉ xóa khỏi chart, không release handle vì OnDeinit sẽ làm)
   for(int i = ChartIndicatorsTotal(chartId, 0) - 1; i >= 0; i--)
     {
      string indName = ChartIndicatorName(chartId, 0, i);
      if(StringFind(indName, "MA(" + IntegerToString(InpMA50Period) + ")") >= 0)
        {
         ChartIndicatorDelete(chartId, 0, indName);
         break;
        }
     }

// Xóa SMA 200
   for(int i = ChartIndicatorsTotal(chartId, 0) - 1; i >= 0; i--)
     {
      string indName = ChartIndicatorName(chartId, 0, i);
      if(StringFind(indName, "MA(" + IntegerToString(InpMA200Period) + ")") >= 0)
        {
         ChartIndicatorDelete(chartId, 0, indName);
         break;
        }
     }

// Xóa RSI (tìm trong các subwindow)
   int totalWindows = (int)ChartGetInteger(chartId, CHART_WINDOWS_TOTAL);
   for(int w = totalWindows - 1; w >= 1; w--)
     {
      for(int i = ChartIndicatorsTotal(chartId, w) - 1; i >= 0; i--)
        {
         string indName = ChartIndicatorName(chartId, w, i);
         if(StringFind(indName, "RSI(" + IntegerToString(InpRSIPeriod) + ")") >= 0)
           {
            ChartIndicatorDelete(chartId, w, indName);
            break;
           }
        }
     }

// Xóa MACD (tìm trong các subwindow)
   totalWindows = (int)ChartGetInteger(chartId, CHART_WINDOWS_TOTAL);
   for(int w = totalWindows - 1; w >= 1; w--)
     {
      for(int i = ChartIndicatorsTotal(chartId, w) - 1; i >= 0; i--)
        {
         string indName = ChartIndicatorName(chartId, w, i);
         if(StringFind(indName, "MACD") >= 0)
           {
            ChartIndicatorDelete(chartId, w, indName);
            break;
           }
        }
     }
  }

// ==================================================
// ================== ON CALCULATE ==================
// ==================================================
int OnCalculate(
   const int rates_total,
   const int prev_calculated,
   const datetime &time[],
   const double &open[],
   const double &high[],
   const double &low[],
   const double &close[],
   const long &tick_volume[],
   const long &volume[],
   const int &spread[]
)
  {
   if(rates_total < 200)
      return rates_total;

// QUAN TRỌNG: Set arrays as series để index 0 = nến hiện tại
   ArraySetAsSeries(time, true);
   ArraySetAsSeries(open, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(close, true);

// Xác định phạm vi cần scan
   int limit;
   if(prev_calculated == 0)
     {
      // Lần đầu load: scan tất cả nến
      limit = rates_total - InpMaxWaitBars - 5;
     }
   else
     {
      // Realtime: chỉ scan nến mới đóng
      limit = 1;
     }

// Copy SMA buffers - cần đủ data cho tất cả nến
   double sma50[], sma200[];
   ArraySetAsSeries(sma50, true);
   ArraySetAsSeries(sma200, true);

   int copyCount = MathMin(rates_total, 10000); // Copy tối đa 10000 nến
   if(CopyBuffer(hSMA50, 0, 0, copyCount, sma50) <= 0)
      return rates_total;

   if(CopyBuffer(hSMA200, 0, 0, copyCount, sma200) <= 0)
      return rates_total;

// Copy RSI / MACD
   double rsi[];
   double macdMain[], macdSignal[];

   ArraySetAsSeries(rsi, true);
   ArraySetAsSeries(macdMain, true);
   ArraySetAsSeries(macdSignal, true);

   if(CopyBuffer(hRSI, 0, 0, copyCount, rsi) <= 0)
      return rates_total;

   if(CopyBuffer(hMACD, 0, 0, copyCount, macdMain) <= 0)
      return rates_total;

   if(CopyBuffer(hMACD, 1, 0, copyCount, macdSignal) <= 0)
      return rates_total;

// Copy ADX buffers (for extended filters)
   double adxMain[], adxPlusDI[], adxMinusDI[];
   ArraySetAsSeries(adxMain, true);
   ArraySetAsSeries(adxPlusDI, true);
   ArraySetAsSeries(adxMinusDI, true);

   if(CopyBuffer(hADX, 0, 0, copyCount, adxMain) <= 0)   // ADX main line
      return rates_total;
   if(CopyBuffer(hADX, 1, 0, copyCount, adxPlusDI) <= 0) // +DI
      return rates_total;
   if(CopyBuffer(hADX, 2, 0, copyCount, adxMinusDI) <= 0) // -DI
      return rates_total;

// Copy tick volume to series array
   long volumeAsSeries[];
   ArraySetAsSeries(volumeAsSeries, true);
   if(CopyTickVolume(_Symbol, _Period, 0, copyCount, volumeAsSeries) <= 0)
      return rates_total;

// Loop qua các nến - tìm nến cắt SMA

// Xác định điểm bắt đầu loop (Quá khứ -> Hiện tại)
// Với Series: index lớn là quá khứ, index 0 là hiện tại
// Chúng ta muốn duyệt từ Quá khứ (High Index) về Hiện tại (Low Index)
   int startIdx, endIdx;

   if(prev_calculated == 0)
     {
      startIdx = copyCount - 1 - InpMaxWaitBars; // Bắt đầu từ nến cũ nhất có thể
      endIdx = 1;
     }
   else
     {
      // Realtime: chỉ check các nến mới
      // Bắt đầu từ nến cũ nhất cần kiểm tra (để đảm bảo không bỏ sót)
      // và kết thúc ở nến đóng mới nhất (index 1)
      startIdx = rates_total - prev_calculated + InpMaxWaitBars;
      if(startIdx >= copyCount)
         startIdx = copyCount - 1;
      endIdx = 1;
     }

   for(int cutIdx = startIdx; cutIdx >= endIdx; cutIdx--)
     {
      // Bỏ qua nến cắt nếu nó nằm trong vùng cấm của signal trước đó
      if(g_nextAllowedCutIdx != -1 && cutIdx >= g_nextAllowedCutIdx)
         continue;

      // Kiểm tra nến cắt SMA 50 tại cutIdx
      // BUY: nến mở trên SMA, low chạm dưới SMA (test SMA từ trên)
      // SELL: nến mở dưới SMA, high chạm trên SMA (test SMA từ dưới)
      bool cutUpToBottom = IsGreaterThan(open[cutIdx], sma50[cutIdx], g_tickSize) && IsLessThan(close[cutIdx], sma50[cutIdx], g_tickSize);
      bool cutDownToTop = IsLessThan(open[cutIdx], sma50[cutIdx], g_tickSize) && IsGreaterThan(close[cutIdx], sma50[cutIdx], g_tickSize);

      if(!cutUpToBottom && !cutDownToTop)
         continue; // Không có nến cắt tại đây

      // Sử dụng ScanForSignal từ shared library
      ScanResult scanResult;
      ScanForSignal(g_config, cutIdx, cutUpToBottom, _Symbol, time[0],
                    open, high, low, close, sma50, sma200,
                    rsi, macdMain, macdSignal, volumeAsSeries,
                    adxMain, adxPlusDI, adxMinusDI,
                    g_tickSize, g_pointValue, copyCount, scanResult);

      // Vẽ marker đánh dấu nến cắt SMA (chỉ khi không bị noise filter)
      DrawCutCandle(cutUpToBottom, time[cutIdx], cutUpToBottom ? low[cutIdx] : high[cutIdx], sma50[cutIdx], "");

      if(scanResult.found)
        {
         // Signal found - vẽ lên chart
         DrawSignal(scanResult.isBuy, false, time[scanResult.confirmIdx], cutIdx - scanResult.confirmIdx,
                    scanResult.signal.entry, scanResult.signal.sl, scanResult.signal.tp,
                    scanResult.signal.strength, scanResult.signal.score, scanResult.signal.reasons,
                    scanResult.signal.support, scanResult.signal.resistance);
         g_nextAllowedCutIdx = scanResult.confirmIdx;

         // Alert / Push Notification nếu được bật
         if(InpAlertEnabled || InpPushEnabled)
           {
            string signalType = scanResult.isBuy ? "BUY" : "SELL";
            string alertMsg = StringFormat("%s - %s %s Tín hiệu @ %.5f | SL: %.5f | TP: %.5f | Điểm: %.1f",
                                           _Symbol, signalType, scanResult.signal.strength,
                                           scanResult.signal.entry, scanResult.signal.sl,
                                           scanResult.signal.tp, scanResult.signal.score);

            // Alert popup trên máy tính
            if(InpAlertEnabled)
               Alert(alertMsg);

            // Push notification lên điện thoại
            if(InpPushEnabled)
               SendNotification(alertMsg);
           }
        }
      else
         if(scanResult.cancelled)
           {
            // Signal cancelled - vẽ cancelled marker
            DrawSignal(scanResult.isBuy, true, time[scanResult.confirmIdx], 0,
                       close[scanResult.confirmIdx], 0, 0, "", 0, scanResult.cancelReason, 0, 0);
            g_nextAllowedCutIdx = scanResult.confirmIdx;
           }
     }

   ChartRedraw();
   return rates_total;
  }

// ==================================================
// =================== DRAW SIGNAL ===================
// ==================================================
void DrawSignal(
   bool     isBuy,
   bool     isCanceled,
   datetime signalTime,
   int      signalLength,
   double   entryPrice,
   double   slPrice,
   double   tpPrice,
   string   strengthText,
   double   score,
   string   reasons,
   double   support,
   double   resistance
)
  {
   string id = OBJ_PREFIX + IntegerToString(signalTime);
   if(ObjectFind(0, id + "_AR") >= 0)
      return;

   datetime endTime = signalTime + MathMin(InpLineLengthBars, signalLength) * PeriodSeconds(_Period);

// Entry Arrow
   ObjectCreate(0, id+"_AR", OBJ_ARROW, 0, signalTime, entryPrice);
   ObjectSetInteger(0, id+"_AR", OBJPROP_ARROWCODE, isCanceled ? 251 : (isBuy ? 233 : 234));
   ObjectSetInteger(0, id+"_AR", OBJPROP_COLOR, isCanceled ? InpCancelColor : (isBuy ? InpBuyColor : InpSellColor));
   ObjectSetInteger(0, id+"_AR", OBJPROP_WIDTH, 2);

// Stop Loss Line
   if(slPrice > 0)
     {
      ObjectCreate(0, id+"_SL", OBJ_TREND, 0, signalTime, slPrice, endTime, slPrice);
      ObjectSetInteger(0, id+"_SL", OBJPROP_COLOR, InpSLColor);
      ObjectSetInteger(0, id+"_SL", OBJPROP_RAY, false);
      ObjectSetInteger(0, id+"_SL", OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, id+"_SL", OBJPROP_STYLE, STYLE_SOLID);
     }

// Take Profit Line
   if(tpPrice > 0)
     {
      ObjectCreate(0, id+"_TP", OBJ_TREND, 0, signalTime, tpPrice, endTime, tpPrice);
      ObjectSetInteger(0, id+"_TP", OBJPROP_COLOR, InpTPColor);
      ObjectSetInteger(0, id+"_TP", OBJPROP_RAY, false);
      ObjectSetInteger(0, id+"_TP", OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, id+"_TP", OBJPROP_STYLE, STYLE_SOLID);
     }

// Signal Strength Label + Tooltip
   string signalType = isBuy ? "BUY" : "SELL";
   color labelColor = (strengthText == "STRONG") ? InpStrongColor : InpWeakColor;

// Tính khoảng cách SL và TP theo points
   int slPoints = (int)(MathAbs(entryPrice - slPrice) / g_pointValue);
   int tpPoints = (int)(MathAbs(tpPrice - entryPrice) / g_pointValue);

// Tạo tooltip text (hiển thị khi hover)
   string tooltipText = StringFormat("%s %s (Điểm: %.1f)\nVào: %.5f\nSL: %d pts (%.5f)\nTP: %d pts (%.5f)",
                                     signalType, strengthText, score, entryPrice,
                                     slPoints, slPrice, tpPoints, tpPrice);
   if(reasons != "")
      tooltipText += "\nCảnh báo:\n" + reasons;


// Label hiển thị STRONG/WEAK
   if(!isCanceled)
     {
      double labelPrice = isBuy ? entryPrice + (tpPrice - entryPrice) * 0.1
                          : entryPrice - (entryPrice - tpPrice) * 0.1;
      datetime labelTime = signalTime - PeriodSeconds(_Period);
      ObjectCreate(0, id+"_LBL", OBJ_TEXT, 0, labelTime, labelPrice);
      ObjectSetString(0, id+"_LBL", OBJPROP_TEXT, strengthText);
      ObjectSetInteger(0, id+"_LBL", OBJPROP_COLOR, labelColor);
      ObjectSetInteger(0, id+"_LBL", OBJPROP_FONTSIZE, 10);
      ObjectSetString(0, id+"_LBL", OBJPROP_FONT, "Arial Bold");
      ObjectSetString(0, id+"_LBL", OBJPROP_TOOLTIP, tooltipText);
     }

// Thêm tooltip cho Arrow
   ObjectSetString(0, id+"_AR", OBJPROP_TOOLTIP, tooltipText);

// Thêm tooltip cho SL line
   if(slPrice > 0)
     {
      ObjectSetString(0, id+"_SL", OBJPROP_TOOLTIP, StringFormat("Stop Loss: %.5f (%d pts)", slPrice, slPoints));
     }

// Thêm tooltip cho TP line
   if(tpPrice > 0)
     {
      ObjectSetString(0, id+"_TP", OBJPROP_TOOLTIP, StringFormat("Take Profit: %.5f (%d pts)", tpPrice, tpPoints));
     }

// S/R Zone Boxes - Vẽ cả 2 vùng Support và Resistance
   if(isBuy && support > 0)
     {
      // BUY: Vùng Support (xanh) từ support đến entry
      ObjectCreate(0, id+"_S", OBJ_RECTANGLE, 0, signalTime, support, endTime, entryPrice);
      ObjectSetInteger(0, id+"_S", OBJPROP_COLOR, InpResistColor);
      ObjectSetInteger(0, id+"_S", OBJPROP_FILL, true);
      ObjectSetInteger(0, id+"_S", OBJPROP_BACK, true);
      ObjectSetString(0, id+"_S", OBJPROP_TOOLTIP, StringFormat("Vùng Hỗ Trợ: %.5f - %.5f", support, entryPrice));

      // BUY: Vùng Resistance (đỏ) từ entry đến resistance
      ObjectCreate(0, id+"_R", OBJ_RECTANGLE, 0, signalTime, entryPrice, endTime, resistance);
      ObjectSetInteger(0, id+"_R", OBJPROP_COLOR, InpSupportColor);
      ObjectSetInteger(0, id+"_R", OBJPROP_FILL, true);
      ObjectSetInteger(0, id+"_R", OBJPROP_BACK, true);
      ObjectSetString(0, id+"_R", OBJPROP_TOOLTIP, StringFormat("Vùng Kháng Cự: %.5f - %.5f", entryPrice, resistance));
     }
   else
      if(!isBuy && resistance > 0)
        {
         // SELL: Vùng Resistance (đỏ) từ resistance đến entry
         ObjectCreate(0, id+"_R", OBJ_RECTANGLE, 0, signalTime, resistance, endTime, entryPrice);
         ObjectSetInteger(0, id+"_R", OBJPROP_COLOR, InpResistColor);
         ObjectSetInteger(0, id+"_R", OBJPROP_FILL, true);
         ObjectSetInteger(0, id+"_R", OBJPROP_BACK, true);
         ObjectSetString(0, id+"_R", OBJPROP_TOOLTIP, StringFormat("Vùng Kháng Cự: %.5f - %.5f", resistance, entryPrice));

         // SELL: Vùng Support (xanh) từ entry đến support
         ObjectCreate(0, id+"_S", OBJ_RECTANGLE, 0, signalTime, entryPrice, endTime, support);
         ObjectSetInteger(0, id+"_S", OBJPROP_COLOR, InpSupportColor);
         ObjectSetInteger(0, id+"_S", OBJPROP_FILL, true);
         ObjectSetInteger(0, id+"_S", OBJPROP_BACK, true);
         ObjectSetString(0, id+"_S", OBJPROP_TOOLTIP, StringFormat("Vùng Hỗ Trợ: %.5f - %.5f", entryPrice, support));
        }
  }

// ==================================================
// ============= DRAW CUT CANDLE MARKER =============
// ==================================================
void DrawCutCandle(
   bool     isBuy,
   datetime cutTime,
   double   price,
   double   sma,
   string   filterReason
)
  {
   string id = OBJ_PREFIX + "CUT_" + IntegerToString(cutTime);
   if(ObjectFind(0, id + "_DIA") >= 0)
      return;

// Diamond marker để đánh dấu nến cắt SMA
   ObjectCreate(0, id+"_DIA", OBJ_ARROW, 0, cutTime, price);
   ObjectSetInteger(0, id+"_DIA", OBJPROP_ARROWCODE, filterReason == "" ? 117 : 78); // Diamond shape (Wingdings) or skull (Wingdings)
   ObjectSetInteger(0, id+"_DIA", OBJPROP_COLOR, filterReason == "" ? (isBuy ? clrDodgerBlue : clrMagenta) : clrDarkGray);
   ObjectSetInteger(0, id+"_DIA", OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, id+"_DIA", OBJPROP_ANCHOR, isBuy ? ANCHOR_TOP : ANCHOR_BOTTOM);

// Tooltip
   string signalType = filterReason == "" ? (isBuy ? "Setup BUY" : "Setup SELL") : (isBuy ? "Bỏ qua BUY" : "Bỏ qua SELL");
   string tooltip = filterReason == "" ? StringFormat("%s - Nến cắt SMA = %.5f", signalType, sma) : StringFormat("%s - Nến cắt SMA = %.5f lọc do: %s", signalType, sma, filterReason);
   ObjectSetString(0, id+"_DIA", OBJPROP_TOOLTIP, tooltip);
  }
//+------------------------------------------------------------------+
