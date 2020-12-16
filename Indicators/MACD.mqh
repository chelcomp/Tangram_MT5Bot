//+------------------------------------------------------------------+
//|                                                          Tangram |
//|                        Copyright 2020, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#include "../HelpFunctions/Input.mqh"

enum ENUM_MACD_USE_MODE
   {
    MACD_USE_MODE_ABOVE_BELOW, // MACD Line Above/Below Signal Line
    MACD_USE_MODE_CROSSING     // MACD Line Crossing Signal Line
   };

enum ENUM_MACD_AVERAGE_TYPE
   {
    MACD_AVERAGE_TYPE_SIMPLE     // Simple
//  MACD_AVERAGE_TYPE_EXPONENTIAL // Exponential
   };

input group "3. MACD"
sinput bool MACD_Enable = false;                                                         // Enable MACD
input bool MACD_Reverse = false;                                                         // Reverse
input ENUM_INDICATOR_OPERATION_MODE MACD_Operation_Mode = INDICATOR_OPERATION_MODE_BOTH; // Operation Mode
input ENUM_MACD_USE_MODE MACD_Use_Mode = MACD_USE_MODE_ABOVE_BELOW;                      // Use Mode
input ENUM_APPLIED_PRICE MACD_Applied_Price = PRICE_CLOSE;                               // Applied Price
sinput ENUM_MACD_AVERAGE_TYPE MACD_AVERAGE_TYPE = MACD_AVERAGE_TYPE_SIMPLE;               // Average Type

input int MACD_Slow_Period = 12;                                                          // Slow Periods
input int MACD_Fast_Periods = 26;                                                         // Fast Periods
input int MACD_Signal_Line  = 9;                                                          // Signal Line

input bool MACD_Filter = false;                                                           // Filter(in): Buy/Sell Only With MACD Below/Above the Filter Value
input int MACD_Filter_Value = 0;                                                          // Filter(in): Vaue

int MACD_Handler;
int MACD_HA_Handler;
double MACD_Buffer[];
double MACD_Signal_Buffer[];

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int zMACDInit(ENUM_TIMEFRAMES timeframe, bool use_heikin_ashi)
   {
    if(MACD_Enable)
       {
        if(MACD_Slow_Period >= MACD_Fast_Periods)
           {
            Print("MACD Slow can't be higher than MACD Fast parameter");
            return INIT_PARAMETERS_INCORRECT;
           }

        ArraySetAsSeries(MACD_Buffer, true);
        ArraySetAsSeries(MACD_Signal_Buffer, true);

        //--- create handle of the indicator
        if(!use_heikin_ashi)
           {
            MACD_Handler = iMACD(_Symbol, timeframe, MACD_Fast_Periods, MACD_Slow_Period, MACD_Signal_Line, MACD_Applied_Price);
           }
        else
           {
            MACD_HA_Handler = iCustom(_Symbol, timeframe, "CustomHeikenAshi", MACD_Applied_Price);
            MACD_Handler = iMACD(_Symbol, timeframe, MACD_Fast_Periods, MACD_Slow_Period, MACD_Signal_Line, MACD_HA_Handler);
           }
        //--- if the handle is not created
        if(MACD_Handler == INVALID_HANDLE)
           {
            //--- tell about the failure and output the error code
            PrintFormat("Failed to create handle of the iMACD indicator for the symbol %s/%s, error code %d",
                        _Symbol, EnumToString(timeframe), GetLastError());
            //--- the indicator is stopped early
            return(INIT_FAILED);
           }
       }

//--- normal initialization of the indicator
    return(INIT_SUCCEEDED);
   }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void zMACDOnTesterInit()
   {
    if(!MACD_Enable)
       {
        zDisableInput("MACD_Reverse");
        zDisableInput("MACD_Operation_Mode");
        zDisableInput("MACD_Use_Mode");
        zDisableInput("MACD_Applied_Price");
        zDisableInput("MACD_AVERAGE_TYPE");
        zDisableInput("MACD_Slow_Period");
        zDisableInput("MACD_Fast_Periods");
        zDisableInput("MACD_Signal_Line");

        zDisableInput("MACD_Filter");
        zDisableInput("MACD_Filter_Value");
       }
    else
        if(MACD_Operation_Mode == INDICATOR_OPERATION_MODE_OUT)
           {
            zDisableInput("MACD_Filter");
            zDisableInput("MACD_Filter_Value");
           }
   }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void zMACDDeinit()
   {
    if(MACD_Handler != INVALID_HANDLE)
        IndicatorRelease(MACD_Handler);

    if(MACD_HA_Handler != INVALID_HANDLE)
        IndicatorRelease(MACD_HA_Handler);

    ArrayFree(MACD_Buffer);
    ArrayFree(MACD_Signal_Buffer);
   }

//+------------------------------------------------------------------+
//| MACD                                                             |
//+------------------------------------------------------------------+
ENUM_INDICATOR_SIGNAL zMACD()
   {
    if(!MACD_Enable)
        return INDICATOR_SIGNAL_NEUTRAL_ALLOW;
    ENUM_INDICATOR_SIGNAL indicator_signal = INDICATOR_SIGNAL_NEUTRAL_BLOCK;

//--- Load buffers and
    if(!zMACDFillArraysFromBuffers(MACD_Buffer, MACD_Signal_Buffer, MACD_Handler, 3))
        return indicator_signal;

    if(MACD_Use_Mode == MACD_USE_MODE_ABOVE_BELOW)
       {
        if(MACD_Signal_Buffer[1] < MACD_Buffer[1])
            indicator_signal = INDICATOR_SIGNAL_SELL;
        else
            if(MACD_Signal_Buffer[1] > MACD_Buffer[1])
                indicator_signal = INDICATOR_SIGNAL_BUY;
       }
    else // if(MACD_Use_Mode == MACD_USE_MODE_CROSSING)
       {
        if(MathRound( MACD_Signal_Buffer[1]) <= MathRound( MACD_Buffer[1]) && MathRound( MACD_Signal_Buffer[2]) > MathRound( MACD_Buffer[2]))
            indicator_signal = INDICATOR_SIGNAL_SELL;
        else
            if(MathRound( MACD_Signal_Buffer[1]) >= MathRound( MACD_Buffer[1]) && MathRound( MACD_Signal_Buffer[2]) < MathRound( MACD_Buffer[2]))
                indicator_signal = INDICATOR_SIGNAL_BUY;
       }

    if(MACD_Reverse)
        indicator_signal = indicator_signal == INDICATOR_SIGNAL_SELL ? INDICATOR_SIGNAL_BUY
                           : indicator_signal == INDICATOR_SIGNAL_BUY ? INDICATOR_SIGNAL_SELL
                           : indicator_signal;

    return indicator_signal;
   }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
ENUM_INDICATOR_SIGNAL zMACDFilter(ENUM_INDICATOR_SIGNAL macd_indicator_signal)
   {
    if(!MACD_Enable)
        return INDICATOR_SIGNAL_NEUTRAL_ALLOW;
    ENUM_INDICATOR_SIGNAL indicator_signal = INDICATOR_FILTER_ALLOW;

    if(MACD_Filter)
        if(macd_indicator_signal == INDICATOR_SIGNAL_SELL
           && MACD_Buffer[1] > MACD_Filter_Value)
           {
            indicator_signal = INDICATOR_SIGNAL_NEUTRAL_BLOCK;
           }
        else
            if(macd_indicator_signal == INDICATOR_SIGNAL_BUY
               && MACD_Buffer[1] < MACD_Filter_Value)
               {
                indicator_signal = INDICATOR_SIGNAL_NEUTRAL_BLOCK;
               }

    return indicator_signal;
   }
//+------------------------------------------------------------------+
//| Filling indicator buffers from the iMACD indicator               |
//+------------------------------------------------------------------+
bool zMACDFillArraysFromBuffers(double &macd_buffer[],    // indicator buffer of MACD values
                                double &signal_buffer[],  // indicator buffer of the signal line of MACD
                                int ind_handle,           // handle of the iMACD indicator
                                int amount                // number of copied values
                               )
   {
//--- reset error code
    ResetLastError();
//--- fill a part of the iMACDBuffer array with values from the indicator buffer that has 0 index
    if(CopyBuffer(ind_handle, 0, 0, amount, macd_buffer) < 0)
       {
        //--- if the copying fails, tell the error code
        PrintFormat("Failed to copy data from the iMACD indicator, error code %d", GetLastError());
        //--- quit with zero result - it means that the indicator is considered as not calculated
        return(false);
       }

//--- fill a part of the SignalBuffer array with values from the indicator buffer that has index 1
    if(CopyBuffer(ind_handle, 1, 0, amount, signal_buffer) < 0)
       {
        //--- if the copying fails, tell the error code
        PrintFormat("Failed to copy data from the iMACD indicator, error code %d", GetLastError());
        //--- quit with zero result - it means that the indicator is considered as not calculated
        return(false);
       }
//--- everything is fine
    return(true);
   }
//+------------------------------------------------------------------+
