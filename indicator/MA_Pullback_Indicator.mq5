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
input double   InpMinStopLoss       = 50.0;           // Số points StopLoss tối thiểu (5 pips)
input double   InpRiskRewardRate    = 1.5;            // Tỷ lệ Reward / Risk (1.5 = 1.5R)
input double   InpSRBufferPercent   = 5.0;            // S/R/MA Buffer (%) - Buffer cộng thêm vào S/R zone, MA line

// --- INDICATOR SETTINGS ---
input ENUM_MA_TYPE_MODE InpMAType = MA_TYPE_SMA;    // Loại Moving Average (EMA phản ứng nhanh hơn)
input int      InpMA50Period      = 50;             // Chu kỳ MA Fast
input int      InpMA200Period     = 200;            // Chu kỳ MA Slow
input int      InpRSIPeriod       = 14;             // Chu kỳ RSI
input int      InpMACDFast        = 12;             // Chu kỳ MACD Fast
input int      InpMACDSlow        = 26;             // Chu kỳ MACD Slow
input int      InpMACDSignal      = 9;              // Chu kỳ MACD Signal

// --- STRATEGY SETTINGS ---
input int      InpMaxWaitBars     = 10;             // Số nến tối đa chờ pullback (ít hơn = entry sớm hơn)
input int      InpATRLength       = 14;             // Số nến tính ATR (standard)
input double   InpWickBodyRatio   = 1.5;            // Tỷ lệ Bóng/Thân nến (vừa phải)

// ==================================================
// ============== FILTER SETTINGS ===================
// ==================================================
input double   InpMinScoreToPass  = 60.0;           // Điểm Threshold để signal Valid (60/100)

// ==============================================================
// FILTER 1: MA SLOPE
// Kiểm tra độ dốc MA có đủ mạnh không
// ==============================================================
input bool     InpEnableMASlopeFilter = true;       // [Filter: MA Slope] Bật MA Slope (trend direction)
input bool     InpMASlopeCritical     = false;      // [Filter: MA Slope] Critical
input double   InpMA50SlopeThreshold  = 15.0;       // [Filter: MA Slope] MA Slope Threshold (độ, 15 = vừa phải)
input int      InpSlopeSmoothBars     = 5;          // [Filter: MA Slope] Số nến tính Slope
input double   InpMASlopeWeight       = 10.0;       // [Filter: MA Slope] Weight

// ==============================================================
// FILTER 2A: STATIC MOMENTUM (RSI + MACD position)
// Kiểm tra RSI và MACD có xác nhận xu hướng không
// ==============================================================
input bool     InpEnableStaticMomentum    = true;   // [Filter: Static Momentum] Bật Static Momentum (trend confirmation)
input bool     InpStaticMomentumCritical  = false;  // [Filter: Static Momentum] Critical
input double   InpStaticMomentumWeight    = 15.0;   // [Filter: Static Momentum] Weight

// ==============================================================
// FILTER 2B: RSI REVERSAL DETECTION
// Phát hiện RSI đang đi ngược hướng signal
// ==============================================================
input bool     InpEnableRSIReversal    = true;      // [Filter: RSI Reversal] Bật RSI Reversal
input bool     InpRSIReversalCritical  = true;      // [Filter: RSI Reversal] Critical (quan trọng - phát hiện đảo chiều)
input int      InpRSIReversalLookback  = 2;         // [Filter: RSI Reversal] Lookback (nến)
input double   InpRSIReversalWeight    = 10.0;      // [Filter: RSI Reversal] Weight

// ==============================================================
// FILTER 2C: MACD HISTOGRAM TREND
// Phát hiện histogram đang mở rộng ngược hướng
// ==============================================================
input bool     InpEnableMACDHistogram    = true;    // [Filter: MACD Histogram] Bật MACD Histogram
input bool     InpMACDHistogramCritical  = true;    // [Filter: MACD Histogram] Critical (quan trọng - momentum shift)
input int      InpMACDHistogramLookback  = 2;       // [Filter: MACD Histogram] Lookback (nến)
input double   InpMACDHistogramWeight    = 10.0;    // [Filter: MACD Histogram] Weight

// ==============================================================
// FILTER 3: SMA200 TREND
// Kiểm tra giá có cùng xu hướng với SMA200 không
// ==============================================================
input bool     InpEnableSMA200Filter = true;        // [Filter: SMA200 Trend] Bật SMA200 Trend
input bool     InpSMA200Critical     = true;        // [Filter: SMA200 Trend] Critical (quan trọng - xác định xu hướng chính)
input double   InpSMA200Weight       = 15.0;        // [Filter: SMA200 Trend] Weight

// ==============================================================
// FILTER 4: S/R ZONE
// Kiểm tra giá có trong vùng entry tốt không
// ==============================================================
input bool     InpEnableSRZoneFilter = true;        // [Filter: S/R Zone] Bật S/R Zone
input bool     InpSRZoneCritical     = false;       // [Filter: S/R Zone] Critical
input int      InpSRLookback         = 20;          // [Filter: S/R Zone] Lookback Bars
input double   InpSRZonePercent      = 40.0;        // [Filter: S/R Zone] % Zone Width
input double   InpSRZoneWeight       = 15.0;        // [Filter: S/R Zone] Weight

// ==============================================================
// FILTER 4B: S/R MIN WIDTH
// Lọc vùng S/R quá hẹp
// ==============================================================
input bool     InpEnableSRMinWidthFilter = true;    // [Filter: S/R Min Width] Bật S/R Min Width
input bool     InpSRMinWidthCritical     = true;    // [Filter: S/R Min Width] Critical (quan trọng - đảm bảo vùng S/R đủ rộng để trade)
input double   InpMinSRWidthATR          = 2.0;     // [Filter: S/R Min Width] Độ rộng S/R tối thiểu (2x ATR), timeframe nhỏ nên có bội số lớn
input double   InpSRMinWidthWeight       = 10.0;    // [Filter: S/R Min Width] Weight

// ==============================================================
// FILTER 5: MA NOISE
// Lọc vùng giá dao động quanh MA50 (choppy)
// ==============================================================
input int      InpMinCutInterval          = 3;      // [Filter: MA Noise] Min Cut Interval (0=Off)
input double   InpCutIntervalWeight       = 5.0;    // [Filter: MA Noise] Cut Interval Weight
input int      InpMaxCutsInLookback       = 2;      // [Filter: MA Noise] Max Cuts in Lookback (0=Off)
input int      InpCutsLookbackBars        = 15;     // [Filter: MA Noise] Cuts Lookback Bars
input double   InpMaxCutsWeight           = 5.0;    // [Filter: MA Noise] Max Cuts Weight
input double   InpPeakMADistanceThreshold = 0;      // [Filter: MA Noise] Peak-MA Threshold (0=Off)
input double   InpPeakMADistWeight        = 5.0;    // [Filter: MA Noise] Peak-MA Weight

// ==============================================================
// FILTER 6: ADX TREND STRENGTH
// Kiểm tra thị trường có đang trending không
// ==============================================================
input bool     InpEnableADXFilter        = true;    // [Filter: ADX Trend Strength] Bật ADX (trend strength)
input bool     InpADXCritical            = false;   // [Filter: ADX Trend Strength] Critical
input int      InpADXPeriod              = 14;      // [Filter: ADX Trend Strength] Chu kỳ ADX
input double   InpMinADXThreshold        = 20.0;    // [Filter: ADX Trend Strength] Min ADX Threshold (20 = mild trend)
input bool     InpADXDirectionalConfirm  = true;    // [Filter: ADX Trend Strength] Check +DI/-DI
input double   InpADXWeight              = 10.0;    // [Filter: ADX Trend Strength] Weight

// ==============================================================
// FILTER 7: BODY/ATR RATIO
// Kiểm tra nến confirm có đủ mạnh không
// ==============================================================
input bool     InpEnableBodyATRFilter = true;       // [Filter: Body/ATR] Bật Body/ATR (candle strength)
input bool     InpBodyATRCritical     = false;      // [Filter: Body/ATR] Critical
input double   InpMinBodyATRRatio     = 0.25;       // [Filter: Body/ATR] Min Body/ATR Ratio (25% ATR)
input double   InpBodyATRWeight       = 5.0;        // [Filter: Body/ATR] Weight

// ==============================================================
// FILTER 8: VOLUME CONFIRMATION
// Kiểm tra volume có đủ so với trung bình không
// ==============================================================
input bool     InpEnableVolumeFilter = false;       // [Filter: Volume Confirmation] Bật Volume (off by default - forex ko có volume thật)
input bool     InpVolumeCritical     = false;       // [Filter: Volume Confirmation] Critical
input int      InpVolumeAvgPeriod    = 20;          // [Filter: Volume Confirmation] Volume Avg Period
input double   InpMinVolumeRatio     = 0.8;         // [Filter: Volume Confirmation] Min Volume Ratio (80% avg)
input double   InpVolumeWeight       = 5.0;         // [Filter: Volume Confirmation] Weight

// ==============================================================
// FILTER 9: PRICE-MA DISTANCE
// Tránh chase - giá không quá xa MA50
// ==============================================================
input bool     InpEnablePriceMADistFilter = true;   // [Filter: Price-MA Distance] Bật Price-MA Dist
input bool     InpPriceMADistCritical     = true;   // [Filter: Price-MA Distance] Critical (quan trọng - tránh chase)
input double   InpMaxPriceMADistATR       = 1.5;    // [Filter: Price-MA Distance] Max Distance (1.5x ATR - không chase)
input double   InpPriceMAWeight           = 10.0;   // [Filter: Price-MA Distance] Weight

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
input bool     InpAlertEnabled = true;             // Bật/tắt Alert popup
input bool     InpPushEnabled  = true;             // Bật/tắt Push Notification

// --- AUTO SETUP ---
input bool     InpAutoAddIndicators = true;         // Tự động thêm SMA/RSI/MACD lên chart

// ==================================================
// ================= BIẾN TOÀN CỤC ===================
// ==================================================

// Struct để lưu tooltip data đầy đủ cho mỗi signal
struct SignalTooltipData
  {
   string            objectId;      // ID của object (dùng để match)
   string            fullTooltip;   // Nội dung đầy đủ hiển thị khi click
  };

SignalTooltipData g_tooltipData[];   // Mảng lưu tất cả tooltip
int               g_tooltipCount = 0;

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

   hMACD = iMACD(_Symbol, _Period, InpMACDFast, InpMACDSlow, InpMACDSignal, PRICE_CLOSE);
   if(hMACD == INVALID_HANDLE)
      return INIT_FAILED;

// ADX indicator for trend strength filter
   hADX = iADX(_Symbol, _Period, InpADXPeriod);
   if(hADX == INVALID_HANDLE)
      return INIT_FAILED;

// --- CONFIG INITIALIZATION ---

// ==============================================================
// 1. CORE SETTINGS
// ==============================================================
   g_config.minStopLoss = InpMinStopLoss;
   g_config.riskRewardRate = InpRiskRewardRate;
   g_config.srBufferPercent = InpSRBufferPercent;
   g_config.minScoreToPass = InpMinScoreToPass;

// ==============================================================
// 2. INDICATOR PARAMETERS
// ==============================================================
   g_config.sma50Period = InpMA50Period;
   g_config.sma200Period = InpMA200Period;
   g_config.ma50SlopeThreshold = InpMA50SlopeThreshold;
   g_config.slopeSmoothBars = InpSlopeSmoothBars;
   g_config.rsiPeriod = InpRSIPeriod;
   g_config.macdFast = InpMACDFast;
   g_config.macdSlow = InpMACDSlow;
   g_config.macdSignal = InpMACDSignal;
   g_config.adxPeriod = InpADXPeriod;

// ==============================================================
// 3. STRATEGY PARAMETERS
// ==============================================================
   g_config.maxWaitBars = InpMaxWaitBars;
   g_config.atrLength = InpATRLength;
   g_config.wickBodyRatio = InpWickBodyRatio;

// ==============================================================
// FILTER 1: MA SLOPE
// ==============================================================
   g_config.enableMASlopeFilter = InpEnableMASlopeFilter;
   g_config.maSlopeCritical = InpMASlopeCritical;
   g_config.maSlopeWeight = InpMASlopeWeight;

// ==============================================================
// FILTER 2A: STATIC MOMENTUM
// ==============================================================
   g_config.enableStaticMomentumFilter = InpEnableStaticMomentum;
   g_config.staticMomentumCritical = InpStaticMomentumCritical;
   g_config.staticMomentumWeight = InpStaticMomentumWeight;

// ==============================================================
// FILTER 2B: RSI REVERSAL
// ==============================================================
   g_config.enableRSIReversalFilter = InpEnableRSIReversal;
   g_config.rsiReversalCritical = InpRSIReversalCritical;
   g_config.rsiReversalLookback = InpRSIReversalLookback;
   g_config.rsiReversalWeight = InpRSIReversalWeight;

// ==============================================================
// FILTER 2C: MACD HISTOGRAM
// ==============================================================
   g_config.enableMACDHistogramFilter = InpEnableMACDHistogram;
   g_config.macdHistogramCritical = InpMACDHistogramCritical;
   g_config.macdHistogramLookback = InpMACDHistogramLookback;
   g_config.macdHistogramWeight = InpMACDHistogramWeight;

// ==============================================================
// FILTER 3: SMA200 TREND
// ==============================================================
   g_config.enableSMA200Filter = InpEnableSMA200Filter;
   g_config.sma200Critical = InpSMA200Critical;
   g_config.sma200Weight = InpSMA200Weight;

// ==============================================================
// FILTER 4: S/R ZONE
// ==============================================================
   g_config.enableSRZoneFilter = InpEnableSRZoneFilter;
   g_config.srZoneCritical = InpSRZoneCritical;
   g_config.srLookback = InpSRLookback;
   g_config.srZonePercent = InpSRZonePercent;
   g_config.srZoneWeight = InpSRZoneWeight;

// ==============================================================
// FILTER 4B: S/R MIN WIDTH
// ==============================================================
   g_config.enableSRMinWidthFilter = InpEnableSRMinWidthFilter;
   g_config.srMinWidthCritical = InpSRMinWidthCritical;
   g_config.minSRWidthATR = InpMinSRWidthATR;
   g_config.srMinWidthWeight = InpSRMinWidthWeight;

// ==============================================================
// FILTER 5: MA NOISE
// ==============================================================
   g_config.minCutInterval = InpMinCutInterval;
   g_config.cutIntervalWeight = InpCutIntervalWeight;
   g_config.maxCutsInLookback = InpMaxCutsInLookback;
   g_config.cutsLookbackBars = InpCutsLookbackBars;
   g_config.maxCutsWeight = InpMaxCutsWeight;
   g_config.peakMaDistanceThreshold = InpPeakMADistanceThreshold;
   g_config.peakMADistWeight = InpPeakMADistWeight;

// ==============================================================
// FILTER 6: ADX TREND STRENGTH
// ==============================================================
   g_config.enableADXFilter = InpEnableADXFilter;
   g_config.adxCritical = InpADXCritical;
   g_config.minADXThreshold = InpMinADXThreshold;
   g_config.useADXDirectionalConfirm = InpADXDirectionalConfirm;
   g_config.adxWeight = InpADXWeight;

// ==============================================================
// FILTER 7: BODY/ATR RATIO
// ==============================================================
   g_config.enableBodyATRFilter = InpEnableBodyATRFilter;
   g_config.bodyATRCritical = InpBodyATRCritical;
   g_config.minBodyATRRatio = InpMinBodyATRRatio;
   g_config.bodyATRWeight = InpBodyATRWeight;

// ==============================================================
// FILTER 8: VOLUME CONFIRMATION
// ==============================================================
   g_config.enableVolumeFilter = InpEnableVolumeFilter;
   g_config.volumeCritical = InpVolumeCritical;
   g_config.volumeAvgPeriod = InpVolumeAvgPeriod;
   g_config.minVolumeRatio = InpMinVolumeRatio;
   g_config.volumeWeight = InpVolumeWeight;

// ==============================================================
// FILTER 9: PRICE-MA DISTANCE
// ==============================================================
   g_config.enablePriceMADistanceFilter = InpEnablePriceMADistFilter;
   g_config.priceMADistCritical = InpPriceMADistCritical;
   g_config.maxPriceMADistanceATR = InpMaxPriceMADistATR;
   g_config.priceMADistWeight = InpPriceMAWeight;

// ==============================================================
// FILTER 10-12: TIME/NEWS/CONSEC LOSS (Disabled for Indicator)
// ==============================================================
   g_config.enableTimeFilter = false;
   g_config.timeCritical = false;
   g_config.enableNewsFilter = false;
   g_config.newsCritical = false;
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
   Comment("");  // Xóa comment box
   ObjectsDeleteAll(0, OBJ_PREFIX);
   IndicatorRelease(hSMA50);
   IndicatorRelease(hSMA200);
   IndicatorRelease(hRSI);
   IndicatorRelease(hMACD);
   IndicatorRelease(hADX);

// Xóa chart indicators nếu đã thêm
   RemoveIndicatorsFromChart();

// Clear tooltip data
   ArrayResize(g_tooltipData, 0);
   g_tooltipCount = 0;
  }

// ==================================================
// =============== ON CHART EVENT ====================
// ==================================================
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
  {
// Xử lý khi click vào object
   if(id == CHARTEVENT_OBJECT_CLICK)
     {
      // Kiểm tra xem object có thuộc indicator này không
      if(StringFind(sparam, OBJ_PREFIX) == 0)
        {
         // Tìm tooltip data cho object này
         string baseId = sparam;
         // Loại bỏ suffix - QUAN TRỌNG: check _SL trước _S, _AR trước _R
         int pos = StringFind(baseId, "_DIA");
         if(pos > 0)
            baseId = StringSubstr(baseId, 0, pos);
         pos = StringFind(baseId, "_LBL");
         if(pos > 0)
            baseId = StringSubstr(baseId, 0, pos);
         pos = StringFind(baseId, "_SL");
         if(pos > 0)
            baseId = StringSubstr(baseId, 0, pos);
         pos = StringFind(baseId, "_TP");
         if(pos > 0)
            baseId = StringSubstr(baseId, 0, pos);
         pos = StringFind(baseId, "_AR");
         if(pos > 0)
            baseId = StringSubstr(baseId, 0, pos);
         pos = StringFind(baseId, "_S");
         if(pos > 0)
            baseId = StringSubstr(baseId, 0, pos);
         pos = StringFind(baseId, "_R");
         if(pos > 0)
            baseId = StringSubstr(baseId, 0, pos);

         // Tìm trong mảng tooltip
         for(int i = 0; i < g_tooltipCount; i++)
           {
            if(g_tooltipData[i].objectId == baseId)
              {
               Comment(g_tooltipData[i].fullTooltip);
               ChartRedraw();
               return;
              }
           }
        }
     }
// Click vào vùng trống - xóa comment
   else
      if(id == CHARTEVENT_CLICK)
        {
         Comment("");
         ChartRedraw();
        }
  }

// ==================================================
// ========== AUTO ADD INDICATORS TO CHART ==========
// ==================================================
void AddIndicatorsToChart()
  {
   long chartId = ChartID();
   string indName = "";

// Thêm SMA 50
   if(hSMA50 != INVALID_HANDLE)
     {
      if(IndicatorExists(chartId, "MA(" + IntegerToString(InpMA50Period) + ")", indName) == -1)
        {
         if(!ChartIndicatorAdd(chartId, 0, hSMA50))
            Print("Lỗi thêm SMA50");
        }
     }

// Thêm SMA 200
   if(hSMA200 != INVALID_HANDLE)
     {
      if(IndicatorExists(chartId, "MA(" + IntegerToString(InpMA200Period) + ")", indName) == -1)
        {
         if(!ChartIndicatorAdd(chartId, 0, hSMA200))
            Print("Lỗi thêm SMA200");
        }
     }

// Thêm RSI (subwindow mới)
   if(hRSI != INVALID_HANDLE)
     {
      if(IndicatorExists(chartId, "RSI(" + IntegerToString(InpRSIPeriod) + ")", indName) == -1)
        {
         int rsiWindow = (int)ChartGetInteger(chartId, CHART_WINDOWS_TOTAL);
         if(!ChartIndicatorAdd(chartId, rsiWindow, hRSI))
            Print("Lỗi thêm RSI");
        }
     }

// Thêm MACD (subwindow mới)
   if(hMACD != INVALID_HANDLE)
     {
      if(IndicatorExists(chartId, "MACD", indName) == -1)
        {
         int macdWindow = (int)ChartGetInteger(chartId, CHART_WINDOWS_TOTAL);
         if(!ChartIndicatorAdd(chartId, macdWindow, hMACD))
            Print("Lỗi thêm MACD");
        }
     }
  }

// ==================================================
void RemoveIndicatorsFromChart()
  {
   long chartId = ChartID();

// Xóa SMA 50 (chỉ xóa khỏi chart, không release handle vì OnDeinit sẽ làm)
   string indName = "";
   int window = IndicatorExists(chartId, "MA(" + IntegerToString(InpMA50Period) + ")", indName);
   if(window >= 0 && indName != "")
     {
      ChartIndicatorDelete(chartId, window, indName);
     }

// Xóa SMA 200
   indName = "";
   window = IndicatorExists(chartId, "MA(" + IntegerToString(InpMA200Period) + ")", indName);
   if(window >= 0 && indName != "")
     {
      ChartIndicatorDelete(chartId, window, indName);
     }

// Xóa RSI (tìm trong các subwindow)
   indName = "";
   window = IndicatorExists(chartId, "RSI(" + IntegerToString(InpRSIPeriod) + ")", indName);
   if(window >= 0 && indName != "")
     {
      ChartIndicatorDelete(chartId, window, indName);
     }

// Xóa MACD (tìm trong các subwindow)
   indName = "";
   window = IndicatorExists(chartId, "MACD", indName);
   if(window >= 0 && indName != "")
     {
      ChartIndicatorDelete(chartId, window, indName);
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

   SignalTooltipData tooltipData;
   tooltipData.objectId = id;
   tooltipData.fullTooltip = tooltipText;
   ++g_tooltipCount;
   ArrayResize(g_tooltipData, g_tooltipCount);
   g_tooltipData[g_tooltipCount - 1] = tooltipData;


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
