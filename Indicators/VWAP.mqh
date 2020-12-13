//+------------------------------------------------------------------+
//|                                                          Tangram |
//|                        Copyright 2020, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#include "../HelpFunctions/Input.mqh"

enum ENUM_VWAP_USE_MODE
   {
    VWAP_USE_MODE_SELL_ABOVE_BUY_BELOW, // Sell Above of VWAP / Buy Below VWAP
    VWAP_USE_MODE_BUY_ABOVE_SELL_BELOW, // Buy Above of VWAP / Sell Below VWAP
    VWAP_USE_MODE_RUPTURE               // VWAP Rupture
   };

input group "6. VWAP Activator"
sinput bool VWAP_Enable = false;                                                           // Enable VWAP
input bool VWAP_Reverse = false;                                                          // Reverse
input ENUM_INDICATOR_OPERATION_MODE VWAP_Operation_Mode = INDICATOR_OPERATION_MODE_BOTH;  // Operation Mode
input ENUM_VWAP_USE_MODE VWAP_Use_Mode = VWAP_USE_MODE_SELL_ABOVE_BUY_BELOW;              // Use Mode

ENUM_TIMEFRAMES VWAP_Timeframe;

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int zVWAPInit(ENUM_TIMEFRAMES timeframe)
   {
    if(VWAP_Enable)
       {
        VWAP_Timeframe = timeframe;
       }
//--- normal initialization of the indicator
    return(INIT_SUCCEEDED);
   }

void zVWAPOnTesterInit()
   {
    if(!VWAP_Enable)
       {
        zDisableInput("VWAP_Reverse");
        zDisableInput("VWAP_Operation_Mode");
        zDisableInput("VWAP_Use_Mode");
       }
   }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void zVWAPDeinit()
   {
   }


//+------------------------------------------------------------------+
//| VWAP                                                             |
//+------------------------------------------------------------------+
ENUM_INDICATOR_SIGNAL zVWAP()
   {
    if(!VWAP_Enable)
        return INDICATOR_SIGNAL_NEUTRAL_ALLOW;
    ENUM_INDICATOR_SIGNAL indicator_signal = INDICATOR_SIGNAL_NEUTRAL_BLOCK;

    MqlRates rates[];
    ArraySetAsSeries(rates, true);

    static datetime zVWAP_last_processed_date = 0;
    static double zVWAP_price_volume = 0;
    static long zVWAP_volume = 0;

    if(zVWAP_last_processed_date == 0
       || !IsTheSameDay(TimeCurrent(), zVWAP_last_processed_date))
       {
        MqlDateTime current_day_begin;
        TimeCurrent(current_day_begin);
        current_day_begin.hour = 0;
        current_day_begin.min = 0;
        current_day_begin.sec = 0;
        zVWAP_last_processed_date = StructToTime(current_day_begin);
        zVWAP_price_volume = 0;
        zVWAP_volume = 0;
       }

//--- Load buffers and
    if(CopyRates(Symbol(), VWAP_Timeframe, zVWAP_last_processed_date, TimeCurrent(), rates) < 2)
        return indicator_signal;

    zVWAP_last_processed_date = TimeCurrent();

    for(int i = ArraySize(rates) - 1; i > 0; i--)
       {
        zVWAP_price_volume += rates[i].close * rates[i].real_volume;
        zVWAP_volume += rates[i].real_volume;
       }

    if(zVWAP_price_volume == 0 || zVWAP_volume == 0)
        return indicator_signal;

    double vwap = zVWAP_price_volume / zVWAP_volume;


    if(VWAP_Use_Mode == VWAP_USE_MODE_SELL_ABOVE_BUY_BELOW)
       {
        if(rates[1].close > vwap)
            indicator_signal = INDICATOR_SIGNAL_SELL;
        else
            if(rates[1].close < vwap)
                indicator_signal = INDICATOR_SIGNAL_BUY;
       }
    else
        if(VWAP_Use_Mode == VWAP_USE_MODE_BUY_ABOVE_SELL_BELOW)
           {
            if(rates[1].close < vwap)
                indicator_signal = INDICATOR_SIGNAL_SELL;
            else
                if(rates[1].close > vwap)
                    indicator_signal = INDICATOR_SIGNAL_BUY;
           }
        else //Rupture
           {
            CopyRates(Symbol(), VWAP_Timeframe, 0, 3, rates);
            if(VWAP_Use_Mode == VWAP_USE_MODE_RUPTURE)
               {
                if(rates[1].close < vwap && rates[2].close > vwap)
                    indicator_signal = INDICATOR_SIGNAL_SELL;
                else
                    if(rates[1].close > vwap && rates[2].close < vwap)
                        indicator_signal = INDICATOR_SIGNAL_BUY;
               }
           }

    if(VWAP_Reverse)
        indicator_signal = indicator_signal == INDICATOR_SIGNAL_SELL ? INDICATOR_SIGNAL_BUY
                           : indicator_signal == INDICATOR_SIGNAL_BUY ? INDICATOR_SIGNAL_SELL
                           : indicator_signal;

    return indicator_signal;
   }

//+------------------------------------------------------------------+
//| Filling indicator buffers from the VWAP indicator                  |
//+------------------------------------------------------------------+
bool zVWAPFillArrayFromBuffer(int       indicator_handle,     // indicator handle
                              int       buffer_num,           // indicator buffer number
                              int       start_pos,            // start position
                              int       count,                // amount to copy
                              double    &buffer[]              // target array to copy
                             )
   {
//--- reset error code
    ResetLastError();
//--- fill a part of the iVWAPBuffer array with values from the indicator buffer that has 0 index
    if(CopyBuffer(indicator_handle, buffer_num, start_pos, count, buffer) < 0)
       {
        //--- if the copying fails, tell the error code
        PrintFormat("Failed to copy data from the iVWAP indicator, error code %d", GetLastError());
        //--- quit with zero result - it means that the indicator is considered as not calculated
        return(false);
       }
//--- everything is fine
    return(true);
   }
//+------------------------------------------------------------------+
