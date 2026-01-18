//+------------------------------------------------------------------+
//|                                          SMA Pullback Core Logic |
//|                                    Copyright 2026, Do Nhat Phong |
//|                                   https://github.com/nhatphongdo |
//+------------------------------------------------------------------+
#property copyright "Do Nhat Phong"

#ifndef SMA_PULLBACK_CORE_H
#define SMA_PULLBACK_CORE_H

// Include reusable modules
#include "Filters.mqh"
#include "MA_Filters.mqh"
#include "Utility.mqh"
#include "CandlePatterns.mqh"

// ==================================================
// =================== STRUCTS ======================
// ==================================================

struct SignalResult
  {
   double            score;
   string            strength; // WEAK, MEDIUM, STRONG
   string            reasons;  // List of reasons separated by newline
   string            filterDetails; // Chi tiết đánh giá TẤT CẢ filter (dù pass hay không)
   bool              isCriticalFail;
   double            entry;
   double            sl;
   double            tp;
   double            resistance;
   double            support;
  };

struct SMAPullbackConfig
  {
   // ==============================================================
   // TRADE LIMITS & CORE SETTINGS
   // ==============================================================
   double            minStopLoss;             // Số points stoploss tối thiểu
   double            minTakeProfit;           // Số points takeprofit tối thiểu
   double            maxRiskRewardRate;       // Tỷ lệ Reward / Risk tối đa
   double            minRiskRewardRate;       // Tỷ lệ Reward / Risk tối thiểu (0=none)
   double            srBufferPercent;         // Buffer (%) cộng thêm vào S/R khi tính SL/TP
   double            minScoreToPass;          // Điểm tối thiểu để signal được chấp nhận

   // ==============================================================
   // INDICATOR PARAMETERS
   // ==============================================================
   int               sma50Period;             // Chu kỳ MA Fast
   int               sma200Period;            // Chu kỳ MA Slow
   double            ma50SlopeThreshold;      // Góc dốc MA Fast tối thiểu (độ)
   int               slopeSmoothBars;         // Số nến để tính slope trung bình
   int               rsiPeriod;               // Chu kỳ RSI
   int               macdFast;                // MACD Fast period
   int               macdSlow;                // MACD Slow period
   int               macdSignal;              // MACD Signal period
   int               adxPeriod;               // Chu kỳ ADX

   // ==============================================================
   // STRATEGY PARAMETERS
   // ==============================================================
   int               maxWaitBars;             // Số nến tối đa chờ pullback
   int               atrLength;               // Số nến tính ATR
   double            wickBodyRatio;           // Tỷ lệ Bóng/Thân nến

   // ==============================================================
   // FILTER 1: MA SLOPE
   // Kiểm tra độ dốc MA có đủ mạnh không
   // ==============================================================
   bool              enableMASlopeFilter;      // Bật/tắt MA Slope filter
   bool              maSlopeCritical;          // Nếu true, fail = critical fail
   double            maSlopeWeight;            // Trọng số của MA Slope filter

   // ==============================================================
   // FILTER 2A: STATIC MOMENTUM (RSI + MACD position)
   // Kiểm tra RSI và MACD có xác nhận xu hướng không
   // ==============================================================
   bool              enableStaticMomentumFilter;      // Bật/tắt Momentum filter
   bool              staticMomentumCritical;          // Nếu true, fail = critical fail
   double            staticMomentumWeight;            // Trọng số của Momentum filter

   // ==============================================================
   // FILTER 2B: RSI REVERSAL DETECTION
   // Phát hiện RSI đang đi ngược hướng signal (đảo chiều sớm)
   // ==============================================================
   bool              enableRSIReversalFilter;         // Bật/tắt RSI Reversal filter
   bool              rsiReversalCritical;             // Nếu true, fail = critical fail
   int               rsiReversalLookback;             // Số nến để kiểm tra RSI reversal
   double            rsiReversalWeight;               // Trọng số của RSI Reversal filter

   // ==============================================================
   // FILTER 2C: MACD HISTOGRAM TREND
   // Phát hiện histogram đang mở rộng ngược hướng signal
   // ==============================================================
   bool              enableMACDHistogramFilter;       // Bật/tắt MACD Histogram filter
   bool              macdHistogramCritical;           // Nếu true, fail = critical fail
   int               macdHistogramLookback;           // Số nến để kiểm tra MACD histogram
   double            macdHistogramWeight;             // Trọng số của MACD Histogram filter

   // ==============================================================
   // FILTER 3: SMA200 TREND
   // Kiểm tra giá có cùng xu hướng với SMA200 không
   // ==============================================================
   bool              enableSMA200Filter;              // Bật/tắt SMA200 filter
   bool              sma200Critical;                  // Nếu true, fail = critical fail
   double            sma200Weight;                    // Trọng số của SMA Slow filter

   // ==============================================================
   // FILTER 4: S/R ZONE
   // Kiểm tra giá có trong vùng entry tốt không (% từ S đến R)
   // ==============================================================
   bool              enableSRZoneFilter;           // Bật/tắt S/R Zone filter
   bool              srZoneCritical;               // Nếu true, fail = critical fail
   int               srLookback;                   // Số nến để kiểm tra S/R Zone
   double            srZonePercent;                // % vùng giá cho phép
   double            srZoneWeight;                 // Trọng số của S/R Zone filter

   // ==============================================================
   // FILTER 4B: S/R MIN WIDTH
   // Lọc vùng S/R quá hẹp (không đủ room cho SL/TP)
   // ==============================================================
   bool              enableSRMinWidthFilter;       // Bật/tắt filter độ rộng S/R tối thiểu
   bool              srMinWidthCritical;           // Nếu true, fail = critical fail
   double            minSRWidthATR;                // Độ rộng tối thiểu (bội số ATR)
   double            srMinWidthWeight;             // Trọng số của S/R Min Width filter

   // ==============================================================
   // FILTER 5: MA NOISE (Cut Interval, Max Cuts, Peak Distance)
   // Lọc vùng giá dao động quanh MA50 (choppy market)
   // ==============================================================
   int               minCutInterval;          // Số nến tối thiểu giữa 2 lần cắt (0=Off)
   double            cutIntervalWeight;       // Trọng số của Cut Interval filter
   int               maxCutsInLookback;       // Số lần cắt tối đa trong lookback (0=Off)
   int               cutsLookbackBars;        // Số nến để kiểm tra Max Cuts
   double            maxCutsWeight;           // Trọng số của Max Cuts filter
   double            peakMaDistanceThreshold; // Khoảng cách peak-MA tối thiểu (0=Off)
   double            peakMADistWeight;        // Trọng số của Peak-MA Distance filter

   // ==============================================================
   // FILTER 6: ADX TREND STRENGTH
   // Kiểm tra thị trường có đang trending không
   // ==============================================================
   bool              enableADXFilter;           // Bật/tắt ADX filter
   bool              adxCritical;               // Nếu true, fail = critical fail
   double            minADXThreshold;           // Ngưỡng ADX tối thiểu (20-25 để xác định trending)
   bool              useADXDirectionalConfirm;  // Nếu true, ADX phải cùng hướng với signal
   double            adxWeight;                 // Trọng số của ADX filter

   // ==============================================================
   // FILTER 7: BODY/ATR RATIO
   // Kiểm tra nến confirm có đủ mạnh không
   // ==============================================================
   bool              enableBodyATRFilter;       // Bật/tắt Body/ATR filter
   bool              bodyATRCritical;           // Nếu true, fail = critical fail
   double            minBodyATRRatio;           // Tỷ lệ body/ATR tối thiểu (0.2-0.5 = 20-50% ATR)
   double            bodyATRWeight;             // Trọng số của Body/ATR filter

   // ==============================================================
   // FILTER 8: VOLUME CONFIRMATION
   // Kiểm tra volume có đủ so với trung bình không
   // ==============================================================
   bool              enableVolumeFilter;        // Bật/tắt Volume filter
   bool              volumeCritical;            // Nếu true, fail = critical fail
   int               volumeAvgPeriod;           // Số nến để tính volume trung bình
   double            minVolumeRatio;            // Tỷ lệ volume tối thiểu so với trung bình (1.5 = 150%)
   double            volumeWeight;              // Trọng số của Volume filter

   // ==============================================================
   // FILTER 9: PRICE-MA DISTANCE
   // Tránh chase - giá không quá xa MA50
   // ==============================================================
   bool              enablePriceMADistanceFilter;   // Bật/tắt Price-MA Distance filter
   bool              priceMADistCritical;           // Nếu true, fail = critical fail
   double            maxPriceMADistanceATR;         // Khoảng cách giá-MA tối đa (bội số ATR, ví dụ 2.0 = 2*ATR)
   double            priceMADistWeight;             // Trọng số của Price-MA Distance filter

   // ==============================================================
   // FILTER 10: TIME CONTROL (EA only)
   // Chỉ trade trong giờ tốt
   // ==============================================================
   bool              enableTimeFilter;              // Bật/tắt Time filter
   bool              timeCritical;                  // Nếu true, fail = critical fail
   int               tradeStartHour;                // Giờ bắt đầu trade (0-23, server time)
   int               tradeEndHour;                  // Giờ kết thúc trade (0-23, server time)
   double            timeWeight;                    // Trọng số của Time filter

   // ==============================================================
   // FILTER 11: NEWS FILTER (EA only)
   // Tránh trade gần tin quan trọng
   // ==============================================================
   bool              enableNewsFilter;              // Bật/tắt News filter
   bool              newsCritical;                  // Nếu true, fail = critical fail
   int               newsMinutesBefore;             // Số phút trước tin để dừng trade
   int               newsMinutesAfter;              // Số phút sau tin để dừng trade
   int               newsMinImportance;             // Mức độ quan trọng tối thiểu của tin (1=Low, 2=Medium, 3=High)
   double            newsWeight;                    // Trọng số của News filter

   // ==============================================================
   // FILTER 12: CONSECUTIVE LOSSES (EA only)
   // Tạm dừng sau chuỗi thua liên tiếp
   // ==============================================================
   bool              enableConsecutiveLossFilter; // Bật/tắt Consecutive Loss filter
   int               maxConsecutiveLosses;        // Số lần thua liên tiếp tối đa để kích hoạt pause
   int               pauseMinutesAfterLosses;     // Số phút pause sau chuỗi thua
  };


// ==================================================
// ============= PROCESS SIGNAL =====================
// ==================================================

//+------------------------------------------------------------------+
//| Xử lý signal khi tìm được pattern hoàn chỉnh                     |
//| Unify logic từ Filters.mqh và MA_Filters.mqh đề loại bỏ các      |
//| signal theo config filter.                                       |
//+------------------------------------------------------------------+
void ProcessSignal(
   const SMAPullbackConfig &config,
   bool isBuySignal,
   int cutIdx,
   int confirmIdx,
   string symbol,
   datetime currentTime,
   const double &open[],
   const double &high[],
   const double &low[],
   const double &close[],
   const double &sma50[],
   const double &sma200[],
   const double &rsi[],
   const double &macdMain[],
   const double &macdSignal[],
   const long &volume[],
   const double &adxMain[],
   const double &adxPlusDI[],
   const double &adxMinusDI[],
   double tickSize,
   double pointValue,
   SignalResult &outResult
)
  {
   outResult.score = 100;  // Bắt đầu với 100, sẽ trừ dần bằng failScore
   outResult.reasons = "";
   outResult.filterDetails = "";
   outResult.isCriticalFail = false;
   outResult.strength = "NONE";
   double totalFailScore = 0; // Track tổng điểm fail

// 1. Run MA Filters (Cut Interval, Peak-MA, Max Cuts)
   MAScoringConfig maConfig;
   maConfig.enableCutIntervalFilter = (config.minCutInterval > 0);
   maConfig.minCutInterval = config.minCutInterval;
   maConfig.cutsLookbackBars = config.cutsLookbackBars;
   maConfig.cutIntervalWeight = config.cutIntervalWeight;

   maConfig.enablePeakMADistFilter = (config.peakMaDistanceThreshold > 0);
   maConfig.peakMaDistanceThreshold = config.peakMaDistanceThreshold;
   maConfig.peakMADistWeight = config.peakMADistWeight;

   maConfig.enableMaxCutsFilter = (config.maxCutsInLookback > 0);
   maConfig.maxCutsInLookback = config.maxCutsInLookback;
   maConfig.maxCutsWeight = config.maxCutsWeight;

   MAScoringResult maResult;

   RunMAFilters(maConfig, isBuySignal, cutIdx, open, high, low, close, sma50,
                tickSize, pointValue, ArraySize(high), maResult);

   totalFailScore += maResult.failScore; // Gộp failScore từ MA filters
   if(maResult.allReasons != "")
      outResult.reasons += maResult.allReasons;
   outResult.filterDetails += maResult.filterDetails;

// 2. Run Unified Filters
   UnifiedScoringConfig uniConfig;

   uniConfig.enableMASlopeFilter = config.enableMASlopeFilter;
   uniConfig.maSlopeCritical = config.maSlopeCritical;
   uniConfig.maSlopeThreshold = config.ma50SlopeThreshold;
   uniConfig.slopeSmoothBars = config.slopeSmoothBars;
   uniConfig.maSlopeWeight = config.maSlopeWeight;

// Filter 2A: Static Momentum
   uniConfig.enableStaticMomentumFilter = config.enableStaticMomentumFilter;
   uniConfig.staticMomentumCritical = config.staticMomentumCritical;
   uniConfig.staticMomentumWeight = config.staticMomentumWeight;

// Filter 2B: RSI Reversal
   uniConfig.enableRSIReversalFilter = config.enableRSIReversalFilter;
   uniConfig.rsiReversalCritical = config.rsiReversalCritical;
   uniConfig.rsiReversalLookback = config.rsiReversalLookback;
   uniConfig.rsiReversalWeight = config.rsiReversalWeight;

// Filter 2C: MACD Histogram
   uniConfig.enableMACDHistogramFilter = config.enableMACDHistogramFilter;
   uniConfig.macdHistogramCritical = config.macdHistogramCritical;
   uniConfig.macdHistogramLookback = config.macdHistogramLookback;
   uniConfig.macdHistogramWeight = config.macdHistogramWeight;

   uniConfig.enableSMA200Filter = config.enableSMA200Filter;
   uniConfig.sma200Critical = config.sma200Critical;
   uniConfig.sma200Weight = config.sma200Weight;

   uniConfig.enableSRZoneFilter = config.enableSRZoneFilter;
   uniConfig.srZoneCritical = config.srZoneCritical;
   uniConfig.srZonePercent = config.srZonePercent;
   uniConfig.srZoneWeight = config.srZoneWeight;
   uniConfig.srLookback = config.srLookback;

   uniConfig.enableSRMinWidthFilter = config.enableSRMinWidthFilter;
   uniConfig.srMinWidthCritical = config.srMinWidthCritical;
   uniConfig.minSRWidthATR = config.minSRWidthATR;
   uniConfig.srMinWidthWeight = config.srMinWidthWeight;

   uniConfig.enableADXFilter = config.enableADXFilter;
   uniConfig.adxCritical = config.adxCritical;
   uniConfig.minADXThreshold = config.minADXThreshold;
   uniConfig.useADXDirectionalConfirm = config.useADXDirectionalConfirm;
   uniConfig.adxWeight = config.adxWeight;

   uniConfig.enableBodyATRFilter = config.enableBodyATRFilter;
   uniConfig.bodyATRCritical = config.bodyATRCritical;
   uniConfig.minBodyATRRatio = config.minBodyATRRatio;
   uniConfig.atrLength = config.atrLength;
   uniConfig.bodyATRWeight = config.bodyATRWeight;

   uniConfig.enableVolumeFilter = config.enableVolumeFilter;
   uniConfig.volumeCritical = config.volumeCritical;
   uniConfig.volumeAvgPeriod = config.volumeAvgPeriod;
   uniConfig.minVolumeRatio = config.minVolumeRatio;
   uniConfig.volumeWeight = config.volumeWeight;

   uniConfig.enablePriceMADistFilter = config.enablePriceMADistanceFilter;
   uniConfig.priceMADistCritical = config.priceMADistCritical;
   uniConfig.maxPriceMADistATR = config.maxPriceMADistanceATR;
   uniConfig.priceMADistWeight = config.priceMADistWeight;

   uniConfig.enableTimeFilter = config.enableTimeFilter;
   uniConfig.timeCritical = config.timeCritical;
   uniConfig.tradeStartHour = config.tradeStartHour;
   uniConfig.tradeEndHour = config.tradeEndHour;
   uniConfig.timeWeight = config.timeWeight;

   uniConfig.enableNewsFilter = config.enableNewsFilter;
   uniConfig.newsCritical = config.newsCritical;
   uniConfig.newsMinutesBefore = config.newsMinutesBefore;
   uniConfig.newsMinutesAfter = config.newsMinutesAfter;
   uniConfig.newsMinImportance = config.newsMinImportance;
   uniConfig.newsWeight = config.newsWeight;

   uniConfig.minScoreToPass = config.minScoreToPass;

   UnifiedScoringResult scoringResult;
   RunUnifiedScoringFilters(uniConfig, isBuySignal, confirmIdx, symbol, currentTime,
                            open, high, low, close, sma50, sma200,
                            rsi, macdMain, macdSignal, volume,
                            adxMain, adxPlusDI, adxMinusDI,
                            tickSize, pointValue, ArraySize(high), scoringResult);

   totalFailScore += scoringResult.failScore; // Gộp failScore từ Unified filters
   outResult.reasons += scoringResult.allReasons;
   outResult.filterDetails += scoringResult.filterDetails;

// Tính điểm cuối cùng = 100 - totalFailScore
   outResult.score = outResult.score - totalFailScore;

   double localSupport = scoringResult.support;
   double localResistance = scoringResult.resistance;

   if(scoringResult.hasCriticalFail)
     {
      outResult.isCriticalFail = true;
      return;
     }

// Check if passed min score threshold
   if(outResult.score < config.minScoreToPass)
     {
      outResult.reasons += StringFormat("- Điểm thấp (%.0f < %.0f)\n",
                                        outResult.score, config.minScoreToPass);
      outResult.isCriticalFail = true;
      return;
     }

// Xác định mức độ mạnh yếu
   if(outResult.score >= 70)
      outResult.strength = "STRONG";
   else
      if(outResult.score >= 50)
         outResult.strength = "MEDIUM";
      else
         if(outResult.score >= 20)
            outResult.strength = "WEAK";
         else
            outResult.strength = "NONE";

// Kiểm tra giá vào lệnh và stoploss
   double entry = close[confirmIdx];
   double sl, risk, tp;

   if(isBuySignal)
     {
      // BUY: SL dưới support - trừ thêm buffer % để an toàn hơn
      double baseSupport = MathMin(MathMin(localSupport, sma50[confirmIdx]), sma200[confirmIdx]);
      double srBuffer = (entry - baseSupport) * config.srBufferPercent / 100.0;
      sl = baseSupport - srBuffer;
      risk = entry - sl;
     }
   else
     {
      // SELL: SL trên resistance - cộng thêm buffer % để an toàn hơn
      double baseResistance = MathMax(MathMax(localResistance, sma50[confirmIdx]), sma200[confirmIdx]);
      double srBuffer = (baseResistance - entry) * config.srBufferPercent / 100.0;
      sl = baseResistance + srBuffer;
      risk = sl - entry;
     }

   if(risk <= 0)
     {
      if(isBuySignal)
        {
         outResult.reasons += StringFormat("- Lỗi Entry < SL: Entry = %.5f, SL = %.5f\n", entry, sl);
        }
      else
        {
         outResult.reasons += StringFormat("- Lỗi SL < Entry: Entry = %.5f, SL = %.5f\n", entry, sl);
        }
     }

   if(isBuySignal)
     {
      // BUY: TP dưới resistance - trừ buffer % để an toàn hơn
      double tpBuffer = (localResistance - entry) * config.srBufferPercent / 100.0;
      double tpResistance = localResistance - tpBuffer;
      tp = MathMin(entry + risk, tpResistance);
      for(double j = 1.1; j <= config.maxRiskRewardRate; j += 0.1)
        {
         const double _tp = entry + risk * j;
         if(_tp <= tpResistance)
           {
            tp = _tp;
           }
        }
     }
   else
     {
      // SELL: TP trên support - cộng buffer % để an toàn hơn
      double tpBuffer = (entry - localSupport) * config.srBufferPercent / 100.0;
      double tpSupport = localSupport + tpBuffer;
      tp = MathMax(entry - risk, tpSupport);
      for(double j = 1.1; j <= config.maxRiskRewardRate; j += 0.1)
        {
         const double _tp = entry - risk * j;
         if(_tp >= tpSupport)
           {
            tp = _tp;
           }
        }
     }

   outResult.entry = entry;
   outResult.sl = sl;
   outResult.tp = tp;
   outResult.resistance = localResistance;
   outResult.support = localSupport;

// Validate Entry/SL/TP bằng hàm chung
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   PriceValidationResult priceValidation;
   ValidatePriceConstraints(isBuySignal, entry, sl, tp,
                            config.minStopLoss, config.minTakeProfit, config.minRiskRewardRate,
                            pointValue, digits, priceValidation);

   if(!priceValidation.isValid)
     {
      outResult.reasons += StringFormat("- %s\n", priceValidation.reason);
      outResult.isCriticalFail = true;
      return;
     }
  }

// ==================================================
// ============== SCAN FOR SIGNAL ===================
// ==================================================

struct ScanResult
  {
   bool              found;
   bool              cancelled;
   int               confirmIdx;
   bool              isBuy;
   SignalResult      signal;
   string            cancelReason;
  };

//+------------------------------------------------------------------+
//| Scan for trading signal from a cut candle                        |
//+------------------------------------------------------------------+
void ScanForSignal(
   const SMAPullbackConfig &config,
   int cutIdx,
   bool cutUpToBottom,  // true = potential BUY, false = potential SELL
   string symbol,
   datetime currentTime,
   const double &open[],
   const double &high[],
   const double &low[],
   const double &close[],
   const double &sma50[],
   const double &sma200[],
   const double &rsi[],
   const double &macdMain[],
   const double &macdSignal[],
   const long &volume[],
   const double &adxMain[],
   const double &adxPlusDI[],
   const double &adxMinusDI[],
   double tickSize,
   double pointValue,
   int copyCount,
   ScanResult &outResult
)
  {
   outResult.found = false;
   outResult.cancelled = false;
   outResult.confirmIdx = -1;
   outResult.isBuy = cutUpToBottom;
   outResult.cancelReason = "";

// Vùng sideway: giá dao động quanh SMA +/- 1 ATR
   double emptyArr1[], emptyArr2[];
   double atr = CalculateATR(high, low, emptyArr1, emptyArr2, cutIdx, config.atrLength, copyCount, ATR_HIGH_LOW);
   if(atr <= 0)
      atr = 0.0001; // Fallback để tránh chia 0

   double sidewayUpper = sma50[cutIdx] + atr * 2;
   double sidewayLower = sma50[cutIdx] - atr * 2;

// Scan các nến sau nến cắt (Tương lai = index nhỏ hơn)
// Từ cutIdx-1 lùi về cutIdx - WaitBars
   int stopScanIdx = MathMax(1, cutIdx - config.maxWaitBars);

   for(int k = cutIdx - 1; k >= stopScanIdx; k--)
     {
      // Kiểm tra xem nến có vượt quá vùng sideway không
      if(close[k] < sidewayLower || close[k] > sidewayUpper)
        {
         outResult.cancelled = true;
         outResult.confirmIdx = k;
         outResult.cancelReason = StringFormat("Giá vượt Sideway: Close = %.5f, Lo = %.5f, Up = %.5f", close[k], sidewayLower, sidewayUpper);
         return;
        }

      if(cutUpToBottom)
        {
         // Đang theo dõi BUY - Nếu giá đóng cửa nến không trên SMA thì skip
         if(!IsGreaterThan(close[k], sma50[k], tickSize))
            continue;
        }
      else
        {
         // Đang theo dõi SELL - Nếu giá đóng cửa nến không dưới SMA thì skip
         if(!IsLessThan(close[k], sma50[k], tickSize))
            continue;
        }

      // Kiểm tra pattern
      string buyPatternName = DetectBuyPattern(k, cutIdx, open, high, low, close, sma50, config.wickBodyRatio);
      string sellPatternName = DetectSellPattern(k, cutIdx, open, high, low, close, sma50, config.wickBodyRatio);
      string patternName = "";

      if(cutUpToBottom)
        {
         // Đang theo dõi BUY nhưng phát hiện SELL pattern
         if(sellPatternName != "")
           {
            outResult.cancelled = true;
            outResult.confirmIdx = k;
            outResult.cancelReason = StringFormat("Gặp mô hình giảm: %s", sellPatternName);
            return;
           }
         patternName = buyPatternName;
        }
      else
        {
         // Đang theo dõi SELL nhưng phát hiện BUY pattern
         if(buyPatternName != "")
           {
            outResult.cancelled = true;
            outResult.confirmIdx = k;
            outResult.cancelReason = StringFormat("Gặp mô hình tăng: %s", buyPatternName);
            return;
           }
         patternName = sellPatternName;
        }

      if(patternName != "")
        {
         outResult.confirmIdx = k;

         // Tiến hành kiểm tra điều kiện signal
         SignalResult result;
         ProcessSignal(config, cutUpToBottom, cutIdx, k, symbol, currentTime,
                       open, high, low, close, sma50, sma200,
                       rsi, macdMain, macdSignal, volume,
                       adxMain, adxPlusDI, adxMinusDI,
                       tickSize, pointValue, result);

         if(!result.isCriticalFail)
           {
            outResult.found = true;
            outResult.signal = result;
            return;
           }
         // Nếu Critical Fail, continue loop để tiếp tục tìm pattern khác
        }
     }

// Quan trọng: Sau khi scan xong khoảng WaitBars
// Nếu đã tìm thấy signal -> Cấm tìm nến cắt mới trong vùng ảnh hưởng của signal này
// Nếu scan hết mà không thấy signal nào -> Vẫn cho phép tìm nến cắt mới (vì setup này coi như fail hoàn toàn)
// Chỉ đánh dấu cancel khi đã thực sự quét đủ số nến (maxWaitBars)
// Nếu chưa đủ nến để quét (ví dụ nến cắt vừa xuất hiện), thì không cancel, chờ thêm nến
   int actualBarsScanned = cutIdx - stopScanIdx; // Số nến thực sự đã quét

   if(!outResult.found && !outResult.cancelled)
     {
      // Chỉ cancel khi đã quét đủ số nến theo config
      if(actualBarsScanned >= config.maxWaitBars) // Số nến cần quét
        {
         outResult.cancelled = true;
         outResult.confirmIdx = stopScanIdx;
         outResult.cancelReason = "Không pattern";
        }
      // Nếu chưa đủ nến, không làm gì - pending cho lần scan tiếp theo
     }
  }

#endif // SMA_PULLBACK_CORE_H
