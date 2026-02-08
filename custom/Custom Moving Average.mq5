//+------------------------------------------------------------------+
//|                                        Custom Moving Average.mq5 |
//|                             Copyright 2000-2026, MetaQuotes Ltd. |
//|                                                     www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2000-2026, MetaQuotes Ltd."
#property link "https://www.mql5.com"

//--- indicator settings
#property indicator_chart_window
#property indicator_buffers 3
#property indicator_plots 2

// --- PLOT 1: FILLING ---
#property indicator_type1 DRAW_FILLING
#property indicator_label1 "Zone Top;Zone Bottom"

// --- PLOT 2: LINE ---
#property indicator_type2 DRAW_LINE
#property indicator_label2 "MA"
#property indicator_color2 clrRed
#property indicator_style2 STYLE_SOLID
#property indicator_width2 1

//--- input parameters
input int InpMAPeriod = 13;                    // Period
input int InpMAShift = 0;                      // Shift
input ENUM_MA_METHOD InpMAMethod = MODE_SMMA;  // Method
input color InpLineColor = clrRed;
input int InpLineWidth = 1;
input double InpZoneWidth = 0.0;
input color InpZoneColor = clrRed;
//--- indicator buffer
double HighBuffer[];
double LowBuffer[];
double ExtLineBuffer[];
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
void OnInit()
{
   //--- indicator buffers mapping
   SetIndexBuffer(0, HighBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, LowBuffer, INDICATOR_DATA);
   SetIndexBuffer(2, ExtLineBuffer, INDICATOR_DATA);
   //--- set plot style
   color transparent_color = ColorToARGB(InpZoneColor, 0xA0);
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 0, transparent_color);
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 1, transparent_color);
   if (InpZoneWidth <= 0.0)
   {
      PlotIndexSetInteger(0, PLOT_LINE_WIDTH, 0, 0);
      PlotIndexSetInteger(0, PLOT_LINE_WIDTH, 1, 0);
   }
   PlotIndexSetInteger(1, PLOT_LINE_COLOR, InpLineColor);
   PlotIndexSetInteger(1, PLOT_LINE_WIDTH, InpLineWidth);
   //--- set accuracy
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits + 1);
   //--- set first bar from what index will be drawn
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, 0, InpMAPeriod);
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, 1, InpMAPeriod);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, InpMAPeriod);
   //--- line shifts when drawing
   PlotIndexSetInteger(0, PLOT_SHIFT, 0, InpMAShift);
   PlotIndexSetInteger(0, PLOT_SHIFT, 1, InpMAShift);
   PlotIndexSetInteger(1, PLOT_SHIFT, InpMAShift);
   //--- name for DataWindow
   string short_name;
   switch (InpMAMethod)
   {
      case MODE_EMA:
         short_name = "EMA";
         break;
      case MODE_LWMA:
         short_name = "LWMA";
         break;
      case MODE_SMA:
         short_name = "SMA";
         break;
      case MODE_SMMA:
         short_name = "SMMA";
         break;
      default:
         short_name = "unknown ma";
   }
   IndicatorSetString(INDICATOR_SHORTNAME, short_name + "(" + string(InpMAPeriod) + ")");
   PlotIndexSetString(
       0, PLOT_LABEL,
       short_name + "(" + string(InpMAPeriod) + ") Top;" + short_name + "(" + string(InpMAPeriod) + ") Bottom");
   PlotIndexSetString(1, PLOT_LABEL, short_name + "(" + string(InpMAPeriod) + ")");
   //--- set drawing line empty value
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, 0.0);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, 0.0);
}
//+------------------------------------------------------------------+
//|  Moving Average                                                  |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total, const int prev_calculated, const int begin, const double& price[])
{
   if (rates_total < InpMAPeriod - 1 + begin)
      return (0);
   //--- first calculation or number of bars was changed
   if (prev_calculated == 0)
   {
      ArrayInitialize(ExtLineBuffer, 0);
      PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, InpMAPeriod - 1 + begin);
   }
   //--- calculation
   switch (InpMAMethod)
   {
      case MODE_EMA:
         CalculateEMA(rates_total, prev_calculated, begin, price);
         break;
      case MODE_LWMA:
         CalculateLWMA(rates_total, prev_calculated, begin, price);
         break;
      case MODE_SMMA:
         CalculateSmoothedMA(rates_total, prev_calculated, begin, price);
         break;
      case MODE_SMA:
         CalculateSimpleMA(rates_total, prev_calculated, begin, price);
         break;
   }

   int start = prev_calculated == 0 ? InpMAPeriod + begin : prev_calculated - 1;
   for (int i = start; i < rates_total && !IsStopped(); i++)
   {
      HighBuffer[i] = ExtLineBuffer[i] * (1.0 + InpZoneWidth / 100.0);
      LowBuffer[i] = ExtLineBuffer[i] * (1.0 - InpZoneWidth / 100.0);
   }

   //--- return value of prev_calculated for next call
   return (rates_total);
}
//+------------------------------------------------------------------+
//|   simple moving average                                          |
//+------------------------------------------------------------------+
void CalculateSimpleMA(int rates_total, int prev_calculated, int begin, const double& price[])
{
   int i, start;
   //--- first calculation or number of bars was changed
   if (prev_calculated == 0)
   {
      start = InpMAPeriod + begin;
      //--- set empty value for first start bars
      for (i = 0; i < start - 1; i++)
         ExtLineBuffer[i] = 0.0;
      //--- calculate first visible value
      double first_value = 0;
      for (i = begin; i < start; i++)
         first_value += price[i];
      first_value /= InpMAPeriod;
      ExtLineBuffer[start - 1] = first_value;
   }
   else
      start = prev_calculated - 1;
   //--- main loop
   for (i = start; i < rates_total && !IsStopped(); i++)
      ExtLineBuffer[i] = ExtLineBuffer[i - 1] + (price[i] - price[i - InpMAPeriod]) / InpMAPeriod;
}
//+------------------------------------------------------------------+
//|  exponential moving average                                      |
//+------------------------------------------------------------------+
void CalculateEMA(int rates_total, int prev_calculated, int begin, const double& price[])
{
   int i, start;
   double SmoothFactor = 2.0 / (1.0 + InpMAPeriod);
   //--- first calculation or number of bars was changed
   if (prev_calculated == 0)
   {
      start = InpMAPeriod + begin;
      ExtLineBuffer[begin] = price[begin];
      for (i = begin + 1; i < start; i++)
         ExtLineBuffer[i] = price[i] * SmoothFactor + ExtLineBuffer[i - 1] * (1.0 - SmoothFactor);
   }
   else
      start = prev_calculated - 1;
   //--- main loop
   for (i = start; i < rates_total && !IsStopped(); i++)
      ExtLineBuffer[i] = price[i] * SmoothFactor + ExtLineBuffer[i - 1] * (1.0 - SmoothFactor);
}
//+------------------------------------------------------------------+
//|  linear weighted moving average                                  |
//+------------------------------------------------------------------+
void CalculateLWMA(int rates_total, int prev_calculated, int begin, const double& price[])
{
   int weight = 0;
   int i, l, start;
   double sum = 0.0, lsum = 0.0;
   //--- first calculation or number of bars was changed
   if (prev_calculated <= InpMAPeriod + begin + 2)
   {
      start = InpMAPeriod + begin;
      //--- set empty value for first start bars
      for (i = 0; i < start; i++)
         ExtLineBuffer[i] = 0.0;
   }
   else
      start = prev_calculated - 1;

   for (i = start - InpMAPeriod, l = 1; i < start; i++, l++)
   {
      sum += price[i] * l;
      lsum += price[i];
      weight += l;
   }
   ExtLineBuffer[start - 1] = sum / weight;
   //--- main loop
   for (i = start; i < rates_total && !IsStopped(); i++)
   {
      sum = sum - lsum + price[i] * InpMAPeriod;
      lsum = lsum - price[i - InpMAPeriod] + price[i];
      ExtLineBuffer[i] = sum / weight;
   }
}
//+------------------------------------------------------------------+
//|  smoothed moving average                                         |
//+------------------------------------------------------------------+
void CalculateSmoothedMA(int rates_total, int prev_calculated, int begin, const double& price[])
{
   int i, start;
   //--- first calculation or number of bars was changed
   if (prev_calculated == 0)
   {
      start = InpMAPeriod + begin;
      //--- set empty value for first start bars
      for (i = 0; i < start - 1; i++)
         ExtLineBuffer[i] = 0.0;
      //--- calculate first visible value
      double first_value = 0;
      for (i = begin; i < start; i++)
         first_value += price[i];
      first_value /= InpMAPeriod;
      ExtLineBuffer[start - 1] = first_value;
   }
   else
      start = prev_calculated - 1;
   //--- main loop
   for (i = start; i < rates_total && !IsStopped(); i++)
      ExtLineBuffer[i] = (ExtLineBuffer[i - 1] * (InpMAPeriod - 1) + price[i]) / InpMAPeriod;
}
//+------------------------------------------------------------------+
