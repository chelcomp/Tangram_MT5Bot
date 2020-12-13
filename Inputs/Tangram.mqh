//+------------------------------------------------------------------+
//|                                                          Tangram |
//|                        Copyright 2020, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#include "../Enums/OperationDirection.mqh"
#include "../Enums/TimeInterval.mqh"


enum enum_SmoothingType
   {
    stExponential, // Exponential
    stSimple       // Simple(Arithmetic)
   };

enum ENUM_ORDER_MANAGEMENT_TYPE
   {
    ORDER_MANAGEMENT_TYPE_FIXED_VOLUME,    // Fixed Volume
    ORDER_MANAGEMENT_TYPE_FINANCIAL_VOLUME // Financial Volume R$
   };
   
enum ENUM_GRAPH_TYPE
   {
    GRAPH_TYPE_CANDLE_STICK, // CandleStick
    GRAPH_TYPE_HEIKINASHI   // Heikin-Ashi (NOT Smoothed)
   };
   
enum ENUM_CLOSE_POSITION_BY_INDICATOR
{
   CLOSE_POSITION_BY_INDICATOR_ANY, // Close by Any Indicator
   CLOSE_POSITION_BY_INDICATOR_ALL  // Close by All Indicator Together
};
   
sinput string Comment1 = "NOT PRODUCTION ENABLED"; // Tangram Bot - Only for study ( Demo Account ) on B3 and MBF
sinput string Comment2 = "This bot was created based on options available on Tangram bot, but there is no guarantee of equivalency."; // Disclaimer: No relation with Smarttbot.com.br
sinput string Comment3 = "michelpurper@gmail.com"; // Developper Contact
sinput string Comment4 = "FREE FOR USE"; // This bot can't be sold
input  string BotName  = ""; // Bot Name

//+------------------------------------------------------------------+
//|  Graphic input section                                           |
//+------------------------------------------------------------------+
input group "Graphic";
input ENUM_TIMEFRAMES TimeFrame = PERIOD_M5;                  // Timeframe
//+------------------------------------------------------------------+
input ENUM_GRAPH_TYPE GRAPH_Type = GRAPH_TYPE_CANDLE_STICK;   // Type

/*
input group "Graphic Heikin-Ashi"
input bool input_UseSmoothing = false;                        // Use Smoothing
input enum_SmoothingType input_SmoothingType = stExponential; // Smoothing Type
input int input_SmoothingPeriods = 3;                         // Smoothing Periods
*/

input group "Order Management"
input ENUM_ORDER_MANAGEMENT_TYPE ORDER_Management_Type = ORDER_MANAGEMENT_TYPE_FIXED_VOLUME;   // Volume Type
input ENUM_OPERATION_DIRECTION ORDER_Operation_Direction = OPERATION_DIRECTION_BOTH;           // Operation Direction
input double ORDER_Volume = 2;                                                                 // Volume
input bool ORDER_Block_New_Inputs_On_Same_Day = false;                                         // Block new inputs on the same day after one output
//+------------------------------------------------------------------+

sinput group "TECHNICAL INDICATORS ---------------------------------------------------"
//-- "Moving Average"
#include "../Indicators/MovingAverage.mqh"
#include "../Indicators/HiLoActivator.mqh"
#include "../Indicators/MACD.mqh"
#include "../Indicators/ADX.mqh"
#include "../Indicators/Stochastic.mqh"
#include "../Indicators/VWAP.mqh"
#include "../Indicators/RSI.mqh"
#include "../Indicators/BollingerBands.mqh"
#include "../Indicators/StopATR.mqh"
#include "../Indicators/SARParabolic.mqh"

sinput group "TRADE RISK MANAGEMENT ---------------------------------------------------"
input group "Output Criterias"
input ENUM_CLOSE_POSITION_BY_INDICATOR OUT_Close_Position_By_Indicator = CLOSE_POSITION_BY_INDICATOR_ANY; // Close Positiob By Indicator
input bool OUT_Use_Reverse = true;   // Allow Reverse Order
input int  OUT_Martingale_Times = 0; // Martingale: Maximum number of consecutive losses with position increase
#include "../RiskManagement/Trade.mqh";

//+------------------------------------------------------------------+
sinput group "DAILY RISK MANAGEMENT ---------------------------------------------------"
#include "../RiskManagement/Daily.mqh";

input group "Custom Optimization: Monte Carlo"
#include "../mcarlo/mcarlo.mqh"

input group "Backtesting Setting (Custom Criteria)"
sinput long SETTING_MagicNumber = -1; // Magic Number
/*
sinput bool   SETTING_Backtesting_Stop_On_Negative_Equity = true;      // Stop to backtesting when Equity is over (When Account is Zero)
sinput double SETTING_Backtesting_Stop_On_Max_Drowndow_Percent = 30; // Stop to backtestig when Drowndown higher than %
sinput double SETTING_Backtesting_Expected_AVG_Deal_by_Day = 1.5;    // Average deal by day to ranking up
*/