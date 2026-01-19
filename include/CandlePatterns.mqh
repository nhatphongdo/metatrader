//+------------------------------------------------------------------+
//|                                      Candle Patterns Module      |
//|                                    Copyright 2026, Do Nhat Phong |
//|                                   https://github.com/nhatphongdo |
//+------------------------------------------------------------------+
//| Reusable candlestick pattern detection for any trading strategy  |
//| Dependencies: None (standalone module)                           |
//+------------------------------------------------------------------+
#property copyright "Do Nhat Phong"

#ifndef CANDLE_PATTERNS_H
#define CANDLE_PATTERNS_H

// ==================================================
// ============= BUY PATTERNS =======================
// ==================================================

//+------------------------------------------------------------------+
//| Check BUY Patterns: Returns pattern name or ""                   |
//| Patterns: Hammer, Bullish Engulfing, Piercing, Morning Star      |
//+------------------------------------------------------------------+
string DetectBuyPattern(int i,            // index nến hiện tại
                        int maxLookback,  // index tối đa để tham khảo nến trước
                        const double& open[], const double& high[], const double& low[], const double& close[],
                        const double& ma[],         // Moving average để tham chiếu vị trí
                        double wickBodyRatio = 1.5  // Tỷ lệ bóng/thân cho hammer
)
{
   double body = MathAbs(close[i] - open[i]);
   double range = high[i] - low[i];
   bool green = close[i] > open[i];

   // 1. Hammer / Pinbar
   double lowerWick = MathMin(open[i], close[i]) - low[i];
   double upperWick = high[i] - MathMax(open[i], close[i]);
   bool isHammer = lowerWick >= body * wickBodyRatio && upperWick <= body && low[i] <= ma[i] * 1.0005;

   // 2. Bullish Engulfing (i bao trùm i+1)
   bool isEngulfing = false;
   if (i + 1 <= maxLookback)
   {
      bool prevRed = close[i + 1] < open[i + 1];
      if (prevRed && green)
      {
         isEngulfing = (close[i] > open[i + 1] && open[i] < close[i + 1]) ||  // Bao trùm body
                       (close[i] > high[i + 1] && open[i] < low[i + 1]);      // Bao trùm nến
      }
   }

   // 3. Piercing Line (i+1 đỏ dài, i xanh đóng > 50% i+1)
   bool isPiercing = false;
   if (i + 1 <= maxLookback)
   {
      bool prevRed = close[i + 1] < open[i + 1];
      double prevMid = (open[i + 1] + close[i + 1]) / 2.0;
      if (prevRed && green)
      {
         isPiercing = (open[i] < close[i + 1]) &&  // Gap down
                      (close[i] > prevMid);        // Đóng trên 50%
      }
   }

   // 4. Morning Star (i+2 đỏ, i+1 nhỏ, i xanh)
   bool isMorningStar = false;
   if (i + 2 <= maxLookback)
   {
      // Check i+2 đỏ
      bool bar2Red = close[i + 2] < open[i + 2];
      // Check i+1 nhỏ (star/doji)
      double body1 = MathAbs(close[i + 1] - open[i + 1]);
      bool bar1Small = body1 < (high[i + 1] - low[i + 1]) * 0.5;
      // Check i xanh mạnh
      bool bar0Green = close[i] > open[i];
      double mid2 = (open[i + 2] + close[i + 2]) / 2.0;

      if (bar2Red && bar1Small && bar0Green && close[i] > mid2)
         isMorningStar = true;
   }

   if (isHammer)
      return "Hammer";
   if (isEngulfing)
      return "Engulfing";
   if (isPiercing)
      return "Piercing";
   if (isMorningStar)
      return "Morning Star";

   return "";
}

// ==================================================
// ============= SELL PATTERNS ======================
// ==================================================

//+------------------------------------------------------------------+
//| Check SELL Patterns: Returns pattern name or ""                  |
//| Patterns: Shooting Star, Bearish Engulfing, Dark Cloud, Evening  |
//+------------------------------------------------------------------+
string DetectSellPattern(int i,            // index nến hiện tại
                         int maxLookback,  // index tối đa để tham khảo nến trước
                         const double& open[], const double& high[], const double& low[], const double& close[],
                         const double& ma[],         // Moving average để tham chiếu vị trí
                         double wickBodyRatio = 1.5  // Tỷ lệ bóng/thân cho shooting star
)
{
   double body = MathAbs(close[i] - open[i]);
   bool red = close[i] < open[i];

   // 1. Shooting Star
   double upperWick = high[i] - MathMax(open[i], close[i]);
   double lowerWick = MathMin(open[i], close[i]) - low[i];
   bool isShootingStar = upperWick >= body * wickBodyRatio && lowerWick <= body && high[i] >= ma[i] * 0.9995;

   // 2. Bearish Engulfing
   bool isEngulfing = false;
   if (i + 1 <= maxLookback)
   {
      bool prevGreen = close[i + 1] > open[i + 1];
      if (prevGreen && red)
      {
         isEngulfing =
             (close[i] < open[i + 1] && open[i] > close[i + 1]) || (close[i] < low[i + 1] && open[i] > high[i + 1]);
      }
   }

   // 3. Dark Cloud Cover
   bool isDarkCloud = false;
   if (i + 1 <= maxLookback)
   {
      bool prevGreen = close[i + 1] > open[i + 1];
      double prevMid = (open[i + 1] + close[i + 1]) / 2.0;
      if (prevGreen && red)
      {
         isDarkCloud = (open[i] > close[i + 1]) &&  // Gap up
                       (close[i] < prevMid);        // Đóng dưới 50%
      }
   }

   // 4. Evening Star
   bool isEveningStar = false;
   if (i + 2 <= maxLookback)
   {
      bool bar2Green = close[i + 2] > open[i + 2];
      double body1 = MathAbs(close[i + 1] - open[i + 1]);
      bool bar1Small = body1 < (high[i + 1] - low[i + 1]) * 0.5;
      bool bar0Red = close[i] < open[i];
      double mid2 = (open[i + 2] + close[i + 2]) / 2.0;

      if (bar2Green && bar1Small && bar0Red && close[i] < mid2)
         isEveningStar = true;
   }

   if (isShootingStar)
      return "Shooting Star";
   if (isEngulfing)
      return "Engulfing";
   if (isDarkCloud)
      return "Dark Cloud";
   if (isEveningStar)
      return "Evening Star";

   return "";
}

#endif  // CANDLE_PATTERNS_H
