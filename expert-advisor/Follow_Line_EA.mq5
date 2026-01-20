//+------------------------------------------------------------------+
//| Follow Line Indicator Strategy (Confirmed / Bar-Close Safe)     |
//| Pine Script v4 → MQL5 Expert Advisor                             |
//+------------------------------------------------------------------+
#property strict

#include <Trade/Trade.mqh>
CTrade trade;

//================ INPUTS =================//
input int BBperiod = 20;
input double BBdeviation = 0.1;
input bool UseATRfilter = true;
input int ATRperiod = 5;
input double Lots = 0.1;

//================ HANDLES =================//
int maHandle, stdHandle, atrHandle;

//================ BUFFERS =================//
double maBuf[3], stdBuf[3], atrBuf[3];

//================ STATE =================//
double TrendLine[3];
int iTrend[3];

bool confirmedBuy = false;
bool confirmedSell = false;

double frozenStop = 0.0;

datetime lastBarTime = 0;

//================ BAR CHECK =================//
bool IsNewBar()
{
   datetime t = iTime(_Symbol, _Period, 0);
   if (t != lastBarTime)
   {
      lastBarTime = t;
      return true;
   }
   return false;
}

//================ INIT =================//
int OnInit()
{
   maHandle = iMA(_Symbol, _Period, BBperiod, 0, MODE_SMA, PRICE_CLOSE);
   stdHandle = iStdDev(_Symbol, _Period, BBperiod, 0, MODE_SMA, PRICE_CLOSE);
   atrHandle = iATR(_Symbol, _Period, ATRperiod);

   if (maHandle == INVALID_HANDLE || stdHandle == INVALID_HANDLE || atrHandle == INVALID_HANDLE)
      return INIT_FAILED;

   ArrayInitialize(TrendLine, 0.0);
   ArrayInitialize(iTrend, 0);

   return INIT_SUCCEEDED;
}

//================ DEINIT =================//
void OnDeinit(const int reason)
{
   IndicatorRelease(maHandle);
   IndicatorRelease(stdHandle);
   IndicatorRelease(atrHandle);
}

//================ TICK =================//
void OnTick()
{
   if (!IsNewBar())
      return;

   //--- shift history (bar close confirmed)
   TrendLine[2] = TrendLine[1];
   TrendLine[1] = TrendLine[0];
   iTrend[2] = iTrend[1];
   iTrend[1] = iTrend[0];

   //--- indicator values (CLOSED BAR = shift 1)
   CopyBuffer(maHandle, 0, 1, 1, maBuf);
   CopyBuffer(stdHandle, 0, 1, 1, stdBuf);
   CopyBuffer(atrHandle, 0, 1, 1, atrBuf);

   double close1 = iClose(_Symbol, _Period, 1);
   double high1 = iHigh(_Symbol, _Period, 1);
   double low1 = iLow(_Symbol, _Period, 1);

   double bbUpper = maBuf[0] + stdBuf[0] * BBdeviation;
   double bbLower = maBuf[0] - stdBuf[0] * BBdeviation;

   int BBSignal = 0;
   if (close1 > bbUpper)
      BBSignal = 1;
   else if (close1 < bbLower)
      BBSignal = -1;

   //================ TRENDLINE (CONFIRMED BAR) =================//
   if (UseATRfilter)
   {
      if (BBSignal == 1)
      {
         TrendLine[0] = low1 - atrBuf[0];
         if (TrendLine[0] < TrendLine[1])
            TrendLine[0] = TrendLine[1];
      }
      else if (BBSignal == -1)
      {
         TrendLine[0] = high1 + atrBuf[0];
         if (TrendLine[0] > TrendLine[1])
            TrendLine[0] = TrendLine[1];
      }
      else
         TrendLine[0] = TrendLine[1];
   }
   else
   {
      if (BBSignal == 1)
      {
         TrendLine[0] = low1;
         if (TrendLine[0] < TrendLine[1])
            TrendLine[0] = TrendLine[1];
      }
      else if (BBSignal == -1)
      {
         TrendLine[0] = high1;
         if (TrendLine[0] > TrendLine[1])
            TrendLine[0] = TrendLine[1];
      }
      else
         TrendLine[0] = TrendLine[1];
   }

   //================ TREND DIRECTION =================//
   iTrend[0] = iTrend[1];
   if (TrendLine[0] > TrendLine[1])
      iTrend[0] = 1;
   else if (TrendLine[0] < TrendLine[1])
      iTrend[0] = -1;

   //================ CONFIRMED SIGNAL =================//
   confirmedBuy = (iTrend[2] == -1 && iTrend[1] == 1);
   confirmedSell = (iTrend[2] == 1 && iTrend[1] == -1);

   //================ FREEZE STOP AT FLIP =================//
   if (iTrend[2] != iTrend[1])
      frozenStop = TrendLine[1];

   DrawSignalLabels();
   ExecuteTrades();
}

//================ EXECUTION =================//
void ExecuteTrades()
{
   if (PositionsTotal() > 0)
      return;

   if (confirmedBuy)
      trade.Buy(Lots, _Symbol, 0, frozenStop, 0);

   if (confirmedSell)
      trade.Sell(Lots, _Symbol, 0, frozenStop, 0);
}

//================ VISUAL LABELS =================//
void DrawSignalLabels()
{
   datetime t = iTime(_Symbol, _Period, 1);
   string name;

   if (confirmedBuy)
   {
      name = "BUY_" + IntegerToString((int)t);
      ObjectCreate(0, name, OBJ_TEXT, 0, t, TrendLine[1]);
      ObjectSetString(0, name, OBJPROP_TEXT, "BUY");
      ObjectSetInteger(0, name, OBJPROP_COLOR, clrBlue);
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 10);
   }

   if (confirmedSell)
   {
      name = "SELL_" + IntegerToString((int)t);
      ObjectCreate(0, name, OBJ_TEXT, 0, t, TrendLine[1]);
      ObjectSetString(0, name, OBJPROP_TEXT, "SELL");
      ObjectSetInteger(0, name, OBJPROP_COLOR, clrRed);
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 10);
   }
}
