//+------------------------------------------------------------------+
//|                                                          Tangram |
//|                        Copyright 2020, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#include "../HelpFunctions/Input.mqh"

enum ENUM_RSI_USE_MODE
   {
    RSI_USE_MODE_ABOVE_BELOW, // RSI Above/Below Levels
    RSI_USE_MODE_CROSSING     // RSI Crossing Levels
   };

input group "7. RSI"
sinput bool RSI_Enable = false;                                                          // Enable RSI
input bool RSI_Reverse = false;                                                          // Reverse
input ENUM_INDICATOR_OPERATION_MODE RSI_Operation_Mode = INDICATOR_OPERATION_MODE_BOTH; // Operation Mode
input ENUM_RSI_USE_MODE RSI_Use_Mode = RSI_USE_MODE_ABOVE_BELOW;                        // Use Mode
input ENUM_APPLIED_PRICE RSI_Applied_Price = PRICE_CLOSE;                               // Applied Price
input int RSI_Periods = 14;                                                             // Periods
input int RSI_Level_Oversold = 20;                                                      // Level Oversold (Lower)
input int RSI_Level_Overbought = 80;                                                    // Level Overbought(Higher)

int RSI_Handler;
int HA_RSI_Handler;
double RSI_Buffer[];

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int zRSIInit(ENUM_TIMEFRAMES timeframe, bool use_heikin_ashi)
   {
    if(RSI_Enable)
       {
        if(RSI_Level_Oversold >= RSI_Level_Overbought)
           {
            Print("RSI Oversold level can't be higher than Overbought");
            return INIT_PARAMETERS_INCORRECT;
           }
        if(RSI_Level_Oversold > 100
           || RSI_Level_Overbought > 100)
           {
            Print("RSI Oversold or Overbought level can't be higher than 100");
            return INIT_PARAMETERS_INCORRECT;
           }

        ArraySetAsSeries(RSI_Buffer, true);

        //--- create handle of the indicator
        if(!use_heikin_ashi)
           {
            RSI_Handler = iRSI(_Symbol, timeframe, RSI_Periods, RSI_Applied_Price);
           }
        else
           {
            HA_RSI_Handler = iCustom(_Symbol, timeframe, "CustomHeikenAshi", RSI_Applied_Price);
            RSI_Handler = iRSI(_Symbol, timeframe, RSI_Periods, HA_RSI_Handler);
           }
        //--- if the handle is not created
        if(RSI_Handler == INVALID_HANDLE)
           {
            //--- tell about the failure and output the error code
            PrintFormat("Failed to create handle of the IRSI indicator for the symbol %s/%s, error code %d",
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
void zRSIOnTesterInit()
   {
    zSetInputRangeStop("RSI_Level_Oversold", 100);
    zSetInputRangeStop("RSI_Level_Overbought", 100);

    if(!RSI_Enable)
       {
        zDisableInput("RSI_Reverse");
        zDisableInput("RSI_Operation_Mode");
        zDisableInput("RSI_Use_Mode");
        zDisableInput("RSI_Applied_Price");
        zDisableInput("RSI_Periods");
        zDisableInput("RSI_Level_Oversold");
        zDisableInput("RSI_Level_Overbought");
       }
   }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void zSTOCDeinit()
   {
    if(RSI_Handler != INVALID_HANDLE)
        IndicatorRelease(RSI_Handler);

    if(HA_RSI_Handler != INVALID_HANDLE)
        IndicatorRelease(HA_RSI_Handler);

    ArrayFree(RSI_Buffer);
   }

//+------------------------------------------------------------------+
//| IFR / RSI Indicator                                              |
//+------------------------------------------------------------------+
ENUM_INDICATOR_SIGNAL zRSI()
   {
    if(!RSI_Enable)
        return INDICATOR_SIGNAL_NEUTRAL_ALLOW;
    ENUM_INDICATOR_SIGNAL indicator_signal = INDICATOR_SIGNAL_NEUTRAL_BLOCK;

    if(!FillArrayFromBuffer(RSI_Handler, 0, 0, 3, RSI_Buffer))
        return indicator_signal;

//RSI_Level_Overbought = 80; // Level Overbought(Higher)
//RSI_Level_Oversold = 20;   // Level Oversold (Lower)

    if(RSI_Use_Mode == RSI_USE_MODE_ABOVE_BELOW)
       {
        if(RSI_Buffer[1] > RSI_Level_Overbought)
            indicator_signal = INDICATOR_SIGNAL_SELL;
        else
            if(RSI_Buffer[1] < RSI_Level_Oversold)
                indicator_signal = INDICATOR_SIGNAL_BUY;
       }
    else // if(RSI_Use_Mode == RSI_USE_MODE_CROSSING)
       {
        if(RSI_Buffer[2] > RSI_Level_Overbought && RSI_Buffer[1] < RSI_Level_Overbought)
            indicator_signal = INDICATOR_SIGNAL_SELL;
        else
            if(RSI_Buffer[2] < RSI_Level_Oversold && RSI_Buffer[1] > RSI_Level_Oversold)
                indicator_signal = INDICATOR_SIGNAL_BUY;
       }

    if(RSI_Reverse)
        indicator_signal = indicator_signal == INDICATOR_SIGNAL_SELL ? INDICATOR_SIGNAL_BUY
                           : indicator_signal == INDICATOR_SIGNAL_BUY ? INDICATOR_SIGNAL_SELL
                           : indicator_signal;

    return indicator_signal;
   }
//+------------------------------------------------------------------+
