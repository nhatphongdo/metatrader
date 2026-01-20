//+------------------------------------------------------------------+
//|                                           SMA Pullback indicator |
//|                                    Copyright 2026, Do Nhat Phong |
//|                                   https://github.com/nhatphongdo |
//+------------------------------------------------------------------+
#property indicator_chart_window
#property indicator_plots 0

#include "../include/MA_Pullback_Inputs.mqh"

// ==================================================
// ===================== INPUT =======================
// ==================================================

// --- TRADE LIMITS ---
input group "=== Cấu hình Giới hạn Trade ===";
input double InpMinStopLoss = DEF_MIN_STOP_LOSS;               // Số points StopLoss tối thiểu
input double InpMaxRiskRewardRate = DEF_MAX_RISK_REWARD_RATE;  // Tỷ lệ Reward / Risk tối đa
input double InpMinRiskRewardRate = DEF_MIN_RISK_REWARD_RATE;  // Tỷ lệ Reward / Risk tối thiểu
input double InpSRBufferPercent = DEF_SR_BUFFER_PERCENT;       // S/R/MA Buffer (%)

// --- INDICATOR SETTINGS ---
input group "=== Cấu hình Chỉ báo ===";
input ENUM_MA_TYPE_MODE InpMAType = DEF_MA_TYPE;  // Loại Moving Average
input int InpMA50Period = DEF_MA50_PERIOD;        // Chu kỳ MA Fast
input int InpMA200Period = DEF_MA200_PERIOD;      // Chu kỳ MA Slow
input int InpRSIPeriod = DEF_RSI_PERIOD;          // Chu kỳ RSI
input int InpMACDFast = DEF_MACD_FAST;            // Chu kỳ MACD Fast
input int InpMACDSlow = DEF_MACD_SLOW;            // Chu kỳ MACD Slow
input int InpMACDSignal = DEF_MACD_SIGNAL;        // Chu kỳ MACD Signal
input int InpATRLength = DEF_ATR_LENGTH;          // Số nến tính ATR

// --- STRATEGY SETTINGS ---
input group "=== Cấu hình Chiến lược ===";
input int InpMaxWaitBars = DEF_MAX_WAIT_BARS;         // Số nến tối đa chờ pullback
input double InpWickBodyRatio = DEF_WICK_BODY_RATIO;  // Tỷ lệ Bóng/Thân nến

// ==================================================
// ============== FILTER SETTINGS ===================
// ==================================================
input group "=== Cấu hình Bộ lọc ===";
input double InpMinScoreToPass = DEF_MIN_SCORE_TO_PASS;  // Điểm Threshold để Valid

// FILTER 1: MA SLOPE
input group "=== Cấu hình Bộ lọc 1: Độ dốc đường MA ===";
input bool InpEnableMASlopeFilter = DEF_ENABLE_MA_SLOPE;        // [MA Slope] Bật
input bool InpMASlopeCritical = DEF_MA_SLOPE_CRITICAL;          // [MA Slope] Critical
input double InpMA50SlopeThreshold = DEF_MA50_SLOPE_THRESHOLD;  // [MA Slope] Threshold (độ)
input int InpSlopeSmoothBars = DEF_SLOPE_SMOOTH_BARS;           // [MA Slope] Số nến tính Slope
input double InpMASlopeWeight = DEF_MA_SLOPE_WEIGHT;            // [MA Slope] Weight

// FILTER 2A: STATIC MOMENTUM
input group "=== Cấu hình Bộ lọc 2A: Động lượng ===";
input bool InpEnableStaticMomentum = DEF_ENABLE_STATIC_MOMENTUM;      // [Static Momentum] Bật
input bool InpStaticMomentumCritical = DEF_STATIC_MOMENTUM_CRITICAL;  // [Static Momentum] Critical
input double InpStaticMomentumWeight = DEF_STATIC_MOMENTUM_WEIGHT;    // [Static Momentum] Weight

// FILTER 2B: RSI REVERSAL
input group "=== Cấu hình Bộ lọc 2B: Đảo chiều RSI ===";
bool InpEnableRSIReversal = DEF_ENABLE_RSI_REVERSAL;      // [RSI Reversal] Bật
bool InpRSIReversalCritical = DEF_RSI_REVERSAL_CRITICAL;  // [RSI Reversal] Critical
int InpRSIReversalLookback = DEF_RSI_REVERSAL_LOOKBACK;   // [RSI Reversal] Lookback
double InpRSIReversalWeight = DEF_RSI_REVERSAL_WEIGHT;    // [RSI Reversal] Weight

// FILTER 2C: MACD HISTOGRAM
input group "=== Cấu hình Bộ lọc 2C: MACD Histogram ===";
input bool InpEnableMACDHistogram = DEF_ENABLE_MACD_HISTOGRAM;      // [MACD Histogram] Bật
input bool InpMACDHistogramCritical = DEF_MACD_HISTOGRAM_CRITICAL;  // [MACD Histogram] Critical
input int InpMACDHistogramLookback = DEF_MACD_HISTOGRAM_LOOKBACK;   // [MACD Histogram] Lookback
input double InpMACDHistogramWeight = DEF_MACD_HISTOGRAM_WEIGHT;    // [MACD Histogram] Weight

// FILTER 3: SMA200 TREND
input group "=== Cấu hình Bộ lọc 3: Xu hướng MA dài hạn (vd: MA200) ===";
input bool InpEnableSMA200Filter = DEF_ENABLE_SMA200_FILTER;  // [SMA200 Trend] Bật
input bool InpSMA200Critical = DEF_SMA200_CRITICAL;           // [SMA200 Trend] Critical
input double InpSMA200Weight = DEF_SMA200_WEIGHT;             // [SMA200 Trend] Weight

// FILTER 4A: S/R ZONE
input group "=== Cấu hình Bộ lọc 4A: Vùng S/R ===";
input bool InpEnableSRZoneFilter = DEF_ENABLE_SR_ZONE_FILTER;  // [S/R Zone] Bật
input bool InpSRZoneCritical = DEF_SR_ZONE_CRITICAL;           // [S/R Zone] Critical
input int InpSRLookback = DEF_SR_LOOKBACK;                     // [S/R Zone] Lookback Bars
input double InpSRZonePercent = DEF_SR_ZONE_PERCENT;           // [S/R Zone] % Zone Width
input double InpSRZoneWeight = DEF_SR_ZONE_WEIGHT;             // [S/R Zone] Weight

// FILTER 4B: S/R MIN WIDTH
input group "=== Cấu hình Bộ lọc 4B: Độ rộng tối thiểu vùng S/R ===";
bool InpEnableSRMinWidthFilter = DEF_ENABLE_SR_MIN_WIDTH;  // [S/R Min Width] Bật
bool InpSRMinWidthCritical = DEF_SR_MIN_WIDTH_CRITICAL;    // [S/R Min Width] Critical
double InpMinSRWidthATR = DEF_MIN_SR_WIDTH_ATR;            // [S/R Min Width] Độ rộng tối thiểu (xATR)
double InpSRMinWidthWeight = DEF_SR_MIN_WIDTH_WEIGHT;      // [S/R Min Width] Weight

// FILTER 5: MA NOISE
input group "=== Cấu hình Bộ lọc 5: Nhiễu MA (giao cắt liên tục) ===";
input int InpMinCutInterval = DEF_MIN_CUT_INTERVAL;                    // [MA Noise] Min Cut Interval
input double InpCutIntervalWeight = DEF_CUT_INTERVAL_WEIGHT;           // [MA Noise] Cut Interval Weight
input int InpMaxCutsInLookback = DEF_MAX_CUTS_IN_LOOKBACK;             // [MA Noise] Max Cuts in Lookback
input int InpCutsLookbackBars = DEF_CUTS_LOOKBACK_BARS;                // [MA Noise] Cuts Lookback Bars
input double InpMaxCutsWeight = DEF_MAX_CUTS_WEIGHT;                   // [MA Noise] Max Cuts Weight
input double InpPeakMADistanceThreshold = DEF_PEAK_MA_DIST_THRESHOLD;  // [MA Noise] Peak-MA Threshold
input double InpPeakMADistWeight = DEF_PEAK_MA_DIST_WEIGHT;            // [MA Noise] Peak-MA Weight

// FILTER 6: ADX TREND STRENGTH
input group "=== Cấu hình Bộ lọc 6: Cường độ xu hướng ADX ===";
input bool InpEnableADXFilter = DEF_ENABLE_ADX_FILTER;              // [ADX] Bật
input bool InpADXCritical = DEF_ADX_CRITICAL;                       // [ADX] Critical
input int InpADXPeriod = DEF_ADX_PERIOD;                            // [ADX] Chu kỳ
input double InpMinADXThreshold = DEF_MIN_ADX_THRESHOLD;            // [ADX] Min Threshold
input bool InpADXDirectionalConfirm = DEF_ADX_DIRECTIONAL_CONFIRM;  // [ADX] Check +DI/-DI
input double InpADXWeight = DEF_ADX_WEIGHT;                         // [ADX] Weight

// FILTER 7: BODY/ATR RATIO
input group "=== Cấu hình Bộ lọc 7: Tỷ lệ thân nến/ATR ===";
input bool InpEnableBodyATRFilter = DEF_ENABLE_BODY_ATR_FILTER;  // [Body/ATR] Bật
input bool InpBodyATRCritical = DEF_BODY_ATR_CRITICAL;           // [Body/ATR] Critical
input double InpMinBodyATRRatio = DEF_MIN_BODY_ATR_RATIO;        // [Body/ATR] Min Ratio
input double InpBodyATRWeight = DEF_BODY_ATR_WEIGHT;             // [Body/ATR] Weight

// FILTER 8: VOLUME CONFIRMATION
input group "=== Cấu hình Bộ lọc 8: Xác nhận volume (tắt)===";
bool InpEnableVolumeFilter = DEF_ENABLE_VOLUME_FILTER;  // [Volume] Bật
bool InpVolumeCritical = DEF_VOLUME_CRITICAL;           // [Volume] Critical
int InpVolumeAvgPeriod = DEF_VOLUME_AVG_PERIOD;         // [Volume] Avg Period
double InpMinVolumeRatio = DEF_MIN_VOLUME_RATIO;        // [Volume] Min Ratio
double InpVolumeWeight = DEF_VOLUME_WEIGHT;             // [Volume] Weight

// FILTER 9: PRICE-MA DISTANCE
input group "=== Cấu hình Bộ lọc 9: Khoảng cách giá/MA ===";
input bool InpEnablePriceMADistFilter = DEF_ENABLE_PRICE_MA_DIST;  // [Price-MA] Bật
input bool InpPriceMADistCritical = DEF_PRICE_MA_DIST_CRITICAL;    // [Price-MA] Critical
input double InpMaxPriceMADistATR = DEF_MAX_PRICE_MA_DIST_ATR;     // [Price-MA] Max Distance (xATR)
input double InpPriceMAWeight = DEF_PRICE_MA_DIST_WEIGHT;          // [Price-MA] Weight

// ============== DISPLAY SETTINGS ==================
// ==================================================

// --- COLORS ---
input group "=== Cấu hình Màu sắc tín hiệu ===";
input color InpBuyColor = DEF_BUY_COLOR;          // Màu tín hiệu BUY
input color InpSellColor = DEF_SELL_COLOR;        // Màu tín hiệu SELL
input color InpSLColor = DEF_SL_COLOR;            // Màu đường Stoploss
input color InpTPColor = DEF_TP_COLOR;            // Màu đường Take profit
input color InpStrongColor = DEF_STRONG_COLOR;    // Màu label tín hiệu mạnh
input color InpWeakColor = DEF_WEAK_COLOR;        // Màu label tín hiệu yếu
input color InpSupportColor = DEF_SUPPORT_COLOR;  // Màu vùng Support
input color InpResistColor = DEF_RESIST_COLOR;    // Màu vùng Resistance
input color InpCancelColor = DEF_CANCEL_COLOR;    // Màu tín hiệu bị hủy

// --- ALERTS ---
input group "=== Cấu hình Thông báo ===";
input bool InpAlertEnabled = DEF_ALERT_ENABLED;  // Bật/tắt Alert popup
input bool InpPushEnabled = DEF_PUSH_ENABLED;    // Bật/tắt Push Notification

// --- AUTO SETUP ---
input group "=== Cấu hình Hiển thị chỉ báo tự động ===";
input bool InpAutoAddIndicators = true;       // Tự động thêm SMA/RSI/MACD lên chart
input color InpMAFastColor = clrSalmon;       // Màu đường MA nhanh
input color InpMASlowColor = clrDeepSkyBlue;  // Màu đường MA chậm
input color InpRSIColor = clrDodgerBlue;      // Màu đường RSI
input color InpMACDMainColor = clrSilver;     // Màu đường MACD chính
input color InpMACDSignalColor = clrYellow;   // Màu đường MACD tín hiệu

// ==================================================
// ================= BIẾN TOÀN CỤC ===================
// ==================================================

datetime g_lastProcessedBarTime = 0;
string OBJ_PREFIX = "SIG_";
int hSMA50;
int hSMA200;
int hRSI;
int hMACD;
int hADX;
int hATR;
int g_nextAllowedCutIdx = -1;
double g_tickSize;
double g_pointValue;
SMAPullbackConfig g_config;
SignalDrawConfig g_drawConfig;

// ==================================================
// ===================== INIT ========================
// ==================================================
int OnInit()
{
   hSMA50 = iMA(_Symbol, _Period, InpMA50Period, 0, (ENUM_MA_METHOD)InpMAType, PRICE_CLOSE);
   if (hSMA50 == INVALID_HANDLE)
      return INIT_FAILED;

   hSMA200 = iMA(_Symbol, _Period, InpMA200Period, 0, (ENUM_MA_METHOD)InpMAType, PRICE_CLOSE);
   if (hSMA200 == INVALID_HANDLE)
      return INIT_FAILED;

   hRSI = iRSI(_Symbol, _Period, InpRSIPeriod, PRICE_CLOSE);
   if (hRSI == INVALID_HANDLE)
      return INIT_FAILED;

   hMACD = iMACD(_Symbol, _Period, InpMACDFast, InpMACDSlow, InpMACDSignal, PRICE_CLOSE);
   if (hMACD == INVALID_HANDLE)
      return INIT_FAILED;

   // ADX indicator for trend strength filter
   hADX = iADX(_Symbol, _Period, InpADXPeriod);
   if (hADX == INVALID_HANDLE)
      return INIT_FAILED;

   // ATR indicator
   hATR = iATR(_Symbol, _Period, InpATRLength);
   if (hATR == INVALID_HANDLE)
      return INIT_FAILED;

   // --- CONFIG INITIALIZATION ---
   // Core Settings
   g_config.minStopLoss = InpMinStopLoss;
   g_config.maxRiskRewardRate = InpMaxRiskRewardRate;
   g_config.minRiskRewardRate = InpMinRiskRewardRate;
   g_config.srBufferPercent = InpSRBufferPercent;
   g_config.minScoreToPass = InpMinScoreToPass;
   // Indicator Parameters
   g_config.sma50Period = InpMA50Period;
   g_config.sma200Period = InpMA200Period;
   g_config.ma50SlopeThreshold = InpMA50SlopeThreshold;
   g_config.slopeSmoothBars = InpSlopeSmoothBars;
   g_config.rsiPeriod = InpRSIPeriod;
   g_config.macdFast = InpMACDFast;
   g_config.macdSlow = InpMACDSlow;
   g_config.macdSignal = InpMACDSignal;
   g_config.adxPeriod = InpADXPeriod;
   // Strategy Parameters
   g_config.maxWaitBars = InpMaxWaitBars;
   g_config.atrLength = InpATRLength;
   g_config.wickBodyRatio = InpWickBodyRatio;
   // Filter 1: MA Slope
   g_config.enableMASlopeFilter = InpEnableMASlopeFilter;
   g_config.maSlopeCritical = InpMASlopeCritical;
   g_config.maSlopeWeight = InpMASlopeWeight;
   // Filter 2A: Static Momentum
   g_config.enableStaticMomentumFilter = InpEnableStaticMomentum;
   g_config.staticMomentumCritical = InpStaticMomentumCritical;
   g_config.staticMomentumWeight = InpStaticMomentumWeight;
   // Filter 2B: RSI Reversal
   g_config.enableRSIReversalFilter = InpEnableRSIReversal;
   g_config.rsiReversalCritical = InpRSIReversalCritical;
   g_config.rsiReversalLookback = InpRSIReversalLookback;
   g_config.rsiReversalWeight = InpRSIReversalWeight;
   // Filter 2C: MACD Histogram
   g_config.enableMACDHistogramFilter = InpEnableMACDHistogram;
   g_config.macdHistogramCritical = InpMACDHistogramCritical;
   g_config.macdHistogramLookback = InpMACDHistogramLookback;
   g_config.macdHistogramWeight = InpMACDHistogramWeight;
   // Filter 3: SMA200 Trend
   g_config.enableSMA200Filter = InpEnableSMA200Filter;
   g_config.sma200Critical = InpSMA200Critical;
   g_config.sma200Weight = InpSMA200Weight;
   // Filter 4: S/R Zone
   g_config.enableSRZoneFilter = InpEnableSRZoneFilter;
   g_config.srZoneCritical = InpSRZoneCritical;
   g_config.srLookback = InpSRLookback;
   g_config.srZonePercent = InpSRZonePercent;
   g_config.srZoneWeight = InpSRZoneWeight;
   // Filter 4B: S/R Min Width
   g_config.enableSRMinWidthFilter = InpEnableSRMinWidthFilter;
   g_config.srMinWidthCritical = InpSRMinWidthCritical;
   g_config.minSRWidthATR = InpMinSRWidthATR;
   g_config.srMinWidthWeight = InpSRMinWidthWeight;
   // Filter 5: MA Noise
   g_config.minCutInterval = InpMinCutInterval;
   g_config.cutIntervalWeight = InpCutIntervalWeight;
   g_config.maxCutsInLookback = InpMaxCutsInLookback;
   g_config.cutsLookbackBars = InpCutsLookbackBars;
   g_config.maxCutsWeight = InpMaxCutsWeight;
   g_config.peakMaDistanceThreshold = InpPeakMADistanceThreshold;
   g_config.peakMADistWeight = InpPeakMADistWeight;
   // Filter 6: ADX
   g_config.enableADXFilter = InpEnableADXFilter;
   g_config.adxCritical = InpADXCritical;
   g_config.minADXThreshold = InpMinADXThreshold;
   g_config.useADXDirectionalConfirm = InpADXDirectionalConfirm;
   g_config.adxWeight = InpADXWeight;
   // Filter 7: Body/ATR
   g_config.enableBodyATRFilter = InpEnableBodyATRFilter;
   g_config.bodyATRCritical = InpBodyATRCritical;
   g_config.minBodyATRRatio = InpMinBodyATRRatio;
   g_config.bodyATRWeight = InpBodyATRWeight;
   // Filter 8: Volume
   g_config.enableVolumeFilter = InpEnableVolumeFilter;
   g_config.volumeCritical = InpVolumeCritical;
   g_config.volumeAvgPeriod = InpVolumeAvgPeriod;
   g_config.minVolumeRatio = InpMinVolumeRatio;
   g_config.volumeWeight = InpVolumeWeight;
   // Filter 9: Price-MA Distance
   g_config.enablePriceMADistanceFilter = InpEnablePriceMADistFilter;
   g_config.priceMADistCritical = InpPriceMADistCritical;
   g_config.maxPriceMADistanceATR = InpMaxPriceMADistATR;
   g_config.priceMADistWeight = InpPriceMAWeight;
   // Filter 10-12: Not used in Indicator (EA only)
   g_config.enableTimeFilter = false;
   g_config.timeCritical = false;
   g_config.enableNewsFilter = false;
   g_config.newsCritical = false;
   g_config.enableConsecutiveLossFilter = false;

   g_tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   g_pointValue = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   g_nextAllowedCutIdx = -1;

   // Khởi tạo draw config với màu sắc từ input
   InitDefaultSignalDrawConfig(g_drawConfig, OBJ_PREFIX);
   g_drawConfig.buyColor = InpBuyColor;
   g_drawConfig.sellColor = InpSellColor;
   g_drawConfig.slColor = InpSLColor;
   g_drawConfig.tpColor = InpTPColor;
   g_drawConfig.strongColor = InpStrongColor;
   g_drawConfig.weakColor = InpWeakColor;
   g_drawConfig.supportColor = InpSupportColor;
   g_drawConfig.resistColor = InpResistColor;
   g_drawConfig.cancelColor = InpCancelColor;
   g_drawConfig.lineLengthBars = InpMaxWaitBars;

   // Tự động thêm indicators lên chart
   if (InpAutoAddIndicators)
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
   IndicatorRelease(hATR);

   // Xóa chart indicators nếu đã thêm
   RemoveIndicatorsFromChart();

   // Clear tooltip data
   ClearSignalTooltips(OBJ_PREFIX);
}

// ==================================================
// =============== ON CHART EVENT ====================
// ==================================================
void OnChartEvent(const int id, const long& lparam, const double& dparam, const string& sparam)
{
   // Dùng hàm xử lý từ Utility
   HandleSignalChartEvent(id, lparam, dparam, sparam, OBJ_PREFIX);
}

// ==================================================
// ========== AUTO ADD INDICATORS TO CHART ==========
// ==================================================
void AddIndicatorsToChart()
{
   long chartId = ChartID();
   string indName = "";

   // Thêm MA 50
   if (hSMA50 != INVALID_HANDLE)
   {
      if (IndicatorExists(chartId, "MA(" + IntegerToString(InpMA50Period) + ")", indName) == -1)
      {
         PlotIndexSetInteger(hSMA50, 0, PLOT_LINE_COLOR, InpMAFastColor);
         if (!ChartIndicatorAdd(chartId, 0, hSMA50))
            Print("Lỗi thêm SMA50");
      }
   }

   // Thêm MA 200
   if (hSMA200 != INVALID_HANDLE)
   {
      if (IndicatorExists(chartId, "MA(" + IntegerToString(InpMA200Period) + ")", indName) == -1)
      {
         PlotIndexSetInteger(hSMA200, 0, PLOT_LINE_COLOR, InpMASlowColor);
         if (!ChartIndicatorAdd(chartId, 0, hSMA200))
            Print("Lỗi thêm SMA200");
      }
   }

   // Thêm RSI (subwindow mới)
   if (hRSI != INVALID_HANDLE)
   {
      if (IndicatorExists(chartId, "RSI(" + IntegerToString(InpRSIPeriod) + ")", indName) == -1)
      {
         PlotIndexSetInteger(hRSI, 0, PLOT_LINE_COLOR, InpRSIColor);
         int rsiWindow = (int)ChartGetInteger(chartId, CHART_WINDOWS_TOTAL);
         if (!ChartIndicatorAdd(chartId, rsiWindow, hRSI))
            Print("Lỗi thêm RSI");
      }
   }

   // Thêm MACD (subwindow mới)
   if (hMACD != INVALID_HANDLE)
   {
      if (IndicatorExists(chartId, "MACD", indName) == -1)
      {
         PlotIndexSetInteger(hMACD, 0, PLOT_LINE_COLOR, InpMACDMainColor);
         PlotIndexSetInteger(hMACD, 1, PLOT_LINE_COLOR, InpMACDSignalColor);
         PlotIndexSetInteger(hMACD, 1, PLOT_LINE_WIDTH, 2);
         int macdWindow = (int)ChartGetInteger(chartId, CHART_WINDOWS_TOTAL);
         if (!ChartIndicatorAdd(chartId, macdWindow, hMACD))
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
   if (window >= 0 && indName != "")
   {
      ChartIndicatorDelete(chartId, window, indName);
   }

   // Xóa SMA 200
   indName = "";
   window = IndicatorExists(chartId, "MA(" + IntegerToString(InpMA200Period) + ")", indName);
   if (window >= 0 && indName != "")
   {
      ChartIndicatorDelete(chartId, window, indName);
   }

   // Xóa RSI (tìm trong các subwindow)
   indName = "";
   window = IndicatorExists(chartId, "RSI(" + IntegerToString(InpRSIPeriod) + ")", indName);
   if (window >= 0 && indName != "")
   {
      ChartIndicatorDelete(chartId, window, indName);
   }

   // Xóa MACD (tìm trong các subwindow)
   indName = "";
   window = IndicatorExists(chartId, "MACD", indName);
   if (window >= 0 && indName != "")
   {
      ChartIndicatorDelete(chartId, window, indName);
   }
}

// ==================================================
// ================== ON CALCULATE ==================
// ==================================================
int OnCalculate(const int rates_total, const int prev_calculated, const datetime& time[], const double& open[],
                const double& high[], const double& low[], const double& close[], const long& tick_volume[],
                const long& volume[], const int& spread[])
{
   if (rates_total < 200)
      return rates_total;

   // QUAN TRỌNG: Set arrays as series để index 0 = nến hiện tại
   ArraySetAsSeries(time, true);
   ArraySetAsSeries(open, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(close, true);

   // Xác định phạm vi cần scan
   int limit;
   if (prev_calculated == 0)
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

   int copyCount = MathMin(rates_total, 10000);  // Copy tối đa 10000 nến
   if (CopyBuffer(hSMA50, 0, 0, copyCount, sma50) <= 0)
      return rates_total;

   if (CopyBuffer(hSMA200, 0, 0, copyCount, sma200) <= 0)
      return rates_total;

   // Copy RSI / MACD
   double rsi[];
   double macdMain[], macdSignal[];

   ArraySetAsSeries(rsi, true);
   ArraySetAsSeries(macdMain, true);
   ArraySetAsSeries(macdSignal, true);

   if (CopyBuffer(hRSI, 0, 0, copyCount, rsi) <= 0)
      return rates_total;

   if (CopyBuffer(hMACD, 0, 0, copyCount, macdMain) <= 0)
      return rates_total;

   if (CopyBuffer(hMACD, 1, 0, copyCount, macdSignal) <= 0)
      return rates_total;

   // Copy ADX buffers (for extended filters)
   double adxMain[], adxPlusDI[], adxMinusDI[];
   ArraySetAsSeries(adxMain, true);
   ArraySetAsSeries(adxPlusDI, true);
   ArraySetAsSeries(adxMinusDI, true);

   if (CopyBuffer(hADX, 0, 0, copyCount, adxMain) <= 0)  // ADX main line
      return rates_total;
   if (CopyBuffer(hADX, 1, 0, copyCount, adxPlusDI) <= 0)  // +DI
      return rates_total;
   if (CopyBuffer(hADX, 2, 0, copyCount, adxMinusDI) <= 0)  // -DI
      return rates_total;

   // Copy ATR buffers
   double atr[];
   ArraySetAsSeries(atr, true);
   if (CopyBuffer(hATR, 0, 0, copyCount, atr) <= 0)
      return rates_total;

   // Copy tick volume to series array
   long volumeAsSeries[];
   ArraySetAsSeries(volumeAsSeries, true);
   if (CopyTickVolume(_Symbol, _Period, 0, copyCount, volumeAsSeries) <= 0)
      return rates_total;

   // Loop qua các nến - tìm nến cắt SMA

   // Xác định điểm bắt đầu loop (Quá khứ -> Hiện tại)
   // Với Series: index lớn là quá khứ, index 0 là hiện tại
   // Chúng ta muốn duyệt từ Quá khứ (High Index) về Hiện tại (Low Index)
   int startIdx, endIdx;

   if (prev_calculated == 0)
   {
      startIdx = copyCount - 1 - InpMaxWaitBars;  // Bắt đầu từ nến cũ nhất có thể
      endIdx = 1;
   }
   else
   {
      // Realtime: chỉ check các nến mới
      // Bắt đầu từ nến cũ nhất cần kiểm tra (để đảm bảo không bỏ sót)
      // và kết thúc ở nến đóng mới nhất (index 1)
      startIdx = rates_total - prev_calculated + InpMaxWaitBars;
      if (startIdx >= copyCount)
         startIdx = copyCount - 1;
      endIdx = 1;
   }

   for (int cutIdx = startIdx; cutIdx >= endIdx; cutIdx--)
   {
      // Bỏ qua nến cắt nếu nó nằm trong vùng cấm của signal trước đó
      if (g_nextAllowedCutIdx != -1 && cutIdx >= g_nextAllowedCutIdx)
         continue;

      // Kiểm tra nến cắt SMA 50 tại cutIdx
      // BUY: nến mở trên SMA, low chạm dưới SMA (test SMA từ trên)
      // SELL: nến mở dưới SMA, high chạm trên SMA (test SMA từ dưới)
      bool cutUpToBottom = IsGreaterThan(open[cutIdx], sma50[cutIdx], g_tickSize) &&
                           IsLessThan(close[cutIdx], sma50[cutIdx], g_tickSize);
      bool cutDownToTop = IsLessThan(open[cutIdx], sma50[cutIdx], g_tickSize) &&
                          IsGreaterThan(close[cutIdx], sma50[cutIdx], g_tickSize);

      if (!cutUpToBottom && !cutDownToTop)
         continue;  // Không có nến cắt tại đây

      // Sử dụng ScanForSignal từ shared library
      ScanResult scanResult;
      ScanForSignal(g_config, cutIdx, cutUpToBottom, _Symbol, time[0], open, high, low, close, sma50, sma200, rsi,
                    macdMain, macdSignal, volumeAsSeries, adxMain, adxPlusDI, adxMinusDI, atr, g_tickSize, g_pointValue,
                    copyCount, scanResult);

      // Vẽ marker đánh dấu nến cắt SMA (chỉ khi không bị noise filter)
      DrawCutCandleMarker(g_drawConfig, cutUpToBottom, time[cutIdx], cutUpToBottom ? low[cutIdx] : high[cutIdx],
                          sma50[cutIdx], "", g_pointValue);

      if (scanResult.found)
      {
         // Signal found - vẽ lên chart
         DrawSignalMarker(g_drawConfig, scanResult.isBuy, false, time[scanResult.confirmIdx],
                          cutIdx - scanResult.confirmIdx, scanResult.signal.entry, scanResult.signal.sl,
                          scanResult.signal.tp, scanResult.signal.strength, scanResult.signal.score,
                          scanResult.signal.reasons, scanResult.signal.support, scanResult.signal.resistance,
                          g_pointValue, _Period);
         g_nextAllowedCutIdx = scanResult.confirmIdx;

         // Alert / Push Notification nếu được bật
         // Chỉ alert khi là tín hiệu mới (realtime), không alert khi mới load indicator
         if ((InpAlertEnabled || InpPushEnabled) && prev_calculated > 0)
         {
            string signalType = scanResult.isBuy ? "BUY" : "SELL";
            string alertMsg = StringFormat("%s - %s %s Tín hiệu @ %.5f | SL: %.5f | TP: %.5f | Điểm: %.1f", _Symbol,
                                           signalType, scanResult.signal.strength, scanResult.signal.entry,
                                           scanResult.signal.sl, scanResult.signal.tp, scanResult.signal.score);

            // Alert popup trên máy tính
            if (InpAlertEnabled)
               Alert(alertMsg);

            // Push notification lên điện thoại
            if (InpPushEnabled)
               SendNotification(alertMsg);
         }
      }
      else if (scanResult.cancelled)
      {
         // Signal cancelled - vẽ cancelled marker
         DrawSignalMarker(g_drawConfig, scanResult.isBuy, true, time[scanResult.confirmIdx], 0,
                          close[scanResult.confirmIdx], 0, 0, "", 0, scanResult.cancelReason, 0, 0, g_pointValue,
                          _Period);
         g_nextAllowedCutIdx = scanResult.confirmIdx;
      }
   }

   ChartRedraw();
   return rates_total;
}
//+------------------------------------------------------------------+
