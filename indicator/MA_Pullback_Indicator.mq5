//+------------------------------------------------------------------+
//|                                           SMA Pullback indicator |
//|                                    Copyright 2026, Do Nhat Phong |
//|                                   https://github.com/nhatphongdo |
//+------------------------------------------------------------------+
#property indicator_chart_window
#property indicator_plots 0

#include "../include/MA_Pullback_Inputs.mqh"
#include "../include/MA_Pullback_Draw.mqh"

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
input int InpADXPeriod = DEF_ADX_PERIOD;          // Số nến tính ADX
input int InpATRLength = DEF_ATR_LENGTH;          // Số nến tính ATR

// --- STRATEGY SETTINGS ---
input group "=== Cấu hình Chiến lược ===";
input int InpMinTrendBars = DEF_MIN_TREND_BARS;  // Số nến tối thiểu để hình thành trend trước khi đảo chiều
input int InpMaxWaitBars = DEF_MAX_WAIT_BARS;    // Số nến tối đa chờ pullback
input int InpSRLookback = DEF_SR_LOOKBACK;       // Số nến lookback để tìm support / resistance
input double InpMASidewayZoneRatio = DEF_MA_SIDEWAY_ZONE_RATIO;  // Tỷ lệ % zone để xác định vùng sideway quanh MA

// ==================================================
// ============== FILTER SETTINGS ===================
// ==================================================
input group "=== Cấu hình Bộ lọc ===";
input double InpMinScoreToPass = DEF_MIN_SCORE_TO_PASS;  // Điểm Threshold để Valid

// FILTER: MA SLOPE
input group "=== Cấu hình Bộ lọc: Độ dốc đường MA ===";
input bool InpEnableMASlopeFilter = DEF_ENABLE_MA_SLOPE;    // Bật
input bool InpMASlopeCritical = DEF_MA_SLOPE_CRITICAL;      // Critical
input double InpMASlopeThreshold = DEF_MA_SLOPE_THRESHOLD;  // Threshold (độ)
input double InpMASlopeWeight = DEF_MA_SLOPE_WEIGHT;        // Weight

// FILTER: RSI MOMENTUM
input group "=== Cấu hình Bộ lọc: Động lượng RSI ===";
input bool InpEnableRSIMomentum = DEF_ENABLE_RSI_MOMENTUM;      // Bật (trend confirmation)
input bool InpRSIMomentumCritical = DEF_RSI_MOMENTUM_CRITICAL;  // Critical
input double InpRSIMomentumWeight = DEF_RSI_MOMENTUM_WEIGHT;    // Weight

// FILTER: MACD MOMENTUM
input group "=== Cấu hình Bộ lọc: Động lượng MACD ===";
input bool InpEnableMACDMomentum = DEF_ENABLE_MACD_MOMENTUM;      // Bật (trend confirmation)
input bool InpMACDMomentumCritical = DEF_MACD_MOMENTUM_CRITICAL;  // Critical
input double InpMACDMomentumWeight = DEF_MACD_MOMENTUM_WEIGHT;    // Weight

// FILTER: RSI REVERSAL
input group "=== Cấu hình Bộ lọc: Đảo chiều RSI ===";
input bool InpEnableRSIReversal = DEF_ENABLE_RSI_REVERSAL;      // Bật
input bool InpRSIReversalCritical = DEF_RSI_REVERSAL_CRITICAL;  // Critical
input int InpRSIReversalLookback = DEF_RSI_REVERSAL_LOOKBACK;   // Lookback
input double InpRSIReversalWeight = DEF_RSI_REVERSAL_WEIGHT;    // Weight

// FILTER: MACD HISTOGRAM
input group "=== Cấu hình Bộ lọc: MACD Histogram ===";
input bool InpEnableMACDHistogram = DEF_ENABLE_MACD_HISTOGRAM;      // Bật
input bool InpMACDHistogramCritical = DEF_MACD_HISTOGRAM_CRITICAL;  // Critical
input int InpMACDHistogramLookback = DEF_MACD_HISTOGRAM_LOOKBACK;   // Lookback
input double InpMACDHistogramWeight = DEF_MACD_HISTOGRAM_WEIGHT;    // Weight

// FILTER: SMA200 TREND
input group "=== Cấu hình Bộ lọc: Xu hướng MA dài hạn (vd: MA200) ===";
input bool InpEnableSMA200Filter = DEF_ENABLE_SMA200_FILTER;  // Bật
input bool InpSMA200Critical = DEF_SMA200_CRITICAL;           // Critical
input double InpSMA200Weight = DEF_SMA200_WEIGHT;             // Weight

// FILTER: S/R ZONE
input group "=== Cấu hình Bộ lọc: Vùng S/R ===";
input bool InpEnableSRZoneFilter = DEF_ENABLE_SR_ZONE_FILTER;  // Bật
input bool InpSRZoneCritical = DEF_SR_ZONE_CRITICAL;           // Critical
input double InpSRZonePercent = DEF_SR_ZONE_PERCENT;           // % Zone Width
input double InpSRZoneWeight = DEF_SR_ZONE_WEIGHT;             // Weight

// FILTER: S/R MIN WIDTH
input group "=== Cấu hình Bộ lọc: Độ rộng tối thiểu vùng S/R ===";
bool InpEnableSRMinWidthFilter = DEF_ENABLE_SR_MIN_WIDTH;  // Bật
bool InpSRMinWidthCritical = DEF_SR_MIN_WIDTH_CRITICAL;    // Critical
double InpMinSRWidthATR = DEF_MIN_SR_WIDTH_ATR;            // Độ rộng tối thiểu (xATR)
double InpSRMinWidthWeight = DEF_SR_MIN_WIDTH_WEIGHT;      // Weight

// FILTER: ADX TREND STRENGTH
input group "=== Cấu hình Bộ lọc: Cường độ xu hướng ADX ===";
input bool InpEnableADXFilter = DEF_ENABLE_ADX_FILTER;              // Bật
input bool InpADXCritical = DEF_ADX_CRITICAL;                       // Critical
input double InpMinADXThreshold = DEF_MIN_ADX_THRESHOLD;            // Min Threshold
input bool InpADXDirectionalConfirm = DEF_ADX_DIRECTIONAL_CONFIRM;  // Check +DI/-DI
input double InpADXWeight = DEF_ADX_WEIGHT;                         // Weight

// FILTER: BODY/ATR RATIO
input group "=== Cấu hình Bộ lọc: Tỷ lệ thân nến/ATR ===";
input bool InpEnableBodyATRFilter = DEF_ENABLE_BODY_ATR_FILTER;  // Bật
input bool InpBodyATRCritical = DEF_BODY_ATR_CRITICAL;           // Critical
input double InpMinBodyATRRatio = DEF_MIN_BODY_ATR_RATIO;        // Min Ratio
input double InpBodyATRWeight = DEF_BODY_ATR_WEIGHT;             // Weight

// FILTER: VOLUME CONFIRMATION
input group "=== Cấu hình Bộ lọc: Xác nhận volume (tắt)===";
bool InpEnableVolumeFilter = DEF_ENABLE_VOLUME_FILTER;  // Bật
bool InpVolumeCritical = DEF_VOLUME_CRITICAL;           // Critical
int InpVolumeAvgPeriod = DEF_VOLUME_AVG_PERIOD;         // Avg Period
double InpMinVolumeRatio = DEF_MIN_VOLUME_RATIO;        // Min Ratio
double InpVolumeWeight = DEF_VOLUME_WEIGHT;             // Weight

// FILTER: PRICE-MA DISTANCE
input group "=== Cấu hình Bộ lọc: Khoảng cách giá/MA ===";
input bool InpEnablePriceMADistFilter = DEF_ENABLE_PRICE_MA_DIST;  // Bật
input bool InpPriceMADistCritical = DEF_PRICE_MA_DIST_CRITICAL;    // Critical
input double InpMaxPriceMADistATR = DEF_MAX_PRICE_MA_DIST_ATR;     // Max Distance (xATR)
input double InpPriceMAWeight = DEF_PRICE_MA_DIST_WEIGHT;          // Weight

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
datetime g_lastSignalTime = 0;
double g_tickSize;
double g_pointValue;
SMAPullbackConfig g_config;
SignalDrawConfig g_drawConfig;
int g_signalCount = 0;
long g_lastMouseX = -1;
long g_lastMouseY = -1;

// ==================================================
// ===================== INIT ========================
// ==================================================
int OnInit()
{
   hSMA50 = iCustom(_Symbol, _Period, "Examples\\Custom Moving Average",
                    InpMA50Period,              // Period
                    0,                          // Shift
                    (ENUM_MA_METHOD)InpMAType,  // Method
                    InpMAFastColor,             // Color
                    1,                          // Width
                    InpMASidewayZoneRatio,      // Zone width
                    0x303030,                   // Zone color
                    PRICE_CLOSE                 // Price
   );
   if (hSMA50 == INVALID_HANDLE)
      hSMA50 = iMA(_Symbol, _Period, InpMA50Period, 0, (ENUM_MA_METHOD)InpMAType, PRICE_CLOSE);
   if (hSMA50 == INVALID_HANDLE)
      return INIT_FAILED;

   hSMA200 = iCustom(_Symbol, _Period, "Examples\\Custom Moving Average",
                     InpMA200Period,             // Period
                     0,                          // Shift
                     (ENUM_MA_METHOD)InpMAType,  // Method
                     InpMASlowColor,             // Color
                     1,                          // Width
                     0.0,                        // Zone width
                     0x303030,                   // Zone color
                     PRICE_CLOSE                 // Price
   );
   if (hSMA200 == INVALID_HANDLE)
      hSMA200 = iMA(_Symbol, _Period, InpMA200Period, 0, (ENUM_MA_METHOD)InpMAType, PRICE_CLOSE);
   if (hSMA200 == INVALID_HANDLE)
      return INIT_FAILED;

   hRSI = iCustom(_Symbol, _Period, "Examples\\RSI",
                  InpRSIPeriod,  // Period
                  InpRSIColor,   // Color
                  1,             // Width
                  PRICE_CLOSE    // Price
   );
   if (hRSI == INVALID_HANDLE)
      hRSI = iRSI(_Symbol, _Period, InpRSIPeriod, PRICE_CLOSE);
   if (hRSI == INVALID_HANDLE)
      return INIT_FAILED;

   hMACD = iCustom(_Symbol, _Period, "Examples\\MACD", InpMACDFast, InpMACDSlow, InpMACDSignal, PRICE_CLOSE,
                   InpMACDMainColor, 2, InpMACDSignalColor, 2, STYLE_DOT);
   if (hMACD == INVALID_HANDLE)
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
   // Strategy Parameters
   g_config.minTrendBars = InpMinTrendBars;
   g_config.maxWaitBars = InpMaxWaitBars;
   g_config.maSidewayZoneRatio = InpMASidewayZoneRatio;
   g_config.srLookback = InpSRLookback;
   // Filter: MA Slope
   g_config.enableMASlopeFilter = InpEnableMASlopeFilter;
   g_config.maSlopeCritical = InpMASlopeCritical;
   g_config.maSlopeWeight = InpMASlopeWeight;
   // Filter: RSI Momentum
   g_config.enableRSIMomentumFilter = InpEnableRSIMomentum;
   g_config.rsiMomentumCritical = InpRSIMomentumCritical;
   g_config.rsiMomentumWeight = InpRSIMomentumWeight;
   // Filter: MACD Momentum
   g_config.enableMACDMomentumFilter = InpEnableMACDMomentum;
   g_config.macdMomentumCritical = InpMACDMomentumCritical;
   g_config.macdMomentumWeight = InpMACDMomentumWeight;
   // Filter: RSI Reversal
   g_config.enableRSIReversalFilter = InpEnableRSIReversal;
   g_config.rsiReversalCritical = InpRSIReversalCritical;
   g_config.rsiReversalLookback = InpRSIReversalLookback;
   g_config.rsiReversalWeight = InpRSIReversalWeight;
   // Filter: MACD Histogram
   g_config.enableMACDHistogramFilter = InpEnableMACDHistogram;
   g_config.macdHistogramCritical = InpMACDHistogramCritical;
   g_config.macdHistogramLookback = InpMACDHistogramLookback;
   g_config.macdHistogramWeight = InpMACDHistogramWeight;
   // Filter: SMA200 Trend
   g_config.enableSMA200Filter = InpEnableSMA200Filter;
   g_config.sma200Critical = InpSMA200Critical;
   g_config.sma200Weight = InpSMA200Weight;
   // Filter: S/R Zone
   g_config.enableSRZoneFilter = InpEnableSRZoneFilter;
   g_config.srZoneCritical = InpSRZoneCritical;
   g_config.srZonePercent = InpSRZonePercent;
   g_config.srZoneWeight = InpSRZoneWeight;
   // Filter: S/R Min Width
   g_config.enableSRMinWidthFilter = InpEnableSRMinWidthFilter;
   g_config.srMinWidthCritical = InpSRMinWidthCritical;
   g_config.minSRWidthATR = InpMinSRWidthATR;
   g_config.srMinWidthWeight = InpSRMinWidthWeight;
   // Filter: ADX
   g_config.enableADXFilter = InpEnableADXFilter;
   g_config.adxCritical = InpADXCritical;
   g_config.minADXThreshold = InpMinADXThreshold;
   g_config.useADXDirectionalConfirm = InpADXDirectionalConfirm;
   g_config.adxWeight = InpADXWeight;
   // Filter: Body/ATR
   g_config.enableBodyATRFilter = InpEnableBodyATRFilter;
   g_config.bodyATRCritical = InpBodyATRCritical;
   g_config.minBodyATRRatio = InpMinBodyATRRatio;
   g_config.bodyATRWeight = InpBodyATRWeight;
   // Filter: Volume
   g_config.enableVolumeFilter = InpEnableVolumeFilter;
   g_config.volumeCritical = InpVolumeCritical;
   g_config.volumeAvgPeriod = InpVolumeAvgPeriod;
   g_config.minVolumeRatio = InpMinVolumeRatio;
   g_config.volumeWeight = InpVolumeWeight;
   // Filter: Price-MA Distance
   g_config.enablePriceMADistanceFilter = InpEnablePriceMADistFilter;
   g_config.priceMADistCritical = InpPriceMADistCritical;
   g_config.maxPriceMADistanceATR = InpMaxPriceMADistATR;
   g_config.priceMADistWeight = InpPriceMAWeight;
   // Filter: Not used in Indicator (EA only)
   g_config.enableTimeFilter = false;
   g_config.timeCritical = false;
   g_config.enableNewsFilter = false;
   g_config.newsCritical = false;

   g_tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   g_pointValue = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   g_lastSignalTime = 0;
   g_signalCount = 0;
   g_lastMouseX = -1;
   g_lastMouseY = -1;

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
   HideTooltipLabel();
   ClearSignalTooltips(OBJ_PREFIX);
}

// ==================================================
// =============== ON CHART EVENT ====================
// ==================================================
void OnChartEvent(const int id, const long& lparam, const double& dparam, const string& sparam)
{
   // Dùng hàm xử lý từ Draw Utility
   HandleSignalChartEvent(id, lparam, dparam, sparam, OBJ_PREFIX, g_lastMouseX, g_lastMouseY);
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
         if (!ChartIndicatorAdd(chartId, 0, hSMA50))
            Print("Lỗi thêm SMA50");
      }
   }

   // Thêm MA 200
   if (hSMA200 != INVALID_HANDLE)
   {
      if (IndicatorExists(chartId, "MA(" + IntegerToString(InpMA200Period) + ")", indName) == -1)
      {
         if (!ChartIndicatorAdd(chartId, 0, hSMA200))
            Print("Lỗi thêm SMA200");
      }
   }

   // Thêm RSI (subwindow mới)
   if (hRSI != INVALID_HANDLE)
   {
      if (IndicatorExists(chartId, "RSI(" + IntegerToString(InpRSIPeriod) + ")", indName) == -1)
      {
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

   int copyCount = MathMin(rates_total, 10000);  // Copy tối đa 10000 nến

   // Copy SMA buffers - cần đủ data cho tất cả nến
   double sma50[], sma200[];
   ArraySetAsSeries(sma50, true);
   ArraySetAsSeries(sma200, true);

   // Với đường Custom Moving Average, MA Center Line nằm ở index 2 (0: top, 1: bottom line)
   if (CopyBuffer(hSMA50, 2, 0, copyCount, sma50) <= 0)
      return rates_total;

   if (CopyBuffer(hSMA200, 2, 0, copyCount, sma200) <= 0)
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
      if (g_lastSignalTime <= 0)
      {
         startIdx = rates_total - prev_calculated + InpMaxWaitBars;
         if (startIdx >= copyCount)
            startIdx = copyCount - 1;
      }
      else
      {
         // Tính toán startIdx theo thời gian kết thúc lần trước
         startIdx = 1;
         while (startIdx < copyCount - 1)
         {
            if (time[startIdx + 1] <= g_lastSignalTime)
               break;
            startIdx++;
         }
      }
      endIdx = 1;
   }

   int idx = startIdx;
   while (idx >= endIdx)
   {
      // Bỏ qua nến cắt nếu nó nằm trong vùng cấm của signal trước đó
      if (g_lastSignalTime > 0 && time[idx] <= g_lastSignalTime)
      {
         --idx;
         continue;
      }

      // Gọi ScanForSignal
      ScanResult scanResult;
      ScanForSignal(g_config, _Symbol, time[0], idx, time, open, high, low, close, sma50, sma200, rsi, macdMain,
                    macdSignal, volumeAsSeries, adxMain, adxPlusDI, adxMinusDI, atr, g_tickSize, g_pointValue,
                    copyCount, scanResult);

      if (scanResult.cutFound == false && scanResult.cancelled == false)
      {
         // Vẫn đang scan nhưng đã hết nến
         // Thường là kết thúc tại nến mới nhất idx = 1, và sẽ kết thúc vòng lặp chờ tick sau
         --idx;
         continue;
      }

      // Cập nhật thời gian quét cuối cùng nếu có detect được nến cắt (dù hợp lệ hay không)
      // Sau điều kiện ở trên thì chắc chắn sẽ có thời gian kết thúc ở đây
      g_lastSignalTime = scanResult.endTime;
      idx = scanResult.endIdx;
      g_signalCount++;

      for (int i = 0; i < scanResult.failedSignalCount; i++)
      {
         // Signal failed - vẽ failed marker
         DrawSignalMarker(g_drawConfig, g_signalCount, scanResult.isBuy, true, scanResult.failedTime[i],
                          scanResult.cutTime, scanResult.startTime,
                          scanResult.isBuy ? low[scanResult.failedIdx[i]] : high[scanResult.failedIdx[i]], 0, 0, "", 0,
                          scanResult.failedSignal[i].reasons, 0, 0, "", g_pointValue, _Period);
      }

      if (scanResult.cutFound)
      {
         // Vẽ marker đánh dấu nến cắt
         DrawCutCandleMarker(g_drawConfig, g_signalCount, scanResult.isBuy, scanResult.startTime,
                             scanResult.isBuy ? low[scanResult.startIdx] : high[scanResult.startIdx],
                             scanResult.cutTime, scanResult.isBuy ? low[scanResult.cutIdx] : high[scanResult.cutIdx],
                             sma50[scanResult.cutIdx], "", g_pointValue);

         if (scanResult.cancelled)
         {
            // Signal cancelled - vẽ cancelled marker
            DrawSignalMarker(g_drawConfig, g_signalCount, scanResult.isBuy, true, scanResult.confirmTime,
                             scanResult.cutTime, scanResult.startTime,
                             scanResult.isBuy ? low[scanResult.confirmIdx] : high[scanResult.confirmIdx], 0, 0, "", 0,
                             "- " + scanResult.cancelReason, 0, 0, "", g_pointValue, _Period);
         }
         else
         {
            // Signal found - vẽ lên chart
            DrawSignalMarker(g_drawConfig, g_signalCount, scanResult.isBuy, false, scanResult.confirmTime,
                             scanResult.cutTime, scanResult.startTime, scanResult.signal.entry, scanResult.signal.sl,
                             scanResult.signal.tp, scanResult.signal.strength, scanResult.signal.score,
                             scanResult.signal.reasons, scanResult.signal.support, scanResult.signal.resistance,
                             scanResult.confirmPattern, g_pointValue, _Period);

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
      }
      else
      {
         // Tìm thấy nến cắt lỗi
         DrawCutCandleMarker(g_drawConfig, g_signalCount, scanResult.isBuy, scanResult.startTime,
                             scanResult.isBuy ? low[scanResult.startIdx] : high[scanResult.startIdx],
                             scanResult.confirmTime,
                             scanResult.isBuy ? low[scanResult.confirmIdx] : high[scanResult.confirmIdx],
                             sma50[scanResult.confirmIdx], scanResult.cancelReason, g_pointValue);
      }
   }

   ChartRedraw();
   return rates_total;
}
//+------------------------------------------------------------------+
