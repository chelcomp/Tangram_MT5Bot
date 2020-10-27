//+------------------------------------------------------------------+
//|                                                          Tangram |
//|                        Copyright 2020, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+

enum ENUM_SAR_USE_MODE
   {
    SAR_USE_MODE_ABOVE_BELOW,        // SAR Points Direction ( Above / Below )
    SAR_USE_MODE_DIRECTION_CHANGE    // SAR Points Direction Changes
   };

input group "10. SAR Parabolic"
input bool SAR_Enable = false;                                                          // Enable SAR
input bool SAR_Reverse = false;                                                          // Reverse
input ENUM_INDICATOR_OPERATION_MODE SAR_Operation_Mode = INDICATOR_OPERATION_MODE_BOTH; // Operation Mode
input ENUM_SAR_USE_MODE SAR_Use_Mode = SAR_USE_MODE_DIRECTION_CHANGE;                   // Use Mode
//sinput double  SAR_Acceleration_Step = 0;                                             // Acceleration Factor
input double  SAR_Increment_Step = 0.02;                                                //  Acceleration Factor and/or Increment Step
input double  SAR_Limit_Maximum = 0.20;                                                 // Maximun Value
int SAR_Handler;
double SAR_Buffer[];
ENUM_TIMEFRAMES SAR_Timeframe;


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int zSARInit(ENUM_TIMEFRAMES timeframe)
   {
    if(SAR_Enable)
       {
        ArraySetAsSeries(SAR_Buffer, true);
        SAR_Timeframe = timeframe;;

        //--- create handle of the indicator
        SAR_Handler = iSAR(_Symbol, timeframe, SAR_Increment_Step, SAR_Limit_Maximum);

        //--- if the handle is not created
        if(SAR_Handler == INVALID_HANDLE)
           {
            //--- tell about the failure and output the error code
            PrintFormat("Failed to create handle of the iSAR indicator for the symbol %s/%s, error code %d",
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
void zSARDeinit()
   {
    if(SAR_Handler != INVALID_HANDLE)
        IndicatorRelease(SAR_Handler);

    ArrayFree(SAR_Buffer);
   }

//+------------------------------------------------------------------+
//| Stochastic Full                                                  |
//+------------------------------------------------------------------+
ENUM_INDICATOR_SIGNAL zSAR()
   {
    if(!SAR_Enable)
        return INDICATOR_SIGNAL_NEUTRAL_ALLOW;

    ENUM_INDICATOR_SIGNAL indicator_signal = INDICATOR_SIGNAL_NEUTRAL_BLOCK;
    MqlRates rates[];
    ArraySetAsSeries(rates, true);

    if(!FillArrayFromBuffer(SAR_Handler, 0, 0, 3, SAR_Buffer)
       || CopyRates(Symbol(), SAR_Timeframe, 0, 3, rates) < 0)
        return indicator_signal;

    if(SAR_Use_Mode == SAR_USE_MODE_ABOVE_BELOW)
       {
        if(SAR_Buffer[1] > rates[1].close)
            indicator_signal = INDICATOR_SIGNAL_SELL;
        else
            if(SAR_Buffer[1] < rates[1].close)
                indicator_signal = INDICATOR_SIGNAL_BUY;
       }
    else // if(SAR_Use_Mode == SAR_USE_MODE_DIRECTION_CHANGE)
       {
        if(SAR_Buffer[1] > rates[1].close && SAR_Buffer[2] < rates[2].close)
            indicator_signal = INDICATOR_SIGNAL_SELL;
        else
            if(SAR_Buffer[1] < rates[1].close && SAR_Buffer[2] > rates[2].close)
                indicator_signal = INDICATOR_SIGNAL_BUY;
       }

    if(SAR_Reverse)
        indicator_signal = indicator_signal == INDICATOR_SIGNAL_SELL ? INDICATOR_SIGNAL_BUY
                           : indicator_signal == INDICATOR_SIGNAL_BUY ? INDICATOR_SIGNAL_SELL
                           : indicator_signal;

    return indicator_signal;
   }
//+------------------------------------------------------------------+
