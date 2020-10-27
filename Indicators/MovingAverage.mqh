//+------------------------------------------------------------------+
//|                                                          Tangram |
//|                        Copyright 2020, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#include "../Enums/IndicatorSignal.mqh"

enum ENUM_MA_USE_MODE
   {
    MA_USE_MODE_ABOVE_BELOW, // Short Average Above/Below of Long
    MA_USE_MODE_CROSSING     // Average Crossing over/under
   };

input group "1. Movel Average"
input bool MA_Enable = false;                                                          // Enable MA
input bool MA_Reverse = false;                                                          // Reverse
input ENUM_INDICATOR_OPERATION_MODE MA_Operation_Mode = INDICATOR_OPERATION_MODE_BOTH; // Operation Mode
input ENUM_MA_USE_MODE MA_Use_Mode = MA_USE_MODE_ABOVE_BELOW;                          // Use Mode

input ENUM_MA_METHOD MA_Short_Method = MODE_EMA;                                        // Short Method Type
input int MA_Short_Periods = 9;                                                         // Short Periods
input int MA_Short_Shift = 0;                                                           // Short Shift
input ENUM_APPLIED_PRICE MA_Short_Applied_Price = PRICE_CLOSE;                          // Short Applied Price

input ENUM_MA_METHOD MA_Long_Method = MODE_SMA;                                         // Long Method Type
input int MA_Long_Periods = 40;                                                         // Long Periods
input int MA_Long_Shift = 0;                                                            // Long Shift
input ENUM_APPLIED_PRICE MA_Long_Applied_Price = PRICE_CLOSE;                           // Long Applied Price

int MA_Short_Handler;
int MA_Long_Handler;
double MA_Short_Buffer[];
double MA_Long_Buffer[];

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int zMAInit(ENUM_TIMEFRAMES timeframe)
   {
    if(MA_Enable)
       {
        ArraySetAsSeries(MA_Short_Buffer, true);
        ArraySetAsSeries(MA_Long_Buffer, true);

        //--- create handle of the indicator
        MA_Short_Handler = iMA(_Symbol, timeframe, MA_Short_Periods, MA_Short_Shift, MA_Short_Method,  MA_Short_Applied_Price);
        MA_Long_Handler  = iMA(_Symbol, timeframe, MA_Long_Periods,  MA_Long_Shift,  MA_Long_Method,   MA_Long_Applied_Price);

        //--- if the handle is not created
        if(MA_Short_Handler == INVALID_HANDLE
           || MA_Long_Handler == INVALID_HANDLE)
           {
            //--- tell about the failure and output the error code
            PrintFormat("Failed to create handle of the iMA indicator for the symbol %s/%s, error code %d",
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
void zMADeinit()
   {
    if(MA_Short_Handler != INVALID_HANDLE)
        IndicatorRelease(MA_Short_Handler);

    if(MA_Long_Handler != INVALID_HANDLE)
        IndicatorRelease(MA_Long_Handler);

    ArrayFree(MA_Short_Buffer);
    ArrayFree(MA_Long_Buffer);
   }

//+------------------------------------------------------------------+
//| MCrossing of two Movin Average                                   |
//+------------------------------------------------------------------+
ENUM_INDICATOR_SIGNAL zMA()
   {
    if(!MA_Enable)
        return INDICATOR_SIGNAL_NEUTRAL_ALLOW;
    ENUM_INDICATOR_SIGNAL indicator_signal = INDICATOR_SIGNAL_NEUTRAL_BLOCK;

//--- Load buffers and
    if(!FillArrayFromBuffer(MA_Short_Handler, 0, 0, 3, MA_Short_Buffer)
       || !FillArrayFromBuffer(MA_Long_Handler, 0, 0, 3, MA_Long_Buffer))
        return indicator_signal;

    if(MA_Use_Mode == MA_USE_MODE_ABOVE_BELOW)
       {
        if(MA_Short_Buffer[1] < MA_Long_Buffer[1])
            indicator_signal = INDICATOR_SIGNAL_SELL;
        else
            if(MA_Short_Buffer[1] > MA_Long_Buffer[1])
                indicator_signal = INDICATOR_SIGNAL_BUY;
       }
    else // if(MA_Use_Mode == MA_USE_MODE_CROSSING)
       {
        if(MA_Short_Buffer[1] < MA_Long_Buffer[1] && MA_Short_Buffer[2] > MA_Long_Buffer[2])
            indicator_signal = INDICATOR_SIGNAL_SELL;
        else
            if(MA_Short_Buffer[1] > MA_Long_Buffer[1] && MA_Short_Buffer[2] < MA_Long_Buffer[2])
                indicator_signal = INDICATOR_SIGNAL_BUY;
       }

    if(MA_Reverse)
        indicator_signal = indicator_signal == INDICATOR_SIGNAL_SELL ? INDICATOR_SIGNAL_BUY
                           : indicator_signal == INDICATOR_SIGNAL_BUY ? INDICATOR_SIGNAL_SELL
                           : indicator_signal;

    return indicator_signal;
   }

//+------------------------------------------------------------------+
//| Filling indicator buffers from the MA indicator                  |
//+------------------------------------------------------------------+
bool FillArrayFromBuffer(int       indicator_handle,     // indicator handle
                         int       buffer_num,           // indicator buffer number
                         int       start_pos,            // start position
                         int       count,                // amount to copy
                         double    &buffer[]              // target array to copy
                        )
   {
//--- reset error code
    ResetLastError();
//--- fill a part of the iMABuffer array with values from the indicator buffer that has 0 index
    if(CopyBuffer(indicator_handle, buffer_num, start_pos, count, buffer) < 0)
       {
        //--- if the copying fails, tell the error code
        PrintFormat("Failed to copy data from the iMA indicator, error code %d", GetLastError());
        //--- quit with zero result - it means that the indicator is considered as not calculated
        return(false);
       }
//--- everything is fine
    return(true);
   }
//+------------------------------------------------------------------+
