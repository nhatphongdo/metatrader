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
//| Tính vùng Hỗ trợ / Kháng cự từ vùng giá                          |
//| Trả về giá hỗ trợ, kháng cự qua tham chiếu                       |
//+------------------------------------------------------------------+
void CalculateSupportResistance(const double& high[], const double& low[], int arraySize,
                                int idx,    // Vị trí nến bắt đầu tính
                                int count,  // Số nến cần tính, bao gồm cả vị trí đầu tiên
                                double& outSupport, double& outResistance)
{
   if (arraySize == 0 || idx >= arraySize)
   {
      outSupport = 0;
      outResistance = 0;
      return;
   }

   outSupport = low[idx];
   outResistance = high[idx];

   int endIdx = MathMin(idx + count - 1, arraySize - 1);
   for (int i = idx + 1; i <= endIdx; i++)
   {
      if (low[i] < outSupport)
         outSupport = low[i];
      if (high[i] > outResistance)
         outResistance = high[i];
   }
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
//| Xóa tất cả objects có prefix của signal drawer                   |
//+------------------------------------------------------------------+
void DeleteAllSignalObjects(string objPrefix)
{
   ObjectsDeleteAll(0, objPrefix);
}

// Tên label tooltip cố định
#define TOOLTIP_LABEL_NAME "SIGNAL_TOOLTIP_LABEL"

// Giới hạn ký tự tối đa cho mỗi label (MT5 limit là 63)
#define TOOLTIP_MAX_LABEL_CHARS 63

//+------------------------------------------------------------------+
//| Helper: Tạo một label segment                                    |
//+------------------------------------------------------------------+
void CreateTooltipLabelSegment(string labelName, string labelText, int xDist, int yDist, int textColor, int fontSize)
{
   ObjectCreate(0, labelName, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, labelName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, labelName, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
   ObjectSetInteger(0, labelName, OBJPROP_XDISTANCE, xDist);
   ObjectSetInteger(0, labelName, OBJPROP_YDISTANCE, yDist);
   ObjectSetInteger(0, labelName, OBJPROP_COLOR, textColor);
   ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, fontSize);
   ObjectSetString(0, labelName, OBJPROP_FONT, "Consolas");
   ObjectSetString(0, labelName, OBJPROP_TEXT, labelText);
   ObjectSetInteger(0, labelName, OBJPROP_BACK, false);
   ObjectSetInteger(0, labelName, OBJPROP_SELECTABLE, false);
}

//+------------------------------------------------------------------+
//| Hiển thị tooltip bằng custom label (hỗ trợ multi-line)           |
//| Tự động chia nhỏ dòng dài hơn 63 ký tự thành nhiều label ngang   |
//+------------------------------------------------------------------+
void ShowTooltipLabel(string text, int textColor = clrYellow, int fontSize = 12)
{
   // Xóa tất cả label cũ
   ObjectsDeleteAll(0, TOOLTIP_LABEL_NAME);

   if (text == "")
      return;

   // Tách text thành các dòng
   string lines[];
   int lineCount = StringSplit(text, '\n', lines);
   if (lineCount <= 0)
      return;

   // Khoảng cách giữa các dòng (dựa trên font size)
   int lineHeight = (int)(fontSize * 1.7);
   int startY = 10;
   int startX = 10;

   int labelCount = 0;

   // Tạo label cho từng dòng
   for (int i = 0; i < lineCount; i++)
   {
      string lineText = lines[i];

      // Bỏ qua dòng trống
      StringTrimRight(lineText);
      StringTrimLeft(lineText);
      int lineLen = StringLen(lineText);
      if (lineLen == 0)
         continue;

      int yPos = startY + i * lineHeight;

      // Chia thành nhiều label ngang
      int segmentCount = (int)MathCeil((double)lineLen / TOOLTIP_MAX_LABEL_CHARS);
      for (int seg = 0; seg < segmentCount; seg++)
      {
         int startPos = seg * TOOLTIP_MAX_LABEL_CHARS;
         int segLen = MathMin(TOOLTIP_MAX_LABEL_CHARS, lineLen - startPos);
         string segText = StringSubstr(lineText, startPos, segLen);

         string labelName = TOOLTIP_LABEL_NAME + "_" + IntegerToString(i) + "_" + IntegerToString(seg);
         CreateTooltipLabelSegment(labelName, segText, startX, yPos, textColor, fontSize);
         ++labelCount;
      }
   }

   // Chờ chart draw để có kích thước chính xác
   ChartRedraw();
   Sleep(1000);

   // Tìm tổng chiều rộng lớn nhất của mỗi dòng
   int labelWidths[];
   ArrayResize(labelWidths, labelCount);
   int j = 0;
   int maxTotalWidth = 0;
   for (int i = 0; i < lineCount; i++)
   {
      int lineWidth = 0;
      // Tìm tất cả segments của dòng i
      for (int seg = 0; seg < 100; seg++)
      {
         string labelName = TOOLTIP_LABEL_NAME + "_" + IntegerToString(i) + "_" + IntegerToString(seg);
         if (ObjectFind(0, labelName) < 0)
            break;

         int width = (int)ObjectGetInteger(0, labelName, OBJPROP_XSIZE);
         labelWidths[j++] = width;
         lineWidth += width;
      }
      if (lineWidth > maxTotalWidth)
         maxTotalWidth = lineWidth;
   }

   // Căn chỉnh tất cả các label sang phải
   j = 0;
   for (int i = 0; i < lineCount; i++)
   {
      // Tìm tất cả segments của dòng i
      for (int seg = 0; seg < 100; seg++)
      {
         string labelName = TOOLTIP_LABEL_NAME + "_" + IntegerToString(i) + "_" + IntegerToString(seg);
         if (ObjectFind(0, labelName) < 0)
            break;
         int lastWidth = seg == 0 ? 0 : labelWidths[j - 1];
         j++;
         ObjectSetInteger(0, labelName, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
         ObjectSetInteger(0, labelName, OBJPROP_XDISTANCE, maxTotalWidth - lastWidth + startX);
      }
   }
}

//+------------------------------------------------------------------+
//| Xóa tooltip label                                                |
//+------------------------------------------------------------------+
void HideTooltipLabel()
{
   ObjectsDeleteAll(0, TOOLTIP_LABEL_NAME);
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
