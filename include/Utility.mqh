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


// ====================================================================
// ===================== MATH & COMPARISON  ===========================
// ====================================================================

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

#endif // UTILITY_H
