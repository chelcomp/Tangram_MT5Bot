//+------------------------------------------------------------------+
//|                                                          Tangram |
//|                        Copyright 2020, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+

enum ENUM_STOC_USE_MODE
   {
    STOC_USE_MODE_ABOVE_BELOW, // %K Line Above/Below %D Line
    STOC_USE_MODE_CROSSING     // %K Line Crossing with %D line
   };

input group "5. Stochastic"
input bool STOC_Enable = false;                                                          // Enable STOC
input bool STOC_Reverse = false;                                                          // Reverse
input ENUM_INDICATOR_OPERATION_MODE STOC_Operation_Mode = INDICATOR_OPERATION_MODE_BOTH; // Operation Mode
input ENUM_STOC_USE_MODE STOC_Use_Mode = STOC_USE_MODE_ABOVE_BELOW;                      // Use Mode
input int  STOC_K_Period = 5;                                                            // Period
input int  STOC_Period_Smothled = 3;                                                      // %K Suavisation Period
input int  STOC_D_Period = 3;                                                            // %D Suavisation Period
input bool STOC_Filter = true;                                                           // Enable Filter
input int  STOC_Level_Oversold = 20;                                                     // Level Oversold (Lower)
input int  STOC_Level_Overbought = 80;                                                   // Level Overbought(Higher)
int STOC_Handler;
double STOC_K_Buffer[];
double STOC_D_Buffer[];


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int zSTOCInit(ENUM_TIMEFRAMES timeframe)
   {
    if(STOC_Enable)
       {
        ArraySetAsSeries(STOC_K_Buffer, true);
        ArraySetAsSeries(STOC_D_Buffer, true);

        //--- create handle of the indicator
        STOC_Handler = iStochastic(_Symbol, timeframe, STOC_K_Period, STOC_D_Period, STOC_Period_Smothled, MODE_SMA, STO_LOWHIGH);

        //--- if the handle is not created
        if(STOC_Handler == INVALID_HANDLE)
           {
            //--- tell about the failure and output the error code
            PrintFormat("Failed to create handle of the ISTOC indicator for the symbol %s/%s, error code %d",
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
void zRSIDeinit()
   {
    if(STOC_Handler != INVALID_HANDLE)
        IndicatorRelease(STOC_Handler);

    ArrayFree(STOC_K_Buffer);
    ArrayFree(STOC_D_Buffer);
   }

//+------------------------------------------------------------------+
//| Stochastic Full                                                  |
//+------------------------------------------------------------------+
ENUM_INDICATOR_SIGNAL zSTOC()
   {
    if(!STOC_Enable)
        return INDICATOR_SIGNAL_NEUTRAL_ALLOW;

    ENUM_INDICATOR_SIGNAL indicator_signal = INDICATOR_SIGNAL_NEUTRAL_BLOCK;

    if(!FillArraysFromBuffers(STOC_D_Buffer, STOC_K_Buffer, STOC_Handler, 3))
        return indicator_signal;

    if(STOC_Use_Mode == STOC_USE_MODE_ABOVE_BELOW)
       {
        if(STOC_K_Buffer[1] < STOC_D_Buffer[1])
            indicator_signal = INDICATOR_SIGNAL_SELL;
        else
            if(STOC_K_Buffer[1] > STOC_D_Buffer[1])
                indicator_signal = INDICATOR_SIGNAL_BUY;
       }
    else // if(STOC_Use_Mode == STOC_USE_MODE_CROSSING)
       {
        if(STOC_K_Buffer[1] < STOC_D_Buffer[1] && STOC_K_Buffer[2] >= STOC_D_Buffer[2])
            indicator_signal = INDICATOR_SIGNAL_SELL;
        else
            if(STOC_K_Buffer[1] > STOC_D_Buffer[1] && STOC_K_Buffer[2] <= STOC_D_Buffer[2])
                indicator_signal = INDICATOR_SIGNAL_BUY;
       }

//STOC_Level_Overbought = 80; // Level Overbought(Higher)
//STOC_Level_Oversold   = 20; // Level Oversold  (Lower)


    if(STOC_Filter)
       {
        if(indicator_signal == INDICATOR_SIGNAL_SELL // lower
           || indicator_signal == INDICATOR_SIGNAL_BUY) // Higher
            if(STOC_K_Buffer[1] < STOC_Level_Overbought
               && STOC_K_Buffer[1] > STOC_Level_Oversold)
                indicator_signal = INDICATOR_SIGNAL_NEUTRAL_BLOCK;

            else
                if(indicator_signal == INDICATOR_SIGNAL_SELL
                   && STOC_K_Buffer[1] < STOC_Level_Overbought)
                    indicator_signal = INDICATOR_SIGNAL_NEUTRAL_BLOCK;

                else
                    if(indicator_signal == INDICATOR_SIGNAL_BUY
                       && STOC_K_Buffer[1] > STOC_Level_Oversold)
                        indicator_signal = INDICATOR_SIGNAL_NEUTRAL_BLOCK;
       }

    if(STOC_Reverse)
        indicator_signal = indicator_signal == INDICATOR_SIGNAL_SELL ? INDICATOR_SIGNAL_BUY
                           : indicator_signal == INDICATOR_SIGNAL_BUY ? INDICATOR_SIGNAL_SELL
                           : indicator_signal;

    return indicator_signal;
   }

//+------------------------------------------------------------------+
//| Filling indicator buffers from the iStochastic indicator         |
//+------------------------------------------------------------------+
bool FillArraysFromBuffers(double &D_Buffer[],  // indicator buffer of the signal line
                           double &K_Buffer[],  // indicator buffer of Stochastic Oscillator values
                           int ind_handle,      // handle of the iStochastic indicator
                           int amount           // number of copied values
                          )
   {
//--- reset error code
    ResetLastError();
//--- fill a part of the StochasticBuffer array with values from the indicator buffer that has 0 index
    if(CopyBuffer(ind_handle, SIGNAL_LINE, 0, amount, D_Buffer) < 0)
       {
        //--- if the copying fails, tell the error code
        PrintFormat("Failed to copy data from the iStochastic indicator, error code %d", GetLastError());
        //--- quit with zero result - it means that the indicator is considered as not calculated
        return(false);
       }
//--- fill a part of the SignalBuffer array with values from the indicator buffer that has index 1
    if(CopyBuffer(ind_handle, MAIN_LINE, 0, amount, K_Buffer) < 0)
       {
        //--- if the copying fails, tell the error code
        PrintFormat("Failed to copy data from the iStochastic indicator, error code %d", GetLastError());
        //--- quit with zero result - it means that the indicator is considered as not calculated
        return(false);
       }
//--- everything is fine
    return(true);
   }
//+------------------------------------------------------------------+
