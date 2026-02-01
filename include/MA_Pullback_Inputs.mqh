//+------------------------------------------------------------------+
//|                                          MA_Pullback_Inputs.mqh |
//|                                    Copyright 2026, Do Nhat Phong |
//|                                   https://github.com/nhatphongdo |
//+------------------------------------------------------------------+
//| Shared Input Module for MA_Pullback EA and Indicator            |
//| Tập trung định nghĩa các default values, enums và helper        |
//+------------------------------------------------------------------+
#property copyright "Do Nhat Phong"

#ifndef MA_PULLBACK_INPUTS_H
#define MA_PULLBACK_INPUTS_H

#include "MA_Pullback_Core.mqh"

// ==================================================
// ===================== ENUM ========================
// ==================================================
enum ENUM_MA_TYPE_MODE
{
   MA_TYPE_SMA = MODE_SMA,  // SMA (Simple Moving Average)
   MA_TYPE_EMA = MODE_EMA   // EMA (Exponential Moving Average)
};

// ==================================================
// ============= DEFAULT VALUES =====================
// ==================================================

// --- MAIN SETTINGS (EA Only) ---
// Cài đặt chính cho giao dịch tự động
#define DEF_AUTO_TRADE true
// Khối lượng giao dịch (lots)
#define DEF_LOT_SIZE 1.0
// Số tiền thua tối đa mỗi lệnh (% tài khoản), 0 = không giới hạn
#define DEF_MAX_LOSS_PERCENT 1.0
// Số định danh EA
#define DEF_MAGIC_NUMBER 123456
// Spread tối đa cho phép (points), ~2 pips cho 5-digit
#define DEF_MAX_SPREAD 20.0
// Comment hiển thị trên lệnh
#define DEF_TRADE_COMMENT "MA_Pullback_EA"

// --- DRAWING SETTINGS ---
// Vẽ signal và markers lên chart
#define DEF_ENABLE_DRAW_SIGNAL true
// Giữ lại markers khi EA dừng (để review)
#define DEF_KEEP_MARKERS_ON_STOP false

// --- TRADE LIMITS ---
// Giới hạn giao dịch
// Số points StopLoss tối thiểu (5 pips = 50 points)
#define DEF_MIN_STOP_LOSS 50.0
// Tỷ lệ Reward/Risk (3.0 = TP 3 lần SL)
#define DEF_MAX_RISK_REWARD_RATE 3.0
#define DEF_MIN_RISK_REWARD_RATE 1.5
// Số lệnh tối đa toàn tài khoản, 0 = không giới hạn
#define DEF_MAX_ACCOUNT_ORDERS 3
// Số lệnh tối đa cho mỗi symbol
#define DEF_MAX_SYMBOL_ORDERS 1
// Buffer thêm vào TP (pips)
#define DEF_TP_BUFFER 0
// Buffer cộng thêm vào S/R zone và MA line (%)
#define DEF_SR_BUFFER_PERCENT 5.0

// --- INDICATOR SETTINGS ---
// Cài đặt các indicator kỹ thuật
// Loại Moving Average (EMA phản ứng nhanh hơn SMA)
#define DEF_MA_TYPE MA_TYPE_SMA
// Chu kỳ MA nhanh
#define DEF_MA50_PERIOD 50
// Chu kỳ MA chậm (xác định trend dài hạn)
#define DEF_MA200_PERIOD 200
// Chu kỳ RSI
#define DEF_RSI_PERIOD 14
// Chu kỳ MACD Fast
#define DEF_MACD_FAST 12
// Chu kỳ MACD Slow
#define DEF_MACD_SLOW 26
// Chu kỳ MACD Signal
#define DEF_MACD_SIGNAL 9
// Chu kỳ ADX indicator
#define DEF_ADX_PERIOD 14
// Số nến tính ATR
#define DEF_ATR_LENGTH 14

// --- STRATEGY SETTINGS ---
// Cài đặt chiến lược entry
// Số nến tối thiểu để hình thành trend trước khi đảo chiều
#define DEF_MIN_TREND_BARS 10
// Số nến tối đa chờ pullback
#define DEF_MAX_WAIT_BARS 20
// Số nến lookback để tìm Support/Resistance
#define DEF_SR_LOOKBACK 30
// Tỷ lệ % zone để xác định vùng sideway quanh MA
#define DEF_MA_SIDEWAY_ZONE_RATIO 0.05

// --- FILTER SETTINGS ---
// Điểm tối thiểu để signal được coi là valid (0-100)%
#define DEF_MIN_SCORE_TO_PASS 60.0

// --- FILTER: MA SLOPE ---
// Kiểm tra độ dốc MA có đủ mạnh không - xác định xu hướng rõ ràng
// Bật/tắt filter
#define DEF_ENABLE_MA_SLOPE true
// Nếu true, filter fail sẽ loại bỏ signal hoàn toàn
#define DEF_MA_SLOPE_CRITICAL false
// Ngưỡng độ dốc tối thiểu (độ), 15 = vừa phải, 20 = mạnh hơn
#define DEF_MA_SLOPE_THRESHOLD 15.0
// Trọng số điểm cho filter này (0-100)
#define DEF_MA_SLOPE_WEIGHT 10.0

// --- FILTER: STATIC RSI MOMENTUM ---
// Kiểm tra RSI có xác nhận xu hướng không
// RSI > 50 cho BUY, RSI < 50 cho SELL.
// Bật/tắt filter
#define DEF_ENABLE_RSI_MOMENTUM true
// Nếu true, filter fail sẽ loại bỏ signal hoàn toàn
#define DEF_RSI_MOMENTUM_CRITICAL false
// Trọng số điểm cho filter này (0-100)
#define DEF_RSI_MOMENTUM_WEIGHT 5.0

// --- FILTER: STATIC MACD MOMENTUM ---
// Kiểm tra MACD có xác nhận xu hướng không
// MACD line > signal cho BUY
// Bật/tắt filter
#define DEF_ENABLE_MACD_MOMENTUM true
// Nếu true, filter fail sẽ loại bỏ signal hoàn toàn
#define DEF_MACD_MOMENTUM_CRITICAL false
// Trọng số điểm cho filter này (0-100)
#define DEF_MACD_MOMENTUM_WEIGHT 5.0

// --- FILTER: RSI REVERSAL ---
// Phát hiện RSI đang đi ngược hướng signal (dấu hiệu đảo chiều)
// Bật/tắt filter
#define DEF_ENABLE_RSI_REVERSAL true
// Nếu true, filter fail sẽ loại bỏ signal hoàn toàn (khuyến nghị bật)
#define DEF_RSI_REVERSAL_CRITICAL true
// Số nến để kiểm tra RSI có đang đảo chiều không
#define DEF_RSI_REVERSAL_LOOKBACK 2
// Trọng số điểm cho filter này (0-100)
#define DEF_RSI_REVERSAL_WEIGHT 10.0

// --- FILTER: MACD HISTOGRAM ---
// Phát hiện histogram đang mở rộng ngược hướng (momentum shift)
// Bật/tắt filter
#define DEF_ENABLE_MACD_HISTOGRAM false
// Nếu true, filter fail sẽ loại bỏ signal hoàn toàn
#define DEF_MACD_HISTOGRAM_CRITICAL false
// Số nến để kiểm tra histogram có đang mở rộng ngược hướng không
#define DEF_MACD_HISTOGRAM_LOOKBACK 2
// Trọng số điểm cho filter này (0-100)
#define DEF_MACD_HISTOGRAM_WEIGHT 10.0

// --- FILTER: SMA200 TREND ---
// Kiểm tra giá có cùng xu hướng với SMA200 không (trend dài hạn)
// BUY: giá > SMA200, SELL: giá < SMA200
// Bật/tắt filter
#define DEF_ENABLE_SMA200_FILTER true
// Nếu true, filter fail sẽ loại bỏ signal hoàn toàn
#define DEF_SMA200_CRITICAL false
// Trọng số điểm cho filter này (0-100)
#define DEF_SMA200_WEIGHT 10.0

// --- FILTER: S/R ZONE ---
// Kiểm tra giá có trong vùng entry tốt không
// BUY: giá gần Support, SELL: giá gần Resistance
// Bật/tắt filter
#define DEF_ENABLE_SR_ZONE_FILTER true
// Nếu true, filter fail sẽ loại bỏ signal hoàn toàn
#define DEF_SR_ZONE_CRITICAL false
// % vùng tốt từ S đến R (40% = 40% gần nhất với S cho BUY)
#define DEF_SR_ZONE_PERCENT 40.0
// Trọng số điểm cho filter này (0-100)
#define DEF_SR_ZONE_WEIGHT 10.0

// --- FILTER: S/R MIN WIDTH ---
// Lọc vùng S/R quá hẹp (đảm bảo đủ khoảng để trade)
// Bật/tắt filter
#define DEF_ENABLE_SR_MIN_WIDTH true
// Nếu true, filter fail sẽ loại bỏ signal hoàn toàn (khuyến nghị bật)
#define DEF_SR_MIN_WIDTH_CRITICAL true
// Timeframe Noise đặc trưng   Min S/R Width (× ATR)     Ghi chú
// M5         Rất cao           2.5 – 3.0 ATR             Tránh scalp-range, false breakout
// M15       Cao               2.0 – 2.5 ATR             Phù hợp pullback intraday
// M30       Trung bình       1.8 – 2.2 ATR             Cân bằng tần suất & chất lượng
// H1         Trung bình thấp   1.5 – 2.0 ATR             Sweet spot cho trend-follow
// H4         Thấp             1.2 – 1.5 ATR             Cấu trúc giá rõ
// D1         Rất thấp         1.0 – 1.3 ATR             Không nên >1.5
// Độ rộng tối thiểu của vùng S/R (đơn vị: x ATR)
#define DEF_MIN_SR_WIDTH_ATR 3.0
// Trọng số điểm cho filter này (0-100)
#define DEF_SR_MIN_WIDTH_WEIGHT 10.0

// --- FILTER: ADX TREND STRENGTH ---
// Kiểm tra thị trường có đang trending không (tránh sideway)
// Bật/tắt filter
#define DEF_ENABLE_ADX_FILTER true
// Nếu true, filter fail sẽ loại bỏ signal hoàn toàn
#define DEF_ADX_CRITICAL false
// Ngưỡng ADX tối thiểu:
// 20-25: trending yếu, 25-30: trending mạnh, >30: trending rất mạnh
#define DEF_MIN_ADX_THRESHOLD 20.0
// Kiểm tra +DI/-DI có đúng hướng không (+DI > -DI cho BUY)
#define DEF_ADX_DIRECTIONAL_CONFIRM true
// Trọng số điểm cho filter này (0-100)
#define DEF_ADX_WEIGHT 10.0

// --- FILTER: BODY/ATR RATIO ---
// Kiểm tra nến confirm có đủ mạnh không (thân nến lớn so với ATR)
// Bật/tắt filter
#define DEF_ENABLE_BODY_ATR_FILTER true
// Nếu true, filter fail sẽ loại bỏ signal hoàn toàn
#define DEF_BODY_ATR_CRITICAL false
// Tỷ lệ thân nến tối thiểu so với ATR (0.25 = 25% ATR)
#define DEF_MIN_BODY_ATR_RATIO 0.25
// Trọng số điểm cho filter này (0-100)
#define DEF_BODY_ATR_WEIGHT 5.0

// --- FILTER: VOLUME CONFIRMATION ---
// Kiểm tra volume có đủ so với trung bình không
// Off by default - forex không có volume thật (chỉ tick volume)
// Bật/tắt filter
#define DEF_ENABLE_VOLUME_FILTER false
// Nếu true, filter fail sẽ loại bỏ signal hoàn toàn
#define DEF_VOLUME_CRITICAL false
// Số nến để tính volume trung bình
#define DEF_VOLUME_AVG_PERIOD 20
// Tỷ lệ volume tối thiểu so với trung bình (0.8 = 80%)
#define DEF_MIN_VOLUME_RATIO 0.8
// Trọng số điểm cho filter này (0-100)
#define DEF_VOLUME_WEIGHT 5.0

// --- FILTER: PRICE-MA DISTANCE ---
// Tránh chase - giá không quá xa MA50 (entry đã muộn)
// Bật/tắt filter
#define DEF_ENABLE_PRICE_MA_DIST true
// Nếu true, filter fail sẽ loại bỏ signal hoàn toàn (khuyến nghị bật)
#define DEF_PRICE_MA_DIST_CRITICAL true
// Khoảng cách tối đa từ giá đến MA (đơn vị: x ATR)
#define DEF_MAX_PRICE_MA_DIST_ATR 1.5
// Trọng số điểm cho filter này (0-100)
#define DEF_PRICE_MA_DIST_WEIGHT 10.0

// --- FILTER: TIME CONTROL (EA Only) ---
// Chỉ trade trong giờ tốt - tránh phiên Á trầm lắng
// Bật/tắt filter
#define DEF_ENABLE_TIME_FILTER false
// Nếu true, filter fail sẽ loại bỏ signal hoàn toàn
#define DEF_TIME_CRITICAL false
// Giờ bắt đầu trade (London open = 7 GMT)
#define DEF_TRADE_START_HOUR 7
// Giờ kết thúc trade (NY close = 21 GMT)
#define DEF_TRADE_END_HOUR 21
// Trọng số điểm cho filter này (0 = không tính điểm, chỉ lọc)
#define DEF_TIME_WEIGHT 0.0

// --- FILTER: NEWS FILTER (EA Only) ---
// Tránh trade gần tin quan trọng - volatility cao
// Bật/tắt filter
#define DEF_ENABLE_NEWS_FILTER false
// Nếu true, filter fail sẽ loại bỏ signal hoàn toàn
#define DEF_NEWS_CRITICAL false
// Số phút trước tin không trade
#define DEF_NEWS_MINUTES_BEFORE 15
// Số phút sau tin không trade
#define DEF_NEWS_MINUTES_AFTER 10
// Mức độ quan trọng tối thiểu (1=Low, 2=Medium, 3=High)
#define DEF_NEWS_MIN_IMPORTANCE 3
// Trọng số điểm cho filter này (0 = không tính điểm, chỉ lọc)
#define DEF_NEWS_WEIGHT 0.0

// --- FILTER: CONSECUTIVE LOSSES (EA Only) ---
// Tạm dừng sau chuỗi thua liên tiếp - bảo vệ tâm lý và vốn
// Bật/tắt filter
#define DEF_ENABLE_CONSEC_LOSS_FILTER true
// Số lệnh thua liên tiếp tối đa trước khi tạm dừng
#define DEF_MAX_CONSECUTIVE_LOSSES 3
// Số phút tạm dừng sau khi đạt max losses
#define DEF_PAUSE_MINUTES_AFTER_LOSS 30

// --- DISPLAY SETTINGS (Indicator Only) ---
// Cài đặt giao diện hiển thị trên chart
// Màu tín hiệu BUY
#define DEF_BUY_COLOR clrLime
// Màu tín hiệu SELL
#define DEF_SELL_COLOR clrRed
// Màu đường Stop Loss
#define DEF_SL_COLOR clrOrange
// Màu đường Take Profit
#define DEF_TP_COLOR clrAqua
// Màu label tín hiệu mạnh (score cao)
#define DEF_STRONG_COLOR clrWhite
// Màu label tín hiệu yếu (score thấp)
#define DEF_WEAK_COLOR clrYellow
// clang-format off
// Màu vùng Support (xanh đậm)
#define DEF_SUPPORT_COLOR C'0,100,0'
// Màu vùng Resistance (đỏ đậm)
#define DEF_RESIST_COLOR C'139,0,0'
// clang-format on
// Màu tín hiệu bị hủy/quá hạn
#define DEF_CANCEL_COLOR clrGray

// --- ALERTS (Indicator Only) ---
// Thông báo khi có tín hiệu mới
// Bật Alert popup trên chart
#define DEF_ALERT_ENABLED true
// Bật Push Notification đến điện thoại
#define DEF_PUSH_ENABLED true
// Tự động thêm SMA/RSI/MACD lên chart
#define DEF_AUTO_ADD_INDICATORS true

#endif  // MA_PULLBACK_INPUTS_H
