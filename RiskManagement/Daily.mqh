
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
input ENUM_STOP_AFTER_X_DEALS RISK_Stop_After_X_Deals_Mode = STOP_AFTER_X_DEALS_NONE; // Stop after X Trades If Daily Balance
input int RISK_Stop_After_X_Deals = NULL;                                             // Stop after X Deals

//+------------------------------------------------------------------+
//|  Time windows                                                    |
//+------------------------------------------------------------------+
input group "Time"
input ENUM_TIME_INTERVAL TIME_Daily_Start  = TIME_INTERVAL_0900; // Allow to Open Position
input ENUM_TIME_INTERVAL TIME_Daily_Stop   = TIME_INTERVAL_1640; // Stop Opening Position
input ENUM_TIME_INTERVAL TIME_Daily_Finish = TIME_INTERVAL_1745; // Close All Positions

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

    return true;
   }

//+------------------------------------------------------------------+
