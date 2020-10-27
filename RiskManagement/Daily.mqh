//+------------------------------------------------------------------+
//|                                                          Tangram |
//|                        Copyright 2020, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+

enum ENUM_STOP_AFTER_X_DEALS
   {
    STOP_AFTER_X_DEALS_NONE,    // None
    STOP_AFTER_X_DEALS_WINNING, // Positive
    STOP_AFTER_X_DEALS_BOTH,    // Positive and Negative
    STOP_AFTER_X_DEALS_LOSSING  // Negative
   };

//+------------------------------------------------------------------+
//|  Global Stops                                                     |
//+------------------------------------------------------------------+
input group "Global Stops"
input double RISK_Daily_Stop_Loss_Money = NULL;                                       // Stop Loss $
input double RISK_Daily_Stop_Gain_Money = NULL;                                       // Stop Gain $
input ENUM_STOP_AFTER_X_DEALS RISK_Stop_After_X_Deals_Mode = STOP_AFTER_X_DEALS_NONE; // Stop After X Trades If Daily Balance
input int    RISK_Stop_After_X_Deals = NULL;                                          // Stop After X Deals
input double RISK_Daily_Breakeven_Activation = 30.0;                                  // Daily Breakeven Activation $
input double RISK_Daily_Breakeven_Max_Decline = 10.0;                                 // Daily Breakeven Max Decline $

//+------------------------------------------------------------------+
//|  Time windows                                                    |
//+------------------------------------------------------------------+
input group "Time"
input ENUM_TIME_INTERVAL TIME_Daily_Start  = TIME_INTERVAL_0900; // Start time for opening positions

//-- Lock Window 1
input ENUM_TIME_INTERVAL TIME_Lock1_Begin  = TIME_INTERVAL_0000; // Lock Time 1: Begin
input ENUM_TIME_INTERVAL TIME_Lock1_End    = TIME_INTERVAL_0000; // Lock Time 1: End
input bool TIME_Lock1_Allow_Reverse = true;                      // Lock Time 2: Allow Reverse

//-- Lock Window 2
input ENUM_TIME_INTERVAL TIME_Lock2_Begin  = TIME_INTERVAL_0000; // Lock Time 2: Begin
input ENUM_TIME_INTERVAL TIME_Lock2_End    = TIME_INTERVAL_0000; // Lock Time 2: End
input bool TIME_Lock2_Allow_Reverse = true;                      // Lock Time 2: Allow Reverse

input ENUM_TIME_INTERVAL TIME_Daily_Stop   = TIME_INTERVAL_1640; // End time for opening positions
input ENUM_TIME_INTERVAL TIME_Daily_Finish = TIME_INTERVAL_1745; // Final Time Close All Positions



static double RISK_Daily_Breakeven_Whatermark = 0;

//+------------------------------------------------------------------+
//|  Check all daily Risk parameters                                 |
//|  If returns TRUE, should close all positions ans stop to operate |
//+------------------------------------------------------------------+
bool zDailyRiskEvent()
   {
    double daily_net_profit = zCurrentDayNetProfit();
    double variable_net_profit = daily_net_profit + PositionInfo.Profit() - PositionInfo.Commission();

//-- Stop Loss
    if(RISK_Daily_Stop_Loss_Money > 0
       && variable_net_profit < RISK_Daily_Stop_Loss_Money * -1)
        return true;

//-- Stop Gain
    if(RISK_Daily_Stop_Gain_Money > 0
       && variable_net_profit > RISK_Daily_Stop_Gain_Money)
        return true;

// Stop after X Deals
    int today_deals_totals = zTodayClosedDealsTotal();
    if(RISK_Stop_After_X_Deals > 0
       && RISK_Stop_After_X_Deals_Mode != STOP_AFTER_X_DEALS_NONE
       && today_deals_totals >= RISK_Stop_After_X_Deals)
       {
        if(RISK_Stop_After_X_Deals_Mode == STOP_AFTER_X_DEALS_WINNING
           && daily_net_profit > 0)
            return true;

        if(RISK_Stop_After_X_Deals_Mode == STOP_AFTER_X_DEALS_LOSSING
           && daily_net_profit < 0)
            return true;

        if(RISK_Stop_After_X_Deals_Mode == STOP_AFTER_X_DEALS_BOTH)
            return true;
       }

//-- Daily Breakeven
    if(RISK_Daily_Breakeven_Activation > 0 && RISK_Daily_Breakeven_Max_Decline > 0)
       {
        if(RISK_Daily_Breakeven_Whatermark == 0
           && daily_net_profit >= RISK_Daily_Breakeven_Activation)
            RISK_Daily_Breakeven_Whatermark = daily_net_profit;

        if(RISK_Daily_Breakeven_Whatermark > 0)
           {
            RISK_Daily_Breakeven_Whatermark  = MathMax(RISK_Daily_Breakeven_Whatermark, daily_net_profit);
            if(daily_net_profit + RISK_Daily_Breakeven_Max_Decline < RISK_Daily_Breakeven_Whatermark)
                return true;
           }
       }

//-- Finish day time
    if(TIME_Daily_Finish != TIME_INTERVAL_0000
       && DateTime2Time(TimeCurrent()) >= zEnumToDateTime(TIME_Daily_Finish))
        return true;

    return false;
   }

//+------------------------------------------------------------------+
//|  Validate the Start, Stop and Finish time window                 |
//|  Result: True = Allow to open new positions                      |
//+------------------------------------------------------------------+
bool zCanOpenPositionTimeWindow()
   {
    datetime time_current = DateTime2Time(TimeCurrent());

//-- Check Start Time
    if(TIME_Daily_Start != TIME_INTERVAL_0000
       && zEnumToDateTime(TIME_Daily_Start) > time_current)
        return false;

//-- Check Stop Time
    if(TIME_Daily_Stop != TIME_INTERVAL_0000
       && time_current >= zEnumToDateTime(TIME_Daily_Stop))
        return false;

//-- Check Finish Time
    if(TIME_Daily_Finish != TIME_INTERVAL_0000
       && time_current >= zEnumToDateTime(TIME_Daily_Finish))
        return false;

//-- Lock Time 1
    if(TIME_Lock1_Begin != TIME_INTERVAL_0000 && TIME_Lock1_End != TIME_INTERVAL_0000
       && time_current >= zEnumToDateTime(TIME_Lock1_Begin)
       && time_current <= zEnumToDateTime(TIME_Lock1_End)
      )
        return false;

//-- Lock Time 1
    if(TIME_Lock2_Begin != TIME_INTERVAL_0000 && TIME_Lock2_End != TIME_INTERVAL_0000
       && time_current >= zEnumToDateTime(TIME_Lock2_Begin)
       && time_current <= zEnumToDateTime(TIME_Lock2_End)
      )
        return false;

    return true;
   }


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void zREsetDailyRiskFlagVariables()
   {
    RISK_Daily_Breakeven_Whatermark = 0;
   }


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool zCanReversePosition()
   {
    if(!OUT_Use_Reverse)
        return false;

    datetime time_current = DateTime2Time(TimeCurrent());
    bool can_reverse = zCanOpenPositionTimeWindow();

//-- Lock Time 1
    if(TIME_Lock1_Begin != TIME_INTERVAL_0000 && TIME_Lock1_End != TIME_INTERVAL_0000
       && TIME_Lock1_Allow_Reverse
       && time_current >= zEnumToDateTime(TIME_Lock1_Begin)
       && time_current <= zEnumToDateTime(TIME_Lock1_End)
      )
        can_reverse = true;

//-- Lock Time 1
    if(TIME_Lock2_Begin != TIME_INTERVAL_0000 && TIME_Lock2_End != TIME_INTERVAL_0000
       && TIME_Lock2_Allow_Reverse
       && time_current >= zEnumToDateTime(TIME_Lock2_Begin)
       && time_current <= zEnumToDateTime(TIME_Lock2_End)
      )
        can_reverse = true;

    return can_reverse;
   }
//+------------------------------------------------------------------+
