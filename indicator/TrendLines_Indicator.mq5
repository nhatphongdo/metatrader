//+------------------------------------------------------------------+
//|                                        TrendLines Indicator      |
//|                                    Copyright 2026, Do Nhat Phong |
//|                                   https://github.com/nhatphongdo |
//+------------------------------------------------------------------+
//| Hiển thị tất cả Trendlines detected trên chart                   |
//+------------------------------------------------------------------+
#property copyright "Do Nhat Phong"
#property link "https://github.com/nhatphongdo"
#property version "1.00"
#property indicator_chart_window
#property indicator_plots 0

#include "../include/TrendLine.mqh"

// ==================================================
// ================== INPUTS ========================
// ==================================================

input string InpSep1 = "=== Cấu hình Trendline ===";            // ---
input int InpSwingPeriod = 3;                                   // Swing Period (N nến)
input ENUM_SWING_SOURCE InpSwingSource = SWING_SOURCE_HIGHLOW;  // Swing Source (High/Low vs Body)
input int InpMinTouchPoints = 3;                                // Số điểm chạm tối thiểu
input double InpTolerancePercent = 10.0;                        // Tolerance (%ATR) - dùng cho cả touch & breakout
input int InpATRPeriod = 14;                                    // ATR Period

input string InpSep2 = "=== Slope Validation ===";       // ---
input ENUM_SLOPE_TYPE InpSlopeType = SLOPE_ATR_PERCENT;  // Loại Slope
input double InpMinSlope = 0.01;                         // Min Slope
input double InpMaxSlope = 50.0;                         // Max Slope

input string InpSep3 = "=== Time Validation ===";  // ---
input int InpMinTimeSpan = 10;                     // Min Time Span (nến)
input int InpMinTouchGap = 3;                      // Min Gap giữa touches

input string InpSep4 = "=== Detection ===";  // ---
input bool InpDetectTop = true;              // Detect Top Trendlines
input bool InpDetectBottom = true;           // Detect Bottom Trendlines
input bool InpShowInvalid = false;           // Hiển thị Trendlines không hợp lệ
input bool InpShowIncompleteOnly = false;    // Chỉ hiển thị Trendlines chưa hoàn thiện
input bool InpShowBestScoreOnly = true;      // Chỉ hiển thị Trendlines có điểm số cao nhất trong nhóm

// ==================================================
// ================== COLORS ========================
// ==================================================

color g_trendlineColors[] = {clrGreen, clrOrange,     clrMagenta, clrCyan,        clrYellow, clrLime,     clrPink,
                             clrGold,  clrDodgerBlue, clrCoral,   clrSpringGreen, clrViolet, clrTurquoise};
color g_invalidColor = clrGray;
color g_incompleteColor = clrWhite;
color g_breakoutColor = clrRed;

// ==================================================
// ================== GLOBALS =======================
// ==================================================

int hATR;
string g_prefix = "TL_";
string g_prefixComplete = "TL_C_";    // Trendlines hoàn thiện
string g_prefixIncomplete = "TL_I_";  // Trendlines chưa hoàn thiện
TrendlineConfig g_config;
datetime g_lastCalculated = 0;
TrendlineData g_cachedTrendlines[];  // Cache tất cả trendlines
int g_cachedCount = 0;
int g_maxLookback = 1000;  // Limit lookback for performance

// ==================================================
// ================== INIT/DEINIT ===================
// ==================================================
int OnInit()
{
   // ATR indicator
   hATR = iATR(_Symbol, _Period, InpATRPeriod);
   if (hATR == INVALID_HANDLE)
      return INIT_FAILED;

   GetDefaultTrendlineConfig(g_config);
   g_config.swingPeriod = InpSwingPeriod;
   g_config.swingSource = InpSwingSource;
   g_config.minTouchPoints = InpMinTouchPoints;
   g_config.tolerancePercent = InpTolerancePercent;
   g_config.atrPeriod = InpATRPeriod;
   g_config.slopeType = InpSlopeType;
   g_config.minSlope = InpMinSlope;
   g_config.maxSlope = InpMaxSlope;
   g_config.minTimeSpan = InpMinTimeSpan;
   g_config.minTouchGap = InpMinTouchGap;

   return (INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   IndicatorRelease(hATR);

   ObjectsDeleteAll(0, g_prefix);
   Comment("");
}

//+------------------------------------------------------------------+
//| Vẽ marker cho điểm chạm trendline                                |
//+------------------------------------------------------------------+
void DrawTouchPointMarker(const string& baseId, int touchIndex, datetime touchTime, double touchPrice, color lineColor,
                          ENUM_TRENDLINE_TYPE tlType)
{
   string touchId = baseId + "T" + IntegerToString(touchIndex);
   ObjectCreate(0, touchId, OBJ_ARROW, 0, touchTime, touchPrice);
   ObjectSetInteger(0, touchId, OBJPROP_ARROWCODE, 159);
   ObjectSetInteger(0, touchId, OBJPROP_COLOR, lineColor);
   ObjectSetInteger(0, touchId, OBJPROP_WIDTH, 3);
   ObjectSetInteger(0, touchId, OBJPROP_ANCHOR, (tlType == TRENDLINE_TOP) ? ANCHOR_BOTTOM : ANCHOR_TOP);
   ObjectSetString(0, touchId, OBJPROP_TOOLTIP, StringFormat("#%d | %.5f", touchIndex + 1, touchPrice));
}

//+------------------------------------------------------------------+
//| Vẽ marker cho điểm phá vỡ trendline                               |
//+------------------------------------------------------------------+
void DrawBreakoutMarker(const string& baseId, int breakIndex, datetime breakTime, double breakPrice,
                        double trendlinePrice, ENUM_TRENDLINE_TYPE tlType)
{
   string breakId = baseId + "B" + IntegerToString(breakIndex);
   ObjectCreate(0, breakId, OBJ_ARROW, 0, breakTime, breakPrice);
   ObjectSetInteger(0, breakId, OBJPROP_ARROWCODE, 251);
   ObjectSetInteger(0, breakId, OBJPROP_COLOR, g_breakoutColor);
   ObjectSetInteger(0, breakId, OBJPROP_WIDTH, 3);

   double distance = MathAbs(breakPrice - trendlinePrice);
   string direction = (tlType == TRENDLINE_TOP) ? "BREAK UP" : "BREAK DOWN";
   ObjectSetString(
       0, breakId, OBJPROP_TOOLTIP,
       StringFormat("%s | Price: %.5f | TL: %.5f | Δ: %.5f", direction, breakPrice, trendlinePrice, distance));
}

//+------------------------------------------------------------------+
//| Vẽ toàn bộ trendline (line + touch points + breakout markers)    |
//+------------------------------------------------------------------+
void DrawTrendline(int index, const TrendlineData& trendline, bool isValid, const datetime& time[],
                   const double& high[], const double& low[], int rates_total)
{
   // Xác định prefix dựa trên completion status
   string prefix = trendline.isCompleted ? g_prefixComplete : g_prefixIncomplete;
   string baseId = prefix + IntegerToString(index) + "_";

   // Xác định màu và style
   color lineColor;
   if (!isValid)
      lineColor = g_invalidColor;
   else if (!trendline.isCompleted)
      lineColor = g_incompleteColor;
   else
      lineColor = g_trendlineColors[index % ArraySize(g_trendlineColors)];

   ENUM_LINE_STYLE lineStyle = isValid ? STYLE_SOLID : STYLE_DASH;
   int lineWidth = trendline.isCompleted ? 2 : 1;

   // Sử dụng datetime trực tiếp - ổn định khi có bar mới
   datetime startTime = trendline.startTime;
   double startPrice = trendline.startPrice;

   // Điểm kết thúc: nếu có breakout thì dừng ở breakout đầu tiên
   datetime finalEndTime = trendline.endTime;
   double finalEndPrice = trendline.endPrice;

   if (trendline.breakoutCount > 0)
   {
      // Tìm breakout gần nhất (thời gian lớn nhất = mới nhất)
      datetime earliestBreakout = trendline.breakoutTimes[0];
      double earliestBreakoutPrice = trendline.breakoutPrices[0];
      for (int b = 1; b < trendline.breakoutCount; b++)
      {
         if (trendline.breakoutTimes[b] > earliestBreakout)
         {
            earliestBreakout = trendline.breakoutTimes[b];
            earliestBreakoutPrice = trendline.breakoutPrices[b];
         }
      }

      // Nếu breakout xảy ra sau endTime, kéo dài đến breakout
      if (earliestBreakout > finalEndTime)
      {
         finalEndTime = earliestBreakout;
         // Tính giá tại breakout time trên trendline
         int startIdx = FindIndexByTime(time, rates_total, startTime);
         int breakIdx = FindIndexByTime(time, rates_total, earliestBreakout);
         if (startIdx >= 0 && breakIdx >= 0)
         {
            finalEndPrice = GetPriceAtOffset(trendline.slopePrice, startPrice, startIdx - breakIdx);
         }
      }
   }
   else if (!trendline.isCompleted)
   {
      // Trendline chưa hoàn thiện: extend về phía current (time[0])
      // Tính giá tại vị trí gần nhất
      int startIdx = FindIndexByTime(time, rates_total, startTime);
      if (startIdx >= 0)
      {
         int extendIdx = MathMax(0, FindIndexByTime(time, rates_total, finalEndTime) - 10);
         if (extendIdx >= 0 && extendIdx < rates_total)
         {
            finalEndTime = time[extendIdx];
            finalEndPrice = GetPriceAtOffset(trendline.slopePrice, startPrice, startIdx - extendIdx);
         }
      }
   }

   // Tooltip
   string typeStr = (trendline.type == TRENDLINE_TOP) ? "Đỉnh" : "Đáy";
   string validStr = isValid ? "OK" : "Lỗi";
   string completeStr = trendline.isCompleted ? "Hoàn thiện" : "Chưa hoàn thiện";
   double priceDiff = finalEndPrice - startPrice;
   double slopeVal = (g_config.slopeType == SLOPE_ATR_PERCENT) ? trendline.slopeAtrPercent : trendline.slopePrice;

   string tooltip =
       StringFormat("%s | %s | %s\nSlope: %.4f | Chạm: %d | Breakout: %d\nĐiểm: %.0f | ĐĐ: %.5f → ĐC: %.5f | Δ: %+.5f",
                    typeStr, validStr, completeStr, slopeVal, trendline.touchCount, trendline.breakoutCount,
                    trendline.score, startPrice, finalEndPrice, priceDiff);

   if (!isValid && trendline.invalidReason != "")
      tooltip = tooltip + "\n" + trendline.invalidReason;

   // Vẽ Trendline
   ObjectCreate(0, baseId + "L", OBJ_TREND, 0, startTime, startPrice, finalEndTime, finalEndPrice);
   ObjectSetInteger(0, baseId + "L", OBJPROP_COLOR, lineColor);
   ObjectSetInteger(0, baseId + "L", OBJPROP_WIDTH, lineWidth);
   ObjectSetInteger(0, baseId + "L", OBJPROP_STYLE, lineStyle);
   ObjectSetInteger(0, baseId + "L", OBJPROP_RAY_RIGHT, false);
   ObjectSetString(0, baseId + "L", OBJPROP_TOOLTIP, tooltip);

   // Vẽ Touch points - dùng datetime trực tiếp
   for (int t = 0; t < trendline.touchCount; t++)
   {
      datetime touchTime = trendline.touchTimes[t];
      double touchPrice = trendline.touchPrices[t];
      DrawTouchPointMarker(baseId, t, touchTime, touchPrice, lineColor, trendline.type);
   }

   // Vẽ Breakout markers
   for (int b = 0; b < trendline.breakoutCount; b++)
   {
      datetime breakTime = trendline.breakoutTimes[b];
      double breakPrice = trendline.breakoutPrices[b];

      // Tính giá trendline tại thời điểm breakout
      int startIdx = FindIndexByTime(time, rates_total, startTime);
      int breakIdx = FindIndexByTime(time, rates_total, breakTime);
      double tlPrice = (startIdx >= 0 && breakIdx >= 0)
                           ? GetPriceAtOffset(trendline.slopePrice, startPrice, startIdx - breakIdx)
                           : breakPrice;

      DrawBreakoutMarker(baseId, b, breakTime, breakPrice, tlPrice, trendline.type);
   }
}

// ==================================================
// ================== CALCULATE =====================
// ==================================================

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total, const int prev_calculated, const datetime& time[], const double& open[],
                const double& high[], const double& low[], const double& close[], const long& tick_volume[],
                const long& volume[], const int& spread[])
{
   if (rates_total < g_config.swingPeriod * 2 + g_config.minTouchPoints)
   {
      return rates_total;
   }

   // Set arrays as series (index 0 = newest bar)
   ArraySetAsSeries(time, true);
   ArraySetAsSeries(open, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(close, true);

   // Copy ATR buffers
   double atr[];
   ArraySetAsSeries(atr, true);
   if (CopyBuffer(hATR, 0, 0, rates_total, atr) <= 0)
      return rates_total;

   // Xác định có cần detect lại không
   bool needFullUpdate = false;
   bool needPartialUpdate = false;

   // 1. New Bar
   if (time[0] != g_lastCalculated)
      needPartialUpdate = true;

   // 2. First Run or View Change or Reset
   if (g_lastCalculated == 0 || prev_calculated == 0)
      needFullUpdate = true;

   if (!needFullUpdate && !needPartialUpdate)
   {
      return rates_total;
   }

   g_lastCalculated = time[0];

   // Tính lookback range
   int firstVisibleBar = (int)ChartGetInteger(0, CHART_FIRST_VISIBLE_BAR);
   int visibleBars = (int)ChartGetInteger(0, CHART_VISIBLE_BARS);

   int lookbackBars = firstVisibleBar + visibleBars + 100;
   if (lookbackBars > g_maxLookback)
      lookbackBars = g_maxLookback;
   if (lookbackBars > rates_total)
      lookbackBars = rates_total;
   if (lookbackBars < 200)
      lookbackBars = 200;

   // ==================================================
   // INCREMENTAL UPDATE LOGIC
   // ==================================================

   if (needFullUpdate)
   {
      // Full update: detect tất cả trendlines
      ObjectsDeleteAll(0, g_prefix);

      g_cachedCount = DetectTrendlines(high, low, open, close, time, atr, rates_total, 0, lookbackBars, g_config,
                                       g_cachedTrendlines, InpDetectTop, InpDetectBottom);
      Print("TL: Full detect - found ", g_cachedCount, " trendlines in ", lookbackBars, " bars");
   }
   else if (needPartialUpdate)
   {
      // Partial update: chỉ update trendlines chưa hoàn thiện
      ObjectsDeleteAll(0, g_prefixIncomplete);

      // Tách trendlines đã hoàn thiện và chưa hoàn thiện
      TrendlineData completedTrendlines[];
      int completedCount = 0;

      for (int i = 0; i < g_cachedCount; i++)
      {
         if (g_cachedTrendlines[i].isCompleted)
         {
            ArrayResize(completedTrendlines, completedCount + 1);
            completedTrendlines[completedCount++] = g_cachedTrendlines[i];
         }
      }

      // Re-detect với lookback ngắn hơn cho incomplete trendlines
      TrendlineData newTrendlines[];
      int newCount = DetectTrendlines(high, low, open, close, time, atr, rates_total, 0, MathMin(lookbackBars, 500),
                                      g_config, newTrendlines, InpDetectTop, InpDetectBottom);

      // Merge: giữ completed, thêm từ detection mới
      g_cachedCount = completedCount;
      ArrayResize(g_cachedTrendlines, completedCount);
      for (int i = 0; i < completedCount; i++)
      {
         g_cachedTrendlines[i] = completedTrendlines[i];
      }

      // Thêm các trendlines mới (không trùng với completed)
      for (int i = 0; i < newCount; i++)
      {
         bool isDuplicate = false;
         for (int j = 0; j < completedCount; j++)
         {
            // So sánh bằng startTime (datetime ổn định)
            if (completedTrendlines[j].startTime == newTrendlines[i].startTime &&
                completedTrendlines[j].type == newTrendlines[i].type)
            {
               isDuplicate = true;
               break;
            }
         }

         if (!isDuplicate)
         {
            ArrayResize(g_cachedTrendlines, g_cachedCount + 1);
            g_cachedTrendlines[g_cachedCount++] = newTrendlines[i];
         }
      }

      Print("TL: Partial update - ", completedCount, " completed + ", (g_cachedCount - completedCount), " new/updated");
   }

   // ==================================================
   // VẼ TRENDLINES
   // ==================================================

   for (int i = 0; i < g_cachedCount; i++)
   {
      bool isValid = g_cachedTrendlines[i].isValid;

      // Lọc theo config hiển thị
      if (!isValid && !InpShowInvalid)
         continue;
      if (InpShowIncompleteOnly && g_cachedTrendlines[i].isCompleted)
         continue;

      // Với partial update, chỉ vẽ lại incomplete (completed đã có sẵn)
      if (needPartialUpdate && !needFullUpdate && g_cachedTrendlines[i].isCompleted)
         continue;

      // Chỉ vẽ trendline có điểm số cao nhất
      if (InpShowBestScoreOnly)
      {
         double bestScore = -1;
         for (int j = 0; j < g_cachedCount; j++)
         {
            if (i != j && g_cachedTrendlines[j].isValid == g_cachedTrendlines[i].isValid &&
                g_cachedTrendlines[j].startTime == g_cachedTrendlines[i].startTime &&
                g_cachedTrendlines[j].score > bestScore)
               bestScore = g_cachedTrendlines[j].score;
         }
         if (bestScore >= 0 && g_cachedTrendlines[i].score < bestScore)
            continue;
      }

      DrawTrendline(i, g_cachedTrendlines[i], isValid, time, high, low, rates_total);
   }

   return rates_total;
}
//+------------------------------------------------------------------+
