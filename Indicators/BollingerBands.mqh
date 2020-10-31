//+------------------------------------------------------------------+
//|                                                          Tangram |
//|                        Copyright 2020, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+


enum ENUM_BB_USE_MODE
   {
    BB_USE_MODE_ABOVE_BELOW,        // Close Price Above or Below of the Bands
    BB_USE_MODE_CROSSING            // Close Price Crossing With the Bands
   };

input group "8. Bolliger's Band"
input bool BB_Enable = false;                                                          // Enable BB
input bool BB_Reverse = false;                                                          // Reverse
input ENUM_INDICATOR_OPERATION_MODE BB_Operation_Mode = INDICATOR_OPERATION_MODE_BOTH; // Operation Mode
input ENUM_BB_USE_MODE BB_Use_Mode = BB_USE_MODE_ABOVE_BELOW;                          // Use Mode
input ENUM_APPLIED_PRICE BB_Applied_Price = PRICE_CLOSE;                               // Applied Price
input int BB_Period = 14;                                                              // Period
input double BB_Deviation_Multiplier = 1.5;                                            // Deviation Multiplier
int BB_Handler;
int BB_HA_Short_Handler;
double BB_Upper_Buffer[];
double BB_Middle_Buffer[];
double BB_Lower_Buffer[];
ENUM_TIMEFRAMES BB_Timeframe;

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int zBBInit(ENUM_TIMEFRAMES timeframe, bool use_heikin_ashi)
   {
    if(BB_Enable)
       {
        ArraySetAsSeries(BB_Upper_Buffer, true);
        ArraySetAsSeries(BB_Middle_Buffer, true);
        ArraySetAsSeries(BB_Lower_Buffer, true);
        BB_Timeframe = timeframe;

        //--- create handle of the indicator
        if(!use_heikin_ashi)
            BB_Handler = iBands(_Symbol, timeframe, BB_Period, 0, BB_Deviation_Multiplier, BB_Applied_Price);
        else
           {
            BB_HA_Short_Handler = iCustom(_Symbol, timeframe, "CustomHeikenAshi", BB_Applied_Price);
            BB_Handler = iBands(_Symbol, timeframe, BB_Period, 0, BB_Deviation_Multiplier, BB_Applied_Price);
           }

        //--- if the handle is not created
        if(BB_Handler == INVALID_HANDLE)
           {
            //--- tell about the failure and output the error code
            PrintFormat("Failed to create handle of the iBB indicator for the symbol %s/%s, error code %d",
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
void zBBDeinit()
   {
    if(BB_Handler != INVALID_HANDLE)
        IndicatorRelease(BB_Handler);

    if(BB_HA_Short_Handler != INVALID_HANDLE)
        IndicatorRelease(BB_HA_Short_Handler);

    ArrayFree(BB_Upper_Buffer);
    ArrayFree(BB_Middle_Buffer);
    ArrayFree(BB_Lower_Buffer);
   }

//+------------------------------------------------------------------+
//| Stochastic Full                                                  |
//+------------------------------------------------------------------+
ENUM_INDICATOR_SIGNAL zBB()
   {
    if(!BB_Enable)
        return INDICATOR_SIGNAL_NEUTRAL_ALLOW;

    ENUM_INDICATOR_SIGNAL indicator_signal = INDICATOR_SIGNAL_NEUTRAL_BLOCK;
    MqlRates rates[];
    ArraySetAsSeries(rates, true);

    if(!zBBFillArraysFromBuffers(BB_Middle_Buffer, BB_Upper_Buffer, BB_Lower_Buffer, BB_Handler, 3)
       || CopyRates(Symbol(), BB_Timeframe, 0, 3, rates) < 0)
        return indicator_signal;

    if(BB_Use_Mode == BB_USE_MODE_ABOVE_BELOW)
       {
        if(BB_Upper_Buffer[1] < rates[1].close)
            indicator_signal = INDICATOR_SIGNAL_SELL;
        else
            if(BB_Lower_Buffer[1] > rates[1].close)
                indicator_signal = INDICATOR_SIGNAL_BUY;
       }
    else // if(BB_Use_Mode == BB_USE_MODE_CROSSING)
       {
        if(BB_Upper_Buffer[2] < rates[2].close && BB_Upper_Buffer[1] > rates[1].close)
            indicator_signal = INDICATOR_SIGNAL_SELL;
        else
            if(BB_Lower_Buffer[2] > rates[2].close && BB_Lower_Buffer[1] < rates[1].close)
                indicator_signal = INDICATOR_SIGNAL_BUY;
       }

    if(BB_Reverse)
        indicator_signal = indicator_signal == INDICATOR_SIGNAL_SELL ? INDICATOR_SIGNAL_BUY
                           : indicator_signal == INDICATOR_SIGNAL_BUY ? INDICATOR_SIGNAL_SELL
                           : indicator_signal;

    return indicator_signal;
   }


//+------------------------------------------------------------------+
//| Filling indicator buffers from the iBands indicator              |
//+------------------------------------------------------------------+
bool zBBFillArraysFromBuffers(double &base_values[],     // indicator buffer of the middle line of Bollinger Bands
                              double &upper_values[],    // indicator buffer of the upper border
                              double &lower_values[],    // indicator buffer of the lower border
                              int ind_handle,            // handle of the iBands indicator
                              int amount                 // number of copied values
                             )
   {
//--- reset error code
    ResetLastError();
//--- fill a part of the MiddleBuffer array with values from the indicator buffer that has 0 index
    if(CopyBuffer(ind_handle, BASE_LINE, 0, amount, base_values) < 0)
       {
        //--- if the copying fails, tell the error code
        PrintFormat("Failed to copy data from the iBands indicator, error code %d", GetLastError());
        //--- quit with zero result - it means that the indicator is considered as not calculated
        return(false);
       }

//--- fill a part of the UpperBuffer array with values from the indicator buffer that has index 1
    if(CopyBuffer(ind_handle, UPPER_BAND, 0, amount, upper_values) < 0)
       {
        //--- if the copying fails, tell the error code
        PrintFormat("Failed to copy data from the iBands indicator, error code %d", GetLastError());
        //--- quit with zero result - it means that the indicator is considered as not calculated
        return(false);
       }

//--- fill a part of the LowerBuffer array with values from the indicator buffer that has index 2
    if(CopyBuffer(ind_handle, LOWER_BAND, 0, amount, lower_values) < 0)
       {
        //--- if the copying fails, tell the error code
        PrintFormat("Failed to copy data from the iBands indicator, error code %d", GetLastError());
        //--- quit with zero result - it means that the indicator is considered as not calculated
        return(false);
       }
//--- everything is fine
    return(true);
   }
//+------------------------------------------------------------------+
