//+------------------------------------------------------------------+
//|                                            MA Filters Module     |
//|                                    Copyright 2026, Do Nhat Phong |
//|                                   https://github.com/nhatphongdo |
//+------------------------------------------------------------------+
//| Module chứa các filter liên quan đến MA (Moving Average)         |
//| Kiểm tra vùng noise/choppy quanh MA50                            |
//| Mỗi filter có thể bật/tắt và có trọng số riêng                   |
//+------------------------------------------------------------------+
#property copyright "Do Nhat Phong"

#ifndef MA_FILTERS_H
#define MA_FILTERS_H

// Import types từ Filters.mqh để tái sử dụng
#include "Filters.mqh"
#include "Utility.mqh"

// ====================================================================
// ===================== CẤU HÌNH MA FILTERS ==========================
// ====================================================================
// Struct chứa cấu hình cho 3 MA-related filters
// Mỗi filter có: enable (bật/tắt), threshold (ngưỡng), weight (trọng số)

struct MAScoringConfig
  {
   // -----------------------------------------------------------------
   // FILTER 1: CUT INTERVAL (Khoảng cách giữa các lần cắt MA)
   // Kiểm tra khoảng cách tối thiểu giữa 2 lần cắt MA50
   // Nếu 2 lần cắt quá gần nhau = vùng choppy, nên tránh
   // -----------------------------------------------------------------
   bool              enableCutIntervalFilter;   // Bật/tắt filter
   int               minCutInterval;            // Số nến tối thiểu giữa 2 lần cắt
   int               cutsLookbackBars;          // Số nến lookback để tìm lần cắt trước
   double            cutIntervalWeight;         // Trọng số điểm (0-100)

   // -----------------------------------------------------------------
   // FILTER 2: PEAK-MA DISTANCE (Khoảng cách Peak-MA)
   // Kiểm tra khoảng cách giữa peak (high/low) và MA
   // Nếu peak quá gần MA = xu hướng yếu, nên tránh
   // BUY: Tìm highest high giữa 2 lần cắt, peak phải cao hơn MA nhiều
   // SELL: Tìm lowest low giữa 2 lần cắt, peak phải thấp hơn MA nhiều
   // -----------------------------------------------------------------
   bool              enablePeakMADistFilter;    // Bật/tắt filter
   double            peakMaDistanceThreshold;   // Ngưỡng khoảng cách tối thiểu (points)
   double            peakMADistWeight;          // Trọng số điểm (0-100)

   // -----------------------------------------------------------------
   // FILTER 3: MAX CUTS (Số lần cắt tối đa trong lookback)
   // Kiểm tra giá có cắt MA quá nhiều lần không
   // Nếu cắt quá nhiều = vùng sideway/choppy, nên tránh
   // -----------------------------------------------------------------
   bool              enableMaxCutsFilter;       // Bật/tắt filter
   int               maxCutsInLookback;         // Số lần cắt tối đa cho phép
   double            maxCutsWeight;             // Trọng số điểm (0-100)
  };

// ====================================================================
// ===================== KẾT QUẢ MA FILTERS ===========================
// ====================================================================

//+------------------------------------------------------------------+
//| Kết quả tổng hợp từ tất cả MA filters                            |
//+------------------------------------------------------------------+
struct MAScoringResult
  {
   double            successScore;     // Tổng điểm từ các filter PASS
   double            failScore;        // Tổng điểm từ các filter FAIL
   string            allReasons;       // Tất cả lý do fail (mỗi dòng 1 lý do)
   string            filterDetails;    // Chi tiết đánh giá TẤT CẢ filter (dù pass hay không)
   int               lastCutDistance;  // Khoảng cách đến lần cắt gần nhất (bars)
   double            peakMaDistance;   // Khoảng cách peak-MA (points)
   int               cutCount;         // Số lần cắt trong lookback
  };

//+------------------------------------------------------------------+
//| Count MA crosses in lookback period                              |
//| Đếm số lần giá cắt MA trong khoảng lookback                      |
//+------------------------------------------------------------------+
int CountMACrosses(
   int startIdx,
   int lookbackBars,
   const double &open[],
   const double &close[],
   const double &ma[],
   double tickSize,
   int arraySize
)
  {
   int cutCount = 0;
   int endIdx = startIdx + lookbackBars;
   if(endIdx >= arraySize)
      endIdx = arraySize - 1;

   for(int i = startIdx; i < endIdx; i++)
     {
      // Check if candle crosses MA (either direction)
      bool cutUpToBottom = IsGreaterThan(open[i], ma[i], tickSize) && IsLessThan(close[i], ma[i], tickSize);
      bool cutDownToTop = IsLessThan(open[i], ma[i], tickSize) && IsGreaterThan(close[i], ma[i], tickSize);

      if(cutUpToBottom || cutDownToTop)
         cutCount++;
     }

   return cutCount;
  }

//+------------------------------------------------------------------+
//| Find distance to the last MA cross before startIdx               |
//| Tìm khoảng cách đến lần cắt MA gần nhất                          |
//| Returns: số nến kể từ lần cắt gần nhất, hoặc -1 nếu không tìm thấy|
//+------------------------------------------------------------------+
int FindLastMACutDistance(
   int startIdx,
   int maxLookback,
   const double &open[],
   const double &close[],
   const double &ma[],
   double tickSize,
   int arraySize
)
  {
   int endIdx = startIdx + maxLookback;
   if(endIdx >= arraySize)
      endIdx = arraySize - 1;

   for(int i = startIdx + 1; i < endIdx; i++)
     {
      bool cutUpToBottom = IsGreaterThan(open[i], ma[i], tickSize) && IsLessThan(close[i], ma[i], tickSize);
      bool cutDownToTop = IsLessThan(open[i], ma[i], tickSize) && IsGreaterThan(close[i], ma[i], tickSize);

      if(cutUpToBottom || cutDownToTop)
         return i - startIdx;
     }

   return -1; // No previous cut found
  }

// ====================================================================
// ================= CÁC FILTER FUNCTIONS =============================
// ====================================================================
// Mỗi filter function nhận config và data, trả về ScoringFilterResult
// Nếu filter bị tắt (enable = false) sẽ trả về passed = true, score = 0

//+------------------------------------------------------------------+
//| FILTER 1: CUT INTERVAL                                           |
//| Kiểm tra khoảng cách giữa 2 lần cắt MA có đủ xa không            |
//| Nếu 2 lần cắt quá gần nhau = vùng choppy, signal yếu             |
//+------------------------------------------------------------------+
ScoringFilterResult CheckCutIntervalFilter(
   const MAScoringConfig &config,
   int cutIdx,
   const double &open[],
   const double &close[],
   const double &ma[],
   double tickSize,
   int arraySize,
   int &outLastCutDistance  // Output: khoảng cách đến lần cắt trước
)
  {
   ScoringFilterResult result;
   result.passed = false;
   result.score = 0;
   result.reason = "";
   result.value = 0;

// Tìm khoảng cách đến lần cắt trước (luôn tính để các filter khác dùng)
   int lookback = config.cutsLookbackBars > 0 ? config.cutsLookbackBars : 50;
   outLastCutDistance = FindLastMACutDistance(cutIdx, lookback, open, close, ma, tickSize, arraySize);
   result.value = outLastCutDistance;

// Nếu filter tắt, tự động pass nhưng không cộng điểm
   if(!config.enableCutIntervalFilter)
     {
      result.passed = true;
      return result;
     }

// Nếu không tìm thấy lần cắt trước = signal mạnh (cắt lần đầu)
   if(outLastCutDistance <= 0)
     {
      result.passed = true;
      result.score = config.cutIntervalWeight;
      return result;
     }

// Kiểm tra khoảng cách có đủ xa không
   if(outLastCutDistance >= config.minCutInterval)
     {
      result.passed = true;
      result.score = config.cutIntervalWeight;
     }
   else
     {
      result.reason = StringFormat("Lần cắt trước quá gần (%d nến < yêu cầu %d nến)",
                                   outLastCutDistance, config.minCutInterval);
     }

   return result;
  }

//+------------------------------------------------------------------+
//| FILTER 2: PEAK-MA DISTANCE                                       |
//| Kiểm tra khoảng cách giữa peak và MA giữa 2 lần cắt              |
//| BUY: Peak (highest high) phải cao hơn MA đủ nhiều                |
//| SELL: Peak (lowest low) phải thấp hơn MA đủ nhiều                |
//+------------------------------------------------------------------+
ScoringFilterResult CheckPeakMADistanceFilter(
   const MAScoringConfig &config,
   bool isBuySignal,
   int cutIdx,
   int lastCutDistance,  // Từ filter 1
   const double &high[],
   const double &low[],
   const double &ma[],
   double pointValue,
   int arraySize,
   double &outPeakMaDistance  // Output: khoảng cách peak-MA tính được
)
  {
   ScoringFilterResult result;
   result.passed = false;
   result.score = 0;
   result.reason = "";
   result.value = 0;
   outPeakMaDistance = 0;

// Nếu filter tắt, tự động pass nhưng không cộng điểm
   if(!config.enablePeakMADistFilter)
     {
      result.passed = true;
      return result;
     }

// Cần có lastCutDistance để tính peak
   if(lastCutDistance <= 0)
     {
      // Không có lần cắt trước, không thể tính peak -> pass với điểm cao
      result.passed = true;
      result.score = config.peakMADistWeight;
      return result;
     }

// Tìm peak giữa cutIdx và điểm cắt trước đó
// Với ArraySetAsSeries=true: index lớn = quá khứ
   int prevCutIdx = cutIdx + lastCutDistance;
   if(prevCutIdx >= arraySize)
     {
      result.passed = true;
      result.score = config.peakMADistWeight;
      return result;
     }

   double peakPrice = 0;
   double peakMa = 0;
   int peakIdx = cutIdx;

   if(isBuySignal)
     {
      // BUY signal: tìm giá cao nhất (highest high)
      double highestPrice = high[cutIdx];
      for(int i = cutIdx + 1; i <= prevCutIdx && i < arraySize; i++)
        {
         if(high[i] > highestPrice)
           {
            highestPrice = high[i];
            peakIdx = i;
           }
        }
      peakPrice = highestPrice;
      peakMa = ma[peakIdx];
      // Khoảng cách peak - MA (peak phải cao hơn MA cho BUY)
      outPeakMaDistance = (peakPrice - peakMa) / pointValue;
     }
   else
     {
      // SELL signal: tìm giá thấp nhất (lowest low)
      double lowestPrice = low[cutIdx];
      for(int i = cutIdx + 1; i <= prevCutIdx && i < arraySize; i++)
        {
         if(low[i] < lowestPrice)
           {
            lowestPrice = low[i];
            peakIdx = i;
           }
        }
      peakPrice = lowestPrice;
      peakMa = ma[peakIdx];
      // Khoảng cách MA - peak (MA phải cao hơn peak cho SELL)
      outPeakMaDistance = (peakMa - peakPrice) / pointValue;
     }

   result.value = outPeakMaDistance;

// Check threshold
   if(outPeakMaDistance >= config.peakMaDistanceThreshold)
     {
      result.passed = true;
      result.score = config.peakMADistWeight;
     }
   else
     {
      result.reason = StringFormat("Peak-MA quá gần (%.1f points < %.1f points, %s tại nến #%d)",
                                   outPeakMaDistance, config.peakMaDistanceThreshold,
                                   isBuySignal ? "High" : "Low", peakIdx - cutIdx);
     }

   return result;
  }

//+------------------------------------------------------------------+
//| FILTER 3: MAX CUTS                                               |
//| Kiểm tra số lần cắt MA trong lookback có quá nhiều không         |
//| Quá nhiều lần cắt = vùng choppy/sideway                          |
//+------------------------------------------------------------------+
ScoringFilterResult CheckMaxCutsFilter(
   const MAScoringConfig &config,
   int cutIdx,
   const double &open[],
   const double &close[],
   const double &ma[],
   double tickSize,
   int arraySize,
   int &outCutCount  // Output: số lần cắt đếm được
)
  {
   ScoringFilterResult result;
   result.passed = false;
   result.score = 0;
   result.reason = "";
   result.value = 0;
   outCutCount = 0;

// Nếu filter tắt, tự động pass nhưng không cộng điểm
   if(!config.enableMaxCutsFilter)
     {
      result.passed = true;
      return result;
     }

// Đếm số lần cắt trong lookback
   outCutCount = CountMACrosses(cutIdx, config.cutsLookbackBars, open, close, ma, tickSize, arraySize);
   result.value = outCutCount;

   if(outCutCount <= config.maxCutsInLookback)
     {
      result.passed = true;
      result.score = config.maxCutsWeight;
     }
   else
     {
      result.reason = StringFormat("Quá nhiều lần cắt MA (%d lần trong %d nến, tối đa cho phép %d)",
                                   outCutCount, config.cutsLookbackBars, config.maxCutsInLookback);
     }

   return result;
  }

// ====================================================================
// ================== HÀM CHẠY TẤT CẢ MA FILTERS ======================
// ====================================================================

//+------------------------------------------------------------------+
//| Chạy tất cả 3 MA filters và tính tổng điểm                       |
//| Trả về MAScoringResult chứa totalScore, reasons, metrics         |
//+------------------------------------------------------------------+
void RunMAFilters(
   const MAScoringConfig &config,
   bool isBuySignal,
   int cutIdx,
   const double &open[],
   const double &high[],
   const double &low[],
   const double &close[],
   const double &ma[],
   double tickSize,
   double pointValue,
   int arraySize,
   MAScoringResult &outResult
)
  {
// Khởi tạo kết quả
   outResult.successScore = 0;
   outResult.failScore = 0;
   outResult.allReasons = "";
   outResult.filterDetails = "";
   outResult.lastCutDistance = -1;
   outResult.peakMaDistance = 0;
   outResult.cutCount = 0;

   ScoringFilterResult filterResult;
   string statusStr;
   double penalty;

// -----------------------------------------------------------------
// FILTER 1: CUT INTERVAL
// -----------------------------------------------------------------
   int lastCutDistance = -1;
   filterResult = CheckCutIntervalFilter(config, cutIdx, open, close, ma, tickSize, arraySize, lastCutDistance);
   outResult.lastCutDistance = lastCutDistance;
   if(filterResult.passed)
      outResult.successScore += config.cutIntervalWeight;
   else
      outResult.failScore += config.cutIntervalWeight;
   statusStr = filterResult.passed ? "✓" : "✗";
   penalty = filterResult.passed ? 0 : config.cutIntervalWeight;
   outResult.filterDetails += StringFormat("[MA-1] Cut Interval %s: %d bars (min=%d) | -%.0f pts\n",
                                           statusStr, lastCutDistance, config.minCutInterval, penalty);
   if(!filterResult.passed && filterResult.reason != "")
     {
      outResult.allReasons += "- " + filterResult.reason + "\n";
     }

// -----------------------------------------------------------------
// FILTER 2: PEAK-MA DISTANCE
// -----------------------------------------------------------------
   double peakMaDistance = 0;
   filterResult = CheckPeakMADistanceFilter(config, isBuySignal, cutIdx, lastCutDistance,
                  high, low, ma, pointValue, arraySize, peakMaDistance);
   outResult.peakMaDistance = peakMaDistance;
   if(filterResult.passed)
      outResult.successScore += config.peakMADistWeight;
   else
      outResult.failScore += config.peakMADistWeight;
   statusStr = filterResult.passed ? "✓" : "✗";
   penalty = filterResult.passed ? 0 : config.peakMADistWeight;
   outResult.filterDetails += StringFormat("[MA-2] Peak-MA %s: %.1f pts (min=%.1f) | -%.0f pts\n",
                                           statusStr, peakMaDistance, config.peakMaDistanceThreshold, penalty);
   if(!filterResult.passed && filterResult.reason != "")
     {
      outResult.allReasons += "- " + filterResult.reason + "\n";
     }

// -----------------------------------------------------------------
// FILTER 3: MAX CUTS
// -----------------------------------------------------------------
   int cutCount = 0;
   filterResult = CheckMaxCutsFilter(config, cutIdx, open, close, ma, tickSize, arraySize, cutCount);
   outResult.cutCount = cutCount;
   if(filterResult.passed)
      outResult.successScore += config.maxCutsWeight;
   else
      outResult.failScore += config.maxCutsWeight;
   statusStr = filterResult.passed ? "✓" : "✗";
   penalty = filterResult.passed ? 0 : config.maxCutsWeight;
   outResult.filterDetails += StringFormat("[MA-3] Max Cuts %s: %d (max=%d) | -%.0f pts\n",
                                           statusStr, cutCount, config.maxCutsInLookback, penalty);
   if(!filterResult.passed && filterResult.reason != "")
     {
      outResult.allReasons += "- " + filterResult.reason + "\n";
     }
  }

#endif // MA_FILTERS_H
