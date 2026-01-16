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
   string            objectId;      // ID của object (prefix + timestamp)
   string            fullTooltip;   // Nội dung đầy đủ hiển thị khi click
  };

// Global tooltip storage - sử dụng prefix để phân biệt nguồn
TooltipData g_signalTooltips[];     // Mảng lưu tất cả tooltips
int         g_signalTooltipCount = 0;

//+------------------------------------------------------------------+
//| Thêm tooltip vào mảng global                                     |
//+------------------------------------------------------------------+
void AddSignalTooltip(const string objectId, const string tooltipText)
  {
   if(objectId == "" || tooltipText == "")
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
   for(int i = 0; i < g_signalTooltipCount; i++)
     {
      if(g_signalTooltips[i].objectId == objectId)
         return g_signalTooltips[i].fullTooltip;
     }
   return "";
  }

//+------------------------------------------------------------------+
//| Xóa tất cả tooltips có prefix cụ thể                             |
//+------------------------------------------------------------------+
void ClearSignalTooltips(const string objPrefix = "")
  {
   if(objPrefix == "")
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

      for(int i = 0; i < g_signalTooltipCount; i++)
        {
         if(StringFind(g_signalTooltips[i].objectId, objPrefix) != 0)
           {
            ArrayResize(filtered, filteredCount + 1);
            filtered[filteredCount] = g_signalTooltips[i];
            filteredCount++;
           }
        }

      ArrayResize(g_signalTooltips, filteredCount);
      for(int i = 0; i < filteredCount; i++)
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
bool HandleSignalChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam, const string objPrefix)
  {
// Xử lý khi click vào object
   if(id == CHARTEVENT_OBJECT_CLICK)
     {
      // Kiểm tra xem object có thuộc prefix này không
      if(StringFind(sparam, objPrefix) == 0)
        {
         // Tìm tooltip data cho object này - strip suffix
         string baseId = sparam;

         // Loại bỏ suffix - QUAN TRỌNG: check _SL trước _S, _AR trước _R
         int pos = StringFind(baseId, "_DIA");
         if(pos > 0)
            baseId = StringSubstr(baseId, 0, pos);
         pos = StringFind(baseId, "_LBL");
         if(pos > 0)
            baseId = StringSubstr(baseId, 0, pos);
         pos = StringFind(baseId, "_SL");
         if(pos > 0)
            baseId = StringSubstr(baseId, 0, pos);
         pos = StringFind(baseId, "_TP");
         if(pos > 0)
            baseId = StringSubstr(baseId, 0, pos);
         pos = StringFind(baseId, "_AR");
         if(pos > 0)
            baseId = StringSubstr(baseId, 0, pos);
         pos = StringFind(baseId, "_S");
         if(pos > 0)
            baseId = StringSubstr(baseId, 0, pos);
         pos = StringFind(baseId, "_R");
         if(pos > 0)
            baseId = StringSubstr(baseId, 0, pos);

         // Tìm tooltip trong mảng global
         string tooltip = FindSignalTooltip(baseId);
         if(tooltip != "")
           {
            Comment(tooltip);
            ChartRedraw();
            return true;
           }
        }
     }
// Click vào vùng trống - xóa comment
   else
      if(id == CHARTEVENT_CLICK)
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
   color             buyColor;        // Màu BUY arrow
   color             sellColor;       // Màu SELL arrow
   color             slColor;         // Màu đường SL
   color             tpColor;         // Màu đường TP
   color             strongColor;     // Màu label STRONG
   color             weakColor;       // Màu label WEAK
   color             supportColor;    // Màu vùng Support
   color             resistColor;     // Màu vùng Resistance
   color             cancelColor;     // Màu tín hiệu bị hủy
   color             cutBuyColor;     // Màu cut marker BUY
   color             cutSellColor;    // Màu cut marker SELL
   color             cutFilteredColor;// Màu cut marker bị lọc
   int               lineLengthBars;  // Độ dài đường SL/TP (số nến)
   string            objPrefix;       // Prefix cho tên object (để phân biệt EA vs Indicator)
   bool              saveTooltips;    // Tự động lưu tooltip khi vẽ
  };

//+------------------------------------------------------------------+
//| Khởi tạo default config cho SignalDrawConfig                     |
//+------------------------------------------------------------------+
void InitDefaultSignalDrawConfig(SignalDrawConfig &config, string prefix = "SIG_")
  {
   config.buyColor = clrLime;
   config.sellColor = clrRed;
   config.slColor = clrOrange;
   config.tpColor = clrAqua;
   config.strongColor = clrWhite;
   config.weakColor = clrYellow;
   config.supportColor = C'0,100,0';
   config.resistColor = C'139,0,0';
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
string DrawSignalMarker(
   const SignalDrawConfig &config,
   bool     isBuy,
   bool     isCanceled,
   datetime signalTime,
   int      signalLength,
   double   entryPrice,
   double   slPrice,
   double   tpPrice,
   string   strengthText,
   double   score,
   string   reasons,
   double   support,
   double   resistance,
   double   pointValue,
   ENUM_TIMEFRAMES period
)
  {
   string id = config.objPrefix + IntegerToString(signalTime);

// Skip nếu đã tồn tại
   if(ObjectFind(0, id + "_AR") >= 0)
      return "";

   datetime endTime = signalTime + MathMin(config.lineLengthBars, signalLength) * PeriodSeconds(period);

// Entry Arrow
   ObjectCreate(0, id+"_AR", OBJ_ARROW, 0, signalTime, entryPrice);
   ObjectSetInteger(0, id+"_AR", OBJPROP_ARROWCODE, isCanceled ? 251 : (isBuy ? 233 : 234));
   ObjectSetInteger(0, id+"_AR", OBJPROP_COLOR, isCanceled ? config.cancelColor : (isBuy ? config.buyColor : config.sellColor));
   ObjectSetInteger(0, id+"_AR", OBJPROP_WIDTH, 2);

// Stop Loss Line
   if(slPrice > 0)
     {
      ObjectCreate(0, id+"_SL", OBJ_TREND, 0, signalTime, slPrice, endTime, slPrice);
      ObjectSetInteger(0, id+"_SL", OBJPROP_COLOR, config.slColor);
      ObjectSetInteger(0, id+"_SL", OBJPROP_RAY, false);
      ObjectSetInteger(0, id+"_SL", OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, id+"_SL", OBJPROP_STYLE, STYLE_SOLID);
     }

// Take Profit Line
   if(tpPrice > 0)
     {
      ObjectCreate(0, id+"_TP", OBJ_TREND, 0, signalTime, tpPrice, endTime, tpPrice);
      ObjectSetInteger(0, id+"_TP", OBJPROP_COLOR, config.tpColor);
      ObjectSetInteger(0, id+"_TP", OBJPROP_RAY, false);
      ObjectSetInteger(0, id+"_TP", OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, id+"_TP", OBJPROP_STYLE, STYLE_SOLID);
     }

// Signal Strength Label + Tooltip
   string signalType = isBuy ? "BUY" : "SELL";
   color labelColor = (strengthText == "STRONG") ? config.strongColor : config.weakColor;

// Tính khoảng cách SL và TP theo points
   int slPoints = (int)(MathAbs(entryPrice - slPrice) / pointValue);
   int tpPoints = (int)(MathAbs(tpPrice - entryPrice) / pointValue);

// Tạo tooltip text (hiển thị khi hover)
   string tooltipText = StringFormat("%s %s (Điểm: %.1f)\nVào: %.5f\nSL: %d pts (%.5f)\nTP: %d pts (%.5f)",
                                     signalType, strengthText, score, entryPrice,
                                     slPoints, slPrice, tpPoints, tpPrice);
   if(reasons != "")
      tooltipText += "\nCảnh báo:\n" + reasons;

// Label hiển thị STRONG/WEAK
   if(!isCanceled)
     {
      double labelPrice = isBuy ? entryPrice + (tpPrice - entryPrice) * 0.1
                          : entryPrice - (entryPrice - tpPrice) * 0.1;
      datetime labelTime = signalTime - PeriodSeconds(period);
      ObjectCreate(0, id+"_LBL", OBJ_TEXT, 0, labelTime, labelPrice);
      ObjectSetString(0, id+"_LBL", OBJPROP_TEXT, strengthText);
      ObjectSetInteger(0, id+"_LBL", OBJPROP_COLOR, labelColor);
      ObjectSetInteger(0, id+"_LBL", OBJPROP_FONTSIZE, 10);
      ObjectSetString(0, id+"_LBL", OBJPROP_FONT, "Arial Bold");
      ObjectSetString(0, id+"_LBL", OBJPROP_TOOLTIP, tooltipText);
     }

// Thêm tooltip cho Arrow
   ObjectSetString(0, id+"_AR", OBJPROP_TOOLTIP, tooltipText);

// Thêm tooltip cho SL line
   if(slPrice > 0)
     {
      ObjectSetString(0, id+"_SL", OBJPROP_TOOLTIP, StringFormat("Stop Loss: %.5f (%d pts)", slPrice, slPoints));
     }

// Thêm tooltip cho TP line
   if(tpPrice > 0)
     {
      ObjectSetString(0, id+"_TP", OBJPROP_TOOLTIP, StringFormat("Take Profit: %.5f (%d pts)", tpPrice, tpPoints));
     }

// S/R Zone Boxes - Vẽ cả 2 vùng Support và Resistance
   if(isBuy && support > 0)
     {
      // BUY: Vùng Support (xanh) từ support đến entry
      ObjectCreate(0, id+"_S", OBJ_RECTANGLE, 0, signalTime, support, endTime, entryPrice);
      ObjectSetInteger(0, id+"_S", OBJPROP_COLOR, config.resistColor);
      ObjectSetInteger(0, id+"_S", OBJPROP_FILL, true);
      ObjectSetInteger(0, id+"_S", OBJPROP_BACK, true);
      ObjectSetString(0, id+"_S", OBJPROP_TOOLTIP, StringFormat("Vùng Hỗ Trợ: %.5f - %.5f", support, entryPrice));

      // BUY: Vùng Resistance (đỏ) từ entry đến resistance
      ObjectCreate(0, id+"_R", OBJ_RECTANGLE, 0, signalTime, entryPrice, endTime, resistance);
      ObjectSetInteger(0, id+"_R", OBJPROP_COLOR, config.supportColor);
      ObjectSetInteger(0, id+"_R", OBJPROP_FILL, true);
      ObjectSetInteger(0, id+"_R", OBJPROP_BACK, true);
      ObjectSetString(0, id+"_R", OBJPROP_TOOLTIP, StringFormat("Vùng Kháng Cự: %.5f - %.5f", entryPrice, resistance));
     }
   else
      if(!isBuy && resistance > 0)
        {
         // SELL: Vùng Resistance (đỏ) từ resistance đến entry
         ObjectCreate(0, id+"_R", OBJ_RECTANGLE, 0, signalTime, resistance, endTime, entryPrice);
         ObjectSetInteger(0, id+"_R", OBJPROP_COLOR, config.resistColor);
         ObjectSetInteger(0, id+"_R", OBJPROP_FILL, true);
         ObjectSetInteger(0, id+"_R", OBJPROP_BACK, true);
         ObjectSetString(0, id+"_R", OBJPROP_TOOLTIP, StringFormat("Vùng Kháng Cự: %.5f - %.5f", resistance, entryPrice));

         // SELL: Vùng Support (xanh) từ entry đến support
         ObjectCreate(0, id+"_S", OBJ_RECTANGLE, 0, signalTime, entryPrice, endTime, support);
         ObjectSetInteger(0, id+"_S", OBJPROP_COLOR, config.supportColor);
         ObjectSetInteger(0, id+"_S", OBJPROP_FILL, true);
         ObjectSetInteger(0, id+"_S", OBJPROP_BACK, true);
         ObjectSetString(0, id+"_S", OBJPROP_TOOLTIP, StringFormat("Vùng Hỗ Trợ: %.5f - %.5f", entryPrice, support));
        }

// Tự động lưu tooltip nếu được bật
   if(config.saveTooltips)
     {
      AddSignalTooltip(id, tooltipText);
     }

   return id;
  }

//+------------------------------------------------------------------+
//| Vẽ cut candle marker (Diamond shape)                             |
//+------------------------------------------------------------------+
void DrawCutCandleMarker(
   const SignalDrawConfig &config,
   bool     isBuy,
   datetime cutTime,
   double   price,
   double   sma,
   string   filterReason
)
  {
   string id = config.objPrefix + "CUT_" + IntegerToString(cutTime);
   if(ObjectFind(0, id + "_DIA") >= 0)
      return;

// Diamond marker để đánh dấu nến cắt SMA
   ObjectCreate(0, id+"_DIA", OBJ_ARROW, 0, cutTime, price);
   ObjectSetInteger(0, id+"_DIA", OBJPROP_ARROWCODE, filterReason == "" ? 117 : 78); // Diamond or skull (Wingdings)

   color markerColor;
   if(filterReason != "")
      markerColor = config.cutFilteredColor;
   else
      markerColor = isBuy ? config.cutBuyColor : config.cutSellColor;

   ObjectSetInteger(0, id+"_DIA", OBJPROP_COLOR, markerColor);
   ObjectSetInteger(0, id+"_DIA", OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, id+"_DIA", OBJPROP_ANCHOR, isBuy ? ANCHOR_TOP : ANCHOR_BOTTOM);

// Tooltip
   string signalType = filterReason == "" ? (isBuy ? "Setup BUY" : "Setup SELL") : (isBuy ? "Bỏ qua BUY" : "Bỏ qua SELL");
   string tooltip = filterReason == "" ? StringFormat("%s - Nến cắt SMA = %.5f", signalType, sma)
                    : StringFormat("%s - Nến cắt SMA = %.5f lọc do: %s", signalType, sma, filterReason);
   ObjectSetString(0, id+"_DIA", OBJPROP_TOOLTIP, tooltip);
  }

//+------------------------------------------------------------------+
//| Xóa tất cả objects có prefix của signal drawer                   |
//+------------------------------------------------------------------+
void DeleteAllSignalObjects(string objPrefix)
  {
   ObjectsDeleteAll(0, objPrefix);
  }


#endif // UTILITY_H
