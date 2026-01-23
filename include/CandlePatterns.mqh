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
// ===================== HELPER =====================
// ==================================================

// Size compared to ATR (real size)
#define ZERO_SIZE_ATR_RATIO 0.05
#define BIG_SIZE_ATR_RATIO 1.5
#define NORMAL_SIZE_ATR_RATIO 1.0
#define SMALL_SIZE_ATR_RATIO 0.5
#define VERY_SMALL_SIZE_ATR_RATIO 0.1

// Ratios compared to candle parts (relative size)
#define EQUAL_SIZE_RATIO 0.9
#define VERY_BIG_WICK_BODY_RATIO 3.0
#define BIG_WICK_BODY_RATIO 2.0
#define SMALL_WICK_BODY_RATIO 0.5
#define VERY_BIG_BODY_HEIGHT_RATIO 0.85
#define BIG_BODY_HEIGHT_RATIO 0.7
#define MEDIUM_BODY_HEIGHT_RATIO 0.55
#define SMALL_BODY_HEIGHT_RATIO 0.4
#define VERY_SMALL_BODY_HEIGHT_RATIO 0.25

// Pattern names
// Trend
const string BULLISH = "BULLISH";
const string BEARISH = "BEARISH";

// Doji
const string DOJI = "DOJI";
const string DRAGONFLY_DOJI = "DRAGONFLY_DOJI";
const string GRAVESTONE_DOJI = "GRAVESTONE_DOJI";
const string LONG_LEGGED_DOJI = "LONG_LEGGED_DOJI";

// Hammer
const string HAMMER = "HAMMER";
const string INVERTED_HAMMER = "INVERTED_HAMMER";
const string HANGING_MAN = "HANGING_MAN";
const string SHOOTING_STAR = "SHOOTING_STAR";
const string HAMMER_REVERSAL = "HAMMER_REVERSAL";

// Marubozu
const string MARUBOZU = "MARUBOZU";

// Engulfing
const string ENGULFING = "ENGULFING";
const string BODY_ENGULFING_BODY = "BODY_ENGULFING_BODY";
const string BODY_ENGULFING_WICK = "BODY_ENGULFING_WICK";
const string BODY_OVERLAPING_TOP = "BODY_OVERLAPING_TOP";
const string BODY_OVERLAPING_BOTTOM = "BODY_OVERLAPING_BOTTOM";

// Star
const string MORNING_STAR = "MORNING_STAR";
const string EVENING_STAR = "EVENING_STAR";

// Piercing
const string PIERCING_LINE = "PIERCING_LINE";
const string DARK_CLOUD_COVER = "DARK_CLOUD_COVER";

const string THREE_WHITE_SOLDIERS = "THREE_WHITE_SOLDIERS";
const string THREE_BLACK_CROWS = "THREE_BLACK_CROWS";
const string THREE_LINE_STRIKE = "THREE_LINE_STRIKE";
const string THREE_OUTSIDE_UP = "Three Outside Up";
const string THREE_OUTSIDE_DOWN = "Three Outside Down";
const string THREE_INSIDE_UP = "Three Inside Up";
const string THREE_INSIDE_DOWN = "Three Inside Down";
const string ABANDONED_BABY = "Abandoned Baby";

struct CandleData
{
   int index;  // Chỉ số của nến có thể thay đổi nếu mảng dữ liệu gốc đổi
   double open;
   double close;
   double high;
   double low;
   double atr;

   double body;
   double lowerWick;
   double upperWick;
   double height;

   double bodyATRRatio;
   double lowerWickATRRatio;
   double upperWickATRRatio;
   double heightATRRatio;
   double bodyHeightRatio;
   double bodyLowerWickRatio;
   double bodyUpperWickRatio;
   double lowerWickBodyRatio;
   double lowerWickHeightRatio;
   double lowerWickUpperWickRatio;
   double upperWickBodyRatio;
   double upperWickHeightRatio;
   double upperWickLowerWickRatio;
   double heightBodyRatio;
   double heightLowerWickRatio;
   double heightUpperWickRatio;

   bool isUp;
   bool isDown;
};

CandleData GetCandleData(int i, const double& open[], const double& high[], const double& low[], const double& close[],
                         const double& atr[], int arraySize)
{
   CandleData candleData;
   candleData.index = i;
   candleData.open = open[i];
   candleData.close = close[i];
   candleData.high = high[i];
   candleData.low = low[i];
   candleData.atr = atr[i];

   candleData.body = MathAbs(close[i] - open[i]);
   candleData.lowerWick = MathMin(open[i], close[i]) - low[i];
   candleData.upperWick = high[i] - MathMax(open[i], close[i]);
   candleData.height = high[i] - low[i];
   if (atr[i] > 0)
   {
      candleData.bodyATRRatio = candleData.body / atr[i];
      candleData.lowerWickATRRatio = candleData.lowerWick / atr[i];
      candleData.upperWickATRRatio = candleData.upperWick / atr[i];
      candleData.heightATRRatio = candleData.height / atr[i];
   }
   if (candleData.height > 0)
   {
      candleData.bodyHeightRatio = candleData.body / candleData.height;
      candleData.lowerWickHeightRatio = candleData.lowerWick / candleData.height;
      candleData.upperWickHeightRatio = candleData.upperWick / candleData.height;
   }
   if (candleData.body > 0)
   {
      candleData.heightBodyRatio = candleData.height / candleData.body;
      candleData.lowerWickBodyRatio = candleData.lowerWick / candleData.body;
      candleData.upperWickBodyRatio = candleData.upperWick / candleData.body;
   }
   if (candleData.lowerWick > 0)
   {
      candleData.bodyLowerWickRatio = candleData.body / candleData.lowerWick;
      candleData.heightLowerWickRatio = candleData.height / candleData.lowerWick;
      candleData.upperWickLowerWickRatio = candleData.upperWick / candleData.lowerWick;
   }
   if (candleData.upperWick > 0)
   {
      candleData.bodyUpperWickRatio = candleData.body / candleData.upperWick;
      candleData.heightUpperWickRatio = candleData.height / candleData.upperWick;
      candleData.lowerWickUpperWickRatio = candleData.lowerWick / candleData.upperWick;
   }
   candleData.isUp = close[i] > open[i];
   candleData.isDown = close[i] < open[i];

   return candleData;
}

// ==================================================
// ============= SINGLE CANDLE PATTERNS =============
// ==================================================

struct CandlePatternResult
{
   string trend;
   string name;
   string detail;
   CandleData candleData;
};

CandlePatternResult InitCandlePatternResult()
{
   CandlePatternResult result;
   result.trend = "";
   result.name = "";
   result.detail = "";
   result.candleData.index = -1;
   result.candleData.open = 0;
   result.candleData.high = 0;
   result.candleData.low = 0;
   result.candleData.close = 0;
   result.candleData.atr = 0;
   result.candleData.body = 0;
   result.candleData.upperWick = 0;
   result.candleData.lowerWick = 0;
   result.candleData.height = 0;
   result.candleData.bodyATRRatio = 0;
   result.candleData.upperWickATRRatio = 0;
   result.candleData.lowerWickATRRatio = 0;
   result.candleData.heightATRRatio = 0;
   result.candleData.bodyHeightRatio = 0;
   result.candleData.upperWickHeightRatio = 0;
   result.candleData.lowerWickHeightRatio = 0;
   result.candleData.heightBodyRatio = 0;
   result.candleData.bodyLowerWickRatio = 0;
   result.candleData.heightLowerWickRatio = 0;
   result.candleData.upperWickLowerWickRatio = 0;
   result.candleData.bodyUpperWickRatio = 0;
   result.candleData.heightUpperWickRatio = 0;
   result.candleData.lowerWickUpperWickRatio = 0;
   result.candleData.isUp = false;
   result.candleData.isDown = false;
   return result;
}

// Nến Doji:
// - Thân nến cực kỳ nhỏ, giá mở cửa gần bằng giá đóng cửa
// - Standard Doji: Bóng trên và bóng dưới dài bằng nhau
// - Long-Legged Doji: 1 bóng dài hơn bóng còn lại
// - Dragonfly Doji: không có bóng trên
// - Gravestone Doji: không có bóng dưới
CandlePatternResult IsDojiCandle(int i, const double& open[], const double& high[], const double& low[],
                                 const double& close[], const double& atr[], int arraySize,
                                 double zeroSizeATRRatio = ZERO_SIZE_ATR_RATIO,
                                 double equalSizeRatio = EQUAL_SIZE_RATIO)
{
   CandlePatternResult result = InitCandlePatternResult();

   CandleData candleData = GetCandleData(i, open, high, low, close, atr, arraySize);
   result.candleData = candleData;

   bool isDoji = candleData.bodyATRRatio <= zeroSizeATRRatio;
   if (!isDoji)
      return result;

   if (candleData.upperWickATRRatio <= zeroSizeATRRatio)
      // Dragonfly Doji: không có bóng trên
      result.name = DRAGONFLY_DOJI;
   else if (candleData.lowerWickATRRatio <= zeroSizeATRRatio)
      // Gravestone Doji: không có bóng dưới
      result.name = GRAVESTONE_DOJI;
   else if (candleData.upperWickLowerWickRatio < equalSizeRatio || candleData.lowerWickUpperWickRatio < equalSizeRatio)
      // Long-Legged Doji: 1 bóng dài hơn bóng còn lại
      result.name = LONG_LEGGED_DOJI;
   else
      // Standard Doji: bóng dưới hoặc bóng trên dài tương đương nhau
      result.name = DOJI;

   if (candleData.isUp)
      result.trend = BULLISH;
   else if (candleData.isDown)
      result.trend = BEARISH;

   return result;
}

// Nến Hammer (Nến hình búa):
// - Thân nến nhỏ
// - Bóng dưới dài gấp đôi thân nến
// - Bóng trên ngắn
// - Thân nến nằm trên đỉnh
// Nến Inverted Hammer (Nến hình búa ngược):
// - Thân nến nhỏ
// - Bóng trên dài gấp đôi thân nến
// - Bóng dưới ngắn
// - Thân nến nằm dưới đáy
CandlePatternResult IsHammerCandle(int i, const double& open[], const double& high[], const double& low[],
                                   const double& close[], const double& atr[], int arraySize,
                                   double bodyATRRatio = SMALL_SIZE_ATR_RATIO,
                                   double bigWickBodyRatio = BIG_WICK_BODY_RATIO,
                                   double smallWickBodyRatio = SMALL_WICK_BODY_RATIO)
{
   CandlePatternResult result = InitCandlePatternResult();

   CandleData candleData = GetCandleData(i, open, high, low, close, atr, arraySize);
   result.candleData = candleData;

   bool isHammer = candleData.bodyATRRatio > ZERO_SIZE_ATR_RATIO  // Thân nến phải đủ lớn để không bị nhầm với Doji
                   && candleData.bodyATRRatio <= bodyATRRatio     // Thân nến nhỏ hơn 1/2 ATR
                   && candleData.lowerWickBodyRatio >= bigWickBodyRatio     // Bóng dưới dài ít nhất gấp đôi thân nến
                   && candleData.upperWickBodyRatio <= smallWickBodyRatio;  // Bóng trên ngắn hơn 1/2 thân nến
   bool isInvertedHammer =
       candleData.bodyATRRatio > ZERO_SIZE_ATR_RATIO            // Thân nến phải đủ lớn để không bị nhầm với Doji
       && candleData.bodyATRRatio <= bodyATRRatio               // Thân nến nhỏ hơn 1/2 ATR
       && candleData.upperWickBodyRatio >= bigWickBodyRatio     // Bóng trên dài ít nhất gấp đôi thân nến
       && candleData.lowerWickBodyRatio <= smallWickBodyRatio;  // Bóng dưới ngắn hơn 1/2 thân nến

   if (isHammer)
      result.name = HAMMER;
   if (isInvertedHammer)
      result.name = INVERTED_HAMMER;

   if (candleData.isUp)
      result.trend = BULLISH;
   else if (candleData.isDown)
      result.trend = BEARISH;

   return result;
}

// Nến Marubozu (Nến không có bóng):
// - Thân nến chiếm toàn bộ range nến
// - Bóng trên và bóng dưới rất nhỏ
CandlePatternResult IsMarubozuCandle(int i, const double& open[], const double& high[], const double& low[],
                                     const double& close[], const double& atr[], int arraySize,
                                     double bodyATRRatio = NORMAL_SIZE_ATR_RATIO,
                                     double zeroSizeATRRatio = ZERO_SIZE_ATR_RATIO)
{
   CandlePatternResult result = InitCandlePatternResult();

   CandleData candleData = GetCandleData(i, open, high, low, close, atr, arraySize);
   result.candleData = candleData;

   bool isMarubozu = candleData.lowerWickATRRatio <= zeroSizeATRRatio     // Bóng dưới rất nhỏ
                     && candleData.upperWickATRRatio <= zeroSizeATRRatio  // Bóng trên rất nhỏ
                     && candleData.bodyATRRatio >= bodyATRRatio;          // Thân nến đủ lớn (ít nhất = 1 x ATR)

   if (isMarubozu)
      result.name = MARUBOZU;

   if (candleData.isUp)
      result.trend = BULLISH;
   else if (candleData.isDown)
      result.trend = BEARISH;

   return result;
}

// ==================================================
// ============= MULTI-CANDLE PATTERNS ==============
// ==================================================

// Hammer pattern (và Inverted Hammer pattern) (Mẫu hình búa / búa ngược):
// - Xuất hiện ở đáy, thường báo hiệu tín hiệu đảo chiều tăng
// - Nến trước là nến đỏ, xu hướng giảm
// - Nến hiện tại là nến bullish hammer hoặc bullish inverted hammer
CandlePatternResult IsHammerOrInvertedHammerPattern(int i, const double& open[], const double& high[],
                                                    const double& low[], const double& close[], const double& atr[],
                                                    int arraySize, int lookback = 1,
                                                    double smallBodyATRRatio = SMALL_SIZE_ATR_RATIO,
                                                    double bigWickBodyRatio = BIG_WICK_BODY_RATIO,
                                                    double smallWickBodyRatio = SMALL_WICK_BODY_RATIO)
{
   CandlePatternResult result = InitCandlePatternResult();

   CandleData candleData = GetCandleData(i, open, high, low, close, atr, arraySize);
   result.candleData = candleData;

   if (i + lookback >= arraySize)
   {
      // Không có đủ nến để kiểm tra
      return result;
   }

   CandlePatternResult hammerCandle = IsHammerCandle(i, open, high, low, close, atr, arraySize, smallBodyATRRatio,
                                                     bigWickBodyRatio, smallWickBodyRatio);

   if (hammerCandle.trend != BULLISH)
      // Nến hiện tại không phải là nến bullish
      return result;
   if (hammerCandle.name != HAMMER && hammerCandle.name != INVERTED_HAMMER)
      // Nến hiện tại không phải là nến hammer hoặc inverted hammer
      return result;

   // Kiểm tra nến kế trước là nến giảm
   if (open[i + 1] < close[i + 1])
      return result;

   // Kiểm tra các nến trước là xu hướng giảm
   for (int j = i + 1; j < i + lookback; j++)
   {
      if (close[j] > close[j + 1])
         return result;
   }

   result.name = hammerCandle.name;
   result.trend = hammerCandle.trend;
   return result;
}

// Hanging Man pattern (và Shooting Star pattern) (Mẫu hình người treo cổ / sao bằng):
// - Xuất hiện ở đỉnh, thường báo hiệu tín hiệu đảo chiều giảm
// - Nến trước là nến xanh, xu hướng tăng
// - Nến sau là nến bearish hammer hoặc bearish inverted hammer
CandlePatternResult IsHangingManOrShootingStarPattern(int i, const double& open[], const double& high[],
                                                      const double& low[], const double& close[], const double& atr[],
                                                      int arraySize, int lookback = 1,
                                                      double smallBodyATRRatio = SMALL_SIZE_ATR_RATIO,
                                                      double bigWickBodyRatio = BIG_WICK_BODY_RATIO,
                                                      double smallWickBodyRatio = SMALL_WICK_BODY_RATIO)
{
   CandlePatternResult result = InitCandlePatternResult();

   CandleData candleData = GetCandleData(i, open, high, low, close, atr, arraySize);
   result.candleData = candleData;

   if (i + lookback >= arraySize)
   {
      // Không có đủ nến để kiểm tra
      return result;
   }

   CandlePatternResult hammerCandle = IsHammerCandle(i, open, high, low, close, atr, arraySize, smallBodyATRRatio,
                                                     bigWickBodyRatio, smallWickBodyRatio);

   if (hammerCandle.trend != BEARISH)
      // Nến hiện tại không phải là nến bearish
      return result;
   if (hammerCandle.name != HAMMER && hammerCandle.name != INVERTED_HAMMER)
      // Nến hiện tại không phải là nến hammer hoặc inverted hammer
      return result;

   // Kiểm tra nến kế trước là nến tăng
   if (open[i + 1] > close[i + 1])
      return result;

   // Kiểm tra các nến trước là xu hướng tăng
   for (int j = i + 1; j < i + lookback; j++)
   {
      if (close[j] < close[j + 1])
         return result;
   }

   result.name = hammerCandle.name == HAMMER ? HANGING_MAN : SHOOTING_STAR;
   result.trend = hammerCandle.trend;
   return result;
}

// Bullish Engulfing pattern (Mẫu hình nhấn chìm tăng):
// - Xuất hiện khi nến xanh bao trùm nến đỏ
// - Thường báo hiệu tín hiệu tăng
CandlePatternResult IsBullishEngulfingPattern(int i, const double& open[], const double& high[], const double& low[],
                                              const double& close[], const double& atr[], int arraySize,
                                              double bodyATRRatio = NORMAL_SIZE_ATR_RATIO,
                                              double bigBodyHeightRatio = VERY_BIG_BODY_HEIGHT_RATIO)
{
   CandlePatternResult result = InitCandlePatternResult();

   CandleData candleData = GetCandleData(i, open, high, low, close, atr, arraySize);
   result.candleData = candleData;

   if (i + 1 >= arraySize)
   {
      // Không có đủ nến để kiểm tra
      return result;
   }

   CandleData prevCandleData = GetCandleData(i + 1, open, high, low, close, atr, arraySize);

   // Nến trước phải là nến đỏ giảm
   if (!prevCandleData.isDown)
      return result;

   // Nến hiện tại phải là nến xanh tăng
   if (!candleData.isUp)
      return result;

   // Thân nến hiện tại phải đủ lớn
   if (candleData.bodyATRRatio < bodyATRRatio)
      return result;

   // Nến hiện tại phải bao trùm nến trước
   bool isEngulfing =
       (close[i] > high[i + 1] || high[i] > high[i + 1])  // Hoặc thân hoặc đỉnh nến hiện tại bao trùm đỉnh nến trước
       && (open[i] < low[i + 1] || low[i] < low[i + 1]);  // Hoặc thân hoặc đáy nến hiện tại bao trùm đáy nến trước
   if (!isEngulfing)
      return result;

   // Nến hiện tại phải có thân lớn, dài hơn thân nến trước
   if (candleData.bodyHeightRatio < bigBodyHeightRatio || prevCandleData.body >= candleData.body)
      return result;

   if (close[i] > high[i + 1] && open[i] < low[i + 1])
   {
      // Thân nến hiện tại bao trùm toàn bộ nến trước - mạnh nhất
      result.detail = BODY_ENGULFING_WICK;
   }
   else if (close[i] > open[i + 1] && open[i] < close[i + 1])
   {
      // Thân nến hiện tại bao trùm thân nến trước
      result.detail = BODY_ENGULFING_BODY;
   }
   else if (close[i] > high[i + 1])
   {
      // Thân nến hiện tại bao trùm phần trên của thân nến trước
      result.detail = BODY_OVERLAPING_TOP;
   }
   else if (open[i] < low[i + 1])
   {
      // Thân nến hiện tại bao trùm phần dưới của thân nến trước
      result.detail = BODY_OVERLAPING_BOTTOM;
   }

   result.name = ENGULFING;
   result.trend = BULLISH;
   return result;
}

// Bearish Engulfing pattern (Mẫu hình nhấn chìm giảm):
// - Xuất hiện khi nến đỏ bao trùm nến xanh
// - Thường báo hiệu tín hiệu giảm
CandlePatternResult IsBearishEngulfingPattern(int i, const double& open[], const double& high[], const double& low[],
                                              const double& close[], const double& atr[], int arraySize,
                                              double bodyATRRatio = NORMAL_SIZE_ATR_RATIO,
                                              double bigBodyHeightRatio = VERY_BIG_BODY_HEIGHT_RATIO)
{
   CandlePatternResult result = InitCandlePatternResult();

   CandleData candleData = GetCandleData(i, open, high, low, close, atr, arraySize);
   result.candleData = candleData;

   if (i + 1 >= arraySize)
   {
      // Không có đủ nến để kiểm tra
      return result;
   }

   CandleData prevCandleData = GetCandleData(i + 1, open, high, low, close, atr, arraySize);

   // Nến trước phải là nến xanh tăng
   if (!prevCandleData.isUp)
      return result;

   // Nến hiện tại phải là nến đỏ giảm
   if (!candleData.isDown)
      return result;

   // Thân nến hiện tại phải đủ lớn
   if (candleData.bodyATRRatio < bodyATRRatio)
      return result;

   // Nến hiện tại phải bao trùm nến trước
   bool isEngulfing =
       (open[i] > high[i + 1] || high[i] > high[i + 1])    // Hoặc thân hoặc đỉnh nến hiện tại bao trùm đỉnh nến trước
       && (close[i] < low[i + 1] || low[i] < low[i + 1]);  // Hoặc thân hoặc đáy nến hiện tại bao trùm đáy nến trước
   if (!isEngulfing)
      return result;

   // Nến hiện tại phải có thân lớn, dài hơn thân nến trước
   if (candleData.bodyHeightRatio < bigBodyHeightRatio || prevCandleData.body >= candleData.body)
      return result;

   if (open[i] > high[i + 1] && close[i] < low[i + 1])
   {
      // Thân nến hiện tại bao trùm toàn bộ nến trước - mạnh nhất
      result.detail = BODY_ENGULFING_WICK;
   }
   else if (open[i] > close[i + 1] && close[i] < open[i + 1])
   {
      // Thân nến hiện tại bao trùm thân nến trước
      result.detail = BODY_ENGULFING_BODY;
   }
   else if (open[i] > high[i + 1])
   {
      // Thân nến hiện tại bao trùm phần trên của thân nến trước
      result.detail = BODY_OVERLAPING_TOP;
   }
   else if (close[i] < low[i + 1])
   {
      // Thân nến hiện tại bao trùm phần dưới của thân nến trước
      result.detail = BODY_OVERLAPING_BOTTOM;
   }

   result.name = ENGULFING;
   result.trend = BEARISH;
   return result;
}

// Morning Star pattern (Mẫu hình sao mai):
// - Mô hình nến 3 cây
// - Xuất hiện khi nến 1 giảm dài, nến 2 thân nhỏ hoặc Doji, nến 3 tăng dài
// - Thường báo hiệu tín hiệu tăng
CandlePatternResult IsMorningStarPattern(int i, const double& open[], const double& high[], const double& low[],
                                         const double& close[], const double& atr[], int arraySize,
                                         double smallBodyATRRatio = VERY_SMALL_SIZE_ATR_RATIO,
                                         double bigBodyATRRatio = NORMAL_SIZE_ATR_RATIO,
                                         double bigBodyHeightRatio = BIG_BODY_HEIGHT_RATIO)
{
   CandlePatternResult result = InitCandlePatternResult();

   CandleData candleData = GetCandleData(i, open, high, low, close, atr, arraySize);
   result.candleData = candleData;

   if (i + 2 >= arraySize)
   {
      // Không có đủ nến để kiểm tra
      return result;
   }

   CandleData prevTwoCandleData = GetCandleData(i + 2, open, high, low, close, atr, arraySize);

   // Nến 1 phải là nến giảm
   if (!prevTwoCandleData.isDown)
      return result;

   // Nến 1 phải có thân lớn (so với chiều cao nến và so với ATR)
   if (prevTwoCandleData.bodyHeightRatio < bigBodyHeightRatio || prevTwoCandleData.bodyATRRatio < bigBodyATRRatio)
      return result;

   // Nến 2 phải là nến Doji hoặc thân nhỏ, truyền tham số smallBodyATRRatio vào
   // để chấp nhận thân nến lớn hơn 1 tí so với nến Doji thông thường
   CandlePatternResult dojiCandle;
   dojiCandle = IsDojiCandle(i + 1, open, high, low, close, atr, smallBodyATRRatio, arraySize);
   if (dojiCandle.name == "")
      return result;

   // Nến 3 phải là nến tăng
   if (!candleData.isUp)
      return result;

   // Nến 3 phải có thân lớn
   if (candleData.bodyHeightRatio < bigBodyHeightRatio || candleData.bodyATRRatio < bigBodyATRRatio)
      return result;

   // Nến 2 phải có đáy thấp hơn nến 1 và nến 3
   if (low[i + 1] > prevTwoCandleData.low || low[i + 1] > candleData.low)
      return result;

   // Nến 3 phải có đỉnh cao hơn nến 1
   if (prevTwoCandleData.high > candleData.high)
      return result;

   result.name = MORNING_STAR;
   result.trend = BULLISH;
   return result;
}

// Evening Star pattern (Mẫu hình sao hôm):
// - Mô hình nến 3 cây
// - Xuất hiện khi nến 1 tăng dài, nến 2 thân nhỏ hoặc Doji, nến 3 giảm dài
// - Thường báo hiệu tín hiệu giảm
CandlePatternResult IsEveningStarPattern(int i, const double& open[], const double& high[], const double& low[],
                                         const double& close[], const double& atr[], int arraySize,
                                         double smallBodyATRRatio = VERY_SMALL_SIZE_ATR_RATIO,
                                         double bigBodyATRRatio = NORMAL_SIZE_ATR_RATIO,
                                         double bigBodyHeightRatio = BIG_BODY_HEIGHT_RATIO)
{
   CandlePatternResult result = InitCandlePatternResult();

   CandleData candleData = GetCandleData(i, open, high, low, close, atr, arraySize);
   result.candleData = candleData;

   if (i + 2 >= arraySize)
   {
      // Không có đủ nến để kiểm tra
      return result;
   }

   CandleData prevTwoCandleData = GetCandleData(i + 2, open, high, low, close, atr, arraySize);

   // Nến 1 phải là nến tăng
   if (!prevTwoCandleData.isUp)
      return result;

   // Nến 1 phải có thân lớn (so với chiều cao nến và so với ATR)
   if (prevTwoCandleData.bodyHeightRatio < bigBodyHeightRatio || prevTwoCandleData.bodyATRRatio < bigBodyATRRatio)
      return result;

   // Nến 2 phải là nến Doji hoặc thân nhỏ, truyền tham số smallBodyATRRatio vào
   // để chấp nhận thân nến lớn hơn 1 tí so với nến Doji thông thường
   CandlePatternResult dojiCandle;
   dojiCandle = IsDojiCandle(i + 1, open, high, low, close, atr, smallBodyATRRatio, arraySize);
   if (dojiCandle.name == "")
      return result;

   // Nến 3 phải là nến giảm
   if (!candleData.isDown)
      return result;

   // Nến 3 phải có thân lớn
   if (candleData.bodyHeightRatio < bigBodyHeightRatio || candleData.bodyATRRatio < bigBodyATRRatio)
      return result;

   // Nến 2 phải có đỉnh cao hơn nến 1 và nến 3
   if (high[i + 1] < prevTwoCandleData.high || high[i + 1] < candleData.high)
      return result;

   // Nến 3 phải có đáy thấp hơn nến 1
   if (prevTwoCandleData.low > candleData.low)
      return result;

   result.name = EVENING_STAR;
   result.trend = BEARISH;
   return result;
}

// Piercing Line pattern (Mẫu hình nến xuyên thủng):
// - Mô hình nến 2 cây
// - Xuất hiện khi nến 1 giảm dài, nến 2 tăng dài
// - Nến 2 mở cửa dưới đáy nến 1
// - Nến 2 phải đóng cửa trên 50% thân nến 1
// - Thường báo hiệu tín hiệu tăng
CandlePatternResult IsPiercingLinePattern(int i, const double& open[], const double& high[], const double& low[],
                                          const double& close[], const double& atr[], int arraySize,
                                          double bigBodyATRRatio = NORMAL_SIZE_ATR_RATIO,
                                          double bigBodyHeightRatio = BIG_BODY_HEIGHT_RATIO)
{
   CandlePatternResult result = InitCandlePatternResult();

   CandleData candleData = GetCandleData(i, open, high, low, close, atr, arraySize);
   result.candleData = candleData;

   if (i + 1 >= arraySize)
   {
      // Không có đủ nến để kiểm tra
      return result;
   }

   CandleData prevCandleData = GetCandleData(i + 1, open, high, low, close, atr, arraySize);

   // Nến 1 phải là nến giảm
   if (!prevCandleData.isDown)
      return result;

   // Nến 1 phải có thân lớn (so với chiều cao nến và so với ATR)
   if (prevCandleData.bodyHeightRatio < bigBodyHeightRatio || prevCandleData.bodyATRRatio < bigBodyATRRatio)
      return result;

   // Nến 2 phải là nến tăng
   if (!candleData.isUp)
      return result;

   // Nến 2 phải có thân lớn
   if (candleData.bodyHeightRatio < bigBodyHeightRatio || candleData.bodyATRRatio < bigBodyATRRatio)
      return result;

   // Nến 2 mở cửa dưới đáy nến 1
   if (candleData.open >= prevCandleData.close)
      return result;

   // Nến 2 phải đóng cửa trên 50% thân nến 1
   if (candleData.close <= (prevCandleData.open + prevCandleData.close) / 2.0)
      return result;

   result.name = PIERCING_LINE;
   result.trend = BULLISH;
   return result;
}

// Dark Cloud Cover pattern (Mẫu hình nến mây đen che phủ):
// - Mô hình nến 2 cây
// - Xuất hiện khi nến 1 tăng dài, nến 2 giảm dài
// - Nến 2 mở cửa trên đỉnh nến 1
// - Nến 2 phải đóng cửa dưới 50% thân nến 1
// - Thường báo hiệu tín hiệu giảm
CandlePatternResult IsDarkCloudCoverPattern(int i, const double& open[], const double& high[], const double& low[],
                                            const double& close[], const double& atr[], int arraySize,
                                            double bigBodyATRRatio = NORMAL_SIZE_ATR_RATIO,
                                            double bigBodyHeightRatio = BIG_BODY_HEIGHT_RATIO)
{
   CandlePatternResult result = InitCandlePatternResult();

   CandleData candleData = GetCandleData(i, open, high, low, close, atr, arraySize);
   result.candleData = candleData;

   if (i + 1 >= arraySize)
   {
      // Không có đủ nến để kiểm tra
      return result;
   }

   CandleData prevCandleData = GetCandleData(i + 1, open, high, low, close, atr, arraySize);

   // Nến 1 phải là nến tăng
   if (!prevCandleData.isUp)
      return result;

   // Nến 1 phải có thân lớn (so với chiều cao nến và so với ATR)
   if (prevCandleData.bodyHeightRatio < bigBodyHeightRatio || prevCandleData.bodyATRRatio < bigBodyATRRatio)
      return result;

   // Nến 2 phải là nến giảm
   if (!candleData.isDown)
      return result;

   // Nến 2 phải có thân lớn
   if (candleData.bodyHeightRatio < bigBodyHeightRatio || candleData.bodyATRRatio < bigBodyATRRatio)
      return result;

   // Nến 2 mở cửa trên đỉnh nến 1
   if (candleData.open <= prevCandleData.close)
      return result;

   // Nến 2 phải đóng cửa dưới 50% thân nến 1
   if (candleData.close >= (prevCandleData.open + prevCandleData.close) / 2.0)
      return result;

   result.name = DARK_CLOUD_COVER;
   result.trend = BEARISH;
   return result;
}

// ==================================================
// ============= BUY PATTERNS =======================
// ==================================================

//+------------------------------------------------------------------+
//| Xác định BUY Patterns                                            |
//| Patterns: Hammer, Bullish Engulfing, Piercing, Morning Star      |
//+------------------------------------------------------------------+
CandlePatternResult DetectBuyPattern(int i,  // index nến hiện tại
                                     const double& open[], const double& high[], const double& low[],
                                     const double& close[], const double& atr[], int arraySize)
{
   CandlePatternResult result = IsHammerOrInvertedHammerPattern(i, open, high, low, close, atr, arraySize);
   if (result.name != "" && result.trend == BULLISH)
      return result;

   result = IsHangingManOrShootingStarPattern(i, open, high, low, close, atr, arraySize);
   if (result.name != "" && result.trend == BULLISH)
      return result;

   result = IsBullishEngulfingPattern(i, open, high, low, close, atr, arraySize);
   if (result.name != "" && result.trend == BULLISH)
      return result;

   result = IsPiercingLinePattern(i, open, high, low, close, atr, arraySize);
   if (result.name != "" && result.trend == BULLISH)
      return result;

   result = IsMorningStarPattern(i, open, high, low, close, atr, arraySize);
   if (result.name != "" && result.trend == BULLISH)
      return result;

   result = IsMarubozuCandle(i, open, high, low, close, atr, arraySize);
   if (result.name != "" && result.trend == BULLISH)
      return result;

   // Kiểm tra nếu nến hiện tại là nến tăng mạnh
   result = InitCandlePatternResult();
   CandleData candleData = GetCandleData(i, open, high, low, close, atr, arraySize);
   if (candleData.isUp && candleData.bodyHeightRatio >= BIG_BODY_HEIGHT_RATIO &&
       candleData.bodyATRRatio >= BIG_SIZE_ATR_RATIO)
   {
      // Nến có nến kế trước đó
      if (i + 1 < arraySize)
      {
         CandlePatternResult hammerCandle = IsHammerCandle(i + 1, open, high, low, close, atr, arraySize);
         if (hammerCandle.name != "" && hammerCandle.trend == BEARISH)
         {
            // Điểm xoay đảo chiều hợp lệ
            result.name = HAMMER_REVERSAL;
            result.trend = BULLISH;
            return result;
         }
      }
   }

   return result;
}

// ==================================================
// ============= SELL PATTERNS ======================
// ==================================================

//+------------------------------------------------------------------+
//| Xác định SELL Patterns                                           |
//| Patterns: Shooting Star, Bearish Engulfing, Dark Cloud, Evening  |
//+------------------------------------------------------------------+
CandlePatternResult DetectSellPattern(int i,  // index nến hiện tại
                                      const double& open[], const double& high[], const double& low[],
                                      const double& close[], const double& atr[], int arraySize)
{
   CandlePatternResult result = IsHammerOrInvertedHammerPattern(i, open, high, low, close, atr, arraySize);
   if (result.name != "" && result.trend == BEARISH)
      return result;

   result = IsHangingManOrShootingStarPattern(i, open, high, low, close, atr, arraySize);
   if (result.name != "" && result.trend == BEARISH)
      return result;

   result = IsBearishEngulfingPattern(i, open, high, low, close, atr, arraySize);
   if (result.name != "" && result.trend == BEARISH)
      return result;

   result = IsDarkCloudCoverPattern(i, open, high, low, close, atr, arraySize);
   if (result.name != "" && result.trend == BEARISH)
      return result;

   result = IsEveningStarPattern(i, open, high, low, close, atr, arraySize);
   if (result.name != "" && result.trend == BEARISH)
      return result;

   result = IsMarubozuCandle(i, open, high, low, close, atr, arraySize);
   if (result.name != "" && result.trend == BEARISH)
      return result;

   return InitCandlePatternResult();
}

#endif  // CANDLE_PATTERNS_H
