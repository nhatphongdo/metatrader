//+------------------------------------------------------------------+
//|                                            SMA Pullback EA       |
//|                                    Copyright 2026, Do Nhat Phong |
//|                                   https://github.com/nhatphongdo |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Do Nhat Phong"
#property link      "https://github.com/nhatphongdo"
#property version   "1.00"
#property strict

#include <Trade\Trade.mqh>
#include <MA_Pullback_Inputs.mqh>

// ==================================================
// ===================== INPUT =======================
// ==================================================

// --- MAIN SETTINGS ---
input bool     InpAutoTrade       = DEF_AUTO_TRADE;      // Tự động đặt lệnh
input double   InpLotSize         = DEF_LOT_SIZE;        // Khối lượng giao dịch
input double   InpMaxLoss         = DEF_MAX_LOSS;        // Số tiền thua tối đa (USD, 0 = không giới hạn)
input int      InpMagicNumber     = DEF_MAGIC_NUMBER;    // Magic Number
input double   InpMaxSpread       = DEF_MAX_SPREAD;      // Spread tối đa (points, ~2 pips for 5-digit)
input string   InpTradeComment    = DEF_TRADE_COMMENT;   // Comment lệnh

// --- DRAWING SETTINGS (Vẽ signal lên chart) ---
input bool     InpEnableDrawSignal  = DEF_ENABLE_DRAW_SIGNAL;    // Bật vẽ signal lên chart
input bool     InpKeepMarkersOnStop = DEF_KEEP_MARKERS_ON_STOP;  // Giữ marker khi EA dừng

// --- TRADE LIMITS ---
input double   InpMinStopLoss      = DEF_MIN_STOP_LOSS;       // Số points StopLoss tối thiểu
input double   InpRiskRewardRate   = DEF_RISK_REWARD_RATE;    // Tỷ lệ Reward / Risk
input int      InpMaxAccountOrders = DEF_MAX_ACCOUNT_ORDERS;  // Max lệnh toàn tài khoản (0 = không giới hạn)
input int      InpMaxSymbolOrders  = DEF_MAX_SYMBOL_ORDERS;   // Max lệnh cho Symbol hiện tại
input double   InpTPBuffer         = DEF_TP_BUFFER;           // TP Buffer (pips, 0 = chỉ dùng spread)
input double   InpSRBufferPercent  = DEF_SR_BUFFER_PERCENT;   // S/R/MA Buffer (%) - Buffer cộng thêm vào S/R zone / MA line

// --- INDICATOR SETTINGS ---
input ENUM_MA_TYPE_MODE InpMAType = DEF_MA_TYPE;       // Loại Moving Average (EMA phản ứng nhanh hơn)
input int      InpMA50Period      = DEF_MA50_PERIOD;    // Chu kỳ MA Fast
input int      InpMA200Period     = DEF_MA200_PERIOD;   // Chu kỳ MA Slow
input int      InpRSIPeriod       = DEF_RSI_PERIOD;     // Chu kỳ RSI
input int      InpMACDFast        = DEF_MACD_FAST;      // Chu kỳ MACD Fast
input int      InpMACDSlow        = DEF_MACD_SLOW;      // Chu kỳ MACD Slow
input int      InpMACDSignal      = DEF_MACD_SIGNAL;    // Chu kỳ MACD Signal

// --- STRATEGY SETTINGS ---
input int      InpMaxWaitBars     = DEF_MAX_WAIT_BARS;     // Số nến tối đa chờ pullback (ít hơn = entry sớm hơn)
input int      InpATRLength       = DEF_ATR_LENGTH;        // Số nến tính ATR
input double   InpWickBodyRatio   = DEF_WICK_BODY_RATIO;   // Tỷ lệ Bóng/Thân nến

// ==================================================
// ============== FILTER SETTINGS ===================
// ==================================================
input double   InpMinScoreToPass  = DEF_MIN_SCORE_TO_PASS;   // Điểm Threshold để Valid (%)

// FILTER 1: MA SLOPE
input bool     InpEnableMASlopeFilter = DEF_ENABLE_MA_SLOPE;        // [MA Slope] Bật (trend direction)
input bool     InpMASlopeCritical     = DEF_MA_SLOPE_CRITICAL;      // [MA Slope] Critical
input double   InpMA50SlopeThreshold  = DEF_MA50_SLOPE_THRESHOLD;   // [MA Slope] Threshold (độ)
input int      InpSlopeSmoothBars     = DEF_SLOPE_SMOOTH_BARS;      // [MA Slope] Số nến tính Slope
input double   InpMASlopeWeight       = DEF_MA_SLOPE_WEIGHT;        // [MA Slope] Weight

// FILTER 2A: STATIC MOMENTUM
input bool     InpEnableStaticMomentum    = DEF_ENABLE_STATIC_MOMENTUM;     // [Static Momentum] Bật (trend confirmation)
input bool     InpStaticMomentumCritical  = DEF_STATIC_MOMENTUM_CRITICAL;   // [Static Momentum] Critical
input double   InpStaticMomentumWeight    = DEF_STATIC_MOMENTUM_WEIGHT;     // [Static Momentum] Weight

// FILTER 2B: RSI REVERSAL (ALWAYS ON)
bool     InpEnableRSIReversal    = DEF_ENABLE_RSI_REVERSAL;       // [RSI Reversal] Bật (phát hiện đảo chiều)
bool     InpRSIReversalCritical  = DEF_RSI_REVERSAL_CRITICAL;     // [RSI Reversal] Critical
int      InpRSIReversalLookback  = DEF_RSI_REVERSAL_LOOKBACK;     // [RSI Reversal] Lookback
double   InpRSIReversalWeight    = DEF_RSI_REVERSAL_WEIGHT;       // [RSI Reversal] Weight

// FILTER 2C: MACD HISTOGRAM
input bool     InpEnableMACDHistogram    = DEF_ENABLE_MACD_HISTOGRAM;     // [MACD Histogram] Bật (momentum shift)
input bool     InpMACDHistogramCritical  = DEF_MACD_HISTOGRAM_CRITICAL;   // [MACD Histogram] Critical
input int      InpMACDHistogramLookback  = DEF_MACD_HISTOGRAM_LOOKBACK;   // [MACD Histogram] Lookback
input double   InpMACDHistogramWeight    = DEF_MACD_HISTOGRAM_WEIGHT;     // [MACD Histogram] Weight

// FILTER 3: SMA200 TREND
input bool     InpEnableSMA200Filter = DEF_ENABLE_SMA200_FILTER;   // [SMA200 Trend] Bật (xác định xu hướng chính)
input bool     InpSMA200Critical     = DEF_SMA200_CRITICAL;        // [SMA200 Trend] Critical
input double   InpSMA200Weight       = DEF_SMA200_WEIGHT;          // [SMA200 Trend] Weight

// FILTER 4: S/R ZONE
input bool     InpEnableSRZoneFilter = DEF_ENABLE_SR_ZONE_FILTER;   // [S/R Zone] Bật
input bool     InpSRZoneCritical     = DEF_SR_ZONE_CRITICAL;        // [S/R Zone] Critical
input int      InpSRLookback         = DEF_SR_LOOKBACK;             // [S/R Zone] Lookback Bars
input double   InpSRZonePercent      = DEF_SR_ZONE_PERCENT;         // [S/R Zone] % Zone Width (40% từ S đến R)
input double   InpSRZoneWeight       = DEF_SR_ZONE_WEIGHT;          // [S/R Zone] Weight

// FILTER 4B: S/R MIN WIDTH (ALWAYS ON)
bool     InpEnableSRMinWidthFilter = DEF_ENABLE_SR_MIN_WIDTH;    // [S/R Min Width] Bật (đảm bảo vùng S/R đủ rộng để trade)
bool     InpSRMinWidthCritical     = DEF_SR_MIN_WIDTH_CRITICAL;  // [S/R Min Width] Critical
input double   InpMinSRWidthATR    = DEF_MIN_SR_WIDTH_ATR;       // [S/R Min Width] Độ rộng tối thiểu (xATR)
double   InpSRMinWidthWeight       = DEF_SR_MIN_WIDTH_WEIGHT;    // [S/R Min Width] Weight

// FILTER 5: MA NOISE
input int      InpMinCutInterval          = DEF_MIN_CUT_INTERVAL;         // [MA Noise] Min Cut Interval (0=tắt)
input double   InpCutIntervalWeight       = DEF_CUT_INTERVAL_WEIGHT;      // [MA Noise] Cut Interval Weight
input int      InpMaxCutsInLookback       = DEF_MAX_CUTS_IN_LOOKBACK;     // [MA Noise] Max Cuts in Lookback (0=tắt)
input int      InpCutsLookbackBars        = DEF_CUTS_LOOKBACK_BARS;       // [MA Noise] Cuts Lookback Bars
input double   InpMaxCutsWeight           = DEF_MAX_CUTS_WEIGHT;          // [MA Noise] Max Cuts Weight
input double   InpPeakMADistanceThreshold = DEF_PEAK_MA_DIST_THRESHOLD;   // [MA Noise] Peak-MA Threshold (0=tắt)
input double   InpPeakMADistWeight        = DEF_PEAK_MA_DIST_WEIGHT;      // [MA Noise] Peak-MA Weight

// FILTER 6: ADX TREND STRENGTH
input bool     InpEnableADXFilter        = DEF_ENABLE_ADX_FILTER;         // [ADX] Bật (trend strength)
input bool     InpADXCritical            = DEF_ADX_CRITICAL;              // [ADX] Critical
input int      InpADXPeriod              = DEF_ADX_PERIOD;                // [ADX] Chu kỳ
input double   InpMinADXThreshold        = DEF_MIN_ADX_THRESHOLD;         // [ADX] Min Threshold
input bool     InpADXDirectionalConfirm  = DEF_ADX_DIRECTIONAL_CONFIRM;   // [ADX] Check +DI/-DI
input double   InpADXWeight              = DEF_ADX_WEIGHT;                // [ADX] Weight

// FILTER 7: BODY/ATR RATIO
input bool     InpEnableBodyATRFilter = DEF_ENABLE_BODY_ATR_FILTER;   // [Body/ATR] Bật (candle strength)
input bool     InpBodyATRCritical     = DEF_BODY_ATR_CRITICAL;        // [Body/ATR] Critical
input double   InpMinBodyATRRatio     = DEF_MIN_BODY_ATR_RATIO;       // [Body/ATR] Min Body/ATR Ratio
input double   InpBodyATRWeight       = DEF_BODY_ATR_WEIGHT;          // [Body/ATR] Weight

// FILTER 8: VOLUME CONFIRMATION
input bool     InpEnableVolumeFilter = DEF_ENABLE_VOLUME_FILTER;   // [Volume] Bật
input bool     InpVolumeCritical     = DEF_VOLUME_CRITICAL;        // [Volume] Critical
input int      InpVolumeAvgPeriod    = DEF_VOLUME_AVG_PERIOD;      // [Volume] Avg Period
input double   InpMinVolumeRatio     = DEF_MIN_VOLUME_RATIO;       // [Volume] Min Ratio
input double   InpVolumeWeight       = DEF_VOLUME_WEIGHT;          // [Volume] Weight

// FILTER 9: PRICE-MA DISTANCE (ALWAYS ON)
bool     InpEnablePriceMADistFilter = DEF_ENABLE_PRICE_MA_DIST;    // [Price-MA] Bật
bool     InpPriceMADistCritical     = DEF_PRICE_MA_DIST_CRITICAL;  // [Price-MA] Critical
double   InpMaxPriceMADistATR       = DEF_MAX_PRICE_MA_DIST_ATR;   // [Price-MA] Max Distance (xATR)
double   InpPriceMAWeight           = DEF_PRICE_MA_DIST_WEIGHT;    // [Price-MA] Weight

// FILTER 10: TIME CONTROL (EA Only)
input bool     InpEnableTimeFilter = DEF_ENABLE_TIME_FILTER;   // [Time] Bật
input bool     InpTimeCritical     = DEF_TIME_CRITICAL;        // [Time] Critical
input int      InpTradeStartHour   = DEF_TRADE_START_HOUR;     // [Time] Start Hour
input int      InpTradeEndHour     = DEF_TRADE_END_HOUR;       // [Time] End Hour
input double   InpTimeWeight       = DEF_TIME_WEIGHT;          // [Time] Weight

// FILTER 11: NEWS FILTER (EA Only)
input bool     InpEnableNewsFilter   = DEF_ENABLE_NEWS_FILTER;      // [News] Bật
input bool     InpNewsCritical       = DEF_NEWS_CRITICAL;           // [News] Critical
input int      InpNewsMinutesBefore  = DEF_NEWS_MINUTES_BEFORE;     // [News] Mins Before
input int      InpNewsMinutesAfter   = DEF_NEWS_MINUTES_AFTER;      // [News] Mins After
input int      InpNewsMinImportance  = DEF_NEWS_MIN_IMPORTANCE;     // [News] Min Importance
input double   InpNewsWeight         = DEF_NEWS_WEIGHT;             // [News] Weight

// FILTER 12: CONSECUTIVE LOSSES (EA Only)
input bool     InpEnableConsecLossFilter = DEF_ENABLE_CONSEC_LOSS_FILTER;   // [Consec Loss] Bật
input int      InpMaxConsecutiveLosses   = DEF_MAX_CONSECUTIVE_LOSSES;      // [Consec Loss] Max
input int      InpPauseMinutesAfterLoss  = DEF_PAUSE_MINUTES_AFTER_LOSS;    // [Consec Loss] Pause Mins

// ==================================================
// ================= BIẾN TOÀN CỤC ===================
// ==================================================

CTrade         g_trade;
int            hSMA50;
int            hSMA200;
int            hRSI;
int            hMACD;
int            hADX;              // ADX indicator handle
datetime       g_lastBarTime = 0;
datetime       g_lastSignalTime = 0;  // Thời gian của signal cuối cùng
double         g_tickSize;
double         g_pointValue;
SMAPullbackConfig g_config;
SignalDrawConfig  g_drawConfig;  // Config cho drawing utilities
string            EA_OBJ_PREFIX = "EA_SIG_";  // Prefix cho EA objects

// Consecutive Losses tracking
int            g_consecutiveLosses = 0;   // Số lệnh thua liên tiếp
datetime       g_pauseUntil = 0;          // Thời gian tạm dừng đến
double         g_lastClosedProfit = 0;    // Profit của lệnh đóng gần nhất

// ==================================================
// ===================== INIT ========================
// ==================================================
int OnInit()
  {
// Khởi tạo indicator handles
   hSMA50 = iMA(_Symbol, _Period, InpMA50Period, 0, (ENUM_MA_METHOD)InpMAType, PRICE_CLOSE);
   if(hSMA50 == INVALID_HANDLE)
     {
      Print("Lỗi tạo MA50 handle");
      return INIT_FAILED;
     }

   hSMA200 = iMA(_Symbol, _Period, InpMA200Period, 0, (ENUM_MA_METHOD)InpMAType, PRICE_CLOSE);
   if(hSMA200 == INVALID_HANDLE)
     {
      Print("Lỗi tạo MA200 handle");
      return INIT_FAILED;
     }

   hRSI = iRSI(_Symbol, _Period, InpRSIPeriod, PRICE_CLOSE);
   if(hRSI == INVALID_HANDLE)
     {
      Print("Lỗi tạo RSI handle");
      return INIT_FAILED;
     }

   hMACD = iMACD(_Symbol, _Period, InpMACDFast, InpMACDSlow, InpMACDSignal, PRICE_CLOSE);
   if(hMACD == INVALID_HANDLE)
     {
      Print("Lỗi tạo MACD handle");
      return INIT_FAILED;
     }

// ADX indicator for trend strength filter
   hADX = iADX(_Symbol, _Period, InpADXPeriod);
   if(hADX == INVALID_HANDLE)
     {
      Print("Lỗi tạo ADX handle");
      return INIT_FAILED;
     }

// Khởi tạo trade object
   g_trade.SetExpertMagicNumber(InpMagicNumber);
   g_trade.SetDeviationInPoints(10);
   g_trade.SetTypeFilling(ORDER_FILLING_IOC);

// --- CONFIG INITIALIZATION ---
// Core Settings
   g_config.minStopLoss = InpMinStopLoss;
   g_config.riskRewardRate = InpRiskRewardRate;
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
// Filter 10: Time Control (EA Only)
   g_config.enableTimeFilter = InpEnableTimeFilter;
   g_config.timeCritical = InpTimeCritical;
   g_config.tradeStartHour = InpTradeStartHour;
   g_config.tradeEndHour = InpTradeEndHour;
   g_config.timeWeight = InpTimeWeight;
// Filter 11: News Filter (EA Only)
   g_config.enableNewsFilter = InpEnableNewsFilter;
   g_config.newsCritical = InpNewsCritical;
   g_config.newsMinutesBefore = InpNewsMinutesBefore;
   g_config.newsMinutesAfter = InpNewsMinutesAfter;
   g_config.newsMinImportance = InpNewsMinImportance;
   g_config.newsWeight = InpNewsWeight;
// Filter 12: Consecutive Losses (EA Only)
   g_config.enableConsecutiveLossFilter = InpEnableConsecLossFilter;
   g_config.maxConsecutiveLosses = InpMaxConsecutiveLosses;
   g_config.pauseMinutesAfterLosses = InpPauseMinutesAfterLoss;

   g_tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   g_pointValue = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   g_lastSignalTime = 0;
   g_consecutiveLosses = 0;
   g_pauseUntil = 0;

// Khởi tạo draw config cho EA
   if(InpEnableDrawSignal)
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
   if(g_config.enableMASlopeFilter)
      activeFilters += "Slope ";
   if(g_config.enableStaticMomentumFilter)
      activeFilters += "StaticMom ";
   if(g_config.enableRSIReversalFilter)
      activeFilters += "RSIRev ";
   if(g_config.enableMACDHistogramFilter)
      activeFilters += "MACDHist ";
   if(g_config.enableSMA200Filter)
      activeFilters += "SMA200 ";
   if(g_config.enableSRZoneFilter)
      activeFilters += "S/R ";
   if(g_config.minCutInterval > 0)
      activeFilters += "CutInterval ";
   if(g_config.maxCutsInLookback > 0)
      activeFilters += "MaxCuts ";
   if(g_config.peakMaDistanceThreshold > 0)
      activeFilters += "PeakMA ";
   if(g_config.enableADXFilter)
      activeFilters += "ADX ";
   if(g_config.enableBodyATRFilter)
      activeFilters += "Body/ATR ";
   if(g_config.enableVolumeFilter)
      activeFilters += "Volume ";
   if(g_config.enablePriceMADistanceFilter)
      activeFilters += "Price-MA ";
   if(g_config.enableTimeFilter)
      activeFilters += "Time ";
   if(g_config.enableNewsFilter)
      activeFilters += "News ";
   if(g_config.enableConsecutiveLossFilter)
      activeFilters += "ConsecLoss ";
   Print(activeFilters);
  }

// ==================================================
void OnDeinit(const int reason)
  {
   Comment("");  // Xóa comment box
   IndicatorRelease(hSMA50);
   IndicatorRelease(hSMA200);
   IndicatorRelease(hRSI);
   IndicatorRelease(hMACD);
   IndicatorRelease(hADX);

// Xử lý marker/tooltip khi EA dừng
// Nếu InpKeepMarkersOnStop = true và EA bị remove thủ công, giữ lại marker để review
   bool keepMarkers = InpKeepMarkersOnStop &&
                      (reason == REASON_PROGRAM || reason == REASON_REMOVE);

   if(InpEnableDrawSignal && !keepMarkers)
     {
      DeleteAllSignalObjects(EA_OBJ_PREFIX);
      ClearSignalTooltips(EA_OBJ_PREFIX);
     }

   Print("EA đã hủy. Reason: ", reason, keepMarkers ? " - Giữ marker" : "");
  }

// ==================================================
// =============== ON CHART EVENT ====================
// ==================================================
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
  {
// Bỏ qua nếu không bật vẽ signal
   if(!InpEnableDrawSignal)
      return;

// Dùng hàm xử lý tập trung từ Utility
   HandleSignalChartEvent(id, lparam, dparam, sparam, EA_OBJ_PREFIX);
  }

// ==================================================
// =================== ON TICK =======================
// ==================================================
void OnTick()
  {
// Chỉ xử lý khi nến mới đóng
   datetime currentBarTime = iTime(_Symbol, _Period, 0);
   if(currentBarTime == g_lastBarTime)
      return;
   g_lastBarTime = currentBarTime;

// Kiểm tra giới hạn số lệnh toàn tài khoản
   if(InpMaxAccountOrders > 0)
     {
      int accountOrders = CountAccountPositions();
      if(accountOrders >= InpMaxAccountOrders)
        {
         return;  // Đã đạt giới hạn lệnh toàn tài khoản
        }
     }

// Kiểm tra giới hạn số lệnh cho symbol hiện tại
   if(InpMaxSymbolOrders > 0)
     {
      int symbolOrders = CountSymbolPositions();
      if(symbolOrders >= InpMaxSymbolOrders)
        {
         return;  // Đã đạt giới hạn lệnh cho symbol này
        }
     }

// Check Consecutive Losses Filter - Tạm dừng trade nếu cần
   if(g_config.enableConsecutiveLossFilter && g_pauseUntil > 0)
     {
      if(TimeCurrent() < g_pauseUntil)
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
   if(spreadPips > InpMaxSpread)
     {
      Print("Spread cao: ", DoubleToString(spreadPips, 1), " pips > ", DoubleToString(InpMaxSpread, 1), " pips");
      return;
     }

// Copy dữ liệu giá
   int rates_total = Bars(_Symbol, _Period);
   if(rates_total < 200)
      return;

   double open[], high[], low[], close[];
   datetime time[];
   ArraySetAsSeries(open, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(close, true);
   ArraySetAsSeries(time, true);

   int copyCount = MathMin(rates_total, 10000);
   if(CopyOpen(_Symbol, _Period, 0, copyCount, open) <= 0)
      return;
   if(CopyHigh(_Symbol, _Period, 0, copyCount, high) <= 0)
      return;
   if(CopyLow(_Symbol, _Period, 0, copyCount, low) <= 0)
      return;
   if(CopyClose(_Symbol, _Period, 0, copyCount, close) <= 0)
      return;
   if(CopyTime(_Symbol, _Period, 0, copyCount, time) <= 0)
      return;

// Copy indicator buffers
   double sma50[], sma200[], rsi[], macdMain[], macdSignal[];
   ArraySetAsSeries(sma50, true);
   ArraySetAsSeries(sma200, true);
   ArraySetAsSeries(rsi, true);
   ArraySetAsSeries(macdMain, true);
   ArraySetAsSeries(macdSignal, true);

   if(CopyBuffer(hSMA50, 0, 0, copyCount, sma50) <= 0)
      return;
   if(CopyBuffer(hSMA200, 0, 0, copyCount, sma200) <= 0)
      return;
   if(CopyBuffer(hRSI, 0, 0, copyCount, rsi) <= 0)
      return;
   if(CopyBuffer(hMACD, 0, 0, copyCount, macdMain) <= 0)
      return;
   if(CopyBuffer(hMACD, 1, 0, copyCount, macdSignal) <= 0)
      return;

// Copy ADX buffers (for extended filters)
   double adxMain[], adxPlusDI[], adxMinusDI[];
   ArraySetAsSeries(adxMain, true);
   ArraySetAsSeries(adxPlusDI, true);
   ArraySetAsSeries(adxMinusDI, true);

   if(CopyBuffer(hADX, 0, 0, copyCount, adxMain) <= 0)   // ADX main line
      return;
   if(CopyBuffer(hADX, 1, 0, copyCount, adxPlusDI) <= 0) // +DI
      return;
   if(CopyBuffer(hADX, 2, 0, copyCount, adxMinusDI) <= 0) // -DI
      return;

// Copy tick volume (for volume filter)
   long tickVolume[];
   ArraySetAsSeries(tickVolume, true);
   if(CopyTickVolume(_Symbol, _Period, 0, copyCount, tickVolume) <= 0)
      return;

// Scan for signals - tìm nến cắt trong phạm vi maxWaitBars
// Bắt đầu từ nến cũ nhất trong phạm vi và tiến về nến mới nhất
   int startIdx = 1 + g_config.maxWaitBars;
   int endIdx = 1;

// Đảm bảo startIdx không vượt quá dữ liệu có sẵn
   if(startIdx >= copyCount)
      startIdx = copyCount - 1;

   for(int cutIdx = startIdx; cutIdx >= endIdx; cutIdx--)
     {
      // Bỏ qua nến cắt nếu nó cũ hơn hoặc bằng thời gian signal cuối cùng
      if(g_lastSignalTime > 0 && time[cutIdx] <= g_lastSignalTime)
         continue;

      // Kiểm tra nến cắt SMA 50 tại cutIdx
      bool cutUpToBottom = IsGreaterThan(open[cutIdx], sma50[cutIdx], g_tickSize) && IsLessThan(close[cutIdx], sma50[cutIdx], g_tickSize);
      bool cutDownToTop = IsLessThan(open[cutIdx], sma50[cutIdx], g_tickSize) && IsGreaterThan(close[cutIdx], sma50[cutIdx], g_tickSize);

      if(!cutUpToBottom && !cutDownToTop)
         continue;

      // Vẽ cut candle marker (nếu bật)
      if(InpEnableDrawSignal)
        {
         DrawCutCandleMarker(g_drawConfig, cutUpToBottom, time[cutIdx],
                             cutUpToBottom ? low[cutIdx] : high[cutIdx],
                             sma50[cutIdx], "");
        }

      // Scan for signal
      ScanResult scanResult;
      ScanForSignal(g_config, cutIdx, cutUpToBottom, _Symbol, time[0],
                    open, high, low, close, sma50, sma200,
                    rsi, macdMain, macdSignal, tickVolume,
                    adxMain, adxPlusDI, adxMinusDI,
                    g_tickSize, g_pointValue, copyCount, scanResult);

      if(scanResult.found)
        {
         // Vẽ signal lên chart (nếu bật)
         if(InpEnableDrawSignal)
           {
            DrawSignalMarker(g_drawConfig, scanResult.isBuy, false,
                             time[scanResult.confirmIdx], cutIdx - scanResult.confirmIdx,
                             scanResult.signal.entry, scanResult.signal.sl, scanResult.signal.tp,
                             scanResult.signal.strength, scanResult.signal.score,
                             scanResult.signal.reasons,
                             scanResult.signal.support, scanResult.signal.resistance,
                             g_pointValue, _Period);
           }

         // Chỉ trade nếu signal xác nhận tại nến vừa đóng (index = 1)
         if(scanResult.confirmIdx == 1)
           {
            // In chi tiết tất cả tham số và đánh giá filter
            PrintSignalDetails(scanResult, time, close, sma50, sma200,
                               rsi, macdMain, macdSignal,
                               adxMain, adxPlusDI, adxMinusDI, tickVolume,
                               high, low, open);

            if(InpAutoTrade)
              {
               ExecuteTrade(scanResult.isBuy, scanResult.signal);
              }
            else
              {
               Print("AutoTrade OFF. Không vào lệnh.");
              }
           }

         // Lưu thời gian signal để tránh xử lý lại nến cắt này
         g_lastSignalTime = time[scanResult.confirmIdx];
         break;
        }
      else
         if(scanResult.cancelled)
           {
            // Vẽ cancelled signal (nếu bật)
            if(InpEnableDrawSignal)
              {
               DrawSignalMarker(g_drawConfig, scanResult.isBuy, true,
                                time[scanResult.confirmIdx], 0,
                                close[scanResult.confirmIdx], 0, 0,
                                "", 0, scanResult.cancelReason,
                                0, 0, g_pointValue, _Period);
              }

            // Lưu thời gian để bỏ qua nến cắt đã cancelled
            g_lastSignalTime = time[scanResult.confirmIdx];
            break;  // Quan trọng: break để ngăn tìm signal mới trong cùng tick
           }
     }
  }

//+------------------------------------------------------------------+
//| Track closed trades to count consecutive losses                  |
//+------------------------------------------------------------------+
void OnTradeTransaction(
   const MqlTradeTransaction& trans,
   const MqlTradeRequest& request,
   const MqlTradeResult& result
)
  {
// Chỉ xử lý khi lệnh được đóng hoàn toàn (position closed)
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD)
      return;

// Kiểm tra deal có thuộc EA này không
   if(trans.symbol != _Symbol)
      return;

   ulong dealTicket = trans.deal;
   if(dealTicket == 0)
      return;

// Lấy thông tin deal
   if(!HistoryDealSelect(dealTicket))
      return;

   long magic = HistoryDealGetInteger(dealTicket, DEAL_MAGIC);
   if(magic != InpMagicNumber)
      return;

// Kiểm tra loại deal (chỉ xét khi đóng lệnh: DEAL_ENTRY_OUT)
   long entry = HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
   if(entry != DEAL_ENTRY_OUT)
      return;

// Lấy profit của deal
   double profit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
   double commission = HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);
   double swap = HistoryDealGetDouble(dealTicket, DEAL_SWAP);
   double netProfit = profit + commission + swap;

// Cập nhật consecutive losses
   if(netProfit < 0)
     {
      g_consecutiveLosses++;
      Print("Lệnh thua. Chuỗi thua: ", g_consecutiveLosses);

      // Kiểm tra và tạm dừng nếu đạt ngƯỡng
      if(g_config.enableConsecutiveLossFilter && g_consecutiveLosses >= g_config.maxConsecutiveLosses)
        {
         g_pauseUntil = TimeCurrent() + g_config.pauseMinutesAfterLosses * 60;
         Print("Max chuỗi thua (", g_consecutiveLosses, "). Tạm dừng đến ", TimeToString(g_pauseUntil));
        }
     }
   else
     {
      // Reset counter khi có lệnh thắng
      if(g_consecutiveLosses > 0)
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
void PrintSignalDetails(
   const ScanResult &scanResult,
   const datetime &time[],
   const double &close[],
   const double &sma50[],
   const double &sma200[],
   const double &rsi[],
   const double &macdMain[],
   const double &macdSignal[],
   const double &adxMain[],
   const double &adxPlusDI[],
   const double &adxMinusDI[],
   const long &tickVolume[],
   const double &high[],
   const double &low[],
   const double &open[]
)
  {
   int idx = scanResult.confirmIdx;
   bool isBuy = scanResult.isBuy;

   Print("========== TÍN HIỆU ", isBuy ? "BUY" : "SELL", " ==========");
   Print("Thời gian: ", TimeToString(time[idx]));
   Print("Score: ", scanResult.signal.score, " | Strength: ", scanResult.signal.strength);

// ============ GIÁ TRỊ INDICATOR ============
   Print("---------- INDICATOR VALUES ----------");
   Print("Close: ", DoubleToString(close[idx], _Digits));
   Print("SMA50: ", DoubleToString(sma50[idx], _Digits),
         " | SMA200: ", DoubleToString(sma200[idx], _Digits));
   Print("RSI: ", DoubleToString(rsi[idx], 2));

   double macdHist = macdMain[idx] - macdSignal[idx];
   Print("MACD: ", DoubleToString(macdMain[idx], 6),
         " | Sig: ", DoubleToString(macdSignal[idx], 6),
         " | Hist: ", DoubleToString(macdHist, 6));

   Print("ADX: ", DoubleToString(adxMain[idx], 2),
         " | +DI: ", DoubleToString(adxPlusDI[idx], 2),
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
   if(scanResult.signal.reasons != "")
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
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0)
        {
         if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
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
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0)
        {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
            PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
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
void ExecuteTrade(bool isBuy, const SignalResult &signal)
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
   double tpBuffer = MathMax(configBuffer, spread);   // Buffer = Max(config, spread)

// Điều chỉnh TP: giảm khoảng bằng buffer để tăng khả năng khớp lệnh
   if(isBuy)
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
   ValidatePriceConstraints(isBuy, entryPrice, sl, tp,
                            InpMinStopLoss, InpMinStopLoss, MIN_RISK_REWARD_RATE,
                            g_pointValue, digits, priceValidation);

   if(!priceValidation.isValid)
     {
      Print(priceValidation.reason);
      return;
     }

   double slDistancePoints = priceValidation.slDistancePoints;
   double tpDistancePoints = priceValidation.tpDistancePoints;

// ============================================================
// Tính lot size dựa trên InpMaxLoss
// ============================================================
   double lotSize = InpLotSize;
   double slDistance = MathAbs(entryPrice - sl);

   if(InpMaxLoss > 0)
     {
      // Lấy giá trị mỗi tick và tick size
      double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);

      if(tickSize > 0 && tickValue > 0)
        {
         // Tính số ticks trong khoảng cách S/L
         double slTicks = slDistance / tickSize;

         // Tính loss với 1 lot
         double lossPerLot = slTicks * tickValue;

         if(lossPerLot > 0)
           {
            // Tính lot size tối đa để không vượt quá InpMaxLoss
            double maxLotByRisk = InpMaxLoss / lossPerLot;

            // Lấy giá trị nhỏ hơn giữa InpLotSize và maxLotByRisk
            lotSize = MathMin(InpLotSize, maxLotByRisk);

            // Normalize lot size theo step
            double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
            double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
            double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);

            lotSize = MathFloor(lotSize / lotStep) * lotStep;
            lotSize = MathMax(minLot, MathMin(maxLot, lotSize));

            Print("Tính rủi ro: SL Dist = ", DoubleToString(slDistance, digits),
                  ", Loss/Lot = $", DoubleToString(lossPerLot, 2),
                  ", Max Lot = ", DoubleToString(maxLotByRisk, 2),
                  ", Lot chốt = ", DoubleToString(lotSize, 2));
           }
        }
     }

   bool result = false;

   if(isBuy)
     {
      result = g_trade.Buy(lotSize, _Symbol, ask, sl, tp, InpTradeComment);
     }
   else
     {
      result = g_trade.Sell(lotSize, _Symbol, bid, sl, tp, InpTradeComment);
     }

   if(result)
     {
      Print("Vào lệnh thành công: ", isBuy ? "BUY" : "SELL",
            " Lot: ", DoubleToString(lotSize, 2),
            " Entry: ", isBuy ? ask : bid,
            " SL: ", sl, " (", DoubleToString(slDistancePoints, 1), " pts)",
            " TP: ", tp, " (", DoubleToString(tpDistancePoints, 1), " pts)");
     }
   else
     {
      Print("Vào lệnh thất bại: ", g_trade.ResultRetcode(), " - ", g_trade.ResultRetcodeDescription());
     }
  }
//+------------------------------------------------------------------+
