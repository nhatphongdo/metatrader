//+------------------------------------------------------------------+
//|                                                 Draw Utilities   |
//|                                    Copyright 2026, Do Nhat Phong |
//|                                   https://github.com/nhatphongdo |
//+------------------------------------------------------------------+
//| Module chứa các hàm vẽ dùng chung                                |
//+------------------------------------------------------------------+
#property copyright "Do Nhat Phong"

#ifndef DRAW_UTILITIES_H
#define DRAW_UTILITIES_H

// ==================================================
// ============== DRAWING UTILITIES =================
// ==================================================
// Các hàm vẽ tín hiệu dùng chung cho EA và Indicator

//+------------------------------------------------------------------+
//| Xử lý chart event cho signal objects                             |
//| Gọi hàm này từ OnChartEvent của EA/Indicator                     |
//| Return: true nếu đã xử lý event, false nếu không liên quan       |
//+------------------------------------------------------------------+
bool HandleSignalChartEvent(const int id, const long& lparam, const double& dparam, const string& sparam,
                            const string objPrefix, long& lastMouseX, long& lastMouseY)
{
   // Xử lý khi click vào object
   if (id == CHARTEVENT_OBJECT_CLICK)
   {
      lastMouseX = -1;
      lastMouseY = -1;
      // Kiểm tra xem object có thuộc prefix này không
      if (StringFind(sparam, objPrefix) == 0)
      {
         // Tìm tooltip data cho object này - strip suffix
         string baseId = sparam;

         // Loại bỏ suffix - QUAN TRỌNG: check _STR, _SL trước _S, _AR trước _R
         int pos = StringFind(baseId, "_DIA");
         if (pos > 0)
            baseId = StringSubstr(baseId, 0, pos);
         pos = StringFind(baseId, "_LBL");
         if (pos > 0)
            baseId = StringSubstr(baseId, 0, pos);
         pos = StringFind(baseId, "_STR");
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
            lastMouseX = lparam;
            lastMouseY = dparam;
            Comment(tooltip);
            ChartRedraw();
            return true;
         }
      }
   }
   // Click vào vùng trống - xóa comment
   else if (id == CHARTEVENT_CLICK)
   {
      // Do double events (OBJECT_CLICK và CLICK đều được gọi), cần kiểm tra last mouse position nếu không đổi thì không
      // clear comment
      if (lastMouseX == lparam && lastMouseY == dparam)
         return true;

      lastMouseX = -1;
      lastMouseY = -1;
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
string DrawSignalMarker(const SignalDrawConfig& config, int signalIdx, bool isBuy, bool isCanceled, datetime signalTime,
                        int signalLength, double entryPrice, double slPrice, double tpPrice, string strengthText,
                        double score, string reasons, double support, double resistance, string patternName,
                        double pointValue, ENUM_TIMEFRAMES period)
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
   if (isCanceled)
   {
      ObjectSetInteger(0, id + "_AR", OBJPROP_ANCHOR, isBuy ? ANCHOR_TOP : ANCHOR_BOTTOM);
   }

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
   string tooltipText = StringFormat("#%d. %s %s (Điểm: %.1f)", signalIdx, signalType, strengthText, score);

   if (!isCanceled)
   {
      tooltipText += StringFormat("\nVào: %.5f, mô hình: %s\nSL: %d pts (%.5f)\nTP: %d pts (%.5f)", entryPrice,
                                  patternName, slPoints, slPrice, tpPoints, tpPrice);
   }

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
void DrawCutCandleMarker(const SignalDrawConfig& config, int signalIdx, bool isBuy, datetime startTime,
                         double startPrice, datetime cutTime, double price, double sma, string filterReason,
                         double pointValue = 0  // Để tính offset tránh overlap
)
{
   string id = config.objPrefix + "CUT_" + IntegerToString(cutTime);
   if (ObjectFind(0, id + "_DIA") >= 0)
      return;

   // Diamond marker để đánh dấu nến cắt SMA
   ObjectCreate(0, id + "_DIA", OBJ_ARROW, 0, cutTime, price);
   ObjectSetInteger(0, id + "_DIA", OBJPROP_ARROWCODE, filterReason == "" ? 117 : 78);  // Diamond or skull (Wingdings)

   color markerColor;
   if (filterReason != "")
      markerColor = config.cutFilteredColor;
   else
      markerColor = isBuy ? config.cutBuyColor : config.cutSellColor;

   ObjectSetInteger(0, id + "_DIA", OBJPROP_COLOR, markerColor);
   ObjectSetInteger(0, id + "_DIA", OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, id + "_DIA", OBJPROP_ANCHOR, isBuy ? ANCHOR_TOP : ANCHOR_BOTTOM);

   // Start marker
   if (startTime != cutTime)
   {
      // Tính offset để tránh overlap với cancel marker
      // BUY: dịch xuống dưới, SELL: dịch lên trên
      double offset = 0;
      if (pointValue > 0)
      {
         offset = 10 * pointValue;  // 10 points offset
         if (isBuy)
            offset = -offset;  // BUY: dịch xuống (giá thấp hơn)
                               // SELL: giữ nguyên dương (giá cao hơn)
      }

      ObjectCreate(0, id + "_STR", OBJ_ARROW, 0, startTime, startPrice + offset);
      ObjectSetInteger(0, id + "_STR", OBJPROP_ARROWCODE, 232);
      ObjectSetInteger(0, id + "_STR", OBJPROP_COLOR, isBuy ? config.cutBuyColor : config.cutSellColor);
      ObjectSetInteger(0, id + "_STR", OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, id + "_STR", OBJPROP_ANCHOR, isBuy ? ANCHOR_TOP : ANCHOR_BOTTOM);
      ObjectSetString(0, id + "_STR", OBJPROP_TOOLTIP, StringFormat("#%d", signalIdx));
   }

   // Tooltip
   string signalType =
       filterReason == "" ? (isBuy ? "Setup BUY" : "Setup SELL") : (isBuy ? "Bỏ qua BUY" : "Bỏ qua SELL");
   string tooltip = filterReason == "" ? StringFormat("#%d. %s - Nến cắt SMA = %.5f", signalIdx, signalType, sma)
                                       : StringFormat("#%d. %s - Nến cắt SMA = %.5f lọc do: %s", signalIdx, signalType,
                                                      sma, filterReason);
   ObjectSetString(0, id + "_DIA", OBJPROP_TOOLTIP, tooltip);
}

#endif  // DRAW_UTILITIES_H
