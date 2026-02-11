//+------------------------------------------------------------------+
//| AMG_Scalper.mq5                                                  |
//| Based on "Adaptive Momentum Grid" Research                       |
//| Zero Commission Scalping                                         |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Do Nhat Phong"
#property link "https://github.com/nhatphongdo"
#property version "1.00"
#property strict

// Import Trade Library for Order Execution
#include <Trade\Trade.mqh>

// Object of CTrade class
CTrade trade;

//--- INPUT PARAMETERS ---
// Core Indicators
input group "--- Indicator Settings ---";
input int InpMagicNum = 123456;  // Magic Number
input int InpFastEMA = 8;        // Fast EMA (Hỗ trợ xu hướng ngắn)
input int InpMedEMA = 21;        // Medium EMA (Vùng Pullback)
input int InpSlowEMA = 50;       // Slow EMA (Xu hướng chính)
input int InpATR = 14;           // ATR Period (Đo biến động)

// Dynamic TP/SL
input group "--- Risk & Management ---";
input double InpMaxBalance = 0;      // Tài khoản tối đa để tính rủi ro (0 = không giới hạn)
input double InpRiskPercent = 1.0;   // % Rủi ro trên vốn (Risk per trade)
input double InpTP_ATR_Mult = 10.0;  // Hệ số nhân ATR cho TP
input double InpSL_ATR_Mult = 10.0;  // Hệ số nhân ATR cho SL
input int InpMaxOrders = 10;         // Số lệnh tối đa cùng lúc (Grid stacking)
input bool InpUseTrailing = false;   // Kích hoạt Trailing Stop?
input double InpTrail_Start = 5.0;   // Bắt đầu Trail khi lãi đạt (ATR x hệ số)
input double InpTrail_Dist = 3.0;    // Khoảng cách Trail Stop (ATR x hệ số)
input double InpTrail_Step = 0.5;    // Bước nhảy tối thiểu để dời SL (ATR x hệ số)

// Environment Filters
input group "--- Filters ---";
input double InpMaxSpreadATR = 0.2;  // Max Spread allowed (% of ATR)
input int InpStartHour = 8;          // Giờ bắt đầu (GMT)
input int InpEndHour = 20;           // Giờ kết thúc (GMT)
// --- RSI ---
input bool InpUse_RSI = false;  // Kích hoạt lọc RSI?
input int InpRSI = 14;          // RSI Period (Đo xung lượng)
// --- MACD ---
input bool InpUse_MACD = false;  // Kích hoạt lọc MACD?
input int Inp_MACD_Fast = 12;
input int Inp_MACD_Slow = 26;
input int Inp_MACD_Sig = 9;
// --- Stochastic ---
input bool InpUse_Stoch = true;  // Kích hoạt lọc Stoch (Trend > 50)
input int Inp_Stoch_K = 14;
input int Inp_Stoch_D = 3;
input int Inp_Stoch_Slow = 3;
// --- Higher Timeframe MA ---
input bool InpUse_HTF_MA = true;                 // Kích hoạt lọc MA khung lớn?
input ENUM_TIMEFRAMES Inp_HTF_Time = PERIOD_D1;  // Khung thời gian lớn (VD: M15)
input int Inp_HTF_Period = 200;                  // Chu kỳ MA khung lớn
// --- Cooldown ---
input int InpMaxLosses = 3;   // Số lệnh thua liên tiếp để kích hoạt dừng
input int InpPauseMins = 60;  // Thời gian dừng giao dịch (phút) sau chuỗi thua

input group "--- HACK ---";
input bool InpReverseTrade = false;  // Đảo ngược tín hiệu (SELL khi có tín hiệu BUY và ngược lại)

//--- GLOBAL VARIABLES ---
int handle_FastEMA, handle_MedEMA, handle_SlowEMA, handle_ATR, handle_RSI, handle_MACD, handle_Stoch, handle_HTF_MA;
double buff_FastEMA[], buff_MedEMA[], buff_SlowEMA[], buff_ATR[], buff_RSI[], buff_MACD[], buff_Stoch[], buff_HTF_MA[];
datetime lastBarTime;
datetime gl_pause_until = 0;  // Biến lưu thời điểm được phép giao dịch lại

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // 1. Khởi tạo Handles cho các chỉ báo
   handle_FastEMA = iMA(_Symbol, _Period, InpFastEMA, 0, MODE_EMA, PRICE_CLOSE);
   handle_MedEMA = iMA(_Symbol, _Period, InpMedEMA, 0, MODE_EMA, PRICE_CLOSE);
   handle_SlowEMA = iMA(_Symbol, _Period, InpSlowEMA, 0, MODE_EMA, PRICE_CLOSE);
   handle_ATR = iATR(_Symbol, _Period, InpATR);

   if (InpUse_RSI)
      handle_RSI = iRSI(_Symbol, _Period, InpRSI, PRICE_CLOSE);

   if (InpUse_MACD)
      handle_MACD = iMACD(_Symbol, _Period, Inp_MACD_Fast, Inp_MACD_Slow, Inp_MACD_Sig, PRICE_CLOSE);

   if (InpUse_Stoch)
      handle_Stoch = iStochastic(_Symbol, _Period, Inp_Stoch_K, Inp_Stoch_D, Inp_Stoch_Slow, MODE_SMA, STO_LOWHIGH);

   if (InpUse_HTF_MA)
      handle_HTF_MA = iMA(_Symbol, Inp_HTF_Time, Inp_HTF_Period, 0, MODE_EMA, PRICE_CLOSE);

   if (handle_FastEMA == INVALID_HANDLE || handle_MedEMA == INVALID_HANDLE || handle_SlowEMA == INVALID_HANDLE ||
       handle_ATR == INVALID_HANDLE || handle_RSI == INVALID_HANDLE)
   {
      Print("Lỗi: Không thể khởi tạo chỉ báo!");
      return (INIT_FAILED);
   }

   // 2. Thiết lập Arrays
   ArraySetAsSeries(buff_FastEMA, true);
   ArraySetAsSeries(buff_MedEMA, true);
   ArraySetAsSeries(buff_SlowEMA, true);
   ArraySetAsSeries(buff_ATR, true);
   ArraySetAsSeries(buff_RSI, true);
   ArraySetAsSeries(buff_MACD, true);
   ArraySetAsSeries(buff_Stoch, true);
   ArraySetAsSeries(buff_HTF_MA, true);

   // 3. Cấu hình đối tượng Trade
   trade.SetExpertMagicNumber(InpMagicNum);
   trade.SetDeviationInPoints(5);  // Kiểm soát trượt giá
   trade.SetTypeFilling(ORDER_FILLING_FOK);

   return (INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   IndicatorRelease(handle_FastEMA);
   IndicatorRelease(handle_MedEMA);
   IndicatorRelease(handle_SlowEMA);
   IndicatorRelease(handle_ATR);
   if (InpUse_RSI)
      IndicatorRelease(handle_RSI);
   if (InpUse_MACD)
      IndicatorRelease(handle_MACD);
   if (InpUse_Stoch)
      IndicatorRelease(handle_Stoch);
   if (InpUse_HTF_MA)
      IndicatorRelease(handle_HTF_MA);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // New Bar Check - We only trade on confirmed close candles
   datetime currentTime = iTime(_Symbol, _Period, 0);
   if (currentTime == lastBarTime)
      return;  // Already checked this bar
   lastBarTime = currentTime;

   // Lấy dữ liệu nến và chỉ báo
   if (!GetData())
      return;

   // --- A. QUẢN LÝ LỆNH ĐANG MỞ (TRAILING STOP) ---
   if (InpUseTrailing)
      ManagePositions();

   // --- B. KIỂM TRA ĐIỀU KIỆN MÔI TRƯỜNG ---

   // 1. Kiểm tra Cooldown (Dừng trade sau chuỗi thua)
   if (IsTradingPaused())
      return;

   // 2. Kiểm tra thời gian (Time Filter)
   MqlDateTime dt;
   TimeGMT(dt);
   if (dt.hour < InpStartHour || dt.hour >= InpEndHour)
      return;

   double atr_val = buff_ATR[1];

   // 3. Kiểm tra Spread (Spread < 20% ATR)
   // Critical for Zero Commission accounts
   double currentSpread = (SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID));
   if (currentSpread > (atr_val * InpMaxSpreadATR))
   {
      Print("Spread quá cao so với ATR. Bỏ qua.");
      return;
   }

   // 4. Kiểm tra số lượng lệnh tối đa (Max Orders Grid)
   if (PositionsTotal() >= InpMaxOrders)
      return;

   // --- C. LOGIC XÁC ĐỊNH TREND ---
   // 1 = Uptrend, -1 = Downtrend, 0 = Mixed/Neutral
   int trend_direction = GetCombinedTrend();

   // --- D. LOGIC VÀO LỆNH ---

   // Dữ liệu nến [1] (Nến vừa đóng cửa)
   double close1 = iClose(_Symbol, _Period, 1);
   double open1 = iOpen(_Symbol, _Period, 1);
   double high1 = iHigh(_Symbol, _Period, 1);
   double low1 = iLow(_Symbol, _Period, 1);

   // Logic BUY
   // - Vẫn đang trong trend tăng
   // - Giá hồi về vùng MA giữa (<= fast MA, > medium MA)
   // - Nến xác nhận tăng
   if (trend_direction == 1)
   {
      // Giá chạm vùng EMA 8-21 và nến tăng trở lại
      bool pullback = (low1 <= buff_FastEMA[1] && close1 > buff_MedEMA[1]);
      bool bullish_candle = (close1 > open1);

      if (pullback && bullish_candle)
         OpenTrade(InpReverseTrade ? ORDER_TYPE_SELL : ORDER_TYPE_BUY, atr_val);
   }

   // Logic SELL
   // - Vẫn đang trong trend giảm
   // - Giá hồi về vùng MA giữa (>= fast MA, < medium MA)
   // - Nến xác nhận giảm
   else if (trend_direction == -1)
   {
      // Giá chạm vùng EMA 8-21 và nến giảm trở lại
      bool pullback = (high1 >= buff_FastEMA[1] && close1 < buff_MedEMA[1]);
      bool bearish_candle = (close1 < open1);

      if (pullback && bearish_candle)
         OpenTrade(InpReverseTrade ? ORDER_TYPE_BUY : ORDER_TYPE_SELL, atr_val);
   }
}

//+------------------------------------------------------------------+
//| Hàm lấy dữ liệu chỉ báo                                          |
//+------------------------------------------------------------------+
bool GetData()
{
   if (CopyBuffer(handle_FastEMA, 0, 0, 3, buff_FastEMA) < 0)
      return false;
   if (CopyBuffer(handle_MedEMA, 0, 0, 3, buff_MedEMA) < 0)
      return false;
   if (CopyBuffer(handle_SlowEMA, 0, 0, 3, buff_SlowEMA) < 0)
      return false;
   if (CopyBuffer(handle_ATR, 0, 0, 3, buff_ATR) < 0)
      return false;

   if (InpUse_RSI)
      if (CopyBuffer(handle_RSI, 0, 0, 3, buff_RSI) < 0)
         return false;

   if (InpUse_MACD)
      if (CopyBuffer(handle_MACD, 0, 0, 3, buff_MACD) < 0)
         return false;

   if (InpUse_Stoch)
      if (CopyBuffer(handle_Stoch, 0, 0, 3, buff_Stoch) < 0)
         return false;

   if (InpUse_HTF_MA)
      // Lấy giá trị MA khung lớn tương ứng với thời điểm hiện tại
      if (CopyBuffer(handle_HTF_MA, 0, 0, 3, buff_HTF_MA) < 0)
         return false;

   return true;
}

//+------------------------------------------------------------------+
//| Logic xác định xu hướng tổng hợp                                 |
//+------------------------------------------------------------------+
int GetCombinedTrend()
{
   bool is_buy = true;
   bool is_sell = true;

   // 1. Basic EMA Structure
   // Buy: Fast > Med > Slow
   if (!(buff_FastEMA[1] > buff_MedEMA[1] && buff_MedEMA[1] > buff_SlowEMA[1]))
      is_buy = false;
   if (!(buff_FastEMA[1] < buff_MedEMA[1] && buff_MedEMA[1] < buff_SlowEMA[1]))
      is_sell = false;

   // 2. RSI Filter
   if (InpUse_RSI)
   {
      // Buy: RSI > 50
      if (buff_RSI[1] <= 50)
         is_buy = false;
      // Sell: RSI < 50
      if (buff_RSI[1] >= 50)
         is_sell = false;
   }

   // 3. MACD Filter
   if (InpUse_MACD)
   {
      // Buy: MACD Main > 0
      if (buff_MACD[1] <= 0)
         is_buy = false;
      // Sell: MACD Main < 0
      if (buff_MACD[1] >= 0)
         is_sell = false;
   }

   // 4. Stochastic Filter
   if (InpUse_Stoch)
   {
      // Buy: Stoch Main > 50 (Lực mua chiếm ưu thế)
      if (buff_Stoch[1] <= 50)
         is_buy = false;
      // Sell: Stoch Main < 50
      if (buff_Stoch[1] >= 50)
         is_sell = false;
   }

   // 5. Higher Timeframe MA Filter
   if (InpUse_HTF_MA)
   {
      double current_price = iClose(_Symbol, _Period, 1);
      // Buy: Giá hiện tại nằm trên MA của khung M15
      if (current_price <= buff_HTF_MA[1])
         is_buy = false;
      // Sell: Giá hiện tại nằm dưới MA của khung M15
      if (current_price >= buff_HTF_MA[1])
         is_sell = false;
   }

   if (is_buy)
      return 1;
   if (is_sell)
      return -1;
   return 0;
}

//+------------------------------------------------------------------+
//| Hàm mở lệnh với Dynamic TP/SL theo ATR                           |
//+------------------------------------------------------------------+
void OpenTrade(ENUM_ORDER_TYPE type, double atr)
{
   double price =
       (type == ORDER_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);

   // Calculate Dynamic TP/SL based on ATR
   double slDist = atr * InpSL_ATR_Mult;
   double tpDist = atr * InpTP_ATR_Mult;

   double sl = (type == ORDER_TYPE_BUY) ? price - slDist : price + slDist;
   double tp = (type == ORDER_TYPE_BUY) ? price + tpDist : price - tpDist;

   // Tính khối lượng dựa trên rủi ro
   double lot = CalculateLotSize(slDist);
   if (lot == 0.0)
   {
      return;
   }

   if (type == ORDER_TYPE_BUY)
      trade.Buy(lot, _Symbol, price, sl, tp, "AMG Buy");
   else
      trade.Sell(lot, _Symbol, price, sl, tp, "AMG Sell");
}

//+------------------------------------------------------------------+
//| Hàm tính khối lượng giao dịch                                    |
//+------------------------------------------------------------------+
double CalculateLotSize(double slDistancePrice)
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   if (InpMaxBalance > 0 && balance > InpMaxBalance)
   {
      balance = InpMaxBalance;
   }
   double riskMoney = balance * InpRiskPercent / 100.0;

   // Convert price distance to standard lots value
   // Formula simplified for standard Forex pairs
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);

   if (slDistancePrice == 0 || tickSize == 0)
      return SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);

   double points = slDistancePrice / tickSize;
   double lotRaw = riskMoney / (points * tickValue);

   // Chuẩn hóa lot theo broker
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lot = MathFloor(lotRaw / lotStep) * lotStep;

   if (lot < 0.005)
   {
      // Không mở lệnh nếu lot quá nhỏ
      return 0.0;
   }

   if (lot < minLot)
      lot = minLot;
   if (lot > maxLot)
      lot = maxLot;

   return lot;
}

//+------------------------------------------------------------------+
//| Hàm quản lý lệnh (Trailing Stop theo ATR)                        |
//+------------------------------------------------------------------+
void ManagePositions()
{
   // Duyệt qua tất cả các lệnh đang mở
   for (int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if (PositionSelectByTicket(ticket))
      {
         if (PositionGetString(POSITION_SYMBOL) != _Symbol)
            continue;
         if (PositionGetInteger(POSITION_MAGIC) != InpMagicNum)
            continue;

         double current_sl = PositionGetDouble(POSITION_SL);
         double current_tp = PositionGetDouble(POSITION_TP);
         double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
         long type = PositionGetInteger(POSITION_TYPE);

         // Lấy ATR hiện tại để tính khoảng cách Trail
         double atr = buff_ATR[1];

         // Các khoảng cách tính bằng ATR
         double activation_dist = atr * InpTrail_Start;  // Lãi bao nhiêu thì bắt đầu Trail
         double trail_dist = atr * InpTrail_Dist;        // Khoảng cách giữ SL so với giá
         double step_dist = atr * InpTrail_Step;         // Bước nhảy tối thiểu

         if (type == POSITION_TYPE_BUY)
         {
            double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
            // Nếu lãi > Activation Distance
            if (bid - open_price > activation_dist)
            {
               double new_sl = bid - trail_dist;

               // Chỉ dời SL lên cao hơn (không dời xuống) và phải vượt qua bước nhảy tối thiểu
               if (new_sl > current_sl + step_dist)
               {
                  trade.PositionModify(ticket, new_sl, current_tp);
               }
            }
         }
         else if (type == POSITION_TYPE_SELL)
         {
            double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            // Nếu lãi > Activation Distance (giá giảm sâu hơn open)
            if (open_price - ask > activation_dist)
            {
               double new_sl = ask + trail_dist;

               // Chỉ dời SL xuống thấp hơn (không dời lên) và phải vượt qua bước nhảy tối thiểu
               if (new_sl < current_sl - step_dist || current_sl == 0)
               {
                  trade.PositionModify(ticket, new_sl, current_tp);
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Hàm kiểm tra trạng thái Cooldown (Dừng sau chuỗi thua)           |
//+------------------------------------------------------------------+
bool IsTradingPaused()
{
   // 1. Nếu đang trong thời gian phạt, trả về true
   if (TimeCurrent() < gl_pause_until)
      return true;

   // 2. Nếu chưa bị phạt, kiểm tra lịch sử giao dịch gần nhất
   if (!HistorySelect(0, TimeCurrent()))
      return false;  // Chọn toàn bộ lịch sử (hoặc tối ưu chọn 1 ngày gần nhất)

   int deals = HistoryDealsTotal();
   int consecutive_losses = 0;
   datetime last_loss_time = 0;

   // Duyệt ngược từ giao dịch mới nhất
   for (int i = deals - 1; i >= 0; i--)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if (HistoryDealGetInteger(ticket, DEAL_ENTRY) != DEAL_ENTRY_OUT)
         continue;  // Chỉ tính lệnh thoát
      if (HistoryDealGetString(ticket, DEAL_SYMBOL) != _Symbol)
         continue;
      if (HistoryDealGetInteger(ticket, DEAL_MAGIC) != InpMagicNum)
         continue;

      double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);

      if (profit < 0)  // Lệnh thua
      {
         consecutive_losses++;
         if (consecutive_losses == 1)
            last_loss_time = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);
      }
      else if (profit > 0)  // Lệnh thắng -> Ngắt chuỗi
      {
         break;
      }

      // Nếu đạt đủ chuỗi thua
      if (consecutive_losses >= InpMaxLosses)
      {
         // Tính thời gian hết hạn phạt
         gl_pause_until = last_loss_time + (InpPauseMins * 60);

         // Kiểm tra xem hiện tại còn bị phạt không
         if (TimeCurrent() < gl_pause_until)
         {
            Print("PAUSED: Đạt " + IntegerToString(consecutive_losses) +
                  " lệnh thua liên tiếp. Dừng đến: " + TimeToString(gl_pause_until));
            return true;
         }
         else
         {
            // Đã hết thời gian phạt
            return false;
         }
      }
   }

   return false;
}
