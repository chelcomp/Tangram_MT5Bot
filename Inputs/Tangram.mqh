//+------------------------------------------------------------------+
//|                                                          Tangram |
//|                        Copyright 2020, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#include "../Enums/OperationDirection.mqh"
#include "../Enums/TimeInterval.mqh"

enum ENUM_GRAPH_TYPE
   {
    GRAPH_TYPE_CANDLE_STICK, // CandleStick
    GRAPH_TYPE_HEIKINASHI   // Heikin-Ashi
   };

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

sinput string Comment1 = "NOT PRODUCTION READY"; // Tangram Bot - Only for study ( Demo Account ) on B3 and MBF
sinput string Comment2 = "This bot was created based on options available on Tangram bot, but there is no guarantee of equivalency."; // Disclaimer: No relation with Smarttbot.com.br
sinput string Comment3 = "michelpurper@gmail.com"; // Developper Contact
input string BotName = ""; // Bot Name

//+------------------------------------------------------------------+
//|  Graphic input section                                           |
//+------------------------------------------------------------------+
input group "Graphic";
input ENUM_TIMEFRAMES TimeFrame = PERIOD_M5;                // Timeframe
//+------------------------------------------------------------------+
input ENUM_GRAPH_TYPE GraphType = GRAPH_TYPE_CANDLE_STICK;  // Type
input group "Graphic Heikin-Ashi"
input bool input_UseSmoothing = false;                        // Use Smoothing
input enum_SmoothingType input_SmoothingType = stExponential; // Smoothing Type
input int input_SmoothingPeriods = 3;                         // Smoothing Periods
//+------------------------------------------------------------------

input group "Order Management"
input ENUM_ORDER_MANAGEMENT_TYPE ORDER_Management_Type = ORDER_MANAGEMENT_TYPE_FIXED_VOLUME;   // Volume Type
input ENUM_OPERATION_DIRECTION ORDER_Operation_Direction = OPERATION_DIRECTION_BOTH;           // Operation Direction
input double ORDER_Volume = 2;                                                                 // Volume
input bool ORDER_Block_New_Inputs_On_Same_Day = false;                                         // Block new inputs on the same day after one output
//+------------------------------------------------------------------+
sinput string _split3; //--
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
input bool OUT_Use_Reverse = true;   // Allow Reverse Order
input bool OUT_Martingale = false;  // Use Martingale
input int  OUT_Martingale_Times = 1; // Maximum number of consecutive losses with position increase
#include "../RiskManagement/Trade.mqh";

//+------------------------------------------------------------------+
sinput group "DAILY RISK MANAGEMENT ---------------------------------------------------"
#include "../RiskManagement/Daily.mqh";

//input group "Setting"
//input long input_MagicNumber = -1; // Magic Number
