//+------------------------------------------------------------------+
//|                                                          Tangram |
//|                        Copyright 2020, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#include "../Includes/MovingAverages.mqh"
#include "../HelpFunctions/Input.mqh"

enum ENUM_ADX_USE_MODE
   {
    ADX_USE_MODE_ABOVE_BELOW,        // DI+ Above/Below of DI-
    ADX_USE_MODE_CROSSING            // DI+ Crossing with DI-
   };
enum ENUM_ADX_TENDENCY_FILTER
   {
    ADX_TENDENCY_FILTER_NONE,           // None
    ADX_TENDENCY_FILTER_GETTING_STRONG, // Getting Strong ( high value than previous )
    ADX_TENDENCY_FILTER_GETTING_WEAK    // Getting Weak ( lower value than previous )
   };

input group "4. ADX - DI+/DI-"
sinput bool ADX_Enable = false;                                                         // Enable ADX
input bool ADX_Reverse = false;                                                         // Reverse
input ENUM_INDICATOR_OPERATION_MODE ADX_Operation_Mode = INDICATOR_OPERATION_MODE_BOTH; // Operation Mode
input ENUM_ADX_USE_MODE ADX_Use_Mode = ADX_USE_MODE_ABOVE_BELOW;                        // Use Mode
input int ADX_Period = 14;                                                              // Period
input int ADX_Suavisation = 14;                                                         // ADX Suavisation
input int ADX_Minimum_Level = 0;                                                        // Filter(in): Minimum Level
input int ADX_Maximum_Level = 100;                                                      // Filter(in): Maximum Level
input ENUM_ADX_TENDENCY_FILTER ADX_Tendency_Filter = ADX_TENDENCY_FILTER_NONE;          // Filter(in): Following Tendency

int ADX_Handler;
double ADX_Plus_DI_Buffer[];
double ADX_Minus_DI_Buffer[];
double ADX_Buffer[];

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int zADXInit(ENUM_TIMEFRAMES timeframe)
   {
    if(ADX_Enable)
       {
        if(ADX_Minimum_Level > ADX_Maximum_Level)
           {
            Print("ADX Minimun Lever can't be higher than Maximun");
            return INIT_PARAMETERS_INCORRECT;
           }

        if(ADX_Minimum_Level > 100
           || ADX_Maximum_Level > 100)
           {
            Print("ADX Minimun or Maximun levels can't be higher than 100");
            return INIT_PARAMETERS_INCORRECT;
           }

        ArraySetAsSeries(ADX_Plus_DI_Buffer, true);
        ArraySetAsSeries(ADX_Minus_DI_Buffer, true);
        ArraySetAsSeries(ADX_Buffer, true);

        //--- create handle of the indicator
        ADX_Handler = iADX(_Symbol, timeframe, ADX_Period);

        //--- if the handle is not created
        if(ADX_Handler == INVALID_HANDLE)
           {
            //--- tell about the failure and output the error code
            PrintFormat("Failed to create handle of the iADX indicator for the symbol %s/%s, error code %d",
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
void zADXOnTesterInit()
   {
    zSetInputRangeStop("ADX_Minimum_Level", 50);
    zSetInputRangeStop("ADX_Maximum_Level", 100);

    if(!ADX_Enable)
       {
        zDisableInput("ADX_Reverse");
        zDisableInput("ADX_Operation_Mode");
        zDisableInput("ADX_Use_Mode");
        zDisableInput("ADX_Period");
        zDisableInput("ADX_Suavisation");
        zDisableInput("ADX_Minimum_Level");
        zDisableInput("ADX_Maximum_Level");
        zDisableInput("ADX_Tendency_Filter");

       }
    else if(ADX_Operation_Mode == INDICATOR_OPERATION_MODE_OUT)
       {
        zDisableInput("ADX_Minimum_Level");
        zDisableInput("ADX_Maximum_Level");
        zDisableInput("ADX_Tendency_Filter");
       }
   }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void zADXDeinit()
   {
    if(ADX_Handler != INVALID_HANDLE)
        IndicatorRelease(ADX_Handler);

    ArrayFree(ADX_Plus_DI_Buffer);
    ArrayFree(ADX_Minus_DI_Buffer);
   }

//+------------------------------------------------------------------+
//| Stochastic Full                                                  |
//+------------------------------------------------------------------+
ENUM_INDICATOR_SIGNAL zADX()
   {
    if(!ADX_Enable)
        return INDICATOR_SIGNAL_NEUTRAL_ALLOW;

    ENUM_INDICATOR_SIGNAL indicator_signal = INDICATOR_SIGNAL_NEUTRAL_BLOCK;
    int size = ADX_Suavisation * 2;
    size = size > 3 ? size : 3;

    if(!zFillArraysFromBuffers(ADX_Plus_DI_Buffer, ADX_Minus_DI_Buffer, ADX_Handler, 3)
       || !zFillArraysFromBuffers(ADX_Buffer, ADX_Handler, size))
        return indicator_signal;

    double smoothed_adx_budder[];
// ArraySetAsSeries(smoothed_adx_budder, true);
    ArrayResize(smoothed_adx_budder, size);
    ArrayInitialize(smoothed_adx_budder, 0);

    SmoothedMAOnBuffer(ADX_Suavisation * 2, 0, 0, ADX_Suavisation, ADX_Buffer, smoothed_adx_budder);
    ArrayCopy(ADX_Buffer, smoothed_adx_budder);
    ArrayFree(smoothed_adx_budder);

    if(ADX_Use_Mode == ADX_USE_MODE_ABOVE_BELOW)
       {
        if(ADX_Plus_DI_Buffer[1] < ADX_Minus_DI_Buffer[1])
            indicator_signal = INDICATOR_SIGNAL_SELL;
        else
            if(ADX_Plus_DI_Buffer[1] > ADX_Minus_DI_Buffer[1])
                indicator_signal = INDICATOR_SIGNAL_BUY;
       }
    else // if(ADX_Use_Mode == ADX_USE_MODE_CROSSING)
       {
        if(ADX_Plus_DI_Buffer[2] < ADX_Minus_DI_Buffer[2] && ADX_Plus_DI_Buffer[1] > ADX_Minus_DI_Buffer[1])
            indicator_signal = INDICATOR_SIGNAL_SELL;
        else
            if(ADX_Plus_DI_Buffer[2] > ADX_Minus_DI_Buffer[2] && ADX_Plus_DI_Buffer[1] < ADX_Minus_DI_Buffer[1])
                indicator_signal = INDICATOR_SIGNAL_BUY;
       }

    if(ADX_Reverse)
        indicator_signal = indicator_signal == INDICATOR_SIGNAL_SELL ? INDICATOR_SIGNAL_BUY
                           : indicator_signal == INDICATOR_SIGNAL_BUY ? INDICATOR_SIGNAL_SELL
                           : indicator_signal;

    return indicator_signal;
   }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
ENUM_INDICATOR_SIGNAL zADXFilter()
   {
    if(!ADX_Enable)
        return INDICATOR_FILTER_BLOCK;

    ENUM_INDICATOR_SIGNAL indicator_signal = INDICATOR_FILTER_ALLOW;

    if(ADX_Minimum_Level > 0 && ADX_Minimum_Level < 100
       && ADX_Buffer[1] < ADX_Minimum_Level)
        indicator_signal = INDICATOR_FILTER_BLOCK;

    if(ADX_Maximum_Level > 0 && ADX_Maximum_Level < 100
       && ADX_Buffer[1] > ADX_Maximum_Level)
        indicator_signal = INDICATOR_FILTER_BLOCK;

    if(ADX_Tendency_Filter == ADX_TENDENCY_FILTER_GETTING_STRONG
       && ADX_Buffer[1] < ADX_Buffer[2])
        indicator_signal = INDICATOR_FILTER_BLOCK;

    if(ADX_Tendency_Filter == ADX_TENDENCY_FILTER_GETTING_WEAK
       && ADX_Buffer[1] > ADX_Buffer[2])
        indicator_signal = INDICATOR_FILTER_BLOCK;

    return indicator_signal;
   }



//+------------------------------------------------------------------+
//| Filling indicator buffers from the iADX indicator                |
//+------------------------------------------------------------------+
bool zFillArraysFromBuffers(double &DIplus_values[],   // indicator buffer for DI+
                            double &DIminus_values[],  // indicator buffer for DI-
                            int ind_handle,            // handle of the iADX indicator
                            int amount                // number of copied values
                           )
   {
//--- reset error code
    ResetLastError();

//--- fill a part of the DI_plusBuffer array with values from the indicator buffer that has index 1
    if(CopyBuffer(ind_handle, PLUSDI_LINE, 0, amount, DIplus_values) < 0)
       {
        //--- if the copying fails, tell the error code
        PrintFormat("Failed to copy data from the iADX indicator, error code %d", GetLastError());
        //--- quit with zero result - it means that the indicator is considered as not calculated
        return(false);
       }

//--- fill a part of the DI_minusBuffer array with values from the indicator buffer that has index 2
    if(CopyBuffer(ind_handle, MINUSDI_LINE, 0, amount, DIminus_values) < 0)
       {
        //--- if the copying fails, tell the error code
        PrintFormat("Failed to copy data from the iADX indicator, error code %d", GetLastError());
        //--- quit with zero result - it means that the indicator is considered as not calculated
        return(false);
       }
//--- everything is fine
    return(true);
   }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool zFillArraysFromBuffers(double &adx_values[],      // indicator buffer of the ADX line
                            int ind_handle,            // handle of the iADX indicator
                            int amount                // number of copied values
                           )
   {
//--- reset error code
    ResetLastError();
//--- fill a part of the iADXBuffer array with values from the indicator buffer that has 0 index
    if(CopyBuffer(ind_handle, MAIN_LINE, 0, amount, adx_values) < 0)
       {
        //--- if the copying fails, tell the error code
        PrintFormat("Failed to copy data from the iADX indicator, error code %d", GetLastError());
        //--- quit with zero result - it means that the indicator is considered as not calculated
        return(false);
       }

//--- everything is fine
    return(true);
   }
//+------------------------------------------------------------------+
