//+------------------------------------------------------------------+
//|                                          Signal Filters Module   |
//|                                    Copyright 2026, Do Nhat Phong |
//|                                   https://github.com/nhatphongdo |
//+------------------------------------------------------------------+
//| Module chứa tất cả các filter để đánh giá chất lượng tín hiệu    |
//| Mỗi filter có thể bật/tắt và có trọng số riêng                   |
//| Tổng điểm từ tất cả filter sẽ quyết định signal có được chấp nhận|
//+------------------------------------------------------------------+
#property copyright "Do Nhat Phong"

#ifndef SIGNAL_FILTERS_H
#define SIGNAL_FILTERS_H

#include "Utility.mqh"

// ====================================================================
// ===================== CẤU HÌNH THỐNG NHẤT ==========================
// ====================================================================
// Struct chứa tất cả cấu hình cho 10 filters
// Mỗi filter có: enable (bật/tắt), threshold (ngưỡng), weight (trọng số)

struct UnifiedScoringConfig
  {
   // -----------------------------------------------------------------
   // FILTER 1: MA SLOPE (Độ dốc đường MA)
   // Kiểm tra xu hướng của MA50 có đủ mạnh không
   // BUY: MA50 phải đang tăng (slope dương)
   // SELL: MA50 phải đang giảm (slope âm)
   // -----------------------------------------------------------------
   bool              enableMASlopeFilter;     // Bật/tắt filter
   bool              maSlopeCritical;         // Nếu true, fail = critical fail
   double            maSlopeThreshold;        // Góc tối thiểu (độ)
   int               slopeSmoothBars;         // Số nến tính smoothed slope (0 = 2-bar)
   double            maSlopeWeight;           // Trọng số điểm (0-100)

   // -----------------------------------------------------------------
   // FILTER 2A: STATIC MOMENTUM (RSI + MACD position)
   // Kiểm tra RSI và MACD có confirm xu hướng không
   // RSI: BUY nếu > 50, SELL nếu < 50
   // MACD: BUY nếu MACD > Signal, SELL nếu MACD < Signal
   // -----------------------------------------------------------------
   bool              enableStaticMomentumFilter;  // Bật/tắt filter
   bool              staticMomentumCritical;      // Nếu true, fail = critical fail
   double            staticMomentumWeight;        // Trọng số điểm

   // -----------------------------------------------------------------
   // FILTER 2B: RSI REVERSAL
   // Phát hiện RSI đang đi ngược hướng signal (đảo chiều momentum)
   // SELL bị từ chối nếu RSI đang tăng liên tục
   // BUY bị từ chối nếu RSI đang giảm liên tục
   // -----------------------------------------------------------------
   bool              enableRSIReversalFilter;     // Bật/tắt filter
   bool              rsiReversalCritical;         // Nếu true, fail = critical fail
   int               rsiReversalLookback;         // Số nến kiểm tra trend (2-5)
   double            rsiReversalWeight;           // Trọng số điểm

   // -----------------------------------------------------------------
   // FILTER 2C: MACD HISTOGRAM TREND
   // Phát hiện histogram đang mở rộng ngược hướng signal
   // SELL bị từ chối nếu histogram đang tăng
   // BUY bị từ chối nếu histogram đang giảm
   // -----------------------------------------------------------------
   bool              enableMACDHistogramFilter;   // Bật/tắt filter
   bool              macdHistogramCritical;       // Nếu true, fail = critical fail
   int               macdHistogramLookback;       // Số nến kiểm tra trend (1-3)
   double            macdHistogramWeight;         // Trọng số điểm

   // -----------------------------------------------------------------
   // FILTER 3: SMA200 TREND
   // Kiểm tra xu hướng dài hạn
   // BUY: Giá đóng cửa trên SMA200
   // SELL: Giá đóng cửa dưới SMA200
   // -----------------------------------------------------------------
   bool              enableSMA200Filter;      // Bật/tắt filter
   bool              sma200Critical;          // Nếu true, fail = critical fail
   double            sma200Weight;            // Trọng số điểm

   // -----------------------------------------------------------------
   // FILTER 4: S/R ZONE (Vùng hỗ trợ/kháng cự)
   // Kiểm tra giá có nằm trong vùng entry tốt không
   // BUY: Giá gần vùng support
   // SELL: Giá gần vùng resistance
   // -----------------------------------------------------------------
   bool              enableSRZoneFilter;      // Bật/tắt filter
   bool              srZoneCritical;          // Nếu true, fail = critical fail
   double            srZonePercent;           // % vùng S/R cho phép (30 = 30%)
   double            srZoneWeight;            // Trọng số điểm
   int               srLookback;              // Số nến lookback tính S/R

   // -----------------------------------------------------------------
   // FILTER 4B: S/R MIN WIDTH (Độ rộng tối thiểu vùng S/R)
   // Lọc các vùng S/R quá hẹp, tránh bị cắt SL nhanh
   // Khoảng cách R-S phải >= minSRWidthATR * ATR
   // -----------------------------------------------------------------
   bool              enableSRMinWidthFilter;  // Bật/tắt filter
   bool              srMinWidthCritical;      // Nếu true, fail = critical fail
   double            minSRWidthATR;           // Độ rộng tối thiểu (bội số ATR, vd: 1.5 = 1.5*ATR)
   double            srMinWidthWeight;        // Trọng số điểm

   // -----------------------------------------------------------------
   // FILTER 5: ADX (Sức mạnh xu hướng)
   // Kiểm tra thị trường có đang trending không
   // ADX > threshold = trending, nên vào lệnh
   // ADX < threshold = sideway, nên tránh
   // -----------------------------------------------------------------
   bool              enableADXFilter;         // Bật/tắt filter
   bool              adxCritical;             // Nếu true, fail = critical fail
   double            minADXThreshold;         // Ngưỡng ADX tối thiểu (thường 20-25)
   bool              useADXDirectionalConfirm;// Kiểm tra thêm +DI/-DI
   double            adxWeight;               // Trọng số điểm

   // -----------------------------------------------------------------
   // FILTER 6: BODY/ATR RATIO
   // Kiểm tra kích thước body nến confirmation
   // Body phải đủ lớn so với ATR để tránh nến indecision
   // -----------------------------------------------------------------
   bool              enableBodyATRFilter;     // Bật/tắt filter
   bool              bodyATRCritical;         // Nếu true, fail = critical fail
   double            minBodyATRRatio;         // Tỷ lệ tối thiểu (0.3 = 30% ATR)
   int               atrLength;               // Chu kỳ tính ATR
   double            bodyATRWeight;           // Trọng số điểm

   // -----------------------------------------------------------------
   // FILTER 7: VOLUME (Xác nhận khối lượng)
   // Kiểm tra volume nến confirmation có cao hơn trung bình không
   // Volume cao = nhiều người tham gia = tín hiệu mạnh hơn
   // -----------------------------------------------------------------
   bool              enableVolumeFilter;      // Bật/tắt filter
   bool              volumeCritical;          // Nếu true, fail = critical fail
   int               volumeAvgPeriod;         // Chu kỳ tính volume trung bình
   double            minVolumeRatio;          // Tỷ lệ tối thiểu (1.0 = 100%)
   double            volumeWeight;            // Trọng số điểm

   // -----------------------------------------------------------------
   // FILTER 8: PRICE-MA DISTANCE (Khoảng cách giá-MA)
   // Kiểm tra giá có quá xa MA không
   // Nếu quá xa = đã miss entry, không nên chase
   // -----------------------------------------------------------------
   bool              enablePriceMADistFilter; // Bật/tắt filter
   bool              priceMADistCritical;     // Nếu true, fail = critical fail
   double            maxPriceMADistATR;       // Khoảng cách tối đa (bội số ATR)
   double            priceMADistWeight;       // Trọng số điểm

   // -----------------------------------------------------------------
   // FILTER 9: TIME (Giờ giao dịch)
   // Chỉ giao dịch trong khung giờ được chỉ định
   // Tránh giờ ít thanh khoản hoặc spread cao
   // -----------------------------------------------------------------
   bool              enableTimeFilter;        // Bật/tắt filter
   bool              timeCritical;            // Nếu true, fail = critical fail
   int               tradeStartHour;          // Giờ bắt đầu (0-23)
   int               tradeEndHour;            // Giờ kết thúc (0-23)
   double            timeWeight;              // Trọng số điểm

   // -----------------------------------------------------------------
   // FILTER 10: NEWS (Tin tức kinh tế)
   // Tránh giao dịch trước/sau tin quan trọng
   // Sử dụng MQL5 Economic Calendar API
   // -----------------------------------------------------------------
   bool              enableNewsFilter;        // Bật/tắt filter
   bool              newsCritical;            // Nếu true, fail = critical fail
   int               newsMinutesBefore;       // Phút trước tin cần tránh
   int               newsMinutesAfter;        // Phút sau tin cần tránh
   int               newsMinImportance;       // Mức quan trọng (1=Low, 2=Med, 3=High)
   double            newsWeight;              // Trọng số điểm

   // -----------------------------------------------------------------
   // NGƯỠNG ĐIỂM TỐI THIỂU
   // Signal phải đạt tổng điểm >= minScoreToPass mới được chấp nhận
   // -----------------------------------------------------------------
   double            minScoreToPass;          // Điểm tối thiểu để pass
  };

// ====================================================================
// ===================== KẾT QUẢ FILTER ===============================
// ====================================================================

//+------------------------------------------------------------------+
//| Kết quả từ một filter đơn lẻ                                     |
//+------------------------------------------------------------------+
struct ScoringFilterResult
  {
   bool              passed;       // Filter có pass không
   double            score;        // Điểm đóng góp (0 nếu không pass)
   string            reason;       // Lý do fail (rỗng nếu pass)
   double            value;        // Giá trị tính được (debug)
  };

//+------------------------------------------------------------------+
//| Kết quả tổng hợp từ tất cả filters                               |
//+------------------------------------------------------------------+
struct UnifiedScoringResult
  {
   double            totalScore;      // Tổng điểm từ tất cả filters
   string            allReasons;      // Tất cả lý do fail (mỗi dòng 1 lý do)
   double            support;         // Vùng hỗ trợ tính được
   double            resistance;      // Vùng kháng cự tính được
   bool              passed;          // totalScore >= minScoreToPass
   bool              hasCriticalFail; // Có lỗi nghiêm trọng (S/R không hợp lệ)
  };

// ====================================================================
// ================= CÁC FILTER FUNCTIONS =============================
// ====================================================================
// Mỗi filter function nhận config và data, trả về ScoringFilterResult
// Nếu filter bị tắt (enable = false) sẽ trả về passed = true, score = 0

//+------------------------------------------------------------------+
//| FILTER 1: MA SLOPE                                               |
//| Kiểm tra độ dốc của MA50 sử dụng linear regression               |
//| Sử dụng slopeSmoothBars nến để tính slope chính xác hơn          |
//| Công thức: Linear regression để tìm slope, convert sang độ       |
//+------------------------------------------------------------------+
ScoringFilterResult CheckMASlopeFilter(
   const UnifiedScoringConfig &config,
   bool isBuySignal,
   int confirmIdx,
   const double &ma50[],
   double pointValue,
   int arraySize
)
  {
   ScoringFilterResult result;
   result.passed = false;
   result.score = 0;
   result.reason = "";
   result.value = 0;

// Nếu filter tắt, tự động pass nhưng không cộng điểm
   if(!config.enableMASlopeFilter)
     {
      result.passed = true;
      return result;
     }

   double angle = 0;

// Nếu slopeSmoothBars <= 1, dùng tính toán 2-bar đơn giản
   if(config.slopeSmoothBars <= 1)
     {
      // ArraySetAsSeries=true: index nhỏ = mới, index lớn = cũ
      // sma50[confirmIdx] - sma50[confirmIdx+1] = giá trị mới - giá trị cũ
      // Nếu dương = uptrend, âm = downtrend
      double delta = (ma50[confirmIdx] - ma50[confirmIdx + 1]) / pointValue;
      angle = MathArctan(delta) * 180 / M_PI;
     }
   else
     {
      // Sử dụng Linear Regression để tính slope chính xác hơn
      // y = a + b*x, trong đó x là bar index, y là giá trị MA50

      int endIdx = confirmIdx + config.slopeSmoothBars;
      if(endIdx >= arraySize)
         endIdx = arraySize - 1;

      int actualBars = endIdx - confirmIdx;
      angle = CalculateLinearRegressionSlope(ma50, confirmIdx, actualBars, pointValue);
     }

   result.value = angle;

// Kiểm tra góc có đủ ngưỡng không
// BUY cần slope dương, SELL cần slope âm
   bool slopeOk = false;
   if(isBuySignal)
      slopeOk = (angle >= config.maSlopeThreshold);
   else
      slopeOk = (-angle >= config.maSlopeThreshold);

   if(slopeOk)
     {
      result.passed = true;
      result.score = config.maSlopeWeight;
     }
   else
     {
      result.reason = StringFormat("Slope yếu (%.1f°, cần %.1f°, %d nến)",
                                   MathAbs(angle), config.maSlopeThreshold,
                                   config.slopeSmoothBars > 1 ? config.slopeSmoothBars : 2);
     }

   return result;
  }

//+------------------------------------------------------------------+
//| FILTER 2A: STATIC MOMENTUM                                       |
//| Kiểm tra RSI và MACD có confirm xu hướng không                   |
//| Mỗi indicator pass được cộng momentumWeight điểm                 |
//+------------------------------------------------------------------+
ScoringFilterResult CheckStaticMomentumFilter(
   const UnifiedScoringConfig &config,
   bool isBuySignal,
   int confirmIdx,
   const double &rsi[],
   const double &macdMain[],
   const double &macdSignal[]
)
  {
   ScoringFilterResult result;
   result.passed = false;
   result.score = 0;
   result.reason = "";
   result.value = 0;

   if(!config.enableStaticMomentumFilter)
     {
      result.passed = true;
      return result;
     }

   int momentumCount = 0;

// Kiểm tra RSI
// BUY: RSI > 50 (bullish momentum)
// SELL: RSI < 50 (bearish momentum)
   bool rsiOk = false;
   if(isBuySignal)
      rsiOk = (rsi[confirmIdx] > 50);
   else
      rsiOk = (rsi[confirmIdx] < 50);
   if(rsiOk)
      momentumCount++;

// Kiểm tra MACD
// BUY: MACD > Signal (bullish crossover)
// SELL: MACD < Signal (bearish crossover)
   bool macdOk = false;
   if(isBuySignal)
      macdOk = (macdMain[confirmIdx] > macdSignal[confirmIdx]);
   else
      macdOk = (macdMain[confirmIdx] < macdSignal[confirmIdx]);
   if(macdOk)
      momentumCount++;

   result.value = momentumCount;

   if(momentumCount > 0)
     {
      result.passed = true;
      result.score = momentumCount * (config.staticMomentumWeight / 2.0);
     }
   else
     {
      result.reason = StringFormat("Momentum yếu (RSI=%.1f, MACD=%.5f, Sig=%.5f)",
                                   rsi[confirmIdx], macdMain[confirmIdx], macdSignal[confirmIdx]);
     }

   return result;
  }

//+------------------------------------------------------------------+
//| FILTER 2B: RSI REVERSAL                                          |
//| Phát hiện RSI đang đi ngược hướng signal (đảo chiều momentum)    |
//| SELL bị từ chối nếu RSI đang tăng liên tục                       |
//| BUY bị từ chối nếu RSI đang giảm liên tục                        |
//+------------------------------------------------------------------+
ScoringFilterResult CheckRSIReversalFilter(
   const UnifiedScoringConfig &config,
   bool isBuySignal,
   int confirmIdx,
   const double &rsi[],
   int arraySize
)
  {
   ScoringFilterResult result;
   result.passed = false;
   result.score = 0;
   result.reason = "";
   result.value = 0;

   if(!config.enableRSIReversalFilter)
     {
      result.passed = true;
      return result;
     }

// Kiểm tra có đủ nến để tính trend không
   int lookback = config.rsiReversalLookback;
   if(lookback < 2)
      lookback = 2;
   if(confirmIdx + lookback >= arraySize)
     {
      result.passed = true; // Không đủ data, bỏ qua filter
      return result;
     }

// Kiểm tra RSI trend trong lookback nến
// ArraySetAsSeries = true: index nhỏ = mới, index lớn = cũ
// Nên RSI[confirmIdx] là mới nhất, RSI[confirmIdx+1] là cũ hơn
   bool rsiIncreasing = true;  // RSI đang tăng
   bool rsiDecreasing = true;  // RSI đang giảm

   for(int i = 0; i < lookback - 1; i++)
     {
      int idx = confirmIdx + i;
      // So sánh RSI[idx] với RSI[idx+1] (mới vs cũ)
      if(rsi[idx] <= rsi[idx + 1])
         rsiIncreasing = false;  // Không tăng liên tục
      if(rsi[idx] >= rsi[idx + 1])
         rsiDecreasing = false;  // Không giảm liên tục
     }

   result.value = rsi[confirmIdx] - rsi[confirmIdx + lookback - 1];

// Logic đảo chiều:
// - BUY signal + RSI đang giảm = momentum yếu dần, có thể reversal
// - SELL signal + RSI đang tăng = momentum đang mạnh lên, có thể reversal
   bool hasReversal = false;

   if(isBuySignal && rsiDecreasing)
     {
      hasReversal = true;
      result.reason = StringFormat("RSI giảm ngược BUY (%.1f → %.1f)",
                                   rsi[confirmIdx + lookback - 1], rsi[confirmIdx]);
     }
   else
      if(!isBuySignal && rsiIncreasing)
        {
         hasReversal = true;
         result.reason = StringFormat("RSI tăng ngược SELL (%.1f → %.1f)",
                                      rsi[confirmIdx + lookback - 1], rsi[confirmIdx]);
        }

   if(!hasReversal)
     {
      result.passed = true;
      result.score = config.rsiReversalWeight;
     }
// Nếu hasReversal = true, passed = false (mặc định)

   return result;
  }

//+------------------------------------------------------------------+
//| FILTER 2C: MACD HISTOGRAM TREND                                  |
//| Phát hiện histogram đang mở rộng ngược hướng signal              |
//| SELL bị từ chối nếu histogram đang tăng (bullish momentum)       |
//| BUY bị từ chối nếu histogram đang giảm (bearish momentum)        |
//+------------------------------------------------------------------+
ScoringFilterResult CheckMACDHistogramFilter(
   const UnifiedScoringConfig &config,
   bool isBuySignal,
   int confirmIdx,
   const double &macdMain[],
   const double &macdSignal[],
   int arraySize
)
  {
   ScoringFilterResult result;
   result.passed = false;
   result.score = 0;
   result.reason = "";
   result.value = 0;

   if(!config.enableMACDHistogramFilter)
     {
      result.passed = true;
      return result;
     }

// Kiểm tra có đủ nến để tính trend không
   int lookback = config.macdHistogramLookback;
   if(lookback < 1)
      lookback = 1;
   if(confirmIdx + lookback >= arraySize)
     {
      result.passed = true; // Không đủ data, bỏ qua filter
      return result;
     }

// Tính histogram = MACD - Signal
   double histCurrent = macdMain[confirmIdx] - macdSignal[confirmIdx];
   double histPrev = macdMain[confirmIdx + lookback] - macdSignal[confirmIdx + lookback];

   result.value = histCurrent - histPrev;

// Kiểm tra histogram trend
   bool histIncreasing = (histCurrent > histPrev);  // Histogram đang tăng
   bool histDecreasing = (histCurrent < histPrev);  // Histogram đang giảm

// Logic đảo chiều:
// - BUY signal + histogram đang giảm = bearish momentum đang mạnh lên
// - SELL signal + histogram đang tăng = bullish momentum đang mạnh lên
   bool hasReversal = false;

   if(isBuySignal && histDecreasing)
     {
      hasReversal = true;
      result.reason = StringFormat("MACD Hist giảm ngược BUY (%.5f → %.5f)",
                                   histPrev, histCurrent);
     }
   else
      if(!isBuySignal && histIncreasing)
        {
         hasReversal = true;
         result.reason = StringFormat("MACD Hist tăng ngược SELL (%.5f → %.5f)",
                                      histPrev, histCurrent);
        }

   if(!hasReversal)
     {
      result.passed = true;
      result.score = config.macdHistogramWeight;
     }
// Nếu hasReversal = true, passed = false (mặc định)

   return result;
  }


//+------------------------------------------------------------------+
//| FILTER 3: SMA200 TREND                                           |
//| Kiểm tra giá có cùng xu hướng với SMA200 không                   |
//+------------------------------------------------------------------+
ScoringFilterResult CheckSMA200Filter(
   const UnifiedScoringConfig &config,
   bool isBuySignal,
   int confirmIdx,
   const double &close[],
   const double &sma200[],
   double tickSize
)
  {
   ScoringFilterResult result;
   result.passed = false;
   result.score = 0;
   result.reason = "";
   result.value = close[confirmIdx] - sma200[confirmIdx];

   if(!config.enableSMA200Filter)
     {
      result.passed = true;
      return result;
     }

// Helper functions inline
   bool sma200Ok = false;
   if(isBuySignal)
      sma200Ok = (close[confirmIdx] > sma200[confirmIdx] + tickSize);
   else
      sma200Ok = (close[confirmIdx] < sma200[confirmIdx] - tickSize);

   if(sma200Ok)
     {
      result.passed = true;
      result.score = config.sma200Weight;
     }
   else
     {
      result.reason = StringFormat("Sai MA (Close=%.5f, MA Slow=%.5f)",
                                   close[confirmIdx], sma200[confirmIdx]);
     }

   return result;
  }

//+------------------------------------------------------------------+
//| FILTER 4: S/R ZONE                                               |
//| Tính vùng S/R và kiểm tra giá có trong vùng entry tốt không      |
//| Hàm này cũng trả về support/resistance qua tham chiếu            |
//+------------------------------------------------------------------+
ScoringFilterResult CheckSRZoneFilter(
   const UnifiedScoringConfig &config,
   bool isBuySignal,
   int confirmIdx,
   const double &high[],
   const double &low[],
   const double &close[],
   int arraySize,
   double &outSupport,
   double &outResistance
)
  {
   ScoringFilterResult result;
   result.passed = false;
   result.score = 0;
   result.reason = "";
   result.value = 0;

// Luôn tính S/R (cần cho entry/SL/TP)
   outSupport = 999999999;
   outResistance = 0;

   int srStart = confirmIdx;
   int srEnd = confirmIdx + config.srLookback;
   if(srEnd >= arraySize)
      srEnd = arraySize - 1;

// Tìm high nhất và low nhất trong lookback period
   for(int j = srStart; j <= srEnd; j++)
     {
      if(high[j] > outResistance)
         outResistance = high[j];
      if(low[j] < outSupport)
         outSupport = low[j];
     }

// Kiểm tra S/R hợp lệ
   if(outSupport <= 0 || outResistance <= 0 || outResistance <= outSupport)
     {
      result.reason = "Lỗi S/R";
      return result; // Critical fail
     }

   if(!config.enableSRZoneFilter)
     {
      result.passed = true;
      return result;
     }

// Tính vùng entry cho phép
   double srRange = outResistance - outSupport;
   bool inZone = false;
   double limitPrice = 0;

   if(isBuySignal)
     {
      // BUY: Giá phải nằm trong vùng dưới (gần support)
      limitPrice = outSupport + srRange * config.srZonePercent / 100.0;
      inZone = (close[confirmIdx] >= outSupport && close[confirmIdx] <= limitPrice);
     }
   else
     {
      // SELL: Giá phải nằm trong vùng trên (gần resistance)
      limitPrice = outResistance - srRange * config.srZonePercent / 100.0;
      inZone = (close[confirmIdx] <= outResistance && close[confirmIdx] >= limitPrice);
     }

   result.value = close[confirmIdx];

   if(inZone)
     {
      result.passed = true;
      result.score = config.srZoneWeight;
     }
   else
     {
      result.reason = StringFormat("Ngoài vùng S/R (Cl=%.5f, Lim=%.5f, S=%.5f, R=%.5f)",
                                   close[confirmIdx], limitPrice, outSupport, outResistance);
     }

   return result;
  }

//+------------------------------------------------------------------+
//| FILTER 4B: S/R MIN WIDTH                                         |
//| Kiểm tra độ rộng tối thiểu vùng S/R để tránh cắt SL nhanh        |
//| Vùng S/R quá hẹp = rủi ro cao, dễ bị SL                          |
//+------------------------------------------------------------------+
ScoringFilterResult CheckSRMinWidthFilter(
   const UnifiedScoringConfig &config,
   int confirmIdx,
   double support,
   double resistance,
   const double &high[],
   const double &low[],
   int arraySize,
   double &outSRRangeATR
)
  {
   ScoringFilterResult result;
   result.passed = false;
   result.score = 0;
   result.reason = "";
   result.value = 0;
   outSRRangeATR = 0;

   if(!config.enableSRMinWidthFilter)
     {
      result.passed = true;
      return result;
     }

// Tính ATR
   double atr = 0;
   int atrBars = MathMin(config.atrLength, arraySize - confirmIdx - 1);
   for(int i = 0; i < atrBars; i++)
      atr += high[confirmIdx + i] - low[confirmIdx + i];
   if(atrBars > 0)
      atr = atr / atrBars;

   if(atr <= 0)
     {
      result.passed = true;
      return result;
     }

// Tính độ rộng vùng S/R theo bội số ATR
   double srRange = resistance - support;
   outSRRangeATR = srRange / atr;
   result.value = outSRRangeATR;

// Kiểm tra >= ngưỡng
   if(outSRRangeATR >= config.minSRWidthATR)
     {
      result.passed = true;
      result.score = config.srMinWidthWeight;
     }
   else
     {
      result.reason = StringFormat("S/R hẹp (%.1f ATR < %.1f ATR)",
                                   outSRRangeATR, config.minSRWidthATR);
     }

   return result;
  }

//+------------------------------------------------------------------+
//| FILTER 5: ADX                                                    |
//| Kiểm tra sức mạnh xu hướng bằng ADX                              |
//+------------------------------------------------------------------+
ScoringFilterResult CheckADXFilter(
   const UnifiedScoringConfig &config,
   bool isBuySignal,
   int confirmIdx,
   const double &adxMain[],
   const double &adxPlusDI[],
   const double &adxMinusDI[]
)
  {
   ScoringFilterResult result;
   result.passed = false;
   result.score = 0;
   result.reason = "";
   result.value = 0;

   if(!config.enableADXFilter)
     {
      result.passed = true;
      return result;
     }

   result.value = adxMain[confirmIdx];

// ADX phải >= ngưỡng (thị trường đang trending)
   if(adxMain[confirmIdx] < config.minADXThreshold)
     {
      result.reason = StringFormat("ADX yếu (%.1f < %.1f)",
                                   adxMain[confirmIdx], config.minADXThreshold);
      return result;
     }

// Kiểm tra +DI/-DI nếu bật
   if(config.useADXDirectionalConfirm)
     {
      if(isBuySignal && adxPlusDI[confirmIdx] <= adxMinusDI[confirmIdx])
        {
         result.reason = StringFormat("+DI (%.1f) <= -DI (%.1f)",
                                      adxPlusDI[confirmIdx], adxMinusDI[confirmIdx]);
         return result;
        }
      if(!isBuySignal && adxMinusDI[confirmIdx] <= adxPlusDI[confirmIdx])
        {
         result.reason = StringFormat("-DI (%.1f) <= +DI (%.1f)",
                                      adxMinusDI[confirmIdx], adxPlusDI[confirmIdx]);
         return result;
        }
     }

   result.passed = true;
   result.score = config.adxWeight;
   return result;
  }

//+------------------------------------------------------------------+
//| FILTER 6: BODY/ATR RATIO                                         |
//| Kiểm tra body nến confirmation có đủ lớn không                   |
//+------------------------------------------------------------------+
ScoringFilterResult CheckBodyATRFilter(
   const UnifiedScoringConfig &config,
   int confirmIdx,
   const double &open[],
   const double &close[],
   const double &high[],
   const double &low[],
   int arraySize
)
  {
   ScoringFilterResult result;
   result.passed = false;
   result.score = 0;
   result.reason = "";
   result.value = 0;

   if(!config.enableBodyATRFilter)
     {
      result.passed = true;
      return result;
     }

// Tính body size
   double body = MathAbs(close[confirmIdx] - open[confirmIdx]);

// Tính ATR
   double atr = 0;
   int atrBars = MathMin(config.atrLength, arraySize - confirmIdx - 1);
   for(int i = 0; i < atrBars; i++)
      atr += high[confirmIdx + i] - low[confirmIdx + i];
   if(atrBars > 0)
      atr = atr / atrBars;

   if(atr <= 0)
     {
      result.passed = true;
      return result;
     }

   result.value = body / atr;

   if(result.value >= config.minBodyATRRatio)
     {
      result.passed = true;
      result.score = config.bodyATRWeight;
     }
   else
     {
      result.reason = StringFormat("Body/ATR nhỏ (%.2f < %.2f)",
                                   result.value, config.minBodyATRRatio);
     }

   return result;
  }

//+------------------------------------------------------------------+
//| FILTER 7: VOLUME                                                 |
//| Kiểm tra volume nến confirmation có cao hơn trung bình không     |
//+------------------------------------------------------------------+
ScoringFilterResult CheckVolumeFilter(
   const UnifiedScoringConfig &config,
   int confirmIdx,
   const long &volume[],
   int arraySize
)
  {
   ScoringFilterResult result;
   result.passed = false;
   result.score = 0;
   result.reason = "";
   result.value = 0;

   if(!config.enableVolumeFilter)
     {
      result.passed = true;
      return result;
     }

// Tính volume trung bình
   double avgVolume = 0;
   int avgBars = MathMin(config.volumeAvgPeriod, arraySize - confirmIdx - 1);
   for(int i = 1; i <= avgBars; i++)
      avgVolume += (double)volume[confirmIdx + i];
   if(avgBars > 0)
      avgVolume = avgVolume / avgBars;

   if(avgVolume <= 0)
     {
      result.passed = true;
      return result;
     }

   result.value = (double)volume[confirmIdx] / avgVolume;

   if(result.value >= config.minVolumeRatio)
     {
      result.passed = true;
      result.score = config.volumeWeight;
     }
   else
     {
      result.reason = StringFormat("Volume thấp (%.0f%% < %.0f%%)",
                                   result.value * 100, config.minVolumeRatio * 100);
     }

   return result;
  }

//+------------------------------------------------------------------+
//| FILTER 8: PRICE-MA DISTANCE                                      |
//| Kiểm tra giá có quá xa MA không (tránh chase)                    |
//+------------------------------------------------------------------+
ScoringFilterResult CheckPriceMADistFilter(
   const UnifiedScoringConfig &config,
   int confirmIdx,
   const double &close[],
   const double &high[],
   const double &low[],
   const double &ma[],
   int arraySize
)
  {
   ScoringFilterResult result;
   result.passed = false;
   result.score = 0;
   result.reason = "";
   result.value = 0;

   if(!config.enablePriceMADistFilter)
     {
      result.passed = true;
      return result;
     }

// Tính ATR
   double atr = 0;
   int atrBars = MathMin(config.atrLength, arraySize - confirmIdx - 1);
   for(int i = 0; i < atrBars; i++)
      atr += high[confirmIdx + i] - low[confirmIdx + i];
   if(atrBars > 0)
      atr = atr / atrBars;

   if(atr <= 0)
     {
      result.passed = true;
      return result;
     }

// Tính khoảng cách giá-MA theo bội số ATR
   double distance = MathAbs(close[confirmIdx] - ma[confirmIdx]);
   result.value = distance / atr;

   if(result.value <= config.maxPriceMADistATR)
     {
      result.passed = true;
      result.score = config.priceMADistWeight;
     }
   else
     {
      result.reason = StringFormat("Giá xa MA (%.1f ATR > %.1f ATR)",
                                   result.value, config.maxPriceMADistATR);
     }

   return result;
  }

//+------------------------------------------------------------------+
//| FILTER 9: TIME                                                   |
//| Kiểm tra có trong khung giờ giao dịch không                      |
//+------------------------------------------------------------------+
ScoringFilterResult CheckTimeFilter(
   const UnifiedScoringConfig &config,
   datetime currentTime
)
  {
   ScoringFilterResult result;
   result.passed = false;
   result.score = 0;
   result.reason = "";
   result.value = 0;

   if(!config.enableTimeFilter)
     {
      result.passed = true;
      return result;
     }

   MqlDateTime timeStruct;
   TimeToStruct(currentTime, timeStruct);
   int currentHour = timeStruct.hour;
   result.value = currentHour;

// Xử lý wrap around (ví dụ: 22:00 - 06:00)
   bool inRange;
   if(config.tradeStartHour <= config.tradeEndHour)
      inRange = (currentHour >= config.tradeStartHour && currentHour < config.tradeEndHour);
   else
      inRange = (currentHour >= config.tradeStartHour || currentHour < config.tradeEndHour);

   if(inRange)
     {
      result.passed = true;
      result.score = config.timeWeight;
     }
   else
     {
      result.reason = StringFormat("Ngoài giờ GD (%02d:00, cần %02d-%02d)",
                                   currentHour, config.tradeStartHour, config.tradeEndHour);
     }

   return result;
  }

//+------------------------------------------------------------------+
//| FILTER 10: NEWS                                                  |
//| Kiểm tra có tin tức quan trọng sắp ra không                      |
//| Sử dụng MQL5 Economic Calendar API                               |
//+------------------------------------------------------------------+
ScoringFilterResult CheckNewsFilter(
   const UnifiedScoringConfig &config,
   string symbol,
   datetime currentTime
)
  {
   ScoringFilterResult result;
   result.passed = false;
   result.score = 0;
   result.reason = "";
   result.value = 0;

   if(!config.enableNewsFilter)
     {
      result.passed = true;
      return result;
     }

// Lấy currency từ symbol (ví dụ: EURUSD -> EUR và USD)
   string baseCurrency = StringSubstr(symbol, 0, 3);
   string quoteCurrency = StringSubstr(symbol, 3, 3);

// Khoảng thời gian cần kiểm tra
   datetime timeFrom = currentTime - config.newsMinutesBefore * 60;
   datetime timeTo = currentTime + config.newsMinutesAfter * 60;

// Kiểm tra tin cho base currency
   MqlCalendarValue values[];
   int count = CalendarValueHistory(values, timeFrom, timeTo, NULL, baseCurrency);
   for(int i = 0; i < count; i++)
     {
      MqlCalendarEvent event;
      if(CalendarEventById(values[i].event_id, event))
        {
         // newsMinImportance: 1=Low, 2=Medium, 3=High
         // event.importance: 0=None, 1=Low, 2=Medium, 3=High
         if((int)event.importance >= config.newsMinImportance + 1)
           {
            int minutes = (int)((values[i].time - currentTime) / 60);
            result.reason = StringFormat("Tin %s (%d p)", baseCurrency, minutes);
            return result;
           }
        }
     }

// Kiểm tra tin cho quote currency
   MqlCalendarValue quoteValues[];
   count = CalendarValueHistory(quoteValues, timeFrom, timeTo, NULL, quoteCurrency);
   for(int i = 0; i < count; i++)
     {
      MqlCalendarEvent event;
      if(CalendarEventById(quoteValues[i].event_id, event))
        {
         if((int)event.importance >= config.newsMinImportance + 1)
           {
            int minutes = (int)((quoteValues[i].time - currentTime) / 60);
            result.reason = StringFormat("Tin %s (%d p)", quoteCurrency, minutes);
            return result;
           }
        }
     }

   result.passed = true;
   result.score = config.newsWeight;
   return result;
  }

// ====================================================================
// ================== HÀM CHẠY TẤT CẢ FILTERS =========================
// ====================================================================

//+------------------------------------------------------------------+
//| Chạy tất cả 10 filters và tính tổng điểm                         |
//| Trả về UnifiedScoringResult chứa totalScore, reasons, S/R        |
//+------------------------------------------------------------------+
void RunUnifiedScoringFilters(
   const UnifiedScoringConfig &config,
   bool isBuySignal,
   int confirmIdx,
   string symbol,
   datetime currentTime,
   const double &open[],
   const double &high[],
   const double &low[],
   const double &close[],
   const double &ma50[],
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
   int arraySize,
   UnifiedScoringResult &outResult
)
  {
// Khởi tạo kết quả
   outResult.totalScore = 0;
   outResult.allReasons = "";
   outResult.support = 0;
   outResult.resistance = 0;
   outResult.passed = false;
   outResult.hasCriticalFail = false;

   ScoringFilterResult filterResult;

// -----------------------------------------------------------------
// FILTER 1: MA SLOPE
// -----------------------------------------------------------------
   filterResult = CheckMASlopeFilter(config, isBuySignal, confirmIdx, ma50, pointValue, arraySize);
   outResult.totalScore += filterResult.score;
   if(!filterResult.passed && filterResult.reason != "")
     {
      outResult.allReasons += "- " + filterResult.reason + "\n";
      if(config.maSlopeCritical)
         outResult.hasCriticalFail = true;
     }

// -----------------------------------------------------------------
// FILTER 2A: STATIC MOMENTUM (RSI + MACD position)
// -----------------------------------------------------------------
   filterResult = CheckStaticMomentumFilter(config, isBuySignal, confirmIdx, rsi, macdMain, macdSignal);
   outResult.totalScore += filterResult.score;
   if(!filterResult.passed && filterResult.reason != "")
     {
      outResult.allReasons += "- " + filterResult.reason + "\n";
      if(config.staticMomentumCritical)
         outResult.hasCriticalFail = true;
     }

// -----------------------------------------------------------------
// FILTER 2B: RSI REVERSAL
// -----------------------------------------------------------------
   filterResult = CheckRSIReversalFilter(config, isBuySignal, confirmIdx, rsi, arraySize);
   outResult.totalScore += filterResult.score;
   if(!filterResult.passed && filterResult.reason != "")
     {
      outResult.allReasons += "- " + filterResult.reason + "\n";
      if(config.rsiReversalCritical)
         outResult.hasCriticalFail = true;
     }

// -----------------------------------------------------------------
// FILTER 2C: MACD HISTOGRAM TREND
// -----------------------------------------------------------------
   filterResult = CheckMACDHistogramFilter(config, isBuySignal, confirmIdx, macdMain, macdSignal, arraySize);
   outResult.totalScore += filterResult.score;
   if(!filterResult.passed && filterResult.reason != "")
     {
      outResult.allReasons += "- " + filterResult.reason + "\n";
      if(config.macdHistogramCritical)
         outResult.hasCriticalFail = true;
     }

// -----------------------------------------------------------------
// FILTER 3: SMA200 TREND
// -----------------------------------------------------------------
   filterResult = CheckSMA200Filter(config, isBuySignal, confirmIdx, close, sma200, tickSize);
   outResult.totalScore += filterResult.score;
   if(!filterResult.passed && filterResult.reason != "")
     {
      outResult.allReasons += "- " + filterResult.reason + "\n";
      if(config.sma200Critical)
         outResult.hasCriticalFail = true;
     }

// -----------------------------------------------------------------
// FILTER 4: S/R ZONE (Critical - tính S/R cho entry/SL/TP)
// -----------------------------------------------------------------
   double support = 0, resistance = 0;
   filterResult = CheckSRZoneFilter(config, isBuySignal, confirmIdx,
                                    high, low, close, arraySize,
                                    support, resistance);
   outResult.support = support;
   outResult.resistance = resistance;

// S/R không hợp lệ là critical fail - DỪNG NGAY vì không thể tính tiếp
   if(filterResult.reason == "Lỗi S/R")
     {
      outResult.allReasons += "- " + filterResult.reason + "\n";
      outResult.hasCriticalFail = true;
      return;
     }

   outResult.totalScore += filterResult.score;
   if(!filterResult.passed && filterResult.reason != "")
     {
      outResult.allReasons += "- " + filterResult.reason + "\n";
      if(config.srZoneCritical)
         outResult.hasCriticalFail = true;
     }

// -----------------------------------------------------------------
// FILTER 4B: S/R MIN WIDTH (lọc vùng S/R quá hẹp)
// -----------------------------------------------------------------
   double srRangeATR = 0;
   filterResult = CheckSRMinWidthFilter(config, confirmIdx, support, resistance,
                                        high, low, arraySize, srRangeATR);
   outResult.totalScore += filterResult.score;
   if(!filterResult.passed && filterResult.reason != "")
     {
      outResult.allReasons += "- " + filterResult.reason + "\n";
      if(config.srMinWidthCritical)
         outResult.hasCriticalFail = true;
     }

// -----------------------------------------------------------------
// FILTER 5: ADX
// -----------------------------------------------------------------
   filterResult = CheckADXFilter(config, isBuySignal, confirmIdx,
                                 adxMain, adxPlusDI, adxMinusDI);
   outResult.totalScore += filterResult.score;
   if(!filterResult.passed && filterResult.reason != "")
     {
      outResult.allReasons += "- " + filterResult.reason + "\n";
      if(config.adxCritical)
         outResult.hasCriticalFail = true;
     }

// -----------------------------------------------------------------
// FILTER 6: BODY/ATR RATIO
// -----------------------------------------------------------------
   filterResult = CheckBodyATRFilter(config, confirmIdx, open, close, high, low, arraySize);
   outResult.totalScore += filterResult.score;
   if(!filterResult.passed && filterResult.reason != "")
     {
      outResult.allReasons += "- " + filterResult.reason + "\n";
      if(config.bodyATRCritical)
         outResult.hasCriticalFail = true;
     }

// -----------------------------------------------------------------
// FILTER 7: VOLUME
// -----------------------------------------------------------------
   filterResult = CheckVolumeFilter(config, confirmIdx, volume, arraySize);
   outResult.totalScore += filterResult.score;
   if(!filterResult.passed && filterResult.reason != "")
     {
      outResult.allReasons += "- " + filterResult.reason + "\n";
      if(config.volumeCritical)
         outResult.hasCriticalFail = true;
     }

// -----------------------------------------------------------------
// FILTER 8: PRICE-MA DISTANCE
// -----------------------------------------------------------------
   filterResult = CheckPriceMADistFilter(config, confirmIdx, close, high, low, ma50, arraySize);
   outResult.totalScore += filterResult.score;
   if(!filterResult.passed && filterResult.reason != "")
     {
      outResult.allReasons += "- " + filterResult.reason + "\n";
      if(config.priceMADistCritical)
         outResult.hasCriticalFail = true;
     }

// -----------------------------------------------------------------
// FILTER 9: TIME
// -----------------------------------------------------------------
   filterResult = CheckTimeFilter(config, currentTime);
   outResult.totalScore += filterResult.score;
   if(!filterResult.passed && filterResult.reason != "")
     {
      outResult.allReasons += "- " + filterResult.reason + "\n";
      if(config.timeCritical)
         outResult.hasCriticalFail = true;
     }

// -----------------------------------------------------------------
// FILTER 10: NEWS
// -----------------------------------------------------------------
   filterResult = CheckNewsFilter(config, symbol, currentTime);
   outResult.totalScore += filterResult.score;
   if(!filterResult.passed && filterResult.reason != "")
     {
      outResult.allReasons += "- " + filterResult.reason + "\n";
      if(config.newsCritical)
         outResult.hasCriticalFail = true;
     }

// -----------------------------------------------------------------
// ĐÁNH GIÁ KẾT QUẢ CUỐI CÙNG
// -----------------------------------------------------------------
   outResult.passed = (outResult.totalScore >= config.minScoreToPass);
  }

#endif // SIGNAL_FILTERS_H
