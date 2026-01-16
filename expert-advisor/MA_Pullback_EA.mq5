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

// --- MAIN SETTINGS ---
input bool     InpAutoTrade       = true;           // Tự động đặt lệnh
input double   InpLotSize         = 1.0;            // Khối lượng giao dịch
input double   InpMaxLoss         = 100.0;          // Số tiền thua tối đa (USD, 0 = không giới hạn)
input int      InpMagicNumber     = 123456;         // Magic Number
input double   InpMaxSpread       = 20.0;           // Spread tối đa (points, ~2 pips for 5-digit)
input string   InpTradeComment    = "SMA_Pullback_EA"; // Comment lệnh

// --- DRAWING SETTINGS (Vẽ signal lên chart) ---
input bool     InpEnableDrawSignal = true;          // Bật vẽ signal lên chart

// --- TRADE LIMITS ---
input double   InpMinStopLoss      = 50.0;           // Số points StopLoss tối thiểu (5 pips)
input double   InpRiskRewardRate   = 1.5;            // Tỷ lệ Reward / Risk (1.5 = 1.5R)
input int      InpMaxAccountOrders = 3;              // Max lệnh toàn tài khoản (0 = không giới hạn)
input int      InpMaxSymbolOrders  = 1;              // Max lệnh cho Symbol hiện tại
input double   InpTPBuffer         = 0;              // TP Buffer (pips, 0 = chỉ dùng spread)
input double   InpSRBufferPercent  = 5.0;            // S/R/MA Buffer (%) - Buffer cộng thêm vào S/R zone / MA line

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
input bool     InpEnableSMA200Filter = true;        // [Filter: SMA Slow Trend] Bật SMA Slow Trend
input bool     InpSMA200Critical     = false;       // [Filter: SMA Slow Trend] Critical (quan trọng - xác định xu hướng chính)
input double   InpSMA200Weight       = 15.0;        // [Filter: SMA Slow Trend] Weight

// ==============================================================
// FILTER 4: S/R ZONE
// Kiểm tra giá có trong vùng entry tốt không
// ==============================================================
input bool     InpEnableSRZoneFilter = true;        // [Filter: S/R Zone] Bật S/R Zone
input bool     InpSRZoneCritical     = false;       // [Filter: S/R Zone] Critical
input int      InpSRLookback         = 20;          // [Filter: S/R Zone] Lookback Bars
input double   InpSRZonePercent      = 40.0;        // [Filter: S/R Zone] % Zone Width (40% từ S đến R)
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
input bool     InpEnableBodyATRFilter = false;      // [Filter: Body/ATR] Bật Body/ATR (candle strength)
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

// ==============================================================
// FILTER 10: TIME CONTROL (EA Only)
// Chỉ trade trong giờ tốt
// ==============================================================
input bool     InpEnableTimeFilter = false;         // [Filter: Time Control] Bật Time Control
input bool     InpTimeCritical     = false;         // [Filter: Time Control] Critical (quan trọng - chỉ trade trong giờ tốt)
input int      InpTradeStartHour   = 7;             // [Filter: Time Control] Start Hour (London open)
input int      InpTradeEndHour     = 21;            // [Filter: Time Control] End Hour (NY close)
input double   InpTimeWeight       = 0.0;           // [Filter: Time Control] Weight

// ==============================================================
// FILTER 11: NEWS FILTER (EA Only)
// Tránh trade gần tin quan trọng
// ==============================================================
input bool     InpEnableNewsFilter   = false;       // [Filter: News Filter] Bật News Filter
input bool     InpNewsCritical       = false;       // [Filter: News Filter] Critical (quan trọng - tránh volatility)
input int      InpNewsMinutesBefore  = 15;          // [Filter: News Filter] Mins Before News
input int      InpNewsMinutesAfter   = 10;          // [Filter: News Filter] Mins After News
input int      InpNewsMinImportance  = 3;           // [Filter: News Filter] Min Importance (3 = High only)
input double   InpNewsWeight         = 0.0;         // [Filter: News Filter] Weight

// ==============================================================
// FILTER 12: CONSECUTIVE LOSSES (EA Only)
// Tạm dừng sau chuỗi thua liên tiếp
// ==============================================================
input bool     InpEnableConsecLossFilter = true;    // [Filter: Consecutive Losses] Bật Consec Loss
input int      InpMaxConsecutiveLosses   = 3;       // [Filter: Consecutive Losses] Max Consec Losses
input int      InpPauseMinutesAfterLoss  = 30;      // [Filter: Consecutive Losses] Pause Mins (30 phút nghỉ)

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
// FILTER 10: TIME CONTROL (EA Only)
// ==============================================================
   g_config.enableTimeFilter = InpEnableTimeFilter;
   g_config.timeCritical = InpTimeCritical;
   g_config.tradeStartHour = InpTradeStartHour;
   g_config.tradeEndHour = InpTradeEndHour;
   g_config.timeWeight = InpTimeWeight;

// ==============================================================
// FILTER 11: NEWS FILTER (EA Only)
// ==============================================================
   g_config.enableNewsFilter = InpEnableNewsFilter;
   g_config.newsCritical = InpNewsCritical;
   g_config.newsMinutesBefore = InpNewsMinutesBefore;
   g_config.newsMinutesAfter = InpNewsMinutesAfter;
   g_config.newsMinImportance = InpNewsMinImportance;
   g_config.newsWeight = InpNewsWeight;

// ==============================================================
// FILTER 12: CONSECUTIVE LOSSES (EA Only)
// ==============================================================
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

// Xóa tất cả signal objects khi EA bị tắt
   if(InpEnableDrawSignal)
     {
      DeleteAllSignalObjects(EA_OBJ_PREFIX);
     }

// Clear tooltip data
   ClearSignalTooltips(EA_OBJ_PREFIX);

   Print("EA đã hủy");
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
            Print("Có tín hiệu tại ", TimeToString(time[scanResult.confirmIdx]),
                  " Type: ", scanResult.isBuy ? "BUY" : "SELL",
                  " Strength: ", scanResult.signal.strength,
                  " Score: ", scanResult.signal.score);

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
