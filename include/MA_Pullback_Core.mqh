//+------------------------------------------------------------------+
//|                                          MA Pullback Core Logic  |
//|                                    Copyright 2026, Do Nhat Phong |
//|                                   https://github.com/nhatphongdo |
//+------------------------------------------------------------------+
#property copyright "Do Nhat Phong"

#ifndef MA_PULLBACK_CORE_H
#define MA_PULLBACK_CORE_H

// Include reusable modules
#include "Filters.mqh"
#include "Utility.mqh"
#include "CandlePatterns.mqh"

// ==================================================
// =================== STRUCTS ======================
// ==================================================

struct SignalResult
{
   double score;
   string strength;       // WEAK, MEDIUM, STRONG
   string reasons;        // List of reasons separated by newline
   string filterDetails;  // Chi tiết đánh giá TẤT CẢ filter (dù pass hay không)
   bool isCriticalFail;
   double entry;
   double sl;
   double tp;
   double resistance;
   double support;
};

struct SMAPullbackConfig
{
   // ==============================================================
   // TRADE LIMITS & CORE SETTINGS
   // ==============================================================
   double minStopLoss;        // Số points stoploss tối thiểu
   double minTakeProfit;      // Số points takeprofit tối thiểu
   double maxRiskRewardRate;  // Tỷ lệ Reward / Risk tối đa
   double minRiskRewardRate;  // Tỷ lệ Reward / Risk tối thiểu (0=none)
   double srBufferPercent;    // Buffer (%) cộng thêm vào S/R khi tính SL/TP
   double minScoreToPass;     // Điểm tối thiểu để signal được chấp nhận

   // ==============================================================
   // STRATEGY PARAMETERS
   // ==============================================================
   int minTrendBars;        // Số nến tối thiểu để hình thành trend trước khi đảo chiều
   double sidewayATRRatio;  // Tỷ lệ vùng sideway 2 bên MA theo ATR
   int maxWaitBars;         // Số nến tối đa chờ pullback
   int srLookback;          // Số nến để kiểm tra S/R Zone

   // ==============================================================
   // FILTER: MA SLOPE
   // Kiểm tra độ dốc MA có đủ mạnh không
   // ==============================================================
   bool enableMASlopeFilter;  // Bật/tắt MA Slope filter
   bool maSlopeCritical;      // Nếu true, fail = critical fail
   double maSlopeThreshold;   // Góc dốc MA Fast tối thiểu
   double maSlopeWeight;      // Trọng số của MA Slope filter

   // ==============================================================
   // FILTER: RSI MOMENTUM
   // Kiểm tra RSI có xác nhận xu hướng không
   // ==============================================================
   bool enableRSIMomentumFilter;  // Bật/tắt RSI Momentum filter
   bool rsiMomentumCritical;      // Nếu true, fail = critical fail
   double rsiMomentumWeight;      // Trọng số của RSI Momentum filter

   // ==============================================================
   // FILTER: MACD MOMENTUM
   // Kiểm tra MACD có xác nhận xu hướng không
   // ==============================================================
   bool enableMACDMomentumFilter;  // Bật/tắt MACD Momentum filter
   bool macdMomentumCritical;      // Nếu true, fail = critical fail
   double macdMomentumWeight;      // Trọng số của MACD Momentum filter

   // ==============================================================
   // FILTER: RSI REVERSAL DETECTION
   // Phát hiện RSI đang đi ngược hướng signal (đảo chiều sớm)
   // ==============================================================
   bool enableRSIReversalFilter;  // Bật/tắt RSI Reversal filter
   bool rsiReversalCritical;      // Nếu true, fail = critical fail
   int rsiReversalLookback;       // Số nến để kiểm tra RSI reversal
   double rsiReversalWeight;      // Trọng số của RSI Reversal filter

   // ==============================================================
   // FILTER: MACD HISTOGRAM TREND
   // Phát hiện histogram đang mở rộng ngược hướng signal
   // ==============================================================
   bool enableMACDHistogramFilter;  // Bật/tắt MACD Histogram filter
   bool macdHistogramCritical;      // Nếu true, fail = critical fail
   int macdHistogramLookback;       // Số nến để kiểm tra MACD histogram
   double macdHistogramWeight;      // Trọng số của MACD Histogram filter

   // ==============================================================
   // FILTER: SMA200 TREND
   // Kiểm tra giá có cùng xu hướng với SMA200 không
   // ==============================================================
   bool enableSMA200Filter;  // Bật/tắt SMA200 filter
   bool sma200Critical;      // Nếu true, fail = critical fail
   double sma200Weight;      // Trọng số của SMA Slow filter

   // ==============================================================
   // FILTER: S/R ZONE
   // Kiểm tra giá có trong vùng entry tốt không (% từ S đến R)
   // ==============================================================
   bool enableSRZoneFilter;  // Bật/tắt S/R Zone filter
   bool srZoneCritical;      // Nếu true, fail = critical fail
   double srZonePercent;     // % vùng giá cho phép
   double srZoneWeight;      // Trọng số của S/R Zone filter

   // ==============================================================
   // FILTER: S/R MIN WIDTH
   // Lọc vùng S/R quá hẹp (không đủ room cho SL/TP)
   // ==============================================================
   bool enableSRMinWidthFilter;  // Bật/tắt filter độ rộng S/R tối thiểu
   bool srMinWidthCritical;      // Nếu true, fail = critical fail
   double minSRWidthATR;         // Độ rộng tối thiểu (bội số ATR)
   double srMinWidthWeight;      // Trọng số của S/R Min Width filter

   // ==============================================================
   // FILTER: ADX TREND STRENGTH
   // Kiểm tra thị trường có đang trending không
   // ==============================================================
   bool enableADXFilter;           // Bật/tắt ADX filter
   bool adxCritical;               // Nếu true, fail = critical fail
   double minADXThreshold;         // Ngưỡng ADX tối thiểu (20-25 để xác định trending)
   bool useADXDirectionalConfirm;  // Nếu true, ADX phải cùng hướng với signal
   double adxWeight;               // Trọng số của ADX filter

   // ==============================================================
   // FILTER: BODY/ATR RATIO
   // Kiểm tra nến confirm có đủ mạnh không
   // ==============================================================
   bool enableBodyATRFilter;  // Bật/tắt Body/ATR filter
   bool bodyATRCritical;      // Nếu true, fail = critical fail
   double minBodyATRRatio;    // Tỷ lệ body/ATR tối thiểu (0.2-0.5 = 20-50% ATR)
   double bodyATRWeight;      // Trọng số của Body/ATR filter

   // ==============================================================
   // FILTER: VOLUME CONFIRMATION
   // Kiểm tra volume có đủ so với trung bình không
   // ==============================================================
   bool enableVolumeFilter;  // Bật/tắt Volume filter
   bool volumeCritical;      // Nếu true, fail = critical fail
   int volumeAvgPeriod;      // Số nến để tính volume trung bình
   double minVolumeRatio;    // Tỷ lệ volume tối thiểu so với trung bình (1.5 = 150%)
   double volumeWeight;      // Trọng số của Volume filter

   // ==============================================================
   // FILTER: PRICE-MA DISTANCE
   // Tránh chase - giá không quá xa MA50
   // ==============================================================
   bool enablePriceMADistanceFilter;  // Bật/tắt Price-MA Distance filter
   bool priceMADistCritical;          // Nếu true, fail = critical fail
   double maxPriceMADistanceATR;      // Khoảng cách giá-MA tối đa (bội số ATR, ví dụ 2.0 = 2*ATR)
   double priceMADistWeight;          // Trọng số của Price-MA Distance filter

   // ==============================================================
   // FILTER: TIME CONTROL (EA only)
   // Chỉ trade trong giờ tốt
   // ==============================================================
   bool enableTimeFilter;  // Bật/tắt Time filter
   bool timeCritical;      // Nếu true, fail = critical fail
   int tradeStartHour;     // Giờ bắt đầu trade (0-23, server time)
   int tradeEndHour;       // Giờ kết thúc trade (0-23, server time)
   double timeWeight;      // Trọng số của Time filter

   // ==============================================================
   // FILTER: NEWS FILTER (EA only)
   // Tránh trade gần tin quan trọng
   // ==============================================================
   bool enableNewsFilter;  // Bật/tắt News filter
   bool newsCritical;      // Nếu true, fail = critical fail
   int newsMinutesBefore;  // Số phút trước tin để dừng trade
   int newsMinutesAfter;   // Số phút sau tin để dừng trade
   int newsMinImportance;  // Mức độ quan trọng tối thiểu của tin (1=Low, 2=Medium, 3=High)
   double newsWeight;      // Trọng số của News filter
};

// ==================================================
// ============= PROCESS SIGNAL =====================
// ==================================================

//+------------------------------------------------------------------+
//| Xử lý signal khi tìm được pattern hoàn chỉnh                     |
//| Kiểm tra điều kiện của signal dựa theo cấu hình                  |
//+------------------------------------------------------------------+
void ProcessSignal(const SMAPullbackConfig& config, bool isBuySignal, int cutIdx, int confirmIdx, string symbol,
                   datetime currentTime, const double& open[], const double& high[], const double& low[],
                   const double& close[], const double& sma50[], const double& sma200[], const double& rsi[],
                   const double& macdMain[], const double& macdSignal[], const long& volume[], const double& adxMain[],
                   const double& adxPlusDI[], const double& adxMinusDI[], const double& atr[], int arraySize,
                   double tickSize, double pointValue, SignalResult& outResult)
{
   outResult.score = 100;  // Bắt đầu với 100, sẽ trừ dần bằng failScore
   outResult.reasons = "";
   outResult.filterDetails = "";
   outResult.isCriticalFail = false;
   outResult.strength = "NONE";

   CalculateSupportResistance(high, low, arraySize, confirmIdx, config.srLookback, outResult.support,
                              outResult.resistance);
   if (outResult.support < 0 || outResult.resistance < 0 || outResult.support > outResult.resistance)
   {
      outResult.isCriticalFail = true;
      outResult.reasons += "- S/R Zone không hợp lệ\n";
      outResult.score = 0;
      return;
   }

   ScoringFilterResult filterResult;

   // Kiểm tra MA Slope
   if (config.enableMASlopeFilter)
   {
      filterResult = CheckMASlope(confirmIdx, sma50, arraySize, config.maSlopeThreshold, cutIdx - confirmIdx + 1,
                                  config.maSlopeWeight);
      if (!filterResult.passed)
      {
         outResult.score += filterResult.score;
         if (filterResult.reason != "")
            outResult.reasons += "- " + filterResult.reason + "\n";
         outResult.isCriticalFail = outResult.isCriticalFail || config.maSlopeCritical;
      }
      outResult.filterDetails += StringFormat("- [%s] MA Slope: %.5f (th=%.5f)\n", filterResult.passed ? "✓" : "✗",
                                              filterResult.value, config.maSlopeThreshold);
   }

   // Kiểm tra RSI Momentum
   if (config.enableRSIMomentumFilter)
   {
      filterResult = CheckRSIMomentum(isBuySignal, confirmIdx, rsi, config.rsiMomentumWeight);
      if (!filterResult.passed)
      {
         outResult.score += filterResult.score;
         if (filterResult.reason != "")
            outResult.reasons += "- " + filterResult.reason + "\n";
         outResult.isCriticalFail = outResult.isCriticalFail || config.rsiMomentumCritical;
      }
      outResult.filterDetails +=
          StringFormat("- [%s] RSI Momentum: %.2f\n", filterResult.passed ? "✓" : "✗", filterResult.value);
   }

   // Kiểm tra MACD Momentum
   if (config.enableMACDMomentumFilter)
   {
      filterResult = CheckMACDMomentum(isBuySignal, confirmIdx, macdMain, macdSignal, config.macdMomentumWeight);
      if (!filterResult.passed)
      {
         outResult.score += filterResult.score;
         if (filterResult.reason != "")
            outResult.reasons += "- " + filterResult.reason + "\n";
         outResult.isCriticalFail = outResult.isCriticalFail || config.macdMomentumCritical;
      }
      outResult.filterDetails +=
          StringFormat("- [%s] MACD Momentum: %.4f\n", filterResult.passed ? "✓" : "✗", filterResult.value);
   }

   // Kiểm tra RSI Reversal
   if (config.enableRSIReversalFilter)
   {
      filterResult = CheckRSIReversal(isBuySignal, confirmIdx, rsi, arraySize, config.rsiReversalLookback,
                                      config.rsiReversalWeight);
      if (!filterResult.passed)
      {
         outResult.score += filterResult.score;
         if (filterResult.reason != "")
            outResult.reasons += "- " + filterResult.reason + "\n";
         outResult.isCriticalFail = outResult.isCriticalFail || config.rsiReversalCritical;
      }
      outResult.filterDetails +=
          StringFormat("- [%s] RSI Reversal: delta=%.1f\n", filterResult.passed ? "✓" : "✗", filterResult.value);
   }

   // Kiểm tra MACD Histogram
   if (config.enableMACDHistogramFilter)
   {
      filterResult = CheckMACDHistogram(isBuySignal, confirmIdx, macdMain, macdSignal, arraySize,
                                        config.macdHistogramLookback, config.macdHistogramWeight);
      if (!filterResult.passed)
      {
         outResult.score += filterResult.score;
         if (filterResult.reason != "")
            outResult.reasons += "- " + filterResult.reason + "\n";
         outResult.isCriticalFail = outResult.isCriticalFail || config.macdHistogramCritical;
      }
      outResult.filterDetails +=
          StringFormat("- [%s] MACD Histogram: delta=%.5f\n", filterResult.passed ? "✓" : "✗", filterResult.value);
   }

   // Kiểm tra MA200 trend
   if (config.enableSMA200Filter)
   {
      filterResult = CheckMATrend(isBuySignal, confirmIdx, close, sma200, tickSize, config.sma200Weight);
      if (!filterResult.passed)
      {
         outResult.score += filterResult.score;
         if (filterResult.reason != "")
            outResult.reasons += "- " + filterResult.reason + "\n";
         outResult.isCriticalFail = outResult.isCriticalFail || config.sma200Critical;
      }
      outResult.filterDetails +=
          StringFormat("- [%s] MA Slow Trend: diff=%.5f\n", filterResult.passed ? "✓" : "✗", filterResult.value);
   }

   // Kiểm tra vùng S/R
   if (config.enableSRZoneFilter)
   {
      filterResult = CheckSRZone(isBuySignal, confirmIdx, close, outResult.support, outResult.resistance,
                                 config.srZonePercent, config.srZoneWeight);
      if (!filterResult.passed)
      {
         outResult.score += filterResult.score;
         if (filterResult.reason != "")
            outResult.reasons += "- " + filterResult.reason + "\n";
         outResult.isCriticalFail = outResult.isCriticalFail || config.srZoneCritical;
      }
      outResult.filterDetails +=
          StringFormat("- [%s] S/R Zone: S=%.5f, R=%.5f, lim=%.5f\n", filterResult.passed ? "✓" : "✗",
                       outResult.support, outResult.resistance, filterResult.value);
   }

   // Kiểm tra min width vùng S/R
   if (config.enableSRMinWidthFilter)
   {
      filterResult = CheckSRMinWidth(confirmIdx, atr, outResult.support, outResult.resistance, config.minSRWidthATR,
                                     config.srMinWidthWeight);
      if (!filterResult.passed)
      {
         outResult.score += filterResult.score;
         if (filterResult.reason != "")
            outResult.reasons += "- " + filterResult.reason + "\n";
         outResult.isCriticalFail = outResult.isCriticalFail || config.srMinWidthCritical;
      }
      outResult.filterDetails +=
          StringFormat("- [%s] S/R Width: %.1f ATR (min=%.1f)\n", filterResult.passed ? "✓" : "✗", filterResult.value,
                       config.minSRWidthATR);
   }

   // Kiểm tra ADX
   if (config.enableADXFilter)
   {
      filterResult = CheckADX(isBuySignal, confirmIdx, adxMain, adxPlusDI, adxMinusDI, config.minADXThreshold,
                              config.useADXDirectionalConfirm, config.adxWeight);
      if (!filterResult.passed)
      {
         outResult.score += filterResult.score;
         if (filterResult.reason != "")
            outResult.reasons += "- " + filterResult.reason + "\n";
         outResult.isCriticalFail = outResult.isCriticalFail || config.adxCritical;
      }
      outResult.filterDetails +=
          StringFormat("- [%s] ADX: %.1f (+DI=%.1f, -DI=%.1f)\n", filterResult.passed ? "✓" : "✗", adxMain[confirmIdx],
                       adxPlusDI[confirmIdx], adxMinusDI[confirmIdx]);
   }

   // Kiểm tra tỷ lệ body / ATR
   if (config.enableBodyATRFilter)
   {
      filterResult =
          CheckBodyATR(isBuySignal, confirmIdx, open, close, atr, config.minBodyATRRatio, config.bodyATRWeight);
      if (!filterResult.passed)
      {
         outResult.score += filterResult.score;
         if (filterResult.reason != "")
            outResult.reasons += "- " + filterResult.reason + "\n";
         outResult.isCriticalFail = outResult.isCriticalFail || config.bodyATRCritical;
      }
      outResult.filterDetails += StringFormat("- [%s] Body/ATR: %.3f (min=%.3f)\n", filterResult.passed ? "✓" : "✗",
                                              filterResult.value, config.minBodyATRRatio);
   }

   // Kiểm tra volume
   if (config.enableVolumeFilter)
   {
      filterResult = CheckVolume(confirmIdx, volume, arraySize, config.volumeAvgPeriod, config.minVolumeRatio,
                                 config.volumeWeight);
      if (!filterResult.passed)
      {
         outResult.score += filterResult.score;
         if (filterResult.reason != "")
            outResult.reasons += "- " + filterResult.reason + "\n";
         outResult.isCriticalFail = outResult.isCriticalFail || config.volumeCritical;
      }
      outResult.filterDetails += StringFormat("- [%s] Volume: %.2fx (min=%.2fx)\n", filterResult.passed ? "✓" : "✗",
                                              filterResult.value, config.minVolumeRatio);
   }

   // Kiểm tra chênh lệch giá và MA
   if (config.enablePriceMADistanceFilter)
   {
      filterResult = CheckPriceMADist(confirmIdx, close, sma50, atr, arraySize, config.maxPriceMADistanceATR,
                                      config.priceMADistWeight);
      if (!filterResult.passed)
      {
         outResult.score += filterResult.score;
         if (filterResult.reason != "")
            outResult.reasons += "- " + filterResult.reason + "\n";
         outResult.isCriticalFail = outResult.isCriticalFail || config.priceMADistCritical;
      }
      outResult.filterDetails += StringFormat("- [%s] Price-MA: %.2f ATR (max=%.2f)\n", filterResult.passed ? "✓" : "✗",
                                              filterResult.value, config.maxPriceMADistanceATR);
   }

   // Kiểm tra time
   if (config.enableTimeFilter)
   {
      filterResult = CheckTime(currentTime, config.tradeStartHour, config.tradeEndHour, config.timeWeight);
      if (!filterResult.passed)
      {
         outResult.score += filterResult.score;
         if (filterResult.reason != "")
            outResult.reasons += "- " + filterResult.reason + "\n";
         outResult.isCriticalFail = outResult.isCriticalFail || config.timeCritical;
      }
      outResult.filterDetails += StringFormat("- [%s] Time: hour=%.0f (%d-%d)\n", filterResult.passed ? "✓" : "✗",
                                              filterResult.value, config.tradeStartHour, config.tradeEndHour);
   }

   // Kiểm tra tin tức
   if (config.enableNewsFilter)
   {
      filterResult = CheckNews(symbol, currentTime, config.newsMinutesBefore, config.newsMinutesAfter,
                               config.newsMinImportance, config.newsWeight);
      if (!filterResult.passed)
      {
         outResult.score += filterResult.score;
         if (filterResult.reason != "")
            outResult.reasons += "- " + filterResult.reason + "\n";
         outResult.isCriticalFail = outResult.isCriticalFail || config.newsCritical;
      }
      outResult.filterDetails +=
          StringFormat("- [%s] News: %d-%d min before/after, importance=%d\n", filterResult.passed ? "✓" : "✗",
                       config.newsMinutesBefore, config.newsMinutesAfter, config.newsMinImportance);
   }

   // Check if passed min score threshold
   if (outResult.score < config.minScoreToPass)
   {
      outResult.reasons += StringFormat("- Điểm thấp (%.0f < %.0f)\n", outResult.score, config.minScoreToPass);
      outResult.isCriticalFail = true;
      return;
   }

   // Xác định mức độ mạnh yếu
   if (outResult.score >= 70)
      outResult.strength = "STRONG";
   else if (outResult.score >= 50)
      outResult.strength = "MEDIUM";
   else if (outResult.score >= 20)
      outResult.strength = "WEAK";
   else
      outResult.strength = "NONE";

   // Kiểm tra giá vào lệnh và stoploss
   double entry = close[confirmIdx];
   double sl, risk, tp;

   if (isBuySignal)
   {
      // BUY: SL dưới support - trừ thêm buffer % để an toàn hơn
      double baseSupport = MathMin(MathMin(outResult.support, sma50[confirmIdx]), sma200[confirmIdx]);
      double srBuffer = (entry - baseSupport) * config.srBufferPercent / 100.0;
      sl = baseSupport - srBuffer;
      risk = entry - sl;
   }
   else
   {
      // SELL: SL trên resistance - cộng thêm buffer % để an toàn hơn
      double baseResistance = MathMax(MathMax(outResult.resistance, sma50[confirmIdx]), sma200[confirmIdx]);
      double srBuffer = (baseResistance - entry) * config.srBufferPercent / 100.0;
      sl = baseResistance + srBuffer;
      risk = sl - entry;
   }

   if (risk <= 0)
   {
      if (isBuySignal)
      {
         outResult.reasons += StringFormat("- Lỗi Entry < SL: Entry = %.5f, SL = %.5f\n", entry, sl);
      }
      else
      {
         outResult.reasons += StringFormat("- Lỗi SL < Entry: Entry = %.5f, SL = %.5f\n", entry, sl);
      }
   }

   if (isBuySignal)
   {
      // BUY: TP dưới resistance - trừ buffer % để an toàn hơn
      double tpBuffer = (outResult.resistance - entry) * config.srBufferPercent / 100.0;
      double tpResistance = outResult.resistance - tpBuffer;
      tp = MathMin(entry + risk, tpResistance);
      for (double j = 1.1; j <= config.maxRiskRewardRate; j += 0.1)
      {
         const double _tp = entry + risk * j;
         if (_tp <= tpResistance)
         {
            tp = _tp;
         }
      }
   }
   else
   {
      // SELL: TP trên support - cộng buffer % để an toàn hơn
      double tpBuffer = (entry - outResult.support) * config.srBufferPercent / 100.0;
      double tpSupport = outResult.support + tpBuffer;
      tp = MathMax(entry - risk, tpSupport);
      for (double j = 1.1; j <= config.maxRiskRewardRate; j += 0.1)
      {
         const double _tp = entry - risk * j;
         if (_tp >= tpSupport)
         {
            tp = _tp;
         }
      }
   }

   outResult.entry = entry;
   outResult.sl = sl;
   outResult.tp = tp;

   // Validate Entry/SL/TP bằng hàm chung
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   PriceValidationResult priceValidation;
   ValidatePriceConstraints(isBuySignal, entry, sl, tp, config.minStopLoss, config.minTakeProfit,
                            config.minRiskRewardRate, pointValue, digits, priceValidation);

   if (!priceValidation.isValid)
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
   // Signal có thể hợp lệ hoặc không cho dù cutFound = true
   // cutFound = true, cancelled = false  : có điểm cắt và signal hợp lệ
   // cutFound = true, cancelled = true   : có điểm cắt nhưng signal không hợp lệ
   // cutFound = false, cancelled = true  : tìm được điểm cắt nhưng không hợp lệ
   // cutFound = false, cancelled = false : vẫn đang tìm điểm cắt nhưng đã kết thúc nến
   // Nếu tìm được điểm cắt nhưng không hợp lệ: found = false, cancelled = true
   bool cancelled;         // Thông báo việc scan signal thất bại
   bool cutFound;          // Thông báo tìm thấy điểm cắt
   int cutIdx;             // Idx nến cắt (có khả năng khởi tạo signal)
   datetime cutTime;       // Thời gian của nến cắt
   int confirmIdx;         // Idx nến xác nhận signal
   datetime confirmTime;   // Thời gian của nến xác nhận
   string confirmPattern;  // Pattern của nến xác nhận
   bool isBuy;             // Lệnh BUY hay SELL
   SignalResult signal;    // Chi tiết signal
   string cancelReason;    // Lý do nếu signal bị hủy
   // Sau khi kết thúc lần scan, thông tin nến hiện tại đang dừng lại sẽ trả về trong tham chiếu sau
   // Lần scan kế tiếp sẽ bắt đầu từ nến mới hơn endIdx
   int startIdx;        // Idx nến bắt đầu scan
   datetime startTime;  // Thời gian của nến bắt đầu scan
   int endIdx;          // Idx nến kết thúc sau khi scan
   datetime endTime;    // Thời gian của nến kết thúc sau khi scan

   int failedSignalCount;        // Số lượng signal bị hủy
   SignalResult failedSignal[];  // Danh sách các signal bị hủy
   int failedIdx[];              // Idx nến các signal bị hủy
   datetime failedTime[];        // Thời gian nến các signal bị hủy
};

//+------------------------------------------------------------------+
//| Scan for trading signal from a startIdx candle                   |
//+------------------------------------------------------------------+
void ScanForSignal(const SMAPullbackConfig& config, string symbol, datetime currentTime, int startIdx,
                   const datetime& time[], const double& open[], const double& high[], const double& low[],
                   const double& close[], const double& sma50[], const double& sma200[], const double& rsi[],
                   const double& macdMain[], const double& macdSignal[], const long& volume[], const double& adxMain[],
                   const double& adxPlusDI[], const double& adxMinusDI[], const double& atr[], double tickSize,
                   double pointValue, int arraySize, ScanResult& outResult)
{
   outResult.cancelled = false;
   outResult.cutFound = false;
   outResult.cutIdx = -1;
   outResult.confirmIdx = -1;
   outResult.confirmPattern = "";
   outResult.isBuy = true;
   outResult.cancelReason = "";
   outResult.startIdx = startIdx;
   outResult.startTime = time[startIdx];
   outResult.endIdx = -1;
   outResult.failedSignalCount = 0;
   ArrayResize(outResult.failedSignal, 0);
   ArrayResize(outResult.failedIdx, 0);
   ArrayResize(outResult.failedTime, 0);

   // Scan từng nến để theo dõi biến động giá, xác định dấu hiệu signal
   int idx = startIdx;
   int trend = 0;               // 0: = MA; 1: >MA, -1: <MA
   int trendBuyBarsCount = 0;   // Số nến tăng trong trend
   int trendSellBarsCount = 0;  // Số nến giảm trong trend
   int trendPeakIdx = -1;       // Idx của đỉnh / đáy trend
   while (idx >= 1)             // Chỉ scan đến nến đóng hoàn thiện gần nhất (nến 0 là nến đang chạy)
   {
      bool isBuyBar = close[idx] > open[idx];
      bool isSellBar = close[idx] < open[idx];

      if (trend == 0)
      {
         // Chỉ kiểm tra trend lần đầu khi chưa xác định
         trend = isBuyBar ? 1 : (isSellBar ? -1 : 0);
         trendPeakIdx = idx;
         outResult.startIdx = idx;
         outResult.startTime = time[idx];
         --idx;
         // Tiếp tục nến tiếp theo
         continue;
      }
      else
      {
         // Đềm nến tăng, giảm
         if (isBuyBar)
            ++trendBuyBarsCount;
         if (isSellBar)
            ++trendSellBarsCount;

         if (trend == 1 && close[trendPeakIdx] < close[idx])
            // Lấy đỉnh nến
            trendPeakIdx = idx;
         else if (trend == -1 && close[trendPeakIdx] > close[idx])
            // Lấy đáy nến
            trendPeakIdx = idx;

         int cutTrend = 0;
         if (IsGreaterThan(high[idx], sma50[idx], tickSize) && IsLessThan(low[idx], sma50[idx], tickSize))
         {
            cutTrend = isBuyBar ? 1 : (isSellBar ? -1 : 0);
         }
         if (cutTrend != 0 && trend != cutTrend)
         {
            outResult.isBuy = trend == 1;
            // Trend đảo chiều (trend != cutTrend)
            // Kiểm tra điều kiện để xác nhận điểm cắt
            string cutReason =
                CheckCutSignal(config, outResult.isBuy, trendBuyBarsCount, trendSellBarsCount,
                               close[outResult.startIdx], close[trendPeakIdx], sma50[trendPeakIdx], atr[trendPeakIdx]);
            if (cutReason != "")
            {
               // Không phải điểm cắt hợp lệ thì break scan tại nến trước đó để vòng scan tiếp theo bắt đầu xử lý từ nến
               // cắt này
               outResult.cutFound = false;
               outResult.cancelled = true;
               outResult.endIdx = idx + 1;
               outResult.endTime = time[idx + 1];
               outResult.cancelReason = cutReason;
               return;
            }
            // Nếu là điểm cắt hợp lệ thì lưu kết quả và tiếp tục vòng lặp để xác nhận signal
            outResult.cutFound = true;
            outResult.cutIdx = idx;
            outResult.cutTime = time[idx];
            outResult.endIdx = idx;  // Điểm kết thúc là tại điểm cắt detect được để bỏ qua nó trong lần scan tiếp theo
            outResult.endTime = time[idx];
         }
         else
         {
            --idx;
            // Tiếp tục nến tiếp theo
            continue;
         }
      }

      // Scan WaitBars nến sau nến cắt, tính từ nến cắt, để tìm điểm hồi
      // Sau thời điểm này, cutFound = true
      for (int k = 0; k <= config.maxWaitBars; k++)
      {
         /** Chuyển thành trọng số filter ----
         double sidewayUpper = sma50[idx] + atr[idx] * config.sidewayATRRatio;
         double sidewayLower = sma50[idx] - atr[idx] * config.sidewayATRRatio;

         // Kiểm tra xem nến có vượt quá vùng sideway không
         if (close[idx] < sidewayLower || close[idx] > sidewayUpper)
         {
            outResult.cancelled = true;
            outResult.confirmIdx = idx;
            outResult.confirmTime = time[idx];
            outResult.cancelReason = StringFormat("Giá vượt Sideway: Close = %.5f, Lo = %.5f, Up = %.5f", close[idx],
                                                  sidewayLower, sidewayUpper);
            return;
         }
         */

         // Kiểm tra pattern
         CandlePatternResult buyPatternResult = DetectBuyPattern(idx, open, high, low, close, atr, arraySize);
         CandlePatternResult sellPatternResult = DetectSellPattern(idx, open, high, low, close, atr, arraySize);
         string patternName = "";

         if (outResult.isBuy)
         {
            patternName = buyPatternResult.trend == BULLISH ? buyPatternResult.name : "";
         }
         else
         {
            patternName = sellPatternResult.trend == BEARISH ? sellPatternResult.name : "";
         }

         if (patternName != "")
         {
            // Tiến hành kiểm tra điều kiện signal
            SignalResult result;
            ProcessSignal(config, outResult.isBuy, outResult.cutIdx, idx, symbol, currentTime, open, high, low, close,
                          sma50, sma200, rsi, macdMain, macdSignal, volume, adxMain, adxPlusDI, adxMinusDI, atr,
                          arraySize, tickSize, pointValue, result);

            if (!result.isCriticalFail)
            {
               // Tìm thấy signal hợp lệ, kết thúc scan, trả về kết quả
               outResult.signal = result;
               outResult.confirmIdx = idx;
               outResult.confirmTime = time[idx];
               outResult.confirmPattern = patternName;
               outResult.endIdx = idx;
               outResult.endTime = time[idx];
               return;
            }
            else
            {
               ArrayResize(outResult.failedSignal, outResult.failedSignalCount + 1);
               ArrayResize(outResult.failedTime, outResult.failedSignalCount + 1);
               ArrayResize(outResult.failedIdx, outResult.failedSignalCount + 1);
               outResult.failedSignal[outResult.failedSignalCount] = result;
               outResult.failedTime[outResult.failedSignalCount] = time[idx];
               outResult.failedIdx[outResult.failedSignalCount] = idx;
               outResult.failedSignalCount++;
            }
         }

         // Tiếp tục nến mới
         --idx;
         if (idx < 1)
         {
            break;
         }
      }

      // Sau WaitBars nến vẫn không nhận diện được tín hiệu, trả về lỗi hủy với vị trí quét từ nến cắt cho lần quét kế
      // tiếp vị trí đã set trước đó nên không cần thay đổi, lý do hủy là "Không nhận diện được signal"
      outResult.cancelled = true;
      outResult.confirmIdx = idx;
      outResult.confirmTime = time[idx];
      outResult.cancelReason = "Không nhận diện được signal";
      return;
   }
}

// Kiểm tra điều kiện cắt
string CheckCutSignal(const SMAPullbackConfig& config, bool isBuyTrend, int buyBarCount, int sellBarCount,
                      double startPrice, double peakPrice, double maAtPeak, double atrAtPeak)
{
   if (buyBarCount + sellBarCount < config.minTrendBars)
      return StringFormat("Không đủ nến để tạo xu hướng, min %d nến", config.minTrendBars);

   if (isBuyTrend)
   {
      // if (maAtPeak < startPrice)
      //    return StringFormat("MA tại đỉnh thấp hơn giá bắt đầu, MA = %.5f < Start = %.5f", maAtPeak, startPrice);
      if (peakPrice - maAtPeak <= config.sidewayATRRatio * atrAtPeak)
         return StringFormat(
             "Đỉnh nến chưa vượt qua vùng sideway của MA, Peak = %.5f, MA = %.5f, ATR = %.5f, Ratio = %.2f", peakPrice,
             maAtPeak, atrAtPeak, config.sidewayATRRatio);
   }
   else
   {
      // if (maAtPeak > startPrice)
      //    return StringFormat("MA tại đáy cao hơn giá bắt đầu, MA = %.5f > Start = %.5f", maAtPeak, startPrice);
      if (maAtPeak - peakPrice <= config.sidewayATRRatio * atrAtPeak)
         return StringFormat(
             "Đáy nến chưa vượt qua vùng sideway của MA, Peak = %.5f, MA = %.5f, ATR = %.5f, Ratio = %.2f", peakPrice,
             maAtPeak, atrAtPeak, config.sidewayATRRatio);
   }

   return "";
}

#endif  // MA_PULLBACK_CORE_H
