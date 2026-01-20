//+------------------------------------------------------------------+
//|                                          Trendline Module        |
//|                                    Copyright 2026, Do Nhat Phong |
//|                                   https://github.com/nhatphongdo |
//+------------------------------------------------------------------+
//| Module phát hiện và validate Trendlines (Top & Bottom)           |
//| Note: Sử dụng datetime thay vì index để dữ liệu ổn định khi có   |
//|       bar mới (index sẽ shift, datetime thì không)               |
//+------------------------------------------------------------------+
#property copyright "Do Nhat Phong"

#ifndef TRENDLINE_H
#define TRENDLINE_H

#include "Utility.mqh"

// ==================================================
// ================== ENUMS =========================
// ==================================================

enum ENUM_TRENDLINE_TYPE
{
   TRENDLINE_TOP,    // Top Trendline (Resistance - nối swing highs)
   TRENDLINE_BOTTOM  // Bottom Trendline (Support - nối swing lows)
};

enum ENUM_SLOPE_TYPE
{
   SLOPE_PRICE_DEVIATION,  // Độ lệch giá mỗi nến (price/bar)
   SLOPE_ATR_PERCENT       // % ATR mỗi nến (%ATR/bar)
};

enum ENUM_SWING_SOURCE
{
   SWING_SOURCE_HIGHLOW,  // Swing High = High, Swing Low = Low (Default)
   SWING_SOURCE_BODY      // Swing High = Max(Open, Close), Swing Low = Min(Open, Close)
};

// ==================================================
// ================== STRUCTS =======================
// ==================================================

//+------------------------------------------------------------------+
//| Cấu hình cho Trendline Detection                                 |
//+------------------------------------------------------------------+
struct TrendlineConfig
{
   // Swing detection
   int swingPeriod;                // Số nến trước/sau để xác định swing (Default: 3)
   ENUM_SWING_SOURCE swingSource;  // Nguồn giá để tính swing points

   // Touch validation
   int minTouchPoints;       // Số điểm chạm tối thiểu (Default: 3)
   double tolerancePercent;  // Tolerance % ATR cho touch & breakout (Default: 1.0)

   // Slope validation
   ENUM_SLOPE_TYPE slopeType;  // Loại slope để validate
   double minSlope;            // Min slope (theo type)
   double maxSlope;            // Max slope (theo type)

   // Time validation
   int minTimeSpan;  // Min nến giữa điểm đầu-cuối (Default: 10)
   int minTouchGap;  // Min gap giữa các touch points (Default: 3)

   // ATR settings
   int atrPeriod;  // Số nến tính ATR (Default: 14)
};

//+------------------------------------------------------------------+
//| Dữ liệu của một Trendline                                        |
//| Lưu ý: Sử dụng datetime thay vì index để dữ liệu ổn định         |
//+------------------------------------------------------------------+
struct TrendlineData
{
   ENUM_TRENDLINE_TYPE type;  // Top hoặc Bottom
   double slope;              // Slope (theo slopeType trong config)
   double slopePrice;         // Slope tính bằng giá/bar
   double slopeAtrPercent;    // Slope tính bằng %ATR/bar
   double intercept;          // Tung độ gốc (y = slope*x + intercept, x = bar offset)
   datetime startTime;        // Thời gian điểm đầu (xa nhất - cũ nhất)
   datetime endTime;          // Thời gian điểm cuối (gần nhất - mới nhất)
   double startPrice;         // Giá tại điểm đầu
   double endPrice;           // Giá tại điểm cuối
   int touchCount;            // Số lần chạm
   datetime touchTimes[];     // Mảng thời gian các điểm chạm
   double touchPrices[];      // Mảng giá tại các điểm chạm
   int breakoutCount;         // Số lượng breakout
   datetime breakoutTimes[];  // Mảng thời gian các breakout
   double breakoutPrices[];   // Mảng giá tại các breakout
   bool isCompleted;          // true = đã hoàn thiện (gặp đảo trend hoặc confirmed breakout)
   double score;              // Điểm đánh giá (0-100)
   bool isValid;              // Hợp lệ sau validation
   string invalidReason;      // Lý do không hợp lệ
};

//+------------------------------------------------------------------+
//| Swing point data (lưu datetime thay vì index)                    |
//+------------------------------------------------------------------+
struct SwingPointData
{
   datetime time;  // Thời gian swing point
   double price;   // Giá tại swing point
};

//+------------------------------------------------------------------+
//| Swing point group (nhóm swing points cùng hướng trend)           |
//+------------------------------------------------------------------+
struct SwingPointGroup
{
   SwingPointData points[];  // Các swing points trong group
   bool isUptrend;           // true = giá tăng theo thời gian
   datetime startTime;       // Thời gian xa nhất (cũ nhất)
   datetime endTime;         // Thời gian gần nhất (mới nhất)
};

// ==================================================
// ============ CONFIG INITIALIZATION ===============
// ==================================================

//+------------------------------------------------------------------+
//| Khởi tạo TrendlineConfig với giá trị mặc định                    |
//+------------------------------------------------------------------+
void GetDefaultTrendlineConfig(TrendlineConfig& config)
{
   config.swingPeriod = 3;
   config.swingSource = SWING_SOURCE_HIGHLOW;
   config.minTouchPoints = 3;
   config.tolerancePercent = 1.0;  // Dùng chung cho touch & breakout
   config.slopeType = SLOPE_ATR_PERCENT;
   config.minSlope = 0.01;  // 0.01% ATR/bar (tránh đường ngang)
   config.maxSlope = 50.0;  // 50% ATR/bar (tránh đường quá dốc)
   config.minTimeSpan = 10;
   config.minTouchGap = 3;
   config.atrPeriod = 14;
}

// ==================================================
// =========== DATETIME/INDEX UTILITIES =============
// ==================================================

//+------------------------------------------------------------------+
//| Tìm index từ datetime trong mảng time[]                          |
//| Return: index của bar trên chart nếu tìm thấy, -1 nếu không      |
//+------------------------------------------------------------------+
int FindIndexByTime(const datetime& time[], int arraySize, datetime targetTime)
{
   for (int i = 0; i < arraySize; i++)
   {
      if (time[i] == targetTime)
         return i;
      // time[] đã SetAsSeries nên index 0 = mới nhất
      // Nếu targetTime > time[i] thì không cần tìm tiếp
      if (time[i] < targetTime && i > 0)
         return -1;
   }
   return -1;
}

//+------------------------------------------------------------------+
//| Tính giá tại thời điểm bất kỳ trên trendline                     |
//| Sử dụng bar offset từ startTime                                  |
//+------------------------------------------------------------------+
double GetPriceAtTime(const TrendlineData& trendline, datetime targetTime, const datetime& time[], int arraySize)
{
   // Tìm index của startTime và targetTime
   int startIdx = FindIndexByTime(time, arraySize, trendline.startTime);  // Time cũ nhưng index lớn
   int targetIdx = FindIndexByTime(time, arraySize, targetTime);          // Time mới nhưng index nhỏ hơn

   if (startIdx < 0 || targetIdx < 0)
      return 0;

   // Trendline đi từ cũ đến mới, nhưng chart index thì từ mới tới cũ, do đó startIdx > targetIdx, cần trừ ngược để lấy
   // offset trên trendline
   return GetPriceAtOffset(trendline.slopePrice, trendline.startPrice, startIdx - targetIdx);
}

//+------------------------------------------------------------------+
//| Tính giá tại index bất kỳ trên trendline (dùng nội bộ)           |
//| offset là số nến từ điểm đầu tiên của trendline (time cũ)        |
//+------------------------------------------------------------------+
double GetPriceAtOffset(double slopePrice, double startPrice, int offset)
{
   return startPrice + slopePrice * offset;
}

// ==================================================
// ============= SWING DETECTION ====================
// ==================================================

//+------------------------------------------------------------------+
//| Kiểm tra nến có phải Swing High không                            |
//| Swing High: high[i] >= max(high của N nến trước và N nến sau)    |
//+------------------------------------------------------------------+
bool IsSwingHigh(int index, int swingPeriod, const double& high[], int arraySize)
{
   // Kiểm tra bounds
   if (index < swingPeriod || index >= arraySize - swingPeriod)
      return false;

   double currentHigh = high[index];

   // Kiểm tra N nến trước (index nhỏ hơn = mới hơn trong series)
   for (int i = 1; i <= swingPeriod; i++)
   {
      if (high[index - i] > currentHigh)
         return false;
   }

   // Kiểm tra N nến sau (index lớn hơn = cũ hơn trong series)
   for (int i = 1; i <= swingPeriod; i++)
   {
      if (high[index + i] > currentHigh)
         return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| Kiểm tra nến có phải Swing Low không                             |
//| Swing Low: low[i] <= min(low của N nến trước và N nến sau)       |
//+------------------------------------------------------------------+
bool IsSwingLow(int index, int swingPeriod, const double& low[], int arraySize)
{
   // Kiểm tra bounds
   if (index < swingPeriod || index >= arraySize - swingPeriod)
      return false;

   double currentLow = low[index];

   // Kiểm tra N nến trước
   for (int i = 1; i <= swingPeriod; i++)
   {
      if (low[index - i] < currentLow)
         return false;
   }

   // Kiểm tra N nến sau
   for (int i = 1; i <= swingPeriod; i++)
   {
      if (low[index + i] < currentLow)
         return false;
   }

   return true;
}

// ==================================================
// ============= TRENDLINE UTILITIES ================
// ==================================================

//+------------------------------------------------------------------+
//| Linear regression để tìm best-fit line từ các điểm               |
//| indices: bar offsets từ một điểm gốc                             |
//| Trả về slope và intercept tính theo y = slope*x + intercept      |
//+------------------------------------------------------------------+
void LinearRegression(const int& indices[], const double& prices[], int count, double& outSlope, double& outIntercept)
{
   if (count < 2)
   {
      outSlope = 0;
      outIntercept = (count > 0) ? prices[0] : 0;
      return;
   }

   // Convert int[] sang double[] để dùng CalculateLinearRegressionLine
   double xArr[];
   ArrayResize(xArr, count);
   for (int i = 0; i < count; i++)
      xArr[i] = (double)indices[i];

   CalculateLinearRegressionLine(xArr, prices, count, outSlope, outIntercept);
}

//+------------------------------------------------------------------+
//| Validate một trendline theo config                               |
//| Trả về true nếu hợp lệ, set invalidReason nếu không              |
//+------------------------------------------------------------------+
bool ValidateTrendline(const datetime& time[], int arraySize, TrendlineData& trendline, int timeSpanBars,
                       const TrendlineConfig& config)
{
   trendline.isValid = true;
   trendline.invalidReason = "";

   // 1. Check touch count
   if (trendline.touchCount < config.minTouchPoints)
   {
      trendline.isValid = false;
      trendline.invalidReason =
          StringFormat("Số lượng touch points không đủ %d < min %d", trendline.touchCount, config.minTouchPoints);
      return false;
   }

   // 2. Check time span (số bars giữa start và end)
   if (timeSpanBars < config.minTimeSpan)
   {
      trendline.isValid = false;
      trendline.invalidReason = StringFormat("Độ dài trendline quá ngắn %d < min %d", timeSpanBars, config.minTimeSpan);
      return false;
   }

   // 3. Check slope range
   double slopeToCheck =
       (config.slopeType == SLOPE_ATR_PERCENT) ? MathAbs(trendline.slopeAtrPercent) : MathAbs(trendline.slopePrice);

   if (slopeToCheck < config.minSlope)
   {
      trendline.isValid = false;
      trendline.invalidReason = StringFormat("Slope %.4f < min %.4f (đường quá ngang)", slopeToCheck, config.minSlope);
      return false;
   }

   if (slopeToCheck > config.maxSlope)
   {
      trendline.isValid = false;
      trendline.invalidReason = StringFormat("Slope %.4f > max %.4f (đường quá dốc)", slopeToCheck, config.maxSlope);
      return false;
   }

   // 4. Check touch gap - cần convert times thành indices để check gap
   int touchIndices[];
   ArrayResize(touchIndices, trendline.touchCount);
   for (int i = 0; i < trendline.touchCount; i++)
   {
      touchIndices[i] = FindIndexByTime(time, arraySize, trendline.touchTimes[i]);
      if (touchIndices[i] < 0)
      {
         trendline.isValid = false;
         trendline.invalidReason =
             StringFormat("Lỗi touch point tại thời gian %s không tìm thấy", TimeToString(trendline.touchTimes[i]));
         return false;
      }
   }

   for (int i = 0; i < trendline.touchCount - 1; i++)
   {
      int gap = touchIndices[i] - touchIndices[i + 1];
      if (gap < config.minTouchGap)
      {
         trendline.isValid = false;
         trendline.invalidReason =
             StringFormat("Khoảng cách 2 touch points quá nhỏ %d < min %d", gap, config.minTouchGap);
         return false;
      }
   }

   return true;
}

//+------------------------------------------------------------------+
//| Tính score cho trendline (0-100)                                 |
//| Factors: touch count, time span, recency, consistency            |
//+------------------------------------------------------------------+
double CalculateTrendlineScore(const TrendlineData& trendline, int timeSpanBars, int distanceFromCurrent)
{
   double score = 0;

   // 1. Touch count score (max 40 points)
   // 3 touches = 20pts, mỗi touch thêm = +5pts, max 40pts (7+ touches)
   score += MathMin(40, 20 + (trendline.touchCount - 3) * 5);

   // 2. Time span score (max 25 points)
   // Longer = better, 10 bars = 10pts, 50+ bars = 25pts
   score += MathMin(25, 10 + (timeSpanBars - 10) * 0.375);

   // 3. Recency score (max 20 points)
   // Trendline gần hơn với current = score cao hơn
   if (distanceFromCurrent <= 5)
      score += 20;
   else if (distanceFromCurrent <= 10)
      score += 15;
   else if (distanceFromCurrent <= 20)
      score += 10;
   else
      score += 5;

   // 4. Consistency score (max 15 points) - simplified
   if (trendline.touchCount >= 4)
      score += 15;
   else if (trendline.touchCount >= 3)
      score += 10;

   return MathMin(100, MathMax(0, score));
}

// ==================================================
// ========= BEST-FIT TRENDLINE DETECTION ===========
// ==================================================

//+------------------------------------------------------------------+
//| Tìm breakouts trong khoảng [startIdx, endIdx]                    |
//| Return: số lượng breakouts tìm được                              |
//+------------------------------------------------------------------+
int FindBreakouts(ENUM_TRENDLINE_TYPE type, double slopePrice, double startPrice,
                  int startIdx,  // Index của startTime
                  int endIdx,    // Index của endTime (nhỏ hơn startIdx)
                  const double& close[], const datetime& time[], int arraySize, double tolerance,
                  datetime& outBreakoutTimes[], double& outBreakoutPrices[])
{
   ArrayResize(outBreakoutTimes, 0);
   ArrayResize(outBreakoutPrices, 0);
   int count = 0;

   for (int i = startIdx; i >= endIdx; i--)
   {
      double trendlinePrice = GetPriceAtOffset(slopePrice, startPrice, startIdx - i);

      bool isBreakout = false;
      if (type == TRENDLINE_TOP)
      {
         // Top: breakout khi close vượt trên trendline + tolerance
         isBreakout = (close[i] > trendlinePrice + tolerance);
      }
      else
      {
         // Bottom: breakout khi close xuống dưới trendline - tolerance
         isBreakout = (close[i] < trendlinePrice - tolerance);
      }

      if (isBreakout)
      {
         ArrayResize(outBreakoutTimes, count + 1);
         ArrayResize(outBreakoutPrices, count + 1);
         outBreakoutTimes[count] = time[i];
         outBreakoutPrices[count] = close[i];
         count++;
      }
   }

   return count;
}

//+------------------------------------------------------------------+
//| Kiểm tra 2 trendlines có trùng lặp không                         |
//| So sánh startTime và slope                                        |
//+------------------------------------------------------------------+
bool IsDuplicateTrendline(const TrendlineData& tl1, const TrendlineData& tl2, double slopeTolerance = 0.15)
{
   // Nếu khác loại thì không trùng
   if (tl1.type != tl2.type)
      return false;

   // Nếu slope quá giống nhau (trong khoảng tolerance %)
   if (MathAbs(tl1.slopePrice) > 0 && MathAbs(tl2.slopePrice) > 0)
   {
      double slopeDiff =
          MathAbs(tl1.slopePrice - tl2.slopePrice) / MathMax(MathAbs(tl1.slopePrice), MathAbs(tl2.slopePrice));
      if (slopeDiff < slopeTolerance)
      {
         // Kiểm tra thêm nếu startTime trùng nhau
         if (tl1.startTime == tl2.startTime || tl1.endTime == tl2.endTime)
            return true;
      }
   }

   return false;
}

//+------------------------------------------------------------------------+
//| Phân đoạn Swing Points thành các nhóm đơn điệu (Increasing/Decreasing) |
//| Thuật toán: Duyệt tuần tự, ngắt nhóm khi đổi hướng hoặc bằng giá       |
//+------------------------------------------------------------------------+
void SegmentMonotonicPoints(const SwingPointData& points[], SwingPointGroup& outIncGroups[],
                            SwingPointGroup& outDecGroups[])
{
   ArrayResize(outIncGroups, 0);
   ArrayResize(outDecGroups, 0);

   int count = ArraySize(points);
   if (count == 0)
      return;

   // Init first group with first point
   SwingPointData currentGroup[];
   ArrayResize(currentGroup, 1);
   currentGroup[0] = points[0];

   int currentTrend = 0;  // 0: Đi ngang, 1: Tăng, -1: Giảm

   for (int i = 1; i < count; i++)
   {
      double valCurrent = points[i].price;
      double valLast = currentGroup[ArraySize(currentGroup) - 1].price;

      int stepTrend = 0;
      if (valCurrent > valLast)
         stepTrend = 1;  // Tăng (Val[i] > Val[i-1])
      else if (valCurrent < valLast)
         stepTrend = -1;  // Giảm
      else
         stepTrend = 0;  // Đi ngang

      bool breakGroup = false;

      if (currentTrend == 0)  // Chưa có trend
      {
         if (stepTrend == 0)
            breakGroup = true;
         else
         {
            currentTrend = stepTrend;
            int s = ArraySize(currentGroup);
            ArrayResize(currentGroup, s + 1);
            currentGroup[s] = points[i];
         }
      }
      else  // Trend đã được xác định
      {
         if (stepTrend == currentTrend)
         {
            int s = ArraySize(currentGroup);
            ArrayResize(currentGroup, s + 1);
            currentGroup[s] = points[i];
         }
         else  // Trend thay đổi hoặc bằng giá -> Break
         {
            breakGroup = true;
         }
      }

      if (breakGroup)
      {
         // Lưu group hiện tại nếu hợp lệ
         if (ArraySize(currentGroup) >= 2)
         {
            if (currentTrend == 1)  // Tăng
            {
               int gIdx = ArraySize(outIncGroups);
               ArrayResize(outIncGroups, gIdx + 1);
               ArrayResize(outIncGroups[gIdx].points, ArraySize(currentGroup));
               ArrayCopy(outIncGroups[gIdx].points, currentGroup);
               outIncGroups[gIdx].isUptrend = true;

               // Fill Time range
               outIncGroups[gIdx].startTime = currentGroup[ArraySize(currentGroup) - 1].time;
               outIncGroups[gIdx].endTime = currentGroup[0].time;
            }
            else if (currentTrend == -1)  // Giảm
            {
               int gIdx = ArraySize(outDecGroups);
               ArrayResize(outDecGroups, gIdx + 1);
               ArrayResize(outDecGroups[gIdx].points, ArraySize(currentGroup));
               ArrayCopy(outDecGroups[gIdx].points, currentGroup);
               outDecGroups[gIdx].isUptrend = false;

               outDecGroups[gIdx].startTime = currentGroup[ArraySize(currentGroup) - 1].time;
               outDecGroups[gIdx].endTime = currentGroup[0].time;
            }
         }

         // Bắt đầu group mới từ điểm hiện tại i
         ArrayResize(currentGroup, 1);
         currentGroup[0] = points[i];
         currentTrend = 0;
      }
   }

   // Xử lý group cuối cùng
   if (ArraySize(currentGroup) >= 2 && currentTrend != 0)
   {
      if (currentTrend == 1)
      {
         int gIdx = ArraySize(outIncGroups);
         ArrayResize(outIncGroups, gIdx + 1);
         ArrayResize(outIncGroups[gIdx].points, ArraySize(currentGroup));
         ArrayCopy(outIncGroups[gIdx].points, currentGroup);
         outIncGroups[gIdx].isUptrend = true;
         outIncGroups[gIdx].startTime = currentGroup[ArraySize(currentGroup) - 1].time;
         outIncGroups[gIdx].endTime = currentGroup[0].time;
      }
      else if (currentTrend == -1)
      {
         int gIdx = ArraySize(outDecGroups);
         ArrayResize(outDecGroups, gIdx + 1);
         ArrayResize(outDecGroups[gIdx].points, ArraySize(currentGroup));
         ArrayCopy(outDecGroups[gIdx].points, currentGroup);
         outDecGroups[gIdx].isUptrend = false;
         outDecGroups[gIdx].startTime = currentGroup[ArraySize(currentGroup) - 1].time;
         outDecGroups[gIdx].endTime = currentGroup[0].time;
      }
   }
}

//+------------------------------------------------------------------+
//| Phát hiện tất cả Trendlines (Top và/hoặc Bottom)                 |
//| Thuật toán: Monotonic Segmentation & Pair-wise Detection         |
//| Return: Số lượng trendlines tìm được                             |
//+------------------------------------------------------------------+
int DetectTrendlines(const double& high[], const double& low[], const double& open[], const double& close[],
                     const datetime& time[], const double& atr[], int arraySize,
                     int startIndex,    // Index của nến bắt đầu quét
                     int lookbackBars,  // Số nến quét (từ index 0)
                     const TrendlineConfig& config, TrendlineData& outTrendlines[],
                     bool detectTop = true,    // Detect Top Trendlines
                     bool detectBottom = true  // Detect Bottom Trendlines
)
{
   // Validate input
   if (arraySize < config.swingPeriod * 2 + config.minTouchPoints)
   {
      ArrayResize(outTrendlines, 0);
      return 0;
   }

   // Nếu lookbackBars <= 0, quét toàn bộ dữ liệu
   int effectiveLookback = (lookbackBars <= 0) ? arraySize : lookbackBars;
   int maxIndex = MathMin(effectiveLookback, arraySize - config.swingPeriod);
   int minIndex = MathMax(startIndex, config.swingPeriod);

   // ==================================================
   // Bước 1: Tìm tất cả swing points (từ cũ đến mới)
   // ==================================================

   // Chuẩn bị source arrays dựa trên config
   double srcHigh[];
   double srcLow[];
   bool useBody = (config.swingSource == SWING_SOURCE_BODY);

   if (useBody)
   {
      ArrayResize(srcHigh, arraySize);
      ArrayResize(srcLow, arraySize);
      for (int i = 0; i < arraySize; i++)
      {
         srcHigh[i] = MathMax(open[i], close[i]);
         srcLow[i] = MathMin(open[i], close[i]);
      }
   }

   SwingPointData swingHighs[];
   int swingHighCount = 0;

   SwingPointData swingLows[];
   int swingLowCount = 0;

   for (int i = maxIndex - 1; i >= minIndex; i--)
   {
      if (detectTop)
      {
         bool isHigh = false;
         double price = 0;

         if (useBody)
         {
            isHigh = IsSwingHigh(i, config.swingPeriod, srcHigh, arraySize);
            price = srcHigh[i];
         }
         else
         {
            isHigh = IsSwingHigh(i, config.swingPeriod, high, arraySize);
            price = high[i];
         }

         if (isHigh)
         {
            ArrayResize(swingHighs, swingHighCount + 1);
            swingHighs[swingHighCount].time = time[i];
            swingHighs[swingHighCount].price = price;
            swingHighCount++;
         }
      }

      if (detectBottom)
      {
         bool isLow = false;
         double price = 0;

         if (useBody)
         {
            isLow = IsSwingLow(i, config.swingPeriod, srcLow, arraySize);
            price = srcLow[i];
         }
         else
         {
            isLow = IsSwingLow(i, config.swingPeriod, low, arraySize);
            price = low[i];
         }

         if (isLow)
         {
            ArrayResize(swingLows, swingLowCount + 1);
            swingLows[swingLowCount].time = time[i];
            swingLows[swingLowCount].price = price;
            swingLowCount++;
         }
      }
   }

   // ==================================================
   // Bước 2: Segment Swing Points thành groups Monotonic
   // ==================================================

   // Highs Groups (Top)
   SwingPointGroup highIncGroups[];  // Indices tăng -> New > Old (Giá tăng) -> Slope > 0 (HH)
   SwingPointGroup highDecGroups[];  // Indices tăng -> New < Old (Giá giảm) -> Slope < 0 (LH)
   if (detectTop)
      SegmentMonotonicPoints(swingHighs, highIncGroups, highDecGroups);

   // Lows Groups (Bottom)
   SwingPointGroup lowIncGroups[];  // Indices tăng -> New > Old (Giá tăng) -> Slope > 0 (HL)
   SwingPointGroup lowDecGroups[];  // Indices tăng -> New < Old (Giá giảm) -> Slope < 0 (LL)
   if (detectBottom)
      SegmentMonotonicPoints(swingLows, lowIncGroups, lowDecGroups);

   TrendlineData tempTrendlines[];
   int trendlineCount = 0;

   // 2a. Detect from HH (High Inc Groups, Slope > 0)
   for (int g = 0; g < ArraySize(highIncGroups); g++)
   {
      TrendlineData found[];
      int count = FindTrendlinesFromPoints(highIncGroups[g].points, TRENDLINE_TOP, high, low, open, close, time, atr,
                                           arraySize, config, found);
      for (int i = 0; i < count; i++)
      {
         ArrayResize(tempTrendlines, trendlineCount + 1);
         tempTrendlines[trendlineCount++] = found[i];
      }
   }

   // 2b. Detect from LH (High Dec Groups, Slope < 0)
   for (int g = 0; g < ArraySize(highDecGroups); g++)
   {
      TrendlineData found[];
      int count = FindTrendlinesFromPoints(highDecGroups[g].points, TRENDLINE_TOP, high, low, open, close, time, atr,
                                           arraySize, config, found);
      for (int i = 0; i < count; i++)
      {
         ArrayResize(tempTrendlines, trendlineCount + 1);
         tempTrendlines[trendlineCount++] = found[i];
      }
   }

   // 2c. Detect from HL (Low Inc Groups, Slope > 0)
   for (int g = 0; g < ArraySize(lowIncGroups); g++)
   {
      TrendlineData found[];
      int count = FindTrendlinesFromPoints(lowIncGroups[g].points, TRENDLINE_BOTTOM, high, low, open, close, time, atr,
                                           arraySize, config, found);
      for (int i = 0; i < count; i++)
      {
         ArrayResize(tempTrendlines, trendlineCount + 1);
         tempTrendlines[trendlineCount++] = found[i];
      }
   }

   // 2d. Detect from LL (Low Dec Groups, Slope < 0)
   for (int g = 0; g < ArraySize(lowDecGroups); g++)
   {
      TrendlineData found[];
      int count = FindTrendlinesFromPoints(lowDecGroups[g].points, TRENDLINE_BOTTOM, high, low, open, close, time, atr,
                                           arraySize, config, found);
      for (int i = 0; i < count; i++)
      {
         ArrayResize(tempTrendlines, trendlineCount + 1);
         tempTrendlines[trendlineCount++] = found[i];
      }
   }

   // ==================================================
   // Bước 3: Post-processing (Validate & Score)
   // ==================================================
   datetime minStartTime = 0;
   datetime maxEndTime = 0;
   for (int i = 0; i < trendlineCount; i++)
   {
      TrendlineData tl = tempTrendlines[i];

      int startIdx = FindIndexByTime(time, arraySize, tl.startTime);
      int endIdx = FindIndexByTime(time, arraySize, tl.endTime);
      int timeSpanBars = (startIdx >= 0 && endIdx >= 0) ? (startIdx - endIdx) : 0;

      // Validate - set isValid và invalidReason
      ValidateTrendline(time, arraySize, tl, timeSpanBars, config);

      // Score
      int distanceFromCurrent = (endIdx >= 0) ? endIdx : 0;
      tl.score = CalculateTrendlineScore(tl, timeSpanBars, distanceFromCurrent);

      if (minStartTime == 0 || tl.startTime < minStartTime)
         minStartTime = tl.startTime;
      if (maxEndTime == 0 || tl.endTime > maxEndTime)
         maxEndTime = tl.endTime;

      tempTrendlines[i] = tl;
   }

   // Completion status
   for (int i = 0; i < trendlineCount; i++)
   {
      TrendlineData tl = tempTrendlines[i];

      tl.isCompleted = !(tl.startTime == minStartTime || tl.endTime == maxEndTime);

      tempTrendlines[i] = tl;
   }

   // ==================================================
   // Bước 4: Sort theo score (descending)
   // ==================================================
   for (int i = 0; i < trendlineCount - 1; i++)
   {
      for (int j = 0; j < trendlineCount - 1 - i; j++)
      {
         if (tempTrendlines[j].score < tempTrendlines[j + 1].score)
         {
            TrendlineData temp = tempTrendlines[j];
            tempTrendlines[j] = tempTrendlines[j + 1];
            tempTrendlines[j + 1] = temp;
         }
      }
   }

   // Copy kết quả
   ArrayResize(outTrendlines, trendlineCount);
   for (int i = 0; i < trendlineCount; i++)
   {
      outTrendlines[i] = tempTrendlines[i];
   }

   return trendlineCount;
}

//+------------------------------------------------------------------+
//| Tìm trendlines từ tập hợp các points (Pair-wise check)           |
//| Duyệt qua các cặp điểm để tạo line candidate, sau đó tìm inliers |
//+------------------------------------------------------------------+
int FindTrendlinesFromPoints(const SwingPointData& points[], ENUM_TRENDLINE_TYPE type, const double& high[],
                             const double& low[], const double& open[], const double& close[], const datetime& time[],
                             const double& atr[], int arraySize, const TrendlineConfig& config,
                             TrendlineData& outTrendlines[])
{
   int pointCount = ArraySize(points);
   ArrayResize(outTrendlines, 0);

   if (pointCount < config.minTouchPoints)
      return 0;

   // Tìm index cho tất cả points để tối ưu
   int pointIndices[];
   ArrayResize(pointIndices, pointCount);
   for (int i = 0; i < pointCount; i++)
   {
      pointIndices[i] = FindIndexByTime(time, arraySize, points[i].time);
      if (pointIndices[i] < 0)
         return 0;  // Should not happen
   }

   TrendlineData tempTrendlines[];
   int trendlineCount = 0;

   // Duyệt qua tất cả các cặp điểm để tạo line candidate
   for (int i = 0; i < pointCount - config.minTouchPoints; i++)
   {
      for (int j = i + config.minTouchPoints - 1; j < pointCount; j++)
      {
         // Tạo line qua points[i] và points[j]
         int idx1 = pointIndices[i];  // Index cũ hơn trên chart (lớn)
         int idx2 = pointIndices[j];  // Index mới hơn trên chart (nhỏ)

         // Tìm tất cả inliers (các điểm nằm trên line này)
         int inlierCount = j - i + 1;
         int inliersOffset[];    // Lưu offset từ điểm gốc i (điểm cũ hơn trên chart)
         double inliersPrice[];  // Lưu giá swing points tại offset
         ArrayResize(inliersOffset, inlierCount);
         ArrayResize(inliersPrice, inlierCount);

         for (int k = 0; k < inlierCount; k++)
         {
            inliersOffset[k] = idx1 - pointIndices[i + k];
            inliersPrice[k] = points[i + k].price;
         }

         // Re-fit line sử dụng tất cả inliers (Linear Regression)
         double bestSlope, bestIntercept;
         LinearRegression(inliersOffset, inliersPrice, inlierCount, bestSlope, bestIntercept);

         // Construct TrendlineData
         TrendlineData tl;
         tl.type = type;
         tl.intercept = bestIntercept;
         tl.startPrice = GetPriceAtOffset(bestSlope, bestIntercept, inliersOffset[0]);
         tl.startTime = points[i].time;
         tl.endTime = points[j].time;
         tl.endPrice = GetPriceAtOffset(bestSlope, bestIntercept, inliersOffset[inlierCount - 1]);

         // Slope
         double tolerance = atr[idx1] * config.tolerancePercent / 100.0;

         tl.slopePrice = bestSlope;
         tl.slopeAtrPercent = (atr[idx1] > 0) ? (bestSlope / atr[idx1]) * 100.0 : 0;
         tl.slope = (config.slopeType == SLOPE_ATR_PERCENT) ? tl.slopeAtrPercent : tl.slopePrice;

         // Copy touch points từ inliers, filter lại nếu touch points cách quá xa trend line
         tl.touchCount = 0;
         for (int k = 0; k < inlierCount; k++)
         {
            double trendlinePrice = GetPriceAtOffset(bestSlope, bestIntercept, inliersOffset[k]);
            if (MathAbs(trendlinePrice - inliersPrice[k]) > tolerance)
               continue;

            tl.touchCount++;
            ArrayResize(tl.touchTimes, tl.touchCount);
            ArrayResize(tl.touchPrices, tl.touchCount);
            tl.touchTimes[tl.touchCount - 1] = points[i + k].time;
            tl.touchPrices[tl.touchCount - 1] = points[i + k].price;
         }
         if (tl.touchCount < 2)
            continue;

         // Breakouts
         FindBreakouts(type, bestSlope, bestIntercept, idx1, idx2, close, time, arraySize, tolerance, tl.breakoutTimes,
                       tl.breakoutPrices);
         tl.breakoutCount = ArraySize(tl.breakoutTimes);

         // Giá trị tạm, sẽ cập nhật trong quá trình Post-processing
         tl.isCompleted = false;
         tl.isValid = false;

         // Check Duplicate before adding
         bool isDuplicate = false;
         for (int x = 0; x < trendlineCount; x++)
         {
            if (IsDuplicateTrendline(tl, tempTrendlines[x]))
            {
               // Nếu trùng, giữ lại cái nào tốt hơn (nhiều touch hơn hoặc dài hơn)
               if (tl.touchCount > tempTrendlines[x].touchCount)
               {
                  tempTrendlines[x] = tl;
               }
               isDuplicate = true;
               break;
            }
         }

         if (!isDuplicate)
         {
            ArrayResize(tempTrendlines, trendlineCount + 1);
            tempTrendlines[trendlineCount++] = tl;
         }
      }
   }

   // Copy kết quả
   ArrayResize(outTrendlines, trendlineCount);
   for (int i = 0; i < trendlineCount; i++)
      outTrendlines[i] = tempTrendlines[i];

   return trendlineCount;
}

// ==================================================
// ========= INCREMENTAL UPDATE SUPPORT =============
// ==================================================

//+------------------------------------------------------------------+
//| Kiểm tra trendline có overlap với time range không               |
//+------------------------------------------------------------------+
bool IsTrendlineOverlapping(const TrendlineData& tl, datetime rangeStart, datetime rangeEnd)
{
   // Overlap nếu có giao nhau giữa [tl.startTime, tl.endTime] và [rangeStart, rangeEnd]
   return (tl.startTime <= rangeEnd && tl.endTime >= rangeStart);
}

//+------------------------------------------------------------------+
//| Lọc trendlines cần update dựa trên time range                    |
//| Return: Số lượng trendlines cần update                           |
//+------------------------------------------------------------------+
int FilterTrendlinesForUpdate(const TrendlineData& allTrendlines[], int totalCount, datetime newDataStartTime,
                              datetime newDataEndTime, TrendlineData& outNeedUpdate[], TrendlineData& outKeepAsIs[])
{
   int updateCount = 0;
   int keepCount = 0;

   for (int i = 0; i < totalCount; i++)
   {
      // Chỉ update trendlines chưa hoàn thiện và overlap với new data
      if (!allTrendlines[i].isCompleted && IsTrendlineOverlapping(allTrendlines[i], newDataStartTime, newDataEndTime))
      {
         ArrayResize(outNeedUpdate, updateCount + 1);
         outNeedUpdate[updateCount++] = allTrendlines[i];
      }
      else
      {
         ArrayResize(outKeepAsIs, keepCount + 1);
         outKeepAsIs[keepCount++] = allTrendlines[i];
      }
   }

   return updateCount;
}

#endif  // TRENDLINE_H
