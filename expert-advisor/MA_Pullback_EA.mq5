//+------------------------------------------------------------------+
//|                                            SMA Pullback EA       |
//|                                    Copyright 2026, Do Nhat Phong |
//|                                   https://github.com/nhatphongdo |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Do Nhat Phong"
#property link "https://github.com/nhatphongdo"
#property version "1.00"
#property strict

#include <Trade\Trade.mqh>
#include "../include/MA_Pullback_Inputs.mqh"
#include "../include/MA_Pullback_Draw.mqh"

// ==================================================
// ===================== INPUT =======================
// ==================================================

// --- MAIN SETTINGS ---
input group "=== Cấu hình chung ===";
input bool InpAutoTrade = DEF_AUTO_TRADE;          // Tự động đặt lệnh
input int InpMagicNumber = DEF_MAGIC_NUMBER;       // Magic Number
input string InpTradeComment = DEF_TRADE_COMMENT;  // Comment lệnh

// --- DRAWING SETTINGS (Vẽ signal lên chart) ---
input group "=== Cấu hình vẽ signal ===";
input bool InpEnableDrawSignal = DEF_ENABLE_DRAW_SIGNAL;     // Bật vẽ signal lên chart
input bool InpKeepMarkersOnStop = DEF_KEEP_MARKERS_ON_STOP;  // Giữ marker khi EA dừng

// --- TRADE LIMITS ---
input group "=== Cấu hình giới hạn trade ===";
input double InpLotSize = DEF_LOT_SIZE;                        // Khối lượng giao dịch tối đa
input double InpMaxLossPercent = DEF_MAX_LOSS_PERCENT;         // Số tiền thua tối đa (% tài khoản, 0 = không giới hạn)
input double InpMinStopLoss = DEF_MIN_STOP_LOSS;               // Số points StopLoss tối thiểu
input double InpMaxSpread = DEF_MAX_SPREAD;                    // Spread tối đa (points, ~2 pips for 5-digit)
input double InpMaxRiskRewardRate = DEF_MAX_RISK_REWARD_RATE;  // Tỷ lệ Reward / Risk tối đa
input double InpMinRiskRewardRate = DEF_MIN_RISK_REWARD_RATE;  // Tỷ lệ Reward / Risk tối thiểu
input int InpMaxAccountOrders = DEF_MAX_ACCOUNT_ORDERS;        // Max lệnh toàn tài khoản (0 = không giới hạn)
input int InpMaxSymbolOrders = DEF_MAX_SYMBOL_ORDERS;          // Max lệnh cho Symbol hiện tại
input double InpTPBuffer = DEF_TP_BUFFER;                      // TP Buffer (pips, 0 = chỉ dùng spread)
input double InpSRBufferPercent = DEF_SR_BUFFER_PERCENT;  // S/R/MA Buffer (%) - Buffer cộng thêm vào S/R zone / MA line

// --- INDICATOR SETTINGS ---
input group "=== Cấu hình Chỉ báo ===";
input ENUM_MA_TYPE_MODE InpMAType = DEF_MA_TYPE;  // Loại Moving Average (EMA phản ứng nhanh hơn)
input int InpMA50Period = DEF_MA50_PERIOD;        // Chu kỳ MA Fast
input int InpMA200Period = DEF_MA200_PERIOD;      // Chu kỳ MA Slow
input int InpRSIPeriod = DEF_RSI_PERIOD;          // Chu kỳ RSI
input int InpMACDFast = DEF_MACD_FAST;            // Chu kỳ MACD Fast
input int InpMACDSlow = DEF_MACD_SLOW;            // Chu kỳ MACD Slow
input int InpMACDSignal = DEF_MACD_SIGNAL;        // Chu kỳ MACD Signal
input int InpADXPeriod = DEF_ADX_PERIOD;          // Số nến tính ADX

// --- STRATEGY SETTINGS ---
input group "=== Cấu hình Chiến lược ===";
input int InpMaxWaitBars = DEF_MAX_WAIT_BARS;             // Số nến tối đa chờ pullback (ít hơn = entry sớm hơn)
input int InpATRLength = DEF_ATR_LENGTH;                  // Số nến tính ATR
input int InpSRLookback = DEF_SR_LOOKBACK;                // Số nến lookback để tìm support / resistance
input double InpSideWayATRRatio = DEF_SIDEWAY_ATR_RATIO;  // Tỷ lệ ATR để xác định vùng sideway
input double InpWickBodyRatio = DEF_WICK_BODY_RATIO;      // Tỷ lệ Bóng/Thân nến

// ==================================================
// ============== FILTER SETTINGS ===================
// ==================================================
input group "=== Cấu hình Bộ lọc ===";
input double InpMinScoreToPass = DEF_MIN_SCORE_TO_PASS;  // Điểm Threshold để Valid (%)

// FILTER: MA SLOPE
input group "=== Cấu hình Bộ lọc: Độ dốc đường MA ===";
input bool InpEnableMASlopeFilter = DEF_ENABLE_MA_SLOPE;    // Bật (trend direction)
input bool InpMASlopeCritical = DEF_MA_SLOPE_CRITICAL;      // Critical
input double InpMASlopeThreshold = DEF_MA_SLOPE_THRESHOLD;  // Threshold
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
input bool InpEnableRSIReversal = DEF_ENABLE_RSI_REVERSAL;      // Bật (phát hiện đảo chiều)
input bool InpRSIReversalCritical = DEF_RSI_REVERSAL_CRITICAL;  // Critical
input int InpRSIReversalLookback = DEF_RSI_REVERSAL_LOOKBACK;   // Lookback
input double InpRSIReversalWeight = DEF_RSI_REVERSAL_WEIGHT;    // Weight

// FILTER: MACD HISTOGRAM
input group "=== Cấu hình Bộ lọc: MACD Histogram ===";
input bool InpEnableMACDHistogram = DEF_ENABLE_MACD_HISTOGRAM;      // Bật (momentum shift)
input bool InpMACDHistogramCritical = DEF_MACD_HISTOGRAM_CRITICAL;  // Critical
input int InpMACDHistogramLookback = DEF_MACD_HISTOGRAM_LOOKBACK;   // Lookback
input double InpMACDHistogramWeight = DEF_MACD_HISTOGRAM_WEIGHT;    // Weight

// FILTER: SMA200 TREND
input group "=== Cấu hình Bộ lọc: Xu hướng MA dài hạn (vd: MA200) ===";
input bool InpEnableSMA200Filter = DEF_ENABLE_SMA200_FILTER;  // Bật (xác định xu hướng chính)
input bool InpSMA200Critical = DEF_SMA200_CRITICAL;           // Critical
input double InpSMA200Weight = DEF_SMA200_WEIGHT;             // Weight

// FILTER: S/R ZONE
input group "=== Cấu hình Bộ lọc: Vùng S/R ===";
input bool InpEnableSRZoneFilter = DEF_ENABLE_SR_ZONE_FILTER;  // Bật
input bool InpSRZoneCritical = DEF_SR_ZONE_CRITICAL;           // Critical
input double InpSRZonePercent = DEF_SR_ZONE_PERCENT;           // % Zone Width (40% từ S đến R)
input double InpSRZoneWeight = DEF_SR_ZONE_WEIGHT;             // Weight

// FILTER: S/R MIN WIDTH
input group "=== Cấu hình Bộ lọc: Độ rộng tối thiểu vùng S/R ===";
input bool InpEnableSRMinWidthFilter = DEF_ENABLE_SR_MIN_WIDTH;  // Bật (đảm bảo vùng S/R đủ rộng để trade)
input bool InpSRMinWidthCritical = DEF_SR_MIN_WIDTH_CRITICAL;    // Critical
input double InpMinSRWidthATR = DEF_MIN_SR_WIDTH_ATR;            // Độ rộng tối thiểu (xATR)
input double InpSRMinWidthWeight = DEF_SR_MIN_WIDTH_WEIGHT;      // Weight

// FILTER: ADX TREND STRENGTH
input group "=== Cấu hình Bộ lọc: Cường độ xu hướng ADX ===";
input bool InpEnableADXFilter = DEF_ENABLE_ADX_FILTER;              // Bật (trend strength)
input bool InpADXCritical = DEF_ADX_CRITICAL;                       // Critical
input double InpMinADXThreshold = DEF_MIN_ADX_THRESHOLD;            // Min Threshold
input bool InpADXDirectionalConfirm = DEF_ADX_DIRECTIONAL_CONFIRM;  // Check +DI/-DI
input double InpADXWeight = DEF_ADX_WEIGHT;                         // Weight

// FILTER: BODY/ATR RATIO
input group "=== Cấu hình Bộ lọc: Tỷ lệ thân nến/ATR ===";
input bool InpEnableBodyATRFilter = DEF_ENABLE_BODY_ATR_FILTER;  // Bật (candle strength)
input bool InpBodyATRCritical = DEF_BODY_ATR_CRITICAL;           // Critical
input double InpMinBodyATRRatio = DEF_MIN_BODY_ATR_RATIO;        // Min Body/ATR Ratio
input double InpBodyATRWeight = DEF_BODY_ATR_WEIGHT;             // Weight

// FILTER: VOLUME CONFIRMATION
input group "=== Cấu hình Bộ lọc: Xác nhận Volume (tắt)===";
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

// FILTER: TIME CONTROL (EA Only)
input group "=== Cấu hình Bộ lọc: Thời gian ===";
input bool InpEnableTimeFilter = DEF_ENABLE_TIME_FILTER;  // Bật
input bool InpTimeCritical = DEF_TIME_CRITICAL;           // Critical
input int InpTradeStartHour = DEF_TRADE_START_HOUR;       // Start Hour
input int InpTradeEndHour = DEF_TRADE_END_HOUR;           // End Hour
input double InpTimeWeight = DEF_TIME_WEIGHT;             // Weight

// FILTER: NEWS FILTER (EA Only)
input group "=== Cấu hình Bộ lọc: Tin tức ===";
input bool InpEnableNewsFilter = DEF_ENABLE_NEWS_FILTER;   // Bật
input bool InpNewsCritical = DEF_NEWS_CRITICAL;            // Critical
input int InpNewsMinutesBefore = DEF_NEWS_MINUTES_BEFORE;  // Mins Before
input int InpNewsMinutesAfter = DEF_NEWS_MINUTES_AFTER;    // Mins After
input int InpNewsMinImportance = DEF_NEWS_MIN_IMPORTANCE;  // Min Importance
input double InpNewsWeight = DEF_NEWS_WEIGHT;              // Weight

// FILTER: CONSECUTIVE LOSSES (EA Only)
input group "=== Cấu hình Bộ lọc: Hạn chế lệnh thua liên tục ===";
input bool InpEnableConsecLossFilter = DEF_ENABLE_CONSEC_LOSS_FILTER;  // Bật
input int InpMaxConsecutiveLosses = DEF_MAX_CONSECUTIVE_LOSSES;        // Max
input int InpPauseMinutesAfterLoss = DEF_PAUSE_MINUTES_AFTER_LOSS;     // Pause Mins

// ==================================================
// ================= BIẾN TOÀN CỤC ===================
// ==================================================

CTrade g_trade;
int hSMA50;
int hSMA200;
int hRSI;
int hMACD;
int hADX;
int hATR;
datetime g_lastBarTime = 0;
datetime g_lastSignalTime = 0;  // Thời gian của signal cuối cùng
double g_tickSize;
double g_pointValue;
SMAPullbackConfig g_config;
SignalDrawConfig g_drawConfig;     // Config cho drawing utilities
string EA_OBJ_PREFIX = "EA_SIG_";  // Prefix cho EA objects
int g_signalCount = 0;
long g_lastMouseX = -1;
long g_lastMouseY = -1;

// Consecutive Losses tracking
int g_consecutiveLosses = 0;    // Số lệnh thua liên tiếp
datetime g_pauseUntil = 0;      // Thời gian tạm dừng đến
double g_lastClosedProfit = 0;  // Profit của lệnh đóng gần nhất

// ==================================================
// ===================== INIT ========================
// ==================================================
int OnInit()
{
   // Khởi tạo indicator handles
   hSMA50 = iMA(_Symbol, _Period, InpMA50Period, 0, (ENUM_MA_METHOD)InpMAType, PRICE_CLOSE);
   if (hSMA50 == INVALID_HANDLE)
   {
      Print("Lỗi tạo MA50 handle");
      return INIT_FAILED;
   }

   hSMA200 = iMA(_Symbol, _Period, InpMA200Period, 0, (ENUM_MA_METHOD)InpMAType, PRICE_CLOSE);
   if (hSMA200 == INVALID_HANDLE)
   {
      Print("Lỗi tạo MA200 handle");
      return INIT_FAILED;
   }

   hRSI = iRSI(_Symbol, _Period, InpRSIPeriod, PRICE_CLOSE);
   if (hRSI == INVALID_HANDLE)
   {
      Print("Lỗi tạo RSI handle");
      return INIT_FAILED;
   }

   hMACD = iMACD(_Symbol, _Period, InpMACDFast, InpMACDSlow, InpMACDSignal, PRICE_CLOSE);
   if (hMACD == INVALID_HANDLE)
   {
      Print("Lỗi tạo MACD handle");
      return INIT_FAILED;
   }

   // ADX indicator for trend strength filter
   hADX = iADX(_Symbol, _Period, InpADXPeriod);
   if (hADX == INVALID_HANDLE)
   {
      Print("Lỗi tạo ADX handle");
      return INIT_FAILED;
   }

   hATR = iATR(_Symbol, _Period, InpATRLength);
   if (hATR == INVALID_HANDLE)
   {
      Print("Lỗi tạo ATR handle");
      return INIT_FAILED;
   }

   // Khởi tạo trade object
   g_trade.SetExpertMagicNumber(InpMagicNumber);
   g_trade.SetDeviationInPoints(10);
   g_trade.SetTypeFilling(ORDER_FILLING_IOC);

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
   g_config.maSlopeThreshold = InpMASlopeThreshold;
   g_config.rsiPeriod = InpRSIPeriod;
   g_config.macdFast = InpMACDFast;
   g_config.macdSlow = InpMACDSlow;
   g_config.macdSignal = InpMACDSignal;
   g_config.adxPeriod = InpADXPeriod;
   // Strategy Parameters
   g_config.maxWaitBars = InpMaxWaitBars;
   g_config.sidewayATRRatio = InpSideWayATRRatio;
   g_config.atrLength = InpATRLength;
   g_config.srLookback = InpSRLookback;
   g_config.wickBodyRatio = InpWickBodyRatio;
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
   // Filter: Time Control (EA Only)
   g_config.enableTimeFilter = InpEnableTimeFilter;
   g_config.timeCritical = InpTimeCritical;
   g_config.tradeStartHour = InpTradeStartHour;
   g_config.tradeEndHour = InpTradeEndHour;
   g_config.timeWeight = InpTimeWeight;
   // Filter: News Filter (EA Only)
   g_config.enableNewsFilter = InpEnableNewsFilter;
   g_config.newsCritical = InpNewsCritical;
   g_config.newsMinutesBefore = InpNewsMinutesBefore;
   g_config.newsMinutesAfter = InpNewsMinutesAfter;
   g_config.newsMinImportance = InpNewsMinImportance;
   g_config.newsWeight = InpNewsWeight;
   // Filter: Consecutive Losses (EA Only)
   g_config.enableConsecutiveLossFilter = InpEnableConsecLossFilter;
   g_config.maxConsecutiveLosses = InpMaxConsecutiveLosses;
   g_config.pauseMinutesAfterLosses = InpPauseMinutesAfterLoss;

   g_tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   g_pointValue = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   g_lastSignalTime = 0;
   g_consecutiveLosses = 0;
   g_pauseUntil = 0;
   g_signalCount = 0;
   g_lastMouseX = -1;
   g_lastMouseY = -1;

   // Khởi tạo draw config cho EA
   if (InpEnableDrawSignal)
   {
      InitDefaultSignalDrawConfig(g_drawConfig, EA_OBJ_PREFIX);
      g_drawConfig.lineLengthBars = g_config.maxWaitBars;
   }

   // Xóa marker và tooltip cũ khi khởi tạo (để bắt đầu mới)
   DeleteAllSignalObjects(EA_OBJ_PREFIX);
   ClearSignalTooltips(EA_OBJ_PREFIX);

   Print("EA đã khởi tạo. AutoTrade: ", InpAutoTrade ? "ON" : "OFF");
   PrintFiltersStatus();
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Print active filters status                                       |
//+------------------------------------------------------------------+
void PrintFiltersStatus()
{
   string activeFilters = "Active Filters: ";
   if (g_config.enableMASlopeFilter)
      activeFilters += "Slope ";
   if (g_config.enableRSIMomentumFilter)
      activeFilters += "RSI Momen ";
   if (g_config.enableMACDMomentumFilter)
      activeFilters += "MACD Momen ";
   if (g_config.enableRSIReversalFilter)
      activeFilters += "RSIRev ";
   if (g_config.enableMACDHistogramFilter)
      activeFilters += "MACDHist ";
   if (g_config.enableSMA200Filter)
      activeFilters += "SMA200 ";
   if (g_config.enableSRZoneFilter)
      activeFilters += "S/R ";
   if (g_config.enableADXFilter)
      activeFilters += "ADX ";
   if (g_config.enableBodyATRFilter)
      activeFilters += "Body/ATR ";
   if (g_config.enableVolumeFilter)
      activeFilters += "Volume ";
   if (g_config.enablePriceMADistanceFilter)
      activeFilters += "Price-MA ";
   if (g_config.enableTimeFilter)
      activeFilters += "Time ";
   if (g_config.enableNewsFilter)
      activeFilters += "News ";
   if (g_config.enableConsecutiveLossFilter)
      activeFilters += "ConsecLoss ";
   Print(activeFilters);
}

// ==================================================
void OnDeinit(const int reason)
{
   IndicatorRelease(hSMA50);
   IndicatorRelease(hSMA200);
   IndicatorRelease(hRSI);
   IndicatorRelease(hMACD);
   IndicatorRelease(hADX);
   IndicatorRelease(hATR);

   // Xử lý marker/tooltip khi EA dừng
   // Nếu InpKeepMarkersOnStop = true và EA bị remove thủ công, giữ lại marker để review
   bool keepMarkers = InpKeepMarkersOnStop && (reason == REASON_PROGRAM || reason == REASON_REMOVE);

   if (InpEnableDrawSignal && !keepMarkers)
   {
      DeleteAllSignalObjects(EA_OBJ_PREFIX);
      HideTooltipLabel();
      ClearSignalTooltips(EA_OBJ_PREFIX);
   }

   Print("EA đã hủy. Reason: ", reason, keepMarkers ? " - Giữ marker" : "");
}

// ==================================================
// =============== ON CHART EVENT ====================
// ==================================================
void OnChartEvent(const int id, const long& lparam, const double& dparam, const string& sparam)
{
   // Bỏ qua nếu không bật vẽ signal
   if (!InpEnableDrawSignal)
      return;

   // Dùng hàm xử lý từ Draw Utility
   HandleSignalChartEvent(id, lparam, dparam, sparam, EA_OBJ_PREFIX, g_lastMouseX, g_lastMouseY);
}

// ==================================================
// =================== ON TICK =======================
// ==================================================
void OnTick()
{
   // Chỉ xử lý khi nến mới đóng
   datetime currentBarTime = iTime(_Symbol, _Period, 0);
   if (currentBarTime == g_lastBarTime)
      return;
   g_lastBarTime = currentBarTime;

   // Kiểm tra giới hạn số lệnh toàn tài khoản
   if (InpMaxAccountOrders > 0)
   {
      int accountOrders = CountAccountPositions();
      if (accountOrders >= InpMaxAccountOrders)
      {
         return;  // Đã đạt giới hạn lệnh toàn tài khoản
      }
   }

   // Kiểm tra giới hạn số lệnh cho symbol hiện tại
   if (InpMaxSymbolOrders > 0)
   {
      int symbolOrders = CountSymbolPositions();
      if (symbolOrders >= InpMaxSymbolOrders)
      {
         return;  // Đã đạt giới hạn lệnh cho symbol này
      }
   }

   // Check Consecutive Losses Filter - Tạm dừng trade nếu cần
   if (g_config.enableConsecutiveLossFilter && g_pauseUntil > 0)
   {
      if (TimeCurrent() < g_pauseUntil)
      {
         // Vẫn đang trong thời gian tạm dừng
         return;
      }
      else
      {
         // Hết thời gian tạm dừng, reset
         g_pauseUntil = 0;
         g_consecutiveLosses = 0;
         Print("Hết tạm dừng. Tiếp tục trade.");
      }
   }

   // Kiểm tra spread (chuyển từ points sang pips để khớp với Market Watch)
   long spreadPoints = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double pipMultiplier = (digits == 3 || digits == 5) ? 10.0 : 1.0;  // 5-digit broker: 1 pip = 10 points
   double spreadPips = spreadPoints / pipMultiplier;
   if (spreadPips > InpMaxSpread)
   {
      Print("Spread cao: ", DoubleToString(spreadPips, 1), " pips > ", DoubleToString(InpMaxSpread, 1), " pips");
      return;
   }

   // Copy dữ liệu giá
   int rates_total = Bars(_Symbol, _Period);
   if (rates_total < 200)
      return;

   double open[], high[], low[], close[];
   datetime time[];
   ArraySetAsSeries(open, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(close, true);
   ArraySetAsSeries(time, true);

   int copyCount = MathMin(rates_total, 1000);  // EA realtime nên chỉ cần lấy 1000 nến trước đó để kiểm tra
   if (CopyOpen(_Symbol, _Period, 0, copyCount, open) <= 0)
      return;
   if (CopyHigh(_Symbol, _Period, 0, copyCount, high) <= 0)
      return;
   if (CopyLow(_Symbol, _Period, 0, copyCount, low) <= 0)
      return;
   if (CopyClose(_Symbol, _Period, 0, copyCount, close) <= 0)
      return;
   if (CopyTime(_Symbol, _Period, 0, copyCount, time) <= 0)
      return;

   // Copy indicator buffers
   double sma50[], sma200[], rsi[], macdMain[], macdSignal[];
   ArraySetAsSeries(sma50, true);
   ArraySetAsSeries(sma200, true);
   ArraySetAsSeries(rsi, true);
   ArraySetAsSeries(macdMain, true);
   ArraySetAsSeries(macdSignal, true);

   if (CopyBuffer(hSMA50, 0, 0, copyCount, sma50) <= 0)
      return;
   if (CopyBuffer(hSMA200, 0, 0, copyCount, sma200) <= 0)
      return;
   if (CopyBuffer(hRSI, 0, 0, copyCount, rsi) <= 0)
      return;
   if (CopyBuffer(hMACD, 0, 0, copyCount, macdMain) <= 0)
      return;
   if (CopyBuffer(hMACD, 1, 0, copyCount, macdSignal) <= 0)
      return;

   // Copy ADX buffers (for extended filters)
   double adxMain[], adxPlusDI[], adxMinusDI[];
   ArraySetAsSeries(adxMain, true);
   ArraySetAsSeries(adxPlusDI, true);
   ArraySetAsSeries(adxMinusDI, true);

   if (CopyBuffer(hADX, 0, 0, copyCount, adxMain) <= 0)  // ADX main line
      return;
   if (CopyBuffer(hADX, 1, 0, copyCount, adxPlusDI) <= 0)  // +DI
      return;
   if (CopyBuffer(hADX, 2, 0, copyCount, adxMinusDI) <= 0)  // -DI
      return;

   double atr[];
   ArraySetAsSeries(atr, true);
   if (CopyBuffer(hATR, 0, 0, copyCount, atr) <= 0)
      return;

   // Copy tick volume (for volume filter)
   long tickVolume[];
   ArraySetAsSeries(tickVolume, true);
   if (CopyTickVolume(_Symbol, _Period, 0, copyCount, tickVolume) <= 0)
      return;

   // Scan for signals - tìm nến cắt trong phạm vi maxWaitBars
   // Bắt đầu từ nến cũ nhất trong phạm vi và tiến về nến mới nhất
   int startIdx = 1 + g_config.maxWaitBars;
   int endIdx = 1;

   // Đảm bảo startIdx không vượt quá dữ liệu có sẵn
   if (startIdx >= copyCount)
      startIdx = copyCount - 1;

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
                    macdSignal, tickVolume, adxMain, adxPlusDI, adxMinusDI, atr, g_tickSize, g_pointValue, copyCount,
                    scanResult);

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

      if (scanResult.cutFound)
      {
         // Vẽ cut candle marker (nếu bật)
         if (InpEnableDrawSignal)
         {
            DrawCutCandleMarker(g_drawConfig, g_signalCount, scanResult.isBuy, scanResult.startTime,
                                scanResult.isBuy ? low[scanResult.startIdx] : high[scanResult.startIdx],
                                scanResult.cutTime, scanResult.isBuy ? low[scanResult.cutIdx] : high[scanResult.cutIdx],
                                sma50[scanResult.cutIdx], "", g_pointValue);
         }

         if (scanResult.cancelled)
         {
            // Vẽ cancelled signal (nếu bật)
            if (InpEnableDrawSignal)
            {
               DrawSignalMarker(g_drawConfig, g_signalCount, scanResult.isBuy, true, time[scanResult.confirmIdx], 0,
                                scanResult.isBuy ? low[scanResult.confirmIdx] : high[scanResult.confirmIdx], 0, 0, "",
                                0, "- " + scanResult.cancelReason, 0, 0, "", g_pointValue, _Period);
            }
         }
         else
         {
            // Vẽ signal lên chart (nếu bật)
            if (InpEnableDrawSignal)
            {
               DrawSignalMarker(g_drawConfig, g_signalCount, scanResult.isBuy, false, time[scanResult.confirmIdx],
                                scanResult.cutIdx - scanResult.confirmIdx, scanResult.signal.entry,
                                scanResult.signal.sl, scanResult.signal.tp, scanResult.signal.strength,
                                scanResult.signal.score, scanResult.signal.reasons, scanResult.signal.support,
                                scanResult.signal.resistance, scanResult.confirmPattern, g_pointValue, _Period);
            }

            // Chỉ trade nếu signal xác nhận tại nến vừa đóng (index = 1)
            if (scanResult.confirmIdx == 1)
            {
               // In chi tiết tất cả tham số và đánh giá filter
               PrintSignalDetails(scanResult, time, close, sma50, sma200, rsi, macdMain, macdSignal, adxMain, adxPlusDI,
                                  adxMinusDI, atr, tickVolume, high, low, open);

               if (InpAutoTrade)
               {
                  ExecuteTrade(scanResult.isBuy, scanResult.signal);
               }
               else
               {
                  Print("AutoTrade OFF. Không vào lệnh.");
               }
            }
            break;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Track closed trades to count consecutive losses                  |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction& trans, const MqlTradeRequest& request, const MqlTradeResult& result)
{
   // Chỉ xử lý khi lệnh được đóng hoàn toàn (position closed)
   if (trans.type != TRADE_TRANSACTION_DEAL_ADD)
      return;

   // Kiểm tra deal có thuộc EA này không
   if (trans.symbol != _Symbol)
      return;

   ulong dealTicket = trans.deal;
   if (dealTicket == 0)
      return;

   // Lấy thông tin deal
   if (!HistoryDealSelect(dealTicket))
      return;

   long magic = HistoryDealGetInteger(dealTicket, DEAL_MAGIC);
   if (magic != InpMagicNumber)
      return;

   // Kiểm tra loại deal (chỉ xét khi đóng lệnh: DEAL_ENTRY_OUT)
   long entry = HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
   if (entry != DEAL_ENTRY_OUT)
      return;

   // Lấy profit của deal
   double profit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
   double commission = HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);
   double swap = HistoryDealGetDouble(dealTicket, DEAL_SWAP);
   double netProfit = profit + commission + swap;

   // Cập nhật consecutive losses
   if (netProfit < 0)
   {
      g_consecutiveLosses++;
      Print("Lệnh thua. Chuỗi thua: ", g_consecutiveLosses);

      // Kiểm tra và tạm dừng nếu đạt ngƯỡng
      if (g_config.enableConsecutiveLossFilter && g_consecutiveLosses >= g_config.maxConsecutiveLosses)
      {
         g_pauseUntil = TimeCurrent() + g_config.pauseMinutesAfterLosses * 60;
         Print("Max chuỗi thua (", g_consecutiveLosses, "). Tạm dừng đến ", TimeToString(g_pauseUntil));
      }
   }
   else
   {
      // Reset counter khi có lệnh thắng
      if (g_consecutiveLosses > 0)
      {
         Print("Lệnh thắng. Reset chuỗi thua.");
         g_consecutiveLosses = 0;
      }
   }
}

// ==================================================
// ============= HELPER FUNCTIONS ===================
// ==================================================

//+------------------------------------------------------------------+
//| Print signal details with all indicator values and filter results|
//+------------------------------------------------------------------+
void PrintSignalDetails(const ScanResult& scanResult, const datetime& time[], const double& close[],
                        const double& sma50[], const double& sma200[], const double& rsi[], const double& macdMain[],
                        const double& macdSignal[], const double& adxMain[], const double& adxPlusDI[],
                        const double& adxMinusDI[], const double& atr[], const long& tickVolume[], const double& high[],
                        const double& low[], const double& open[])
{
   int idx = scanResult.confirmIdx;
   bool isBuy = scanResult.isBuy;

   Print("========== TÍN HIỆU #", g_signalCount, ". ", isBuy ? "BUY" : "SELL", " ==========");
   Print("Thời gian: ", TimeToString(time[idx]));
   Print("Score: ", scanResult.signal.score, " | Strength: ", scanResult.signal.strength);

   // ============ GIÁ TRỊ INDICATOR ============
   Print("---------- INDICATOR VALUES ----------");
   Print("Close: ", DoubleToString(close[idx], _Digits), " | ATR: ", DoubleToString(atr[idx], _Digits));
   Print("SMA50: ", DoubleToString(sma50[idx], _Digits), " | SMA200: ", DoubleToString(sma200[idx], _Digits));
   Print("RSI: ", DoubleToString(rsi[idx], 2));

   double macdHist = macdMain[idx] - macdSignal[idx];
   Print("MACD: ", DoubleToString(macdMain[idx], 6), " | Sig: ", DoubleToString(macdSignal[idx], 6),
         " | Hist: ", DoubleToString(macdHist, 6));

   Print("ADX: ", DoubleToString(adxMain[idx], 2), " | +DI: ", DoubleToString(adxPlusDI[idx], 2),
         " | -DI: ", DoubleToString(adxMinusDI[idx], 2));

   // ============ FILTER RESULTS (từ ProcessSignal) ============
   Print("---------- FILTER RESULTS ----------");
   Print(scanResult.signal.filterDetails);

   // ============ ENTRY/SL/TP ============
   Print("---------- ENTRY/SL/TP ----------");
   Print("Entry: ", DoubleToString(scanResult.signal.entry, _Digits),
         " | SL: ", DoubleToString(scanResult.signal.sl, _Digits),
         " | TP: ", DoubleToString(scanResult.signal.tp, _Digits));
   Print("S: ", DoubleToString(scanResult.signal.support, _Digits),
         " | R: ", DoubleToString(scanResult.signal.resistance, _Digits));

   // ============ REASONS (nếu có fail) ============
   if (scanResult.signal.reasons != "")
   {
      Print("---------- FAIL REASONS ----------");
      Print(scanResult.signal.reasons);
   }

   Print("========================================");
}

//+------------------------------------------------------------------+
//| Count open positions for this EA (by magic number)              |
//+------------------------------------------------------------------+
int CountAccountPositions()
{
   int count = 0;
   for (int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if (ticket > 0)
      {
         if (PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
         {
            count++;
         }
      }
   }
   return count;
}

//+------------------------------------------------------------------+
//| Count open positions for symbol (by magic number)               |
//+------------------------------------------------------------------+
int CountSymbolPositions()
{
   int count = 0;
   for (int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if (ticket > 0)
      {
         if (PositionGetString(POSITION_SYMBOL) == _Symbol && PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
         {
            count++;
         }
      }
   }
   return count;
}

//+------------------------------------------------------------------+
//| Execute trade based on signal                                    |
//+------------------------------------------------------------------+
void ExecuteTrade(bool isBuy, const SignalResult& signal)
{
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   // Normalize prices
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double sl = NormalizeDouble(signal.sl, digits);
   double tp = NormalizeDouble(signal.tp, digits);

   // Tính buffer để điều chỉnh TP (đối phó nhảy giá/slippage)
   double spread = ask - bid;
   double pipMultiplier = (digits == 3 || digits == 5) ? 10.0 : 1.0;  // 5-digit: 1 pip = 10 points
   double configBuffer = InpTPBuffer * pipMultiplier * g_pointValue;  // Chuyển pips sang giá
   double tpBuffer = MathMax(configBuffer, spread);                   // Buffer = Max(config, spread)

   // Điều chỉnh TP: giảm khoảng bằng buffer để tăng khả năng khớp lệnh
   if (isBuy)
   {
      // BUY: TP đóng ở Bid, giảm TP xuống một buffer
      tp = NormalizeDouble(tp - tpBuffer, digits);
   }
   else
   {
      // SELL: TP đóng ở Ask, tăng TP lên một buffer (gần giá hơn)
      tp = NormalizeDouble(tp + tpBuffer, digits);
   }

   // Giá đặt lệnh thực tế
   double entryPrice = isBuy ? ask : bid;

   // ============================================================
   // VALIDATION: Kiểm tra các ràng buộc giá với ask/bid thực tế
   // ============================================================
   PriceValidationResult priceValidation;
   ValidatePriceConstraints(isBuy, entryPrice, sl, tp, InpMinStopLoss, InpMinStopLoss, InpMinRiskRewardRate,
                            g_pointValue, digits, priceValidation);

   if (!priceValidation.isValid)
   {
      Print(priceValidation.reason);
      return;
   }

   double slDistancePoints = priceValidation.slDistancePoints;
   double tpDistancePoints = priceValidation.tpDistancePoints;

   // ============================================================
   // Tính lot size dựa trên InpMaxLossPercent
   // ============================================================
   double lotSize = InpLotSize;
   double slDistance = MathAbs(entryPrice - sl);

   if (InpMaxLossPercent > 0)
   {
      // Lấy giá trị mỗi tick và tick size
      double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);

      if (tickSize > 0 && tickValue > 0)
      {
         // Tính số ticks trong khoảng cách S/L
         double slTicks = slDistance / tickSize;

         // Tính loss với 1 lot
         double lossPerLot = slTicks * tickValue;

         if (lossPerLot > 0)
         {
            // Tính lot size tối đa để không vượt quá InpMaxLossPercent
            double maxLotByRisk = InpMaxLossPercent / lossPerLot;

            // Lấy giá trị nhỏ hơn giữa InpLotSize và maxLotByRisk
            lotSize = MathMin(InpLotSize, maxLotByRisk);

            // Normalize lot size theo step
            double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
            double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
            double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);

            lotSize = MathFloor(lotSize / lotStep) * lotStep;
            lotSize = MathMax(minLot, MathMin(maxLot, lotSize));

            Print("Tính rủi ro: SL Dist = ", DoubleToString(slDistance, digits), ", Loss/Lot = $",
                  DoubleToString(lossPerLot, 2), ", Max Lot = ", DoubleToString(maxLotByRisk, 2),
                  ", Lot chốt = ", DoubleToString(lotSize, 2));
         }
      }
   }

   bool result = false;

   if (isBuy)
   {
      result = g_trade.Buy(lotSize, _Symbol, ask, sl, tp, InpTradeComment);
   }
   else
   {
      result = g_trade.Sell(lotSize, _Symbol, bid, sl, tp, InpTradeComment);
   }

   if (result)
   {
      Print("Vào lệnh thành công: ", isBuy ? "BUY" : "SELL", " Lot: ", DoubleToString(lotSize, 2),
            " Entry: ", isBuy ? ask : bid, " SL: ", sl, " (", DoubleToString(slDistancePoints, 1), " pts)", " TP: ", tp,
            " (", DoubleToString(tpDistancePoints, 1), " pts)");
   }
   else
   {
      Print("Vào lệnh thất bại: ", g_trade.ResultRetcode(), " - ", g_trade.ResultRetcodeDescription());
   }
}
//+------------------------------------------------------------------+
