//+------------------------------------------------------------------+
//|                                                      Utilities   |
//|                                    Copyright 2026, Do Nhat Phong |
//|                                   https://github.com/nhatphongdo |
//+------------------------------------------------------------------+
//| Module chứa các hàm tiện ích dùng chung (Math, Comparison, ...)  |
//+------------------------------------------------------------------+
#property copyright "Do Nhat Phong"

#ifndef UTILITY_H
#define UTILITY_H


//+------------------------------------------------------------------+
//| Check if an indicator exists on the chart (Main or Subwindow)    |
//| namePattern: Partial or full name of the indicator               |
//| Return window index if exists, -1 otherwise                      |
//| indName: Output parameter to return the full indicator name      |
//+------------------------------------------------------------------+
int IndicatorExists(long chartId, string namePattern, string &indName)
  {
   int totalWindows = (int)ChartGetInteger(chartId, CHART_WINDOWS_TOTAL);
   for(int w = 0; w < totalWindows; w++)
     {
      for(int i = ChartIndicatorsTotal(chartId, w) - 1; i >= 0; i--)
        {
         indName = ChartIndicatorName(chartId, w, i);
         if(StringFind(indName, namePattern) >= 0)
            return w;
        }
     }
   indName = "";
   return -1;
  }

//+------------------------------------------------------------------+
//| Compare with tick size tolerance (Less Than)                     |
//+------------------------------------------------------------------+
bool IsLessThan(const double number1, const double number2, double tickSize)
  {
   return number1 < number2 + tickSize;
  }

//+------------------------------------------------------------------+
//| Compare with tick size tolerance (Greater Than)                  |
//+------------------------------------------------------------------+
bool IsGreaterThan(const double number1, const double number2, double tickSize)
  {
   return number1 > number2 - tickSize;
  }

//+------------------------------------------------------------------+
//| Calculate smoothed slope using Linear Regression                 |
//| Returns angle in degrees                                         |
//+------------------------------------------------------------------+
double CalculateLinearRegressionSlope(
   const double &data[],      // Source data (e.g., MA array)
   int startIdx,             // Start index (newer bar)
   int count,                // Number of bars
   double pointValue         // To normalize price to points
)
  {
   if(count < 2)
     {
      // Fallback to 2-bar nếu không đủ data
      double delta = (data[startIdx] - data[startIdx + 1]) / pointValue;
      return MathArctan(delta) * 180 / M_PI;
     }

// Tính linear regression
   double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0;

   for(int i = 0; i < count; i++)
     {
      double x = (double)i;
      double y = data[startIdx + i] / pointValue; // Normalize
      sumX += x;
      sumY += y;
      sumXY += x * y;
      sumX2 += x * x;
     }

   double slope = (count * sumXY - sumX * sumY) / (count * sumX2 - sumX * sumX);

// Slope should be negative when price goes up (newer = lower index)
// Because x increases as we go back in time (index increases)
// So positive slope means value increases as index increases (value was higher in past -> downtrend)
// We want positive slope = uptrend (value higher in future/lower index) -> negate it
   slope = -slope;

   return MathArctan(slope) * 180 / M_PI;
  }


// ==================================================
// ========== VALIDATE PRICE CONSTRAINTS =============
// ==================================================

//+------------------------------------------------------------------+
//| Struct kết quả validation SL/TP                                  |
//+------------------------------------------------------------------+
struct PriceValidationResult
  {
   bool              isValid;         // true nếu tất cả constraints đều pass
   string            reason;          // Lý do từ chối (nếu có)
   double            slDistancePoints;// Khoảng cách SL tính bằng points
   double            tpDistancePoints;// Khoảng cách TP tính bằng points
  };

//+------------------------------------------------------------------+
//| Validate các ràng buộc giá Entry/SL/TP                           |
//| - Kiểm tra SL đúng hướng (BUY: SL < Entry, SELL: SL > Entry)     |
//| - Kiểm tra TP đúng hướng (BUY: TP > Entry, SELL: TP < Entry)     |
//| - Kiểm tra SL/TP đạt khoảng cách tối thiểu                       |
//+------------------------------------------------------------------+
void ValidatePriceConstraints(
   bool isBuy,
   double entryPrice,
   double sl,
   double tp,
   double minStopLoss,      // Số points SL tối thiểu, 0=không kiểm tra
   double minTakeProfit,    // Số points TP tối thiểu, 0=không kiểm tra
   double minRewardRisk,    // Tỷ lệ Reward/Risk tối thiểu, 0=không kiểm tra
   double pointValue,
   int digits,
   PriceValidationResult &outResult
)
  {
   outResult.isValid = true;
   outResult.reason = "";
   outResult.slDistancePoints = 0;
   outResult.tpDistancePoints = 0;

// Tính khoảng cách SL bằng points
   outResult.slDistancePoints = MathAbs(entryPrice - sl) / pointValue;

// Kiểm tra SL phải đúng hướng
   if(isBuy)
     {
      if(sl >= entryPrice)
        {
         outResult.isValid = false;
         outResult.reason = StringFormat("Từ chối: SL (%s) phải < giá BUY (%s)",
                                         DoubleToString(sl, digits),
                                         DoubleToString(entryPrice, digits));
         return;
        }
     }
   else
     {
      if(sl <= entryPrice)
        {
         outResult.isValid = false;
         outResult.reason = StringFormat("Từ chối: SL (%s) phải > giá SELL (%s)",
                                         DoubleToString(sl, digits),
                                         DoubleToString(entryPrice, digits));
         return;
        }
     }

// Kiểm tra SL tối thiểu
   if(minStopLoss > 0 && outResult.slDistancePoints < minStopLoss)
     {
      outResult.isValid = false;
      outResult.reason = StringFormat("Từ chối: SL (%.1f pts) < MinSL (%.1f pts) | Entry: %s, SL: %s",
                                      outResult.slDistancePoints, minStopLoss,
                                      DoubleToString(entryPrice, digits),
                                      DoubleToString(sl, digits));
      return;
     }

// Kiểm tra TP phải đúng hướng
   if(isBuy)
     {
      if(tp <= entryPrice)
        {
         outResult.isValid = false;
         outResult.reason = StringFormat("Từ chối: TP (%s) phải > giá BUY (%s)",
                                         DoubleToString(tp, digits),
                                         DoubleToString(entryPrice, digits));
         return;
        }
     }
   else
     {
      if(tp >= entryPrice)
        {
         outResult.isValid = false;
         outResult.reason = StringFormat("Từ chối: TP (%s) phải < giá SELL (%s)",
                                         DoubleToString(tp, digits),
                                         DoubleToString(entryPrice, digits));
         return;
        }
     }

// Tính khoảng cách TP bằng points
   outResult.tpDistancePoints = MathAbs(tp - entryPrice) / pointValue;

// Kiểm tra TP tối thiểu
   if(minTakeProfit > 0 && outResult.tpDistancePoints < minTakeProfit)
     {
      outResult.isValid = false;
      outResult.reason = StringFormat("Từ chối: TP (%.1f pts) < MinTP (%.1f pts) | Entry: %s, TP: %s",
                                      outResult.tpDistancePoints, minTakeProfit,
                                      DoubleToString(entryPrice, digits),
                                      DoubleToString(tp, digits));
      return;
     }

// Kiểm tra tỷ lệ Reward/Risk tối thiểu
   double rr = outResult.tpDistancePoints / outResult.slDistancePoints;
   if(minRewardRisk > 0 && rr < minRewardRisk)
     {
      outResult.isValid = false;
      outResult.reason = StringFormat("Từ chối: Tỷ lệ Reward/Risk (%.2f) không đạt tối thiểu %.1f", rr, minRewardRisk);
      return;
     }
  }


#endif // UTILITY_H
