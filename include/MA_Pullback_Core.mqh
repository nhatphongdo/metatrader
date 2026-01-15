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
   bool              isCriticalFail;
   double            entry;
   double            sl;
   double            tp;
   double            resistance;
   double            support;
  };

struct SMAPullbackConfig
  {
   // Trade limits
   double            minStopLoss;       // Số points stoploss tối thiểu
   double            riskRewardRate;    // Tỷ lệ Reward / Risk

   // SMA parameters
   int               sma50Period;
   double            ma50SlopeThreshold; // Góc dốc MA50 tối thiểu (độ)
   int               sma200Period;

   // RSI / MACD
   int               rsiPeriod;
   int               macdSlow;
   int               macdFast;
   int               macdSignal;

   // Support/Resistance
   int               srLookback;
   double            srZonePercent;     // % vùng giá cho phép

   // Pullback
   int               maxWaitBars;
   int               atrLength;
   double            wickBodyRatio;

   // Noise Filter - Lọc vùng giá dao động quanh MA50
   int               minCutInterval;     // Số nến tối thiểu giữa 2 lần cắt MA50
   double            cutIntervalWeight;  // Trọng số điểm Cut Interval (default 10)
   int               maxCutsInLookback;  // Số lần cắt tối đa trong lookback (0 = tắt)
   double            maxCutsWeight;      // Trọng số điểm Max Cuts (default 10)
   int               cutsLookbackBars;   // Số nến lookback để đếm lần cắt
   int               slopeSmoothBars;    // Số nến để tính slope trung bình MA50
   double            peakMaDistanceThreshold; // Khoảng cách peak-MA tối thiểu (points) để lọc noise (0 = tắt)
   double            peakMADistWeight;        // Trọng số điểm Peak-MA Distance (default 10)

   // Filter: ADX Trend Strength
   bool              enableADXFilter;           // Bật/tắt ADX filter
   int               adxPeriod;                 // Chu kỳ ADX (thường = 14)
   double            minADXThreshold;           // Ngưỡng ADX tối thiểu (20-25 để xác định trending)
   bool              useADXDirectionalConfirm;  // true = kiểm tra +DI/-DI theo hướng signal

   // Filter: Body/ATR Ratio
   bool              enableBodyATRFilter;       // Bật/tắt Body/ATR filter
   double            minBodyATRRatio;           // Tỷ lệ body/ATR tối thiểu (0.3 = 30% ATR)

   // Filter: Volume Confirmation
   bool              enableVolumeFilter;        // Bật/tắt Volume filter
   int               volumeAvgPeriod;           // Chu kỳ tính volume trung bình
   double            minVolumeRatio;            // Tỷ lệ volume/avg volume tối thiểu (1.0 = 100%)

   // Filter: Price-MA Distance (tránh chase)
   bool              enablePriceMADistanceFilter; // Bật/tắt filter
   double            maxPriceMADistanceATR;       // Khoảng cách tối đa (bội số ATR, ví dụ 2.0 = 2*ATR)

   // Filter: Time/News Filter
   bool              enableTimeFilter;          // Bật/tắt Time filter
   int               tradeStartHour;            // Giờ bắt đầu được phép trade (0-23, server time)
   int               tradeEndHour;              // Giờ kết thúc được phép trade (0-23, server time)
   bool              enableNewsFilter;          // Bật/tắt News filter (MQL5 Calendar)
   int               newsMinutesBefore;         // Số phút trước tin quan trọng cần tránh
   int               newsMinutesAfter;          // Số phút sau tin quan trọng cần tránh
   int               newsMinImportance;         // Mức độ quan trọng tối thiểu (1=Low, 2=Medium, 3=High)

   // Filter: Consecutive Losses (chỉ dùng trong EA, không dùng trong Indicator)
   bool              enableConsecutiveLossFilter; // Bật/tắt filter
   int               maxConsecutiveLosses;        // Số lệnh thua liên tiếp trước khi tạm dừng
   int               pauseMinutesAfterLosses;     // Số phút tạm dừng sau chuỗi thua

   // Signal Scoring Filters (configurable weights)
   bool              enableMASlopeFilter;         // Bật/tắt MA Slope filter
   double            maSlopeWeight;               // Trọng số MA Slope (default 10)
   bool              enableMomentumFilter;        // Bật/tắt Momentum filter
   double            momentumWeight;              // Trọng số mỗi momentum indicator (default 30)
   bool              enableSMA200Filter;          // Bật/tắt SMA200 filter
   double            sma200Weight;                // Trọng số SMA200 (default 10)
   bool              enableSRZoneFilter;          // Bật/tắt S/R Zone filter
   double            srZoneWeight;                // Trọng số S/R Zone (default 20)
   double            adxWeight;                   // Trọng số ADX (default 10)
   double            bodyATRWeight;               // Trọng số Body/ATR (default 5)
   double            volumeWeight;                // Trọng số Volume (default 5)
   double            priceMADistWeight;           // Trọng số Price-MA Distance (default 5)
   double            timeWeight;                  // Trọng số Time (default 0 - không ảnh hưởng score)
   double            newsWeight;                  // Trọng số News (default 0 - không ảnh hưởng score)

   // Min score to pass
   double            minScoreToPass;              // Điểm tối thiểu để signal được chấp nhận (default 50)
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
   outResult.score = 0;
   outResult.reasons = "";
   outResult.isCriticalFail = false;
   outResult.strength = "NONE";

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

   outResult.score += maResult.totalScore;
   if(maResult.allReasons != "")
      outResult.reasons += maResult.allReasons;

// 2. Run Unified Filters (Slope, Momentum, S/R, Ext Filters)
   UnifiedScoringConfig uniConfig;

   uniConfig.enableMASlopeFilter = config.enableMASlopeFilter;
   uniConfig.maSlopeThreshold = config.ma50SlopeThreshold;
   uniConfig.slopeSmoothBars = config.slopeSmoothBars;
   uniConfig.maSlopeWeight = config.maSlopeWeight;

   uniConfig.enableMomentumFilter = config.enableMomentumFilter;
   uniConfig.momentumWeight = config.momentumWeight;

   uniConfig.enableSMA200Filter = config.enableSMA200Filter;
   uniConfig.sma200Weight = config.sma200Weight;

   uniConfig.enableSRZoneFilter = config.enableSRZoneFilter;
   uniConfig.srZonePercent = config.srZonePercent;
   uniConfig.srZoneWeight = config.srZoneWeight;
   uniConfig.srLookback = config.srLookback;

   uniConfig.enableADXFilter = config.enableADXFilter;
   uniConfig.minADXThreshold = config.minADXThreshold;
   uniConfig.useADXDirectionalConfirm = config.useADXDirectionalConfirm;
   uniConfig.adxWeight = config.adxWeight;

   uniConfig.enableBodyATRFilter = config.enableBodyATRFilter;
   uniConfig.minBodyATRRatio = config.minBodyATRRatio;
   uniConfig.atrLength = config.atrLength;
   uniConfig.bodyATRWeight = config.bodyATRWeight;

   uniConfig.enableVolumeFilter = config.enableVolumeFilter;
   uniConfig.volumeAvgPeriod = config.volumeAvgPeriod;
   uniConfig.minVolumeRatio = config.minVolumeRatio;
   uniConfig.volumeWeight = config.volumeWeight;

   uniConfig.enablePriceMADistFilter = config.enablePriceMADistanceFilter;
   uniConfig.maxPriceMADistATR = config.maxPriceMADistanceATR;
   uniConfig.priceMADistWeight = config.priceMADistWeight;

   uniConfig.enableTimeFilter = config.enableTimeFilter;
   uniConfig.tradeStartHour = config.tradeStartHour;
   uniConfig.tradeEndHour = config.tradeEndHour;
   uniConfig.timeWeight = config.timeWeight;

   uniConfig.enableNewsFilter = config.enableNewsFilter;
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

   outResult.score += scoringResult.totalScore;
   outResult.reasons += scoringResult.allReasons;

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
      sl = MathMin(MathMin(localSupport, sma50[confirmIdx]), sma200[confirmIdx]);
      risk = entry - sl;
     }
   else
     {
      sl = MathMax(MathMax(localResistance, sma50[confirmIdx]), sma200[confirmIdx]);
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
      tp = MathMin(entry + risk, localResistance);
      for(double j = 1.1; j <= config.riskRewardRate; j += 0.1)
        {
         const double _tp = entry + risk * j;
         if(_tp <= localResistance)
           {
            tp = _tp;
           }
        }
     }
   else
     {
      tp = MathMax(entry - risk, localSupport);
      for(double j = 1.1; j <= config.riskRewardRate; j += 0.1)
        {
         const double _tp = entry - risk * j;
         if(_tp >= localSupport)
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

// Kiểm tra StopLoss tối thiểu
   int slPoints = (int)(MathAbs(entry - sl) / pointValue);
   if(slPoints < config.minStopLoss)
     {
      outResult.reasons += StringFormat("- SL quá chật: %d pts\n", slPoints);
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
   double atr = 0;
   for(int j = cutIdx; j < cutIdx + config.atrLength && j < copyCount; j++)
      atr += high[j] - low[j];
   atr = atr / config.atrLength;

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
