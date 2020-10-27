//+------------------------------------------------------------------+
//|                                                          Tangram |
//|                        Copyright 2020, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#include "../HelpFunctions/Array.mqh"

enum ENUM_HILO_USE_MODE
   {
    HILO_USE_MODE_ABOVE_BELOW, // HiLo Direction
    HILO_USE_MODE_CROSSING     // HiLo Direction Change
   };

input group "2. HiLo Activator"
input bool HILO_Enable = false;                                                           // Enable HILO
input bool HILO_Reverse = false;                                                           // Reverse
input ENUM_INDICATOR_OPERATION_MODE HILO_Operation_Mode = INDICATOR_OPERATION_MODE_BOTH;  // Operation Mode
input ENUM_HILO_USE_MODE HILO_Use_Mode = HILO_USE_MODE_CROSSING;                          // Use Mode
input int HILO_Periods = 9;                                                               // Periods

int HILO_Hi_Handler;
int HILO_Lo_Handler;
double HILO_Hi_Buffer[];
double HILO_Lo_Buffer[];
int HILO_Buffer[];
ENUM_TIMEFRAMES HILO_Timeframe;

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int zHiLoInit(ENUM_TIMEFRAMES timeframe)
   {
    if(HILO_Enable)
       {
        ArraySetAsSeries(HILO_Hi_Buffer, true);
        ArraySetAsSeries(HILO_Lo_Buffer, true);
        ArraySetAsSeries(HILO_Buffer, true);
        ArrayResize(HILO_Buffer, HILO_Periods);
        ArrayInitialize(HILO_Buffer, 0);

        HILO_Timeframe = timeframe;

        //--- create handle of the indicator
        HILO_Hi_Handler = iMA(_Symbol, timeframe, HILO_Periods, 1, MODE_SMA, PRICE_HIGH);
        HILO_Lo_Handler = iMA(_Symbol, timeframe, HILO_Periods, 1, MODE_SMA, PRICE_LOW);

        //--- if the handle is not created
        if(HILO_Hi_Handler == INVALID_HANDLE
           || HILO_Lo_Handler == INVALID_HANDLE)
           {
            //--- tell about the failure and output the error code
            PrintFormat("Failed to create handle of the iHILO indicator for the symbol %s/%s, error code %d",
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
void zHiLoDeinit()
   {
    if(HILO_Hi_Handler != INVALID_HANDLE)
        IndicatorRelease(HILO_Hi_Handler);

    if(HILO_Lo_Handler != INVALID_HANDLE)
        IndicatorRelease(HILO_Lo_Handler);

    ArrayFree(HILO_Hi_Buffer);
    ArrayFree(HILO_Lo_Buffer);
    ArrayFree(HILO_Buffer);
   }

//+------------------------------------------------------------------+
//| HiLo                                                             |
//+------------------------------------------------------------------+
ENUM_INDICATOR_SIGNAL zHILO()
   {
    if(!HILO_Enable)
        return INDICATOR_SIGNAL_NEUTRAL_ALLOW;
    ENUM_INDICATOR_SIGNAL indicator_signal = INDICATOR_SIGNAL_NEUTRAL_BLOCK;

    MqlRates rates[];
    ArraySetAsSeries(rates, true);

//--- Load buffers and
    if(!zHILOFillArrayFromBuffer(HILO_Hi_Handler, 0, 0, 3, HILO_Hi_Buffer)
       || !zHILOFillArrayFromBuffer(HILO_Lo_Handler, 0, 0, 3, HILO_Lo_Buffer)
       || CopyRates(Symbol(), HILO_Timeframe, 0, 3, rates) < 0)
        return indicator_signal;

    zArrayShift(HILO_Buffer, 1);
    int hilo_direction = rates[1].close < HILO_Lo_Buffer[1] ? 1
                         : rates[1].close > HILO_Hi_Buffer[1] ? -1
                         : HILO_Buffer[2];
    HILO_Buffer[1] = hilo_direction;

    if(HILO_Use_Mode == HILO_USE_MODE_ABOVE_BELOW)
       {
        if(HILO_Buffer[1] > 0)
            indicator_signal = INDICATOR_SIGNAL_SELL;
        else
            if(HILO_Buffer[1] < 0)
                indicator_signal = INDICATOR_SIGNAL_BUY;
       }
    else // if(HILO_Use_Mode == HILO_USE_MODE_CROSSING)
       {
        if(HILO_Buffer[1] > 0 && HILO_Buffer[2] < 0)
            indicator_signal = INDICATOR_SIGNAL_SELL;
        else
            if(HILO_Buffer[1] < 0 && HILO_Buffer[2] > 0)
                indicator_signal = INDICATOR_SIGNAL_BUY;
       }

    if(HILO_Reverse)
        indicator_signal = indicator_signal == INDICATOR_SIGNAL_SELL ? INDICATOR_SIGNAL_BUY
                           : indicator_signal == INDICATOR_SIGNAL_BUY ? INDICATOR_SIGNAL_SELL
                           : indicator_signal;

    return indicator_signal;
   }



//+------------------------------------------------------------------+
//| Filling indicator buffers from the HILO indicator                  |
//+------------------------------------------------------------------+
bool zHILOFillArrayFromBuffer(int       indicator_handle,     // indicator handle
                              int       buffer_num,           // indicator buffer number
                              int       start_pos,            // start position
                              int       count,                // amount to copy
                              double    &buffer[]             // target array to copy
                             )
   {
//--- reset error code
    ResetLastError();
//--- fill a part of the iHILOBuffer array with values from the indicator buffer that has 0 index
    if(CopyBuffer(indicator_handle, buffer_num, start_pos, count, buffer) < 0)
       {
        //--- if the copying fails, tell the error code
        PrintFormat("Failed to copy data from the iHILO indicator, error code %d", GetLastError());
        //--- quit with zero result - it means that the indicator is considered as not calculated
        return(false);
       }
//--- everything is fine
    return(true);
   }
//+------------------------------------------------------------------+
