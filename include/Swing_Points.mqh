//+------------------------------------------------------------------+
//|                                          SwingPoints Module      |
//|                                    Copyright 2026, Do Nhat Phong |
//|                                   https://github.com/nhatphongdo |
//+------------------------------------------------------------------+
//| Module phát hiện và validate Swing Points (High/Low)             |
//+------------------------------------------------------------------+
#property copyright "Do Nhat Phong"

#ifndef SWING_POINTS_H
#define SWING_POINTS_H

#include "Utility.mqh"

// ==================================================
// ================== ENUMS =========================
// ==================================================

enum ENUM_SWING_SOURCE
{
   SWING_SOURCE_HIGHLOW,  // Swing High = High, Swing Low = Low (Default)
   SWING_SOURCE_BODY      // Swing High = Max(Open, Close), Swing Low = Min(Open, Close)
};

// ==================================================
// ================== STRUCTS =======================
// ==================================================

//+------------------------------------------------------------------+
//| Swing point data (lưu datetime thay vì index)                    |
//+------------------------------------------------------------------+
struct SwingPointData
{
   int index;  // Index của nến, lưu ý index có thể thay đổi khi danh sách nến cập nhật. Ưu tiên dùng "time" nếu được
   datetime time;     // Thời gian swing point
   double price;      // Giá tại swing point
   bool isSwingHigh;  // true = Swing High, false = Swing Low
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
//| Phát hiện tất cả Swing Points (Top và/hoặc Bottom)                |
//| Return: Số lượng swing points tìm được                            |
//+------------------------------------------------------------------+
int FindSwingPoints(const double& high[], const double& low[], const double& open[], const double& close[],
                    const datetime& time[], int arraySize,
                    int startIndex,    // Index của nến bắt đầu quét
                    int lookbackBars,  // Số nến quét (từ startIndex)
                    SwingPointData& outSwingHighs[], SwingPointData& outSwingLows[],
                    bool detectTop = true,     // Detect Top Swing Points
                    bool detectBottom = true,  // Detect Bottom Swing Points
                    int swingPeriod = 3,       // Số nến trước/sau để xác định swing (Default: 3)
                    ENUM_SWING_SOURCE swingSource = SWING_SOURCE_HIGHLOW  // Nguồn giá để tính swing points
)
{
   // Validate input
   if (arraySize < swingPeriod * 2)
   {
      return 0;
   }

   // Nếu lookbackBars <= 0, quét toàn bộ dữ liệu
   int effectiveLookback = (lookbackBars <= 0) ? arraySize : lookbackBars;
   int maxIndex = MathMin(effectiveLookback, arraySize - swingPeriod);
   int minIndex = MathMax(startIndex, swingPeriod);

   // Tìm tất cả swing points (từ cũ đến mới)
   // Chuẩn bị source arrays dựa trên config
   double srcHigh[];
   double srcLow[];
   bool useBody = (swingSource == SWING_SOURCE_BODY);

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

   int swingHighCount = 0;
   int swingLowCount = 0;

   for (int i = maxIndex - 1; i >= minIndex; i--)
   {
      if (detectTop)
      {
         bool isHigh = false;
         double price = 0;

         if (useBody)
         {
            isHigh = IsSwingHigh(i, swingPeriod, srcHigh, arraySize);
            price = srcHigh[i];
         }
         else
         {
            isHigh = IsSwingHigh(i, swingPeriod, high, arraySize);
            price = high[i];
         }

         if (isHigh)
         {
            ArrayResize(outSwingHighs, swingHighCount + 1);
            outSwingHighs[swingHighCount].index = i;
            outSwingHighs[swingHighCount].time = time[i];
            outSwingHighs[swingHighCount].price = price;
            outSwingHighs[swingHighCount].isSwingHigh = true;
            swingHighCount++;
         }
      }

      if (detectBottom)
      {
         bool isLow = false;
         double price = 0;

         if (useBody)
         {
            isLow = IsSwingLow(i, swingPeriod, srcLow, arraySize);
            price = srcLow[i];
         }
         else
         {
            isLow = IsSwingLow(i, swingPeriod, low, arraySize);
            price = low[i];
         }

         if (isLow)
         {
            ArrayResize(outSwingLows, swingLowCount + 1);
            outSwingLows[swingLowCount].index = i;
            outSwingLows[swingLowCount].time = time[i];
            outSwingLows[swingLowCount].price = price;
            outSwingLows[swingLowCount].isSwingHigh = false;
            swingLowCount++;
         }
      }
   }

   return swingHighCount + swingLowCount;
}

#endif  // SWING_POINTS_H
