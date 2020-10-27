//+------------------------------------------------------------------+
//|                                                          Tangram |
//|                        Copyright 2020, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+

#include "../HelpFunctions/Array.mqh"

enum ENUM_ATR_USE_MODE
   {
    ATR_USE_MODE_ABOVE_BELOW,        // Stop ATR Direction
    ATR_USE_MODE_DIRECTION_CHANGE    // Stop ATR Direction Change
   };

enum ENUM_ATR_AVERAGE_TYPE
   {
    ATR_AVERAGE_TYPE_SIMPLE     // Simple
//  ATR_AVERAGE_TYPE_EXPONENTIAL // Exponential
   };

input group "9. Stop ATR"
input bool ATR_Enable = false;                                                          // Enable ATR
input bool ATR_Reverse = false;                                                          // Reverse
input ENUM_INDICATOR_OPERATION_MODE ATR_Operation_Mode = INDICATOR_OPERATION_MODE_BOTH; // Operation Mode
input ENUM_ATR_USE_MODE ATR_Use_Mode = ATR_USE_MODE_DIRECTION_CHANGE;                   // Use Mode
sinput ENUM_ATR_AVERAGE_TYPE ATR_AVERAGE_TYPE = ATR_AVERAGE_TYPE_SIMPLE;               // Average Type
input int ATR_Period = 6;                                                               // Period
input double  ATR_Multiplicator = 2;                                                 // Multiplicator

int ATR_Handler;
double ATR_Buffer[];
double ATR_Stop_Buffer[];
ENUM_TIMEFRAMES ATR_Timeframe;

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int zATRInit(ENUM_TIMEFRAMES timeframe)
   {
    if(ATR_Enable)
       {
        ArraySetAsSeries(ATR_Buffer, true);
        ArraySetAsSeries(ATR_Stop_Buffer, true);
        ArrayResize(ATR_Stop_Buffer, ATR_Period);
        ArrayInitialize(ATR_Stop_Buffer, 0);

        ATR_Timeframe = timeframe;;

        //--- create handle of the indicator
        ATR_Handler = iATR(_Symbol, timeframe, ATR_Period);

        //--- if the handle is not created
        if(ATR_Handler == INVALID_HANDLE)
           {
            //--- tell about the failure and output the error code
            PrintFormat("Failed to create handle of the iATR indicator for the symbol %s/%s, error code %d",
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
void zATRDeinit()
   {
    if(ATR_Handler != INVALID_HANDLE)
        IndicatorRelease(ATR_Handler);

    ArrayFree(ATR_Buffer);
    ArrayFree(ATR_Stop_Buffer);
   }

//+------------------------------------------------------------------+
//| ATR                                                              |
//+------------------------------------------------------------------+
ENUM_INDICATOR_SIGNAL zATR()
   {
    if(!ATR_Enable)
        return INDICATOR_SIGNAL_NEUTRAL_ALLOW;

    ENUM_INDICATOR_SIGNAL indicator_signal = INDICATOR_SIGNAL_NEUTRAL_BLOCK;
    MqlRates rates[];
    ArraySetAsSeries(rates, true);

    if(!FillArrayFromBuffer(ATR_Handler, 0, 0, 3, ATR_Buffer)
       || CopyRates(Symbol(), ATR_Timeframe, 0, 3, rates) < 0)
        return indicator_signal;

    zArrayShift(ATR_Stop_Buffer, 1);

    double atr_loss = ATR_Multiplicator * ATR_Buffer[1];
    /*    double atr_stop = rates[1].close > ATR_Stop_Buffer[2] && rates[2].close > ATR_Stop_Buffer[2]
                          ? MathMax(ATR_Stop_Buffer[2], rates[1].close - atr_loss)
                          : rates[1].close < ATR_Stop_Buffer[2] && rates[2].close < ATR_Stop_Buffer[2]
                          ? MathMin(ATR_Stop_Buffer[2], rates[1].close + atr_loss)
                          : rates[2].close > ATR_Stop_Buffer[2]
                          ? rates[2].close - atr_loss
                          : rates[2].close + atr_loss;
    */
    double atr_stop = (rates[1].close > ATR_Stop_Buffer[2] && rates[2].close > ATR_Stop_Buffer[2]
                       ? MathMax(ATR_Stop_Buffer[2], rates[1].close - atr_loss)
                       : (rates[1].close < ATR_Stop_Buffer[2] && rates[2].close < ATR_Stop_Buffer[2]
                          ? MathMin(ATR_Stop_Buffer[2], rates[1].close + atr_loss)
                          : (rates[1].close > ATR_Stop_Buffer[2]
                             ? rates[1].close - atr_loss
                             : rates[1].close + atr_loss)));


    ATR_Stop_Buffer[1] = atr_stop;

    if(ATR_Use_Mode == ATR_USE_MODE_ABOVE_BELOW)
       {
        if(ATR_Stop_Buffer[1] > rates[1].close)
            indicator_signal = INDICATOR_SIGNAL_SELL;
        else
            if(ATR_Stop_Buffer[1] < rates[1].close)
                indicator_signal = INDICATOR_SIGNAL_BUY;
       }
    else // if(ATR_Use_Mode == ATR_USE_MODE_DIRECTION_CHANGE)
       {
        if(ATR_Stop_Buffer[1] > rates[1].close && ATR_Stop_Buffer[2] < rates[2].close)
            indicator_signal = INDICATOR_SIGNAL_SELL;
        else
            if(ATR_Stop_Buffer[1] < rates[1].close && ATR_Stop_Buffer[2] > rates[2].close)
                indicator_signal = INDICATOR_SIGNAL_BUY;
       }

    if(ATR_Reverse)
        indicator_signal = indicator_signal == INDICATOR_SIGNAL_SELL ? INDICATOR_SIGNAL_BUY
                           : indicator_signal == INDICATOR_SIGNAL_BUY ? INDICATOR_SIGNAL_SELL
                           : indicator_signal;
                           
    return indicator_signal;
   }
//+------------------------------------------------------------------+
