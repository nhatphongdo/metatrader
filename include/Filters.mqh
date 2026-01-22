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

//+------------------------------------------------------------------+
//| Kết quả từ một filter đơn lẻ                                     |
//+------------------------------------------------------------------+
struct ScoringFilterResult
{
   bool passed;    // Filter có pass không
   double score;   // Điểm đóng góp (+N nếu pass, -N nếu không pass, 0 nếu lỗi)
   string reason;  // Lý do fail (rỗng nếu pass)
   double value;   // Giá trị tính được (debug)
};

// ====================================================================
// ================= CÁC FILTER FUNCTIONS =============================
// ====================================================================
// Mỗi filter function nhận config và data, trả về ScoringFilterResult
// Nếu filter bị lỗi sẽ trả về passed = false, score = 0 với reason
// Nếu filter thành công sẽ trả về passed = true, score = +điểm
// Nếu filter không pass sẽ trả về passed = false, score = -điểm với reason

//+------------------------------------------------------------------+
//| MA SLOPE (Độ dốc đường MA)                                       |
//| Kiểm tra độ dốc của MA sử dụng linear regression                 |
//| Sử dụng slopeSmoothBars nến để tính slope chính xác hơn          |
//| Công thức: Linear regression để tìm slope                        |
//| BUY: MA phải đang tăng (slope dương)                             |
//| SELL: MA phải đang giảm (slope âm)                               |
//+------------------------------------------------------------------+
ScoringFilterResult CheckMASlope(
    int idx, const double& ma[], int arraySize,
    double maSlopeThreshold,  // Slope tối thiểu (số dương, tùy vào signal sẽ đảo chiều so sánh)
    int slopeSmoothBars,      // Số nến tính smoothed slope (0 = 2-bar) về phía cũ hơn
    double maSlopeWeight      // Trọng số điểm
)
{
   ScoringFilterResult result;
   result.passed = false;
   result.score = 0;
   result.reason = "";
   result.value = 0;

   // Tính slope bằng Linear Regression
   int slopeBars = slopeSmoothBars;
   if (slopeBars < 2)
      slopeBars = 2;  // Tối thiểu 2 bars
   if (idx + slopeBars > arraySize)
      slopeBars = arraySize - idx;

   if (slopeBars < 2 || idx >= arraySize)
   {
      // Không đủ data để tính
      result.reason = "Không đủ dữ liệu để tính slope, cần tối thiểu 2 nến";
      return result;
   }

   // Quy đồng trục thời gian về gốc để tính slope nhất quán cho tất cả lines
   double xArr[];
   ArrayResize(xArr, slopeBars);
   for (int i = 0; i < slopeBars; i++)
      xArr[i] = (double)i;
   double yArr[];
   ArrayResize(yArr, slopeBars);
   for (int i = idx + slopeBars - 1; i >= idx; i--)
   {
      // Lấy giá trị từ cũ (index lớn) đển mới (index nhỏ) gán vào trục y theo trục x tăng dần
      yArr[idx + slopeBars - 1 - i] = ma[i];
   }

   double outSlope, outIntercept;
   CalculateLinearRegressionLine(xArr, yArr, slopeBars, outSlope, outIntercept);

   result.value = outSlope;

   // Kiểm tra slope có đủ ngưỡng không
   bool slopeOk = MathAbs(outSlope) >= MathAbs(maSlopeThreshold);
   if (slopeOk)
   {
      result.passed = true;
      result.score = maSlopeWeight;
   }
   else
   {
      result.reason = StringFormat("Slope yếu (|%.5f|, cần |%.5f|, %d nến)", outSlope, maSlopeThreshold, slopeBars);
      result.score = -maSlopeWeight;
   }

   return result;
}

//+------------------------------------------------------------------+
//| STATIC RSI MOMENTUM                                              |
//| Kiểm tra RSI có confirm xu hướng không                   |
//|   RSI: BUY nếu > 50, SELL nếu < 50                               |
//+------------------------------------------------------------------+
ScoringFilterResult CheckRSIMomentum(bool isBuySignal, int idx, const double& rsi[],
                                     double rsiMomentumWeight  // Trọng số điểm
)
{
   ScoringFilterResult result;
   result.passed = false;
   result.score = 0;
   result.reason = "";
   result.value = 0;

   // Kiểm tra RSI
   bool rsiOk = false;
   if (isBuySignal)
      rsiOk = (rsi[idx] > 50);
   else
      rsiOk = (rsi[idx] < 50);

   result.value = rsi[idx];

   if (rsiOk)
   {
      result.passed = true;
      result.score = rsiMomentumWeight;
   }
   else
   {
      if (isBuySignal)
         result.reason = StringFormat("RSI không cùng xu hướng (RSI=%.2f, BUY cần >50)", rsi[idx]);
      else
         result.reason = StringFormat("RSI không cùng xu hướng (RSI=%.2f, SELL cần <50)", rsi[idx]);
      result.score = -rsiMomentumWeight;
   }

   return result;
}

//+------------------------------------------------------------------+
//| STATIC MACD MOMENTUM                                             |
//| Kiểm tra MACD có confirm xu hướng không                   |
//|   MACD: BUY nếu MACD > Signal, SELL nếu MACD < Signal            |
//+------------------------------------------------------------------+
ScoringFilterResult CheckMACDMomentum(bool isBuySignal, int idx, const double& macdMain[], const double& macdSignal[],
                                      double macdMomentumWeight  // Trọng số điểm
)
{
   ScoringFilterResult result;
   result.passed = false;
   result.score = 0;
   result.reason = "";
   result.value = 0;

   // Kiểm tra MACD
   // BUY: MACD > Signal (bullish crossover)
   // SELL: MACD < Signal (bearish crossover)
   bool macdOk = false;
   if (isBuySignal)
      macdOk = (macdMain[idx] > macdSignal[idx]);
   else
      macdOk = (macdMain[idx] < macdSignal[idx]);

   result.value = macdMain[idx] - macdSignal[idx];

   if (macdOk)
   {
      result.passed = true;
      result.score = macdMomentumWeight;
   }
   else
   {
      if (isBuySignal)
         result.reason =
             StringFormat("MACD không cùng xu hướng (MACD=%.4f, BUY cần >Signal %.4f)", macdMain[idx], macdSignal[idx]);
      else
         result.reason = StringFormat("MACD không cùng xu hướng (MACD=%.4f, SELL cần <Signal %.4f)", macdMain[idx],
                                      macdSignal[idx]);
      result.score = -macdMomentumWeight;
   }

   return result;
}

//+------------------------------------------------------------------+
//| RSI REVERSAL                                                     |
//| Phát hiện RSI đang đi ngược hướng signal (đảo chiều momentum)    |
//| SELL bị từ chối nếu RSI đang tăng liên tục                       |
//| BUY bị từ chối nếu RSI đang giảm liên tục                        |
//+------------------------------------------------------------------+
ScoringFilterResult CheckRSIReversal(bool isBuySignal, int idx, const double& rsi[], int arraySize,
                                     int rsiReversalLookback,  // Số nến để tính trend
                                     double rsiReversalWeight  // Trọng số điểm
)
{
   ScoringFilterResult result;
   result.passed = false;
   result.score = 0;
   result.reason = "";
   result.value = 0;

   // Kiểm tra có đủ nến để tính trend không
   int lookback = rsiReversalLookback;
   if (lookback < 2)
      lookback = 2;
   if (idx + lookback >= arraySize)
   {
      result.reason = "Không đủ dữ liệu để tính RSI reversal, min 3 nến";
      return result;
   }

   // Kiểm tra RSI trend trong lookback nến
   bool rsiIncreasing = true;  // Giả định RSI đang tăng
   bool rsiDecreasing = true;  // Giả định RSI đang giảm

   for (int i = 0; i < lookback; i++)
   {
      // So sánh RSI[idx] với RSI[idx+1] (mới vs cũ)
      if (rsi[idx + i] <= rsi[idx + i + 1])
         rsiIncreasing = false;  // Không tăng liên tục
      if (rsi[idx + i] >= rsi[idx + i + 1])
         rsiDecreasing = false;  // Không giảm liên tục
   }

   result.value = rsi[idx] - rsi[idx + lookback];

   // Logic đảo chiều:
   // - BUY signal + RSI đang giảm = momentum yếu dần, có thể reversal
   // - SELL signal + RSI đang tăng = momentum đang mạnh lên, có thể reversal
   bool hasReversal = false;

   if (isBuySignal && rsiDecreasing)
   {
      hasReversal = true;
      result.reason = StringFormat("RSI giảm ngược BUY (%.1f → %.1f)", rsi[idx + lookback], rsi[idx]);
   }
   else if (!isBuySignal && rsiIncreasing)
   {
      hasReversal = true;
      result.reason = StringFormat("RSI tăng ngược SELL (%.1f → %.1f)", rsi[idx + lookback], rsi[idx]);
   }

   if (!hasReversal)
   {
      result.passed = true;
      result.score = rsiReversalWeight;
   }
   else
   {
      result.score = -rsiReversalWeight;
   }

   return result;
}

//+------------------------------------------------------------------+
//| MACD HISTOGRAM TREND                                             |
//| Phát hiện histogram đang mở rộng ngược hướng signal              |
//| SELL bị từ chối nếu histogram đang tăng (bullish momentum)       |
//| BUY bị từ chối nếu histogram đang giảm (bearish momentum)        |
//+------------------------------------------------------------------+
ScoringFilterResult CheckMACDHistogram(bool isBuySignal, int idx, const double& macdMain[], const double& macdSignal[],
                                       int arraySize,
                                       int macdHistogramLookback,  // Số nến để tính trend
                                       double macdHistogramWeight  // Trọng số điểm
)
{
   ScoringFilterResult result;
   result.passed = false;
   result.score = 0;
   result.reason = "";
   result.value = 0;

   // Kiểm tra có đủ nến để tính trend không
   int lookback = macdHistogramLookback;
   if (lookback < 1)
      lookback = 1;
   if (idx + lookback >= arraySize)
   {
      result.reason = "Không đủ dữ liệu để tính MACD histogram, min 2 nến";
      return result;
   }

   // Tính histogram = MACD - Signal
   double histCurrent = macdMain[idx] - macdSignal[idx];
   double histPrev = macdMain[idx + lookback] - macdSignal[idx + lookback];

   result.value = histCurrent - histPrev;

   // Kiểm tra histogram trend
   bool histIncreasing = true;  // Giả định histogram đang tăng
   bool histDecreasing = true;  // Giả định histogram đang giảm

   for (int i = 0; i < lookback; i++)
   {
      // So sánh histogram[idx] với histogram[idx+1] (mới vs cũ)
      if (macdMain[idx + i] - macdSignal[idx + i] <= macdMain[idx + i + 1] - macdSignal[idx + i + 1])
         histIncreasing = false;  // Không tăng liên tục
      if (macdMain[idx + i] - macdSignal[idx + i] >= macdMain[idx + i + 1] - macdSignal[idx + i + 1])
         histDecreasing = false;  // Không giảm liên tục
   }

   // Logic đảo chiều:
   // - BUY signal + histogram đang giảm = bearish momentum đang mạnh lên
   // - SELL signal + histogram đang tăng = bullish momentum đang mạnh lên
   bool hasReversal = false;

   if (isBuySignal && histDecreasing)
   {
      hasReversal = true;
      result.reason = StringFormat("MACD Hist giảm ngược BUY (%.5f → %.5f)", histPrev, histCurrent);
   }
   else if (!isBuySignal && histIncreasing)
   {
      hasReversal = true;
      result.reason = StringFormat("MACD Hist tăng ngược SELL (%.5f → %.5f)", histPrev, histCurrent);
   }

   if (!hasReversal)
   {
      result.passed = true;
      result.score = macdHistogramWeight;
   }
   else
   {
      result.score = -macdHistogramWeight;
   }

   return result;
}

//+------------------------------------------------------------------+
//| MA TREND                                                         |
//| Kiểm tra giá có cùng xu hướng với MA không                       |
//| BUY: Giá đóng cửa trên MA                                        |
//| SELL: Giá đóng cửa dưới MA                                       |
//+------------------------------------------------------------------+
ScoringFilterResult CheckMATrend(bool isBuySignal, int idx, const double& close[], const double& ma[], double tickSize,
                                 double maTrendWeight  // Trọng số điểm
)
{
   ScoringFilterResult result;
   result.passed = false;
   result.score = 0;
   result.reason = "";
   result.value = close[idx] - ma[idx];

   // Helper functions inline
   bool maOk = false;
   if (isBuySignal)
      maOk = (close[idx] > ma[idx] + tickSize);
   else
      maOk = (close[idx] < ma[idx] - tickSize);

   if (maOk)
   {
      result.passed = true;
      result.score = maTrendWeight;
   }
   else
   {
      if (isBuySignal)
         result.reason = StringFormat("Sai MA BUY Trend (Close=%.5f không > MA=%.5f)", close[idx], ma[idx]);
      else
         result.reason = StringFormat("Sai MA SELL Trend (Close=%.5f không < MA=%.5f)", close[idx], ma[idx]);
      result.score = -maTrendWeight;
   }

   return result;
}

//+------------------------------------------------------------------+
//| S/R ZONE                                                         |
//| Kiểm tra giá có trong vùng entry tốt không                       |
//| BUY: Giá gần vùng support                                        |
//| SELL: Giá gần vùng resistance                                    |
//+------------------------------------------------------------------+
ScoringFilterResult CheckSRZone(bool isBuySignal, int idx, const double& close[],
                                double support,        // Giá hỗ trợ tại idx
                                double resistance,     // Giá kháng cự tại idx
                                double srZonePercent,  // % vùng S/R cho phép (30 = 30%)
                                double srZoneWeight    // Trọng số điểm
)
{
   ScoringFilterResult result;
   result.passed = false;
   result.score = 0;
   result.reason = "";
   result.value = 0;

   // Kiểm tra S/R hợp lệ
   if (support <= 0 || resistance <= 0 || resistance <= support)
   {
      result.reason = "Lỗi S/R";
      return result;
   }

   // Tính vùng entry cho phép
   double srRange = resistance - support;
   bool inZone = false;
   double limitPrice = 0;

   if (isBuySignal)
   {
      // BUY: Giá phải nằm trong vùng dưới (gần support)
      limitPrice = support + srRange * srZonePercent / 100.0;
      inZone = (close[idx] >= support && close[idx] <= limitPrice);
   }
   else
   {
      // SELL: Giá phải nằm trong vùng trên (gần resistance)
      limitPrice = resistance - srRange * srZonePercent / 100.0;
      inZone = (close[idx] <= resistance && close[idx] >= limitPrice);
   }

   result.value = limitPrice;

   if (inZone)
   {
      result.passed = true;
      result.score = srZoneWeight;
   }
   else
   {
      result.reason = StringFormat("Ngoài vùng S/R (Cl=%.5f, Lim=%.5f, S=%.5f, R=%.5f)", close[idx], limitPrice,
                                   support, resistance);
      result.score = -srZoneWeight;
   }

   return result;
}

//+------------------------------------------------------------------+
//| S/R MIN WIDTH (Độ rộng tối thiểu vùng S/R)                       |
//| Kiểm tra độ rộng tối thiểu vùng S/R để tránh cắt SL nhanh        |
//| Lọc các vùng S/R quá hẹp, tránh bị cắt SL nhanh                  |
//| Khoảng cách R-S phải >= minSRWidthATR * ATR                      |
//+------------------------------------------------------------------+
ScoringFilterResult CheckSRMinWidth(int idx, const double& atr[],
                                    double support,          // Giá hỗ trợ tại idx
                                    double resistance,       // Giá kháng cự tại idx
                                    double minSRWidthATR,    // Ngưỡng tối thiểu (bội số ATR)
                                    double srMinWidthWeight  // Trọng số điểm
)
{
   ScoringFilterResult result;
   result.passed = false;
   result.score = 0;
   result.reason = "";
   result.value = 0;

   // Tính độ rộng vùng S/R theo bội số ATR
   double srRange = resistance - support;
   double srRangeATR = srRange / atr[idx];
   result.value = srRangeATR;

   // Kiểm tra >= ngưỡng
   if (srRangeATR >= minSRWidthATR)
   {
      result.passed = true;
      result.score = srMinWidthWeight;
   }
   else
   {
      result.reason = StringFormat("S/R hẹp (%.2f ATR < %.2f ATR)", srRangeATR, minSRWidthATR);
      result.score = -srMinWidthWeight;
   }

   return result;
}

//+------------------------------------------------------------------+
//| ADX - Kiểm tra sức mạnh xu hướng bằng ADX                        |
//| Kiểm tra thị trường có đang trending không                       |
//| ADX > threshold = trending, nên vào lệnh                         |
//| ADX < threshold = sideway, nên tránh                             |
//+------------------------------------------------------------------+
ScoringFilterResult CheckADX(bool isBuySignal, int idx, const double& adxMain[], const double& adxPlusDI[],
                             const double& adxMinusDI[],
                             double minADXThreshold,         // Ngưỡng ADX tối thiểu (thường 20-25)
                             bool useADXDirectionalConfirm,  // Kiểm tra thêm +DI/-DI
                             double adxWeight                // Trọng số điểm
)
{
   ScoringFilterResult result;
   result.passed = false;
   result.score = 0;
   result.reason = "";
   result.value = 0;

   result.value = adxMain[idx];

   // ADX phải >= ngưỡng (thị trường đang trending)
   if (adxMain[idx] < minADXThreshold)
   {
      result.reason = StringFormat("ADX yếu (%.2f < %.2f)", adxMain[idx], minADXThreshold);
      result.score = -adxWeight;
      return result;
   }

   // Kiểm tra +DI/-DI nếu bật
   if (useADXDirectionalConfirm)
   {
      if (isBuySignal && adxPlusDI[idx] <= adxMinusDI[idx])
      {
         result.reason = StringFormat("+DI (%.2f) <= -DI (%.2f)", adxPlusDI[idx], adxMinusDI[idx]);
         result.score = -adxWeight;
         return result;
      }
      if (!isBuySignal && adxMinusDI[idx] <= adxPlusDI[idx])
      {
         result.reason = StringFormat("-DI (%.2f) <= +DI (%.2f)", adxMinusDI[idx], adxPlusDI[idx]);
         result.score = -adxWeight;
         return result;
      }
   }

   result.passed = true;
   result.score = adxWeight;
   return result;
}

//+------------------------------------------------------------------+
//| BODY/ATR RATIO                                                   |
//| Kiểm tra body nến confirmation có đủ lớn không                   |
//| Body phải đủ lớn so với ATR để tránh nến indecision              |
//+------------------------------------------------------------------+
ScoringFilterResult CheckBodyATR(bool isBuySignal, int idx, const double& open[], const double& close[],
                                 const double& atr[],
                                 double minBodyATRRatio,  // Tỷ lệ tối thiểu (0.3 = 30% ATR)
                                 double bodyATRWeight     // Trọng số điểm
)
{
   ScoringFilterResult result;
   result.passed = false;
   result.score = 0;
   result.reason = "";
   result.value = 0;

   // Tính body size
   double body = MathAbs(close[idx] - open[idx]);

   result.value = body / atr[idx];

   if (result.value >= minBodyATRRatio)
   {
      result.passed = true;
      result.score = bodyATRWeight;
   }
   else
   {
      result.reason = StringFormat("Body/ATR nhỏ (%.2f < %.2f)", result.value, minBodyATRRatio);
      result.score = -bodyATRWeight;
   }

   return result;
}

//+------------------------------------------------------------------+
//| VOLUME (xác nhận khối lượng)                                     |
//| Kiểm tra volume nến confirmation có cao hơn trung bình không     |
//| Volume cao = nhiều người tham gia = tín hiệu mạnh hơn            |
//+------------------------------------------------------------------+
ScoringFilterResult CheckVolume(int idx, const long& volume[], int arraySize,
                                int volumeAvgPeriod,    // Chu kỳ tính volume trung bình
                                double minVolumeRatio,  // Tỷ lệ tối thiểu (1.0 = 100%)
                                double volumeWeight     // Trọng số điểm
)
{
   ScoringFilterResult result;
   result.passed = false;
   result.score = 0;
   result.reason = "";
   result.value = 0;

   // Tính volume trung bình
   double avgVolume = 0;
   int avgBars = MathMin(volumeAvgPeriod, arraySize - idx - 1);
   for (int i = 1; i <= avgBars; i++)
      avgVolume += (double)volume[idx + i];
   if (avgBars > 0)
      avgVolume = avgVolume / avgBars;

   if (avgVolume <= 0)
   {
      result.reason = "Không có volume";
      return result;
   }

   result.value = (double)volume[idx] / avgVolume;

   if (result.value >= minVolumeRatio)
   {
      result.passed = true;
      result.score = volumeWeight;
   }
   else
   {
      result.reason = StringFormat("Volume thấp (%.2f%% < %.2f%%), Avg vol: %.0f", result.value * 100,
                                   minVolumeRatio * 100, avgVolume);
      result.score = -volumeWeight;
   }

   return result;
}

//+------------------------------------------------------------------+
//| PRICE-MA DISTANCE                                                |
//| Kiểm tra giá có quá xa MA không (tránh chase)                    |
//| Nếu quá xa = đã miss entry, không nên chase                      |
//+------------------------------------------------------------------+
ScoringFilterResult CheckPriceMADist(int idx, const double& close[], const double& ma[], const double& atr[],
                                     int arraySize,
                                     double maxPriceMADistATR,  // Khoảng cách tối đa (bội số ATR)
                                     double priceMADistWeight   // Trọng số điểm
)
{
   ScoringFilterResult result;
   result.passed = false;
   result.score = 0;
   result.reason = "";
   result.value = 0;

   // Tính khoảng cách giá-MA theo bội số ATR
   double distance = MathAbs(close[idx] - ma[idx]);
   result.value = distance / atr[idx];

   if (result.value <= maxPriceMADistATR)
   {
      result.passed = true;
      result.score = priceMADistWeight;
   }
   else
   {
      result.reason = StringFormat("Giá xa MA (%.1f ATR > %.1f ATR)", result.value, maxPriceMADistATR);
      result.score = -priceMADistWeight;
   }

   return result;
}

//+------------------------------------------------------------------+
//| TIME                                                             |
//| Kiểm tra có trong khung giờ giao dịch không                      |
//| Chỉ giao dịch trong khung giờ được chỉ định                      |
//| Tránh giờ ít thanh khoản hoặc spread cao                         |
//+------------------------------------------------------------------+
ScoringFilterResult CheckTime(datetime currentTime,
                              int tradeStartHour,  // Giờ bắt đầu (0-23)
                              int tradeEndHour,    // Giờ kết thúc (0-23)
                              double timeWeight    // Trọng số điểm

)
{
   ScoringFilterResult result;
   result.passed = false;
   result.score = 0;
   result.reason = "";
   result.value = 0;

   MqlDateTime timeStruct;
   TimeToStruct(currentTime, timeStruct);
   int currentHour = timeStruct.hour;
   result.value = currentHour;

   // Xử lý wrap around (ví dụ: 22:00 - 06:00)
   bool inRange;
   if (tradeStartHour <= tradeEndHour)
      inRange = (currentHour >= tradeStartHour && currentHour < tradeEndHour);
   else
      inRange = (currentHour >= tradeStartHour || currentHour < tradeEndHour);

   if (inRange)
   {
      result.passed = true;
      result.score = timeWeight;
   }
   else
   {
      result.reason = StringFormat("Ngoài giờ GD (%02d:00, cần %02d-%02d)", currentHour, tradeStartHour, tradeEndHour);
      result.score = -timeWeight;
   }

   return result;
}

//+------------------------------------------------------------------+
//| NEWS                                                             |
//| Kiểm tra có tin tức quan trọng sắp ra không                      |
//| Tránh giao dịch trước/sau tin quan trọng                         |
//| Sử dụng MQL5 Economic Calendar API                               |
//+------------------------------------------------------------------+
ScoringFilterResult CheckNews(string symbol, datetime currentTime,
                              int newsMinutesBefore,  // Phút trước tin cần tránh
                              int newsMinutesAfter,   // Phút sau tin cần tránh
                              int newsMinImportance,  // Mức quan trọng (1=Low, 2=Med, 3=High)
                              double newsWeight       // Trọng số điểm
)
{
   ScoringFilterResult result;
   result.passed = false;
   result.score = 0;
   result.reason = "";
   result.value = 0;

   // Lấy currency từ symbol (ví dụ: EURUSD -> EUR và USD)
   string baseCurrency = StringSubstr(symbol, 0, 3);
   string quoteCurrency = StringSubstr(symbol, 3, 3);

   // Khoảng thời gian cần kiểm tra
   datetime timeFrom = currentTime - newsMinutesBefore * 60;
   datetime timeTo = currentTime + newsMinutesAfter * 60;

   // Kiểm tra tin cho base currency
   MqlCalendarValue values[];
   int count = CalendarValueHistory(values, timeFrom, timeTo, NULL, baseCurrency);
   for (int i = 0; i < count; i++)
   {
      MqlCalendarEvent event;
      if (CalendarEventById(values[i].event_id, event))
      {
         // newsMinImportance: 1=Low, 2=Medium, 3=High
         // event.importance: 0=None, 1=Low, 2=Medium, 3=High
         if ((int)event.importance >= newsMinImportance + 1)
         {
            int minutes = (int)((values[i].time - currentTime) / 60);
            result.reason = StringFormat("Tin %s (%d p)", baseCurrency, minutes);
            result.score = -newsWeight;
            return result;
         }
      }
   }

   // Kiểm tra tin cho quote currency
   MqlCalendarValue quoteValues[];
   count = CalendarValueHistory(quoteValues, timeFrom, timeTo, NULL, quoteCurrency);
   for (int i = 0; i < count; i++)
   {
      MqlCalendarEvent event;
      if (CalendarEventById(quoteValues[i].event_id, event))
      {
         if ((int)event.importance >= newsMinImportance + 1)
         {
            int minutes = (int)((quoteValues[i].time - currentTime) / 60);
            result.reason = StringFormat("Tin %s (%d p)", quoteCurrency, minutes);
            result.score = -newsWeight;
            return result;
         }
      }
   }

   result.passed = true;
   result.score = newsWeight;
   return result;
}

#endif  // SIGNAL_FILTERS_H
