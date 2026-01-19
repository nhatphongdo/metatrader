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
int IndicatorExists(long chartId, string namePattern, string& indName)
{
   int totalWindows = (int)ChartGetInteger(chartId, CHART_WINDOWS_TOTAL);
   for (int w = 0; w < totalWindows; w++)
   {
      for (int i = ChartIndicatorsTotal(chartId, w) - 1; i >= 0; i--)
      {
         indName = ChartIndicatorName(chartId, w, i);
         if (StringFind(indName, namePattern) >= 0)
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
//| Tính Linear Regression Line từ các điểm X, Y                     |
//| Trả về slope và intercept theo công thức y = slope*x + intercept |
//| Có thể dùng cho dữ liệu liên tục hoặc rời rạc                    |
//+------------------------------------------------------------------+
void CalculateLinearRegressionLine(const double& x[],    // Mảng giá trị X
                                   const double& y[],    // Mảng giá trị Y
                                   int count,            // Số điểm
                                   double& outSlope,     // Output: slope
                                   double& outIntercept  // Output: intercept
)
{
   if (count < 2)
   {
      outSlope = 0;
      outIntercept = (count > 0) ? y[0] : 0;
      return;
   }

   // Tính mean của x và y
   double sumX = 0, sumY = 0;
   for (int i = 0; i < count; i++)
   {
      sumX += x[i];
      sumY += y[i];
   }
   double meanX = sumX / count;
   double meanY = sumY / count;

   // Tính slope: sum((x-meanX)*(y-meanY)) / sum((x-meanX)^2)
   double numerator = 0, denominator = 0;
   for (int i = 0; i < count; i++)
   {
      double dx = x[i] - meanX;
      double dy = y[i] - meanY;
      numerator += dx * dy;
      denominator += dx * dx;
   }

   if (MathAbs(denominator) < 0.0000001)
   {
      outSlope = 0;
      outIntercept = meanY;
      return;
   }

   outSlope = numerator / denominator;
   outIntercept = meanY - outSlope * meanX;
}

//+------------------------------------------------------------------+
//| Calculate smoothed slope using Linear Regression                 |
//| Returns angle in degrees, scaled by ATR for market adaptation    |
//| Slope = (points change per bar) / ATR, then converted to angle   |
//| atrPoints là ATR tính bằng points (đã chia cho pointValue)       |
//+------------------------------------------------------------------+
double CalculateLinearRegressionSlope(const double& data[],  // Source data (e.g., MA array)
                                      int startIdx,          // Start index (newer bar)
                                      int count,             // Number of bars
                                      double pointValue,     // To normalize price to points
                                      double atrPoints       // ATR in points for scaling (0 = use default 500)
)
{
   // Validate và fallback ATR
   if (atrPoints <= 0)
      atrPoints = 500;  // Default fallback

   // Hệ số scale ATR: 0.1 = 10% ATR/bar cho góc 45°
   // Điều này có nghĩa:
   // - 0.1 ATR/bar = 45° (trend cực mạnh)
   // - 0.05 ATR/bar = ~27° (trend mạnh)
   // - 0.02 ATR/bar = ~11° (trend trung bình)
   // - 0.01 ATR/bar = ~5.7° (trend nhẹ)
   const double ATR_SCALE_FACTOR = 0.1;
   double scalingBase = atrPoints * ATR_SCALE_FACTOR;

   if (count < 2)
   {
      // Fallback to 2-bar: tính slope đơn giản
      double deltaPoints = (data[startIdx] - data[startIdx + 1]) / pointValue;
      return MathArctan(deltaPoints / scalingBase) * 180 / M_PI;
   }

   // Chuẩn bị mảng x, y cho linear regression
   double xArr[];
   double yArr[];
   ArrayResize(xArr, count);
   ArrayResize(yArr, count);

   for (int i = 0; i < count; i++)
   {
      xArr[i] = (double)i;
      yArr[i] = data[startIdx + i] / pointValue;  // Chuyển sang points
   }

   // Tính linear regression
   double slope, intercept;
   CalculateLinearRegressionLine(xArr, yArr, count, slope, intercept);

   // Đảo dấu vì x tăng = đi ngược thời gian
   // slope âm ban đầu = giá tăng theo thời gian = uptrend
   double slopePointsPerBar = -slope;

   // Scale theo ATR (với hệ số) để góc có ý nghĩa thực tế
   double scaledSlope = slopePointsPerBar / scalingBase;

   return MathArctan(scaledSlope) * 180 / M_PI;
}

// ==================================================
// ========== VALIDATE PRICE CONSTRAINTS =============
// ==================================================

//+------------------------------------------------------------------+
//| Struct kết quả validation SL/TP                                  |
//+------------------------------------------------------------------+
struct PriceValidationResult
{
   bool isValid;             // true nếu tất cả constraints đều pass
   string reason;            // Lý do từ chối (nếu có)
   double slDistancePoints;  // Khoảng cách SL tính bằng points
   double tpDistancePoints;  // Khoảng cách TP tính bằng points
};

//+------------------------------------------------------------------+
//| Validate các ràng buộc giá Entry/SL/TP                           |
//| - Kiểm tra SL đúng hướng (BUY: SL < Entry, SELL: SL > Entry)     |
//| - Kiểm tra TP đúng hướng (BUY: TP > Entry, SELL: TP < Entry)     |
//| - Kiểm tra SL/TP đạt khoảng cách tối thiểu                       |
//+------------------------------------------------------------------+
void ValidatePriceConstraints(bool isBuy, double entryPrice, double sl, double tp,
                              double minStopLoss,    // Số points SL tối thiểu, 0=không kiểm tra
                              double minTakeProfit,  // Số points TP tối thiểu, 0=không kiểm tra
                              double minRewardRisk,  // Tỷ lệ Reward/Risk tối thiểu, 0=không kiểm tra
                              double pointValue, int digits, PriceValidationResult& outResult)
{
   outResult.isValid = true;
   outResult.reason = "";
   outResult.slDistancePoints = 0;
   outResult.tpDistancePoints = 0;

   // Tính khoảng cách SL bằng points
   outResult.slDistancePoints = MathAbs(entryPrice - sl) / pointValue;

   // Kiểm tra SL phải đúng hướng
   if (isBuy)
   {
      if (sl >= entryPrice)
      {
         outResult.isValid = false;
         outResult.reason = StringFormat("Từ chối: SL (%s) phải < giá BUY (%s)", DoubleToString(sl, digits),
                                         DoubleToString(entryPrice, digits));
         return;
      }
   }
   else
   {
      if (sl <= entryPrice)
      {
         outResult.isValid = false;
         outResult.reason = StringFormat("Từ chối: SL (%s) phải > giá SELL (%s)", DoubleToString(sl, digits),
                                         DoubleToString(entryPrice, digits));
         return;
      }
   }

   // Kiểm tra SL tối thiểu
   if (minStopLoss > 0 && outResult.slDistancePoints < minStopLoss)
   {
      outResult.isValid = false;
      outResult.reason =
          StringFormat("Từ chối: SL (%.1f pts) < MinSL (%.1f pts) | Entry: %s, SL: %s", outResult.slDistancePoints,
                       minStopLoss, DoubleToString(entryPrice, digits), DoubleToString(sl, digits));
      return;
   }

   // Kiểm tra TP phải đúng hướng
   if (isBuy)
   {
      if (tp <= entryPrice)
      {
         outResult.isValid = false;
         outResult.reason = StringFormat("Từ chối: TP (%s) phải > giá BUY (%s)", DoubleToString(tp, digits),
                                         DoubleToString(entryPrice, digits));
         return;
      }
   }
   else
   {
      if (tp >= entryPrice)
      {
         outResult.isValid = false;
         outResult.reason = StringFormat("Từ chối: TP (%s) phải < giá SELL (%s)", DoubleToString(tp, digits),
                                         DoubleToString(entryPrice, digits));
         return;
      }
   }

   // Tính khoảng cách TP bằng points
   outResult.tpDistancePoints = MathAbs(tp - entryPrice) / pointValue;

   // Kiểm tra TP tối thiểu
   if (minTakeProfit > 0 && outResult.tpDistancePoints < minTakeProfit)
   {
      outResult.isValid = false;
      outResult.reason =
          StringFormat("Từ chối: TP (%.1f pts) < MinTP (%.1f pts) | Entry: %s, TP: %s", outResult.tpDistancePoints,
                       minTakeProfit, DoubleToString(entryPrice, digits), DoubleToString(tp, digits));
      return;
   }

   // Kiểm tra tỷ lệ Reward/Risk tối thiểu
   double rr = outResult.tpDistancePoints / outResult.slDistancePoints;
   if (minRewardRisk > 0 && rr < minRewardRisk)
   {
      outResult.isValid = false;
      outResult.reason = StringFormat("Từ chối: Tỷ lệ Reward/Risk (%.2f) không đạt tối thiểu %.1f", rr, minRewardRisk);
      return;
   }
}

// ==================================================
// ============== DRAWING UTILITIES =================
// ==================================================
// Các hàm vẽ tín hiệu dùng chung cho EA và Indicator

// ==================================================
// ============== TOOLTIP STORAGE ===================
// ==================================================

//+------------------------------------------------------------------+
//| Struct lưu tooltip data (dùng chung cho EA và Indicator)         |
//+------------------------------------------------------------------+
struct TooltipData
{
   string objectId;     // ID của object (prefix + timestamp)
   string fullTooltip;  // Nội dung đầy đủ hiển thị khi click
};

// Global tooltip storage - sử dụng prefix để phân biệt nguồn
TooltipData g_signalTooltips[];  // Mảng lưu tất cả tooltips
int g_signalTooltipCount = 0;

//+------------------------------------------------------------------+
//| Thêm tooltip vào mảng global                                     |
//+------------------------------------------------------------------+
void AddSignalTooltip(const string objectId, const string tooltipText)
{
   if (objectId == "" || tooltipText == "")
      return;

   TooltipData data;
   data.objectId = objectId;
   data.fullTooltip = tooltipText;

   ++g_signalTooltipCount;
   ArrayResize(g_signalTooltips, g_signalTooltipCount);
   g_signalTooltips[g_signalTooltipCount - 1] = data;
}

//+------------------------------------------------------------------+
//| Tìm tooltip theo objectId                                        |
//| Return: tooltip text nếu tìm thấy, "" nếu không                  |
//+------------------------------------------------------------------+
string FindSignalTooltip(const string objectId)
{
   for (int i = 0; i < g_signalTooltipCount; i++)
   {
      if (g_signalTooltips[i].objectId == objectId)
         return g_signalTooltips[i].fullTooltip;
   }
   return "";
}

//+------------------------------------------------------------------+
//| Xóa tất cả tooltips có prefix cụ thể                             |
//+------------------------------------------------------------------+
void ClearSignalTooltips(const string objPrefix = "")
{
   if (objPrefix == "")
   {
      // Xóa tất cả
      ArrayResize(g_signalTooltips, 0);
      g_signalTooltipCount = 0;
   }
   else
   {
      // Xóa chỉ các tooltip có prefix cụ thể
      TooltipData filtered[];
      int filteredCount = 0;

      for (int i = 0; i < g_signalTooltipCount; i++)
      {
         if (StringFind(g_signalTooltips[i].objectId, objPrefix) != 0)
         {
            ArrayResize(filtered, filteredCount + 1);
            filtered[filteredCount] = g_signalTooltips[i];
            filteredCount++;
         }
      }

      ArrayResize(g_signalTooltips, filteredCount);
      for (int i = 0; i < filteredCount; i++)
      {
         g_signalTooltips[i] = filtered[i];
      }
      g_signalTooltipCount = filteredCount;
   }
}

//+------------------------------------------------------------------+
//| Xử lý chart event cho signal objects                             |
//| Gọi hàm này từ OnChartEvent của EA/Indicator                     |
//| Return: true nếu đã xử lý event, false nếu không liên quan       |
//+------------------------------------------------------------------+
bool HandleSignalChartEvent(const int id, const long& lparam, const double& dparam, const string& sparam,
                            const string objPrefix)
{
   // Xử lý khi click vào object
   if (id == CHARTEVENT_OBJECT_CLICK)
   {
      // Kiểm tra xem object có thuộc prefix này không
      if (StringFind(sparam, objPrefix) == 0)
      {
         // Tìm tooltip data cho object này - strip suffix
         string baseId = sparam;

         // Loại bỏ suffix - QUAN TRỌNG: check _SL trước _S, _AR trước _R
         int pos = StringFind(baseId, "_DIA");
         if (pos > 0)
            baseId = StringSubstr(baseId, 0, pos);
         pos = StringFind(baseId, "_LBL");
         if (pos > 0)
            baseId = StringSubstr(baseId, 0, pos);
         pos = StringFind(baseId, "_SL");
         if (pos > 0)
            baseId = StringSubstr(baseId, 0, pos);
         pos = StringFind(baseId, "_TP");
         if (pos > 0)
            baseId = StringSubstr(baseId, 0, pos);
         pos = StringFind(baseId, "_AR");
         if (pos > 0)
            baseId = StringSubstr(baseId, 0, pos);
         pos = StringFind(baseId, "_S");
         if (pos > 0)
            baseId = StringSubstr(baseId, 0, pos);
         pos = StringFind(baseId, "_R");
         if (pos > 0)
            baseId = StringSubstr(baseId, 0, pos);

         // Tìm tooltip trong mảng global
         string tooltip = FindSignalTooltip(baseId);
         if (tooltip != "")
         {
            Comment(tooltip);
            ChartRedraw();
            return true;
         }
      }
   }
   // Click vào vùng trống - xóa comment
   else if (id == CHARTEVENT_CLICK)
   {
      Comment("");
      ChartRedraw();
      return true;
   }

   return false;
}

// ==================================================
// ============== SIGNAL DRAW CONFIG ================
// ==================================================

//+------------------------------------------------------------------+
//| Struct cấu hình màu sắc và style vẽ signal                       |
//+------------------------------------------------------------------+
struct SignalDrawConfig
{
   color buyColor;          // Màu BUY arrow
   color sellColor;         // Màu SELL arrow
   color slColor;           // Màu đường SL
   color tpColor;           // Màu đường TP
   color strongColor;       // Màu label STRONG
   color weakColor;         // Màu label WEAK
   color supportColor;      // Màu vùng Support
   color resistColor;       // Màu vùng Resistance
   color cancelColor;       // Màu tín hiệu bị hủy
   color cutBuyColor;       // Màu cut marker BUY
   color cutSellColor;      // Màu cut marker SELL
   color cutFilteredColor;  // Màu cut marker bị lọc
   int lineLengthBars;      // Độ dài đường SL/TP (số nến)
   string objPrefix;        // Prefix cho tên object (để phân biệt EA vs Indicator)
   bool saveTooltips;       // Tự động lưu tooltip khi vẽ
};

//+------------------------------------------------------------------+
//| Khởi tạo default config cho SignalDrawConfig                     |
//+------------------------------------------------------------------+
void InitDefaultSignalDrawConfig(SignalDrawConfig& config, string prefix = "SIG_")
{
   config.buyColor = clrLime;
   config.sellColor = clrRed;
   config.slColor = clrOrange;
   config.tpColor = clrAqua;
   config.strongColor = clrWhite;
   config.weakColor = clrYellow;
   // clang-format off
   config.supportColor = C'0,100,0';
   config.resistColor = C'139,0,0';
   // clang-format on
   config.cancelColor = clrGray;
   config.cutBuyColor = clrDodgerBlue;
   config.cutSellColor = clrMagenta;
   config.cutFilteredColor = clrDarkGray;
   config.lineLengthBars = 10;
   config.objPrefix = prefix;
   config.saveTooltips = true;  // Mặc định bật lưu tooltip
}

//+------------------------------------------------------------------+
//| Vẽ signal marker (Arrow, SL line, TP line, S/R zones)            |
//| Return: Base ID của signal để dùng cho tooltip                   |
//+------------------------------------------------------------------+
string DrawSignalMarker(const SignalDrawConfig& config, bool isBuy, bool isCanceled, datetime signalTime,
                        int signalLength, double entryPrice, double slPrice, double tpPrice, string strengthText,
                        double score, string reasons, double support, double resistance, double pointValue,
                        ENUM_TIMEFRAMES period)
{
   string id = config.objPrefix + IntegerToString(signalTime);

   // Skip nếu đã tồn tại
   if (ObjectFind(0, id + "_AR") >= 0)
      return "";

   datetime endTime = signalTime + MathMin(config.lineLengthBars, signalLength) * PeriodSeconds(period);

   // Entry Arrow
   ObjectCreate(0, id + "_AR", OBJ_ARROW, 0, signalTime, entryPrice);
   ObjectSetInteger(0, id + "_AR", OBJPROP_ARROWCODE, isCanceled ? 251 : (isBuy ? 233 : 234));
   ObjectSetInteger(0, id + "_AR", OBJPROP_COLOR,
                    isCanceled ? config.cancelColor : (isBuy ? config.buyColor : config.sellColor));
   ObjectSetInteger(0, id + "_AR", OBJPROP_WIDTH, 2);

   // Stop Loss Line
   if (slPrice > 0)
   {
      ObjectCreate(0, id + "_SL", OBJ_TREND, 0, signalTime, slPrice, endTime, slPrice);
      ObjectSetInteger(0, id + "_SL", OBJPROP_COLOR, config.slColor);
      ObjectSetInteger(0, id + "_SL", OBJPROP_RAY, false);
      ObjectSetInteger(0, id + "_SL", OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, id + "_SL", OBJPROP_STYLE, STYLE_SOLID);
   }

   // Take Profit Line
   if (tpPrice > 0)
   {
      ObjectCreate(0, id + "_TP", OBJ_TREND, 0, signalTime, tpPrice, endTime, tpPrice);
      ObjectSetInteger(0, id + "_TP", OBJPROP_COLOR, config.tpColor);
      ObjectSetInteger(0, id + "_TP", OBJPROP_RAY, false);
      ObjectSetInteger(0, id + "_TP", OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, id + "_TP", OBJPROP_STYLE, STYLE_SOLID);
   }

   // Signal Strength Label + Tooltip
   string signalType = isBuy ? "BUY" : "SELL";
   color labelColor = (strengthText == "STRONG") ? config.strongColor : config.weakColor;

   // Tính khoảng cách SL và TP theo points
   int slPoints = (int)(MathAbs(entryPrice - slPrice) / pointValue);
   int tpPoints = (int)(MathAbs(tpPrice - entryPrice) / pointValue);

   // Tạo tooltip text (hiển thị khi hover)
   string tooltipText = StringFormat("%s %s (Điểm: %.1f)\nVào: %.5f\nSL: %d pts (%.5f)\nTP: %d pts (%.5f)", signalType,
                                     strengthText, score, entryPrice, slPoints, slPrice, tpPoints, tpPrice);
   if (reasons != "")
      tooltipText += "\nCảnh báo:\n" + reasons;

   // Label hiển thị STRONG/WEAK
   if (!isCanceled)
   {
      double labelPrice = isBuy ? entryPrice + (tpPrice - entryPrice) * 0.1 : entryPrice - (entryPrice - tpPrice) * 0.1;
      datetime labelTime = signalTime - PeriodSeconds(period);
      ObjectCreate(0, id + "_LBL", OBJ_TEXT, 0, labelTime, labelPrice);
      ObjectSetString(0, id + "_LBL", OBJPROP_TEXT, strengthText);
      ObjectSetInteger(0, id + "_LBL", OBJPROP_COLOR, labelColor);
      ObjectSetInteger(0, id + "_LBL", OBJPROP_FONTSIZE, 10);
      ObjectSetString(0, id + "_LBL", OBJPROP_FONT, "Arial Bold");
      ObjectSetString(0, id + "_LBL", OBJPROP_TOOLTIP, tooltipText);
   }

   // Thêm tooltip cho Arrow
   ObjectSetString(0, id + "_AR", OBJPROP_TOOLTIP, tooltipText);

   // Thêm tooltip cho SL line
   if (slPrice > 0)
   {
      ObjectSetString(0, id + "_SL", OBJPROP_TOOLTIP, StringFormat("Stop Loss: %.5f (%d pts)", slPrice, slPoints));
   }

   // Thêm tooltip cho TP line
   if (tpPrice > 0)
   {
      ObjectSetString(0, id + "_TP", OBJPROP_TOOLTIP, StringFormat("Take Profit: %.5f (%d pts)", tpPrice, tpPoints));
   }

   // S/R Zone Boxes - Vẽ cả 2 vùng Support và Resistance
   if (isBuy && support > 0)
   {
      // BUY: Vùng Support (xanh) từ support đến entry
      ObjectCreate(0, id + "_S", OBJ_RECTANGLE, 0, signalTime, support, endTime, entryPrice);
      ObjectSetInteger(0, id + "_S", OBJPROP_COLOR, config.resistColor);
      ObjectSetInteger(0, id + "_S", OBJPROP_FILL, true);
      ObjectSetInteger(0, id + "_S", OBJPROP_BACK, true);
      ObjectSetString(0, id + "_S", OBJPROP_TOOLTIP, StringFormat("Vùng Hỗ Trợ: %.5f - %.5f", support, entryPrice));

      // BUY: Vùng Resistance (đỏ) từ entry đến resistance
      ObjectCreate(0, id + "_R", OBJ_RECTANGLE, 0, signalTime, entryPrice, endTime, resistance);
      ObjectSetInteger(0, id + "_R", OBJPROP_COLOR, config.supportColor);
      ObjectSetInteger(0, id + "_R", OBJPROP_FILL, true);
      ObjectSetInteger(0, id + "_R", OBJPROP_BACK, true);
      ObjectSetString(0, id + "_R", OBJPROP_TOOLTIP,
                      StringFormat("Vùng Kháng Cự: %.5f - %.5f", entryPrice, resistance));
   }
   else if (!isBuy && resistance > 0)
   {
      // SELL: Vùng Resistance (đỏ) từ resistance đến entry
      ObjectCreate(0, id + "_R", OBJ_RECTANGLE, 0, signalTime, resistance, endTime, entryPrice);
      ObjectSetInteger(0, id + "_R", OBJPROP_COLOR, config.resistColor);
      ObjectSetInteger(0, id + "_R", OBJPROP_FILL, true);
      ObjectSetInteger(0, id + "_R", OBJPROP_BACK, true);
      ObjectSetString(0, id + "_R", OBJPROP_TOOLTIP,
                      StringFormat("Vùng Kháng Cự: %.5f - %.5f", resistance, entryPrice));

      // SELL: Vùng Support (xanh) từ entry đến support
      ObjectCreate(0, id + "_S", OBJ_RECTANGLE, 0, signalTime, entryPrice, endTime, support);
      ObjectSetInteger(0, id + "_S", OBJPROP_COLOR, config.supportColor);
      ObjectSetInteger(0, id + "_S", OBJPROP_FILL, true);
      ObjectSetInteger(0, id + "_S", OBJPROP_BACK, true);
      ObjectSetString(0, id + "_S", OBJPROP_TOOLTIP, StringFormat("Vùng Hỗ Trợ: %.5f - %.5f", entryPrice, support));
   }

   // Tự động lưu tooltip nếu được bật
   if (config.saveTooltips)
   {
      AddSignalTooltip(id, tooltipText);
   }

   return id;
}

//+------------------------------------------------------------------+
//| Vẽ cut candle marker (Diamond shape)                             |
//+------------------------------------------------------------------+
void DrawCutCandleMarker(const SignalDrawConfig& config, bool isBuy, datetime cutTime, double price, double sma,
                         string filterReason,
                         double pointValue = 0  // Để tính offset tránh overlap
)
{
   string id = config.objPrefix + "CUT_" + IntegerToString(cutTime);
   if (ObjectFind(0, id + "_DIA") >= 0)
      return;

   // Tính offset để tránh overlap với cancel marker
   // BUY: dịch xuống dưới, SELL: dịch lên trên
   double offset = 0;
   if (pointValue > 0)
   {
      offset = 50 * pointValue;  // 50 points offset
      if (isBuy)
         offset = -offset;  // BUY: dịch xuống (giá thấp hơn)
                            // SELL: giữ nguyên dương (giá cao hơn)
   }
   double markerPrice = price + offset;

   // Diamond marker để đánh dấu nến cắt SMA
   ObjectCreate(0, id + "_DIA", OBJ_ARROW, 0, cutTime, markerPrice);
   ObjectSetInteger(0, id + "_DIA", OBJPROP_ARROWCODE, filterReason == "" ? 117 : 78);  // Diamond or skull (Wingdings)

   color markerColor;
   if (filterReason != "")
      markerColor = config.cutFilteredColor;
   else
      markerColor = isBuy ? config.cutBuyColor : config.cutSellColor;

   ObjectSetInteger(0, id + "_DIA", OBJPROP_COLOR, markerColor);
   ObjectSetInteger(0, id + "_DIA", OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, id + "_DIA", OBJPROP_ANCHOR, isBuy ? ANCHOR_TOP : ANCHOR_BOTTOM);

   // Tooltip
   string signalType =
       filterReason == "" ? (isBuy ? "Setup BUY" : "Setup SELL") : (isBuy ? "Bỏ qua BUY" : "Bỏ qua SELL");
   string tooltip = filterReason == ""
                        ? StringFormat("%s - Nến cắt SMA = %.5f", signalType, sma)
                        : StringFormat("%s - Nến cắt SMA = %.5f lọc do: %s", signalType, sma, filterReason);
   ObjectSetString(0, id + "_DIA", OBJPROP_TOOLTIP, tooltip);
}

//+------------------------------------------------------------------+
//| Xóa tất cả objects có prefix của signal drawer                   |
//+------------------------------------------------------------------+
void DeleteAllSignalObjects(string objPrefix)
{
   ObjectsDeleteAll(0, objPrefix);
}

// ============================================================
// =================== ATR CALCULATION ========================
// ============================================================

// Enum định nghĩa loại range để tính ATR
enum ENUM_ATR_RANGE_TYPE
{
   ATR_HIGH_LOW,   // High - Low (True Range truyền thống)
   ATR_CLOSE_OPEN  // |Close - Open| (Body range)
};

//+------------------------------------------------------------------+
//| Tính Average True Range (ATR) linh hoạt                          |
//| Params:                                                          |
//|   high[]     - Mảng giá high                                     |
//|   low[]      - Mảng giá low                                      |
//|   open[]     - Mảng giá open (dùng cho ATR_CLOSE_OPEN)           |
//|   close[]    - Mảng giá close (dùng cho ATR_CLOSE_OPEN)          |
//|   startIdx   - Index bắt đầu tính (inclusive)                    |
//|   atrLength  - Số nến để tính ATR                                |
//|   arraySize  - Kích thước mảng                                   |
//|   rangeType  - Loại range (ATR_HIGH_LOW hoặc ATR_CLOSE_OPEN)     |
//| Return: Giá trị ATR, 0 nếu không đủ data                         |
//+------------------------------------------------------------------+
double CalculateATR(const double& high[], const double& low[], const double& open[], const double& close[],
                    int startIdx, int atrLength, int arraySize, ENUM_ATR_RANGE_TYPE rangeType = ATR_HIGH_LOW)
{
   // Validate input
   if (startIdx < 0 || atrLength <= 0)
      return 0;

   int atrBars = MathMin(atrLength, arraySize - startIdx - 1);
   if (atrBars <= 0)
      return 0;

   double sum = 0;
   for (int i = 0; i < atrBars; i++)
   {
      int idx = startIdx + i;
      if (rangeType == ATR_HIGH_LOW)
         sum += high[idx] - low[idx];
      else  // ATR_CLOSE_OPEN
         sum += MathAbs(close[idx] - open[idx]);
   }

   return sum / atrBars;
}

// ============================================================
// =================== CANDLE UTILITIES =======================
// ============================================================

//+------------------------------------------------------------------+
//| Lấy N candles từ timeframe bất kỳ tính từ thời điểm chỉ định     |
//| Params:                                                          |
//|   symbol     - Symbol cần lấy dữ liệu (NULL = symbol hiện tại)   |
//|   timeframe  - Timeframe cần lấy (không phụ thuộc chart)         |
//|   fromTime   - Thời điểm bắt đầu (lấy từ đây về trước)           |
//|   count      - Số candles cần lấy                                |
//|   time[]     - Mảng output thời gian                             |
//|   open[]     - Mảng output giá mở cửa                            |
//|   high[]     - Mảng output giá cao nhất                          |
//|   low[]      - Mảng output giá thấp nhất                         |
//|   close[]    - Mảng output giá đóng cửa                          |
//|   volume[]   - Mảng output khối lượng (tick volume)              |
//| Return: Số candles thực tế đã lấy được, -1 nếu lỗi               |
//| Note: index [0] là candle gần nhất với fromTime                  |
//+------------------------------------------------------------------+
int GetHistoricalCandles(const string symbol, ENUM_TIMEFRAMES timeframe, datetime fromTime, int count, datetime& time[],
                         double& open[], double& high[], double& low[], double& close[], long& volume[])
{
   if (count <= 0)
      return -1;

   string sym = (symbol == NULL || symbol == "") ? Symbol() : symbol;

   // Tìm index của candle tại hoặc trước fromTime
   int startBar = iBarShift(sym, timeframe, fromTime, false);
   if (startBar < 0)
   {
      Print("GetHistoricalCandles: Không tìm thấy bar tại thời điểm ", fromTime);
      return -1;
   }

   // Đảm bảo không vượt quá số bars có sẵn
   int availableBars = iBars(sym, timeframe);
   int actualCount = MathMin(count, availableBars - startBar);
   if (actualCount <= 0)
   {
      Print("GetHistoricalCandles: Không đủ dữ liệu lịch sử");
      return -1;
   }

   // Copy dữ liệu từng candle
   MqlRates rates[];
   ArraySetAsSeries(rates, true);

   int copied = CopyRates(sym, timeframe, startBar, actualCount, rates);
   if (copied <= 0)
   {
      Print("GetHistoricalCandles: Lỗi CopyRates, error code = ", GetLastError());
      return -1;
   }

   // Resize các mảng output
   ArrayResize(time, copied);
   ArrayResize(open, copied);
   ArrayResize(high, copied);
   ArrayResize(low, copied);
   ArrayResize(close, copied);
   ArrayResize(volume, copied);

   // Copy dữ liệu vào các mảng riêng biệt (rates đã là series nên [0] là candle mới nhất)
   for (int i = 0; i < copied; i++)
   {
      time[i] = rates[i].time;
      open[i] = rates[i].open;
      high[i] = rates[i].high;
      low[i] = rates[i].low;
      close[i] = rates[i].close;
      volume[i] = rates[i].tick_volume;
   }

   return copied;
}

// ============================================================
// =================== TIMEFRAME UTILITIES ====================
// ============================================================

//+------------------------------------------------------------------+
//| Danh sách tất cả các timeframe chuẩn của MT5                     |
//+------------------------------------------------------------------+
ENUM_TIMEFRAMES g_allTimeframes[] = {PERIOD_M1,  PERIOD_M2,  PERIOD_M3,  PERIOD_M4,  PERIOD_M5, PERIOD_M6, PERIOD_M10,
                                     PERIOD_M12, PERIOD_M15, PERIOD_M20, PERIOD_M30, PERIOD_H1, PERIOD_H2, PERIOD_H3,
                                     PERIOD_H4,  PERIOD_H6,  PERIOD_H8,  PERIOD_H12, PERIOD_D1, PERIOD_W1, PERIOD_MN1};

//+------------------------------------------------------------------+
//| Lấy danh sách các timeframe CAO HƠN timeframe hiện tại           |
//| Params:                                                          |
//|   currentTF     - Timeframe hiện tại (0 = Period() của chart)    |
//|   higherTFs[]   - Mảng output chứa các timeframe cao hơn         |
//| Return: Số lượng timeframe cao hơn tìm được                      |
//| Note: Mảng output được sắp xếp từ thấp đến cao                   |
//+------------------------------------------------------------------+
int GetHigherTimeframes(ENUM_TIMEFRAMES currentTF, ENUM_TIMEFRAMES& higherTFs[])
{
   // Nếu truyền 0 hoặc PERIOD_CURRENT, lấy timeframe của chart
   if (currentTF == 0 || currentTF == PERIOD_CURRENT)
      currentTF = (ENUM_TIMEFRAMES)Period();

   // Lấy số giây của timeframe hiện tại
   int currentSeconds = PeriodSeconds(currentTF);

   // Đếm số timeframe cao hơn
   int count = 0;
   int totalTFs = ArraySize(g_allTimeframes);

   for (int i = 0; i < totalTFs; i++)
   {
      if (PeriodSeconds(g_allTimeframes[i]) > currentSeconds)
         count++;
   }

   if (count == 0)
   {
      ArrayResize(higherTFs, 0);
      return 0;
   }

   // Resize và copy các timeframe cao hơn
   ArrayResize(higherTFs, count);
   int idx = 0;

   for (int i = 0; i < totalTFs; i++)
   {
      if (PeriodSeconds(g_allTimeframes[i]) > currentSeconds)
      {
         higherTFs[idx] = g_allTimeframes[i];
         idx++;
      }
   }

   return count;
}

//+------------------------------------------------------------------+
//| Chuyển ENUM_TIMEFRAMES sang chuỗi hiển thị                       |
//| Ví dụ: PERIOD_M5 -> "M5", PERIOD_H1 -> "H1"                      |
//+------------------------------------------------------------------+
string TimeframeToString(ENUM_TIMEFRAMES tf)
{
   switch (tf)
   {
      case PERIOD_M1:
         return "M1";
      case PERIOD_M2:
         return "M2";
      case PERIOD_M3:
         return "M3";
      case PERIOD_M4:
         return "M4";
      case PERIOD_M5:
         return "M5";
      case PERIOD_M6:
         return "M6";
      case PERIOD_M10:
         return "M10";
      case PERIOD_M12:
         return "M12";
      case PERIOD_M15:
         return "M15";
      case PERIOD_M20:
         return "M20";
      case PERIOD_M30:
         return "M30";
      case PERIOD_H1:
         return "H1";
      case PERIOD_H2:
         return "H2";
      case PERIOD_H3:
         return "H3";
      case PERIOD_H4:
         return "H4";
      case PERIOD_H6:
         return "H6";
      case PERIOD_H8:
         return "H8";
      case PERIOD_H12:
         return "H12";
      case PERIOD_D1:
         return "D1";
      case PERIOD_W1:
         return "W1";
      case PERIOD_MN1:
         return "MN1";
      default:
         return EnumToString(tf);
   }
}

#endif  // UTILITY_H
