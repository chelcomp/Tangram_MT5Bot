//+------------------------------------------------------------------+
//|                                                          Tangram |
//|                        Copyright 2020, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|  PROPERTIES                                                      |
//+------------------------------------------------------------------+
#property version "100.001"
#property description "Tangram Bot ( Mimic SmartBot Tangram Bot )"
#property script_show_inputs
//---

//+------------------------------------------------------------------+
//| INCLUDE SECTION                                                  |
//+------------------------------------------------------------------+
#include <Trade/Trade.mqh>
#include <Trade/AccountInfo.mqh>
#include <Trade/PositionInfo.mqh>
#include <Trade/OrderInfo.mqh>
#include <Trade/SymbolInfo.mqh>
#include <Expert/ExpertBase.mqh>
#include <Trade/HistoryOrderInfo.mqh>


//+------------------------------------------------------------------+
//| GLOBAL VARIABLES                                                 |
//+------------------------------------------------------------------+
CTrade Trade;
CPositionInfo PositionInfo;

#include "Inputs/Tangram.mqh"
#include "Indicators/ADX.mqh"
#include "Indicators/BollingerBands.mqh"
#include "Indicators/HiLoActivator.mqh"
#include "Indicators/MACD.mqh"
#include "Indicators/MovingAverage.mqh"
#include "Indicators/RSI.mqh"
#include "Indicators/SARParabolic.mqh"
#include "Indicators/Stochastic.mqh"
#include "Indicators/StopATR.mqh"
#include "Indicators/VWAP.mqh"

#include "DateTime/DateTimeHelper.mqh"
#include "HelpFunctions/Candle.mqh"
#include "HelpFunctions/TraderInfo.mqh"
#include "HelpFunctions/AccountInfo.mqh"
#include "HelpFunctions/SymbolInfo.mqh"

static bool g_is_new_candle, g_daily_risk_triggered;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
   {
    zADXInit(TimeFrame);
    zBBInit(TimeFrame);
    zHiLoInit(TimeFrame);
    zMACDInit(TimeFrame);
    zMAInit(TimeFrame);
    zRSIInit(TimeFrame);
    zSARInit(TimeFrame);
    zSTOCInit(TimeFrame);
    zATRInit(TimeFrame);
    zVWAPInit(TimeFrame);

    return(INIT_SUCCEEDED);
   }

//+------------------------------------------------------------------+
//| Indicator deinitialization function                              |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
   {
    zADXDeinit();
    zBBDeinit();
    zHiLoDeinit();
    zMACDDeinit();
    zMADeinit();
    zRSIDeinit();
    zSARDeinit();
    zSTOCDeinit();
    zATRDeinit();
    zVWAPDeinit();
    Comment("");
   }


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void zResetDailyVariables()
   {
    static datetime zResetDailyVariables_previous_day = 0;
    datetime current_day = iTime(_Symbol, PERIOD_D1, 0);

    if(zResetDailyVariables_previous_day  != current_day)
       {
        g_daily_risk_triggered = false;
        zResetDailyVariables_previous_day = current_day;
        zREsetDailyRiskFlagVariables();
       }
   }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
   {
    PositionInfo.Select(_Symbol);

    g_is_new_candle = zIsNewCandle(TimeFrame);
    bool buy = false, sell = false, close = false;

    zResetDailyVariables();

    if(SETTING_Backtesting_Stop_On_Negative_Equity
       && AccountInfoDouble(ACCOUNT_EQUITY) < 0)
        ExpertRemove();

    if(SETTING_Backtesting_Stop_On_Max_Drowndow_Percent > 0)
       {
        static double Max_Equity = 0;
        Max_Equity  = MathMax(Max_Equity, AccountInfoDouble(ACCOUNT_EQUITY));
        if(Max_Equity > 0)
           {
            double drawndown = (Max_Equity - AccountInfoDouble(ACCOUNT_EQUITY)) * 100 / Max_Equity;
            if(drawndown > SETTING_Backtesting_Stop_On_Max_Drowndow_Percent)
                ExpertRemove();
           }
       }

//-- Check Daily Risk Archievement
    if(!g_daily_risk_triggered)
        g_daily_risk_triggered = zDailyRiskEvent();

    if(g_daily_risk_triggered)
       {
        zCancelAllPendingOrders();
        zCloseAllOpenPositions();
        return;
       }

//-- Normal Close
    close = zTradeCloseAllPositions();

    if(zCanOpenPositionTimeWindow())
       {
        if(!close)
            zIndicatorsSignal(buy, sell, close);

        if(close)
            close = !zReversePosition();
       }

    if(close)
       {
        zCancelAllPendingOrders();
        zCloseAllOpenPositions();
        return;
       }
//-- If not close, then Partial
    bool partial_close = zTradeClosePartialPositions();
    if(partial_close)
       {
        zCancelAllPendingOrders();
        zClosePartialOppenedPositions();
        return;
       }

//-- Create new Order
    if(buy || sell)
        zCreateOrder(buy, sell);
   }


//+------------------------------------------------------------------+
//|  Cancel all Pending Orders                                       |
//+------------------------------------------------------------------+
bool zCancelAllPendingOrders()
   {
    uint orders_total = OrdersTotal();
    for(uint i = 0; i < orders_total; i++)
       {
        ulong ticket = OrderGetTicket(i);
        return Trade.OrderDelete(ticket);
       }
    return true;
   }

//+------------------------------------------------------------------+
//|  Close in Market all Open Position                               |
//+------------------------------------------------------------------+
bool zCloseAllOpenPositions()
   {
    uint positions_total = PositionsTotal();
    for(uint i = 0; i < positions_total; i++)
       {
        ulong ticket = PositionGetTicket(i);
        return Trade.PositionClose(ticket);
       }
    return true;
   }

//+------------------------------------------------------------------+
//|  Partial Close in Market the open positions                      |
//+------------------------------------------------------------------+
bool zClosePartialOppenedPositions()
   {
    if(PositionsTotal() <= 0)
        return true;

//-- Get last deal volume
    HistorySelect(0, TimeCurrent());
    uint history_deals_total = HistoryDealsTotal();
    ulong deal_ticket = 0;
    for(uint i = history_deals_total - 1; i > 0; i--)
       {
        deal_ticket = HistoryDealGetTicket(i);
        ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal_ticket, DEAL_ENTRY);
        if(entry == DEAL_ENTRY_IN || entry == DEAL_ENTRY_INOUT)
            break;
       }
    if(deal_ticket <= 0)
        return false;

    double volume_initial = HistoryDealGetDouble(deal_ticket, DEAL_VOLUME);;
    double volume_current = PositionInfo.Volume();

//-- if volume requested is lowed then the oppen
    if(volume_initial == volume_current)
       {
        double partial_volume = volume_initial * PARTIAL_Gain_Volume_Percentage / 100;
        partial_volume = zNomalizeSymbolVolume(partial_volume);
        partial_volume = MathMin(partial_volume, volume_current);
        if(IsNetting())
           {
            if(PositionInfo.PositionType() == POSITION_TYPE_BUY)
                return Trade.Sell(partial_volume, _Symbol);

            //if(PositionInfo.PositionType() == POSITION_TYPE_SELL)
            return Trade.Buy(partial_volume, _Symbol);
           }
        //else if(IsHedging)
        return Trade.PositionClosePartial(_Symbol, partial_volume);

       }

//-- if volume requested is high then the oppen Close all
//return zCloseAllOpenPositions();
    return false;
   }

//+------------------------------------------------------------------+
//|  Create a Market Order                                           |
//+------------------------------------------------------------------+
bool zCreateOrder(bool buy, bool sell)
   {
    if((!buy && !sell) || (buy && sell))
        return false;

    double volume = ORDER_Volume;
    if(OUT_Martingale)
        volume = zNextMartigaleVolume();

    if(ORDER_Management_Type == ORDER_MANAGEMENT_TYPE_FINANCIAL_VOLUME)
        volume = volume / SymbolInfoDouble(_Symbol, SYMBOL_LAST) / SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

    volume = zNomalizeSymbolVolume(volume);

    Trade.SetDeviationInPoints(ULONG_MAX);
    if(buy)
        return Trade.Buy(volume);
//-- else if(sell)
    return Trade.Sell(volume);

    return true;
   }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double zNextMartigaleVolume()
   {
    static int zNextMartigaleVolume_times = 0;
    if(OUT_Martingale
       && zNextMartigaleVolume_times <= OUT_Martingale_Times)
       {
        int history_deals_total = zTodayDealsTotal();
        ulong ticket = HistoryDealGetTicket(history_deals_total - 1);
        double volume_initial = HistoryDealGetDouble(ticket, DEAL_VOLUME);
        double last_profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
        if(ticket > 0 && last_profit < 0)
           {
            return volume_initial * 2;
            zNextMartigaleVolume_times++;
           }
       }

    return ORDER_Volume;
   }

//+------------------------------------------------------------------+
//|  Add another Order in reverse to the current position            |
//+------------------------------------------------------------------+
bool zReversePosition()
   {
    if(!OUT_Use_Reverse
       || PositionsTotal() <= 0)
        return false;

    double volume = zNomalizeSymbolVolume(PositionInfo.Volume() + ORDER_Volume);

    Trade.SetDeviationInPoints(ULONG_MAX);
    if(PositionInfo.PositionType() == POSITION_TYPE_SELL)
        return Trade.Buy(volume);
//--else if(sell)
    return Trade.Sell(volume);
   }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
ENUM_INDICATOR_SIGNAL zIndicadorSignalNormalizer_IN(ENUM_INDICATOR_SIGNAL indicator_signal, ENUM_INDICATOR_OPERATION_MODE indicator_mode)
   {
    if(indicator_mode == INDICATOR_OPERATION_MODE_IN || indicator_mode == INDICATOR_OPERATION_MODE_BOTH)
       {
        return indicator_signal;
       }

    return INDICATOR_SIGNAL_NEUTRAL_ALLOW;
   }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
ENUM_INDICATOR_SIGNAL zIndicadorSignalNormalizer_OUT(ENUM_INDICATOR_SIGNAL indicator_signal, ENUM_INDICATOR_OPERATION_MODE indicator_mode)
   {
    if(indicator_mode == INDICATOR_OPERATION_MODE_OUT || indicator_mode == INDICATOR_OPERATION_MODE_BOTH)
       {
        return indicator_signal;
       }

    return INDICATOR_SIGNAL_NEUTRAL_ALLOW;
   }


//+------------------------------------------------------------------+
//|  Analize all Technical Indicators and generate Buy, Sell or Close|
//|  Signals based on the current position                           |
//+------------------------------------------------------------------+
bool zIndicatorsSignal(bool & buy, bool & sell, bool & close)
   {
    buy = false;
    sell = false;
    close = false;

    if(!g_is_new_candle)
        return false;

    ENUM_INDICATOR_SIGNAL indicator_signals[];
    ArrayResize(indicator_signals, 10);
    ArrayInitialize(indicator_signals, (int)INDICATOR_SIGNAL_NEUTRAL_ALLOW);

    ENUM_INDICATOR_SIGNAL bb = zBB();
    ENUM_INDICATOR_SIGNAL adx = zADX();
    ENUM_INDICATOR_SIGNAL hilo = zHILO();
    ENUM_INDICATOR_SIGNAL macd = zMACD();
    ENUM_INDICATOR_SIGNAL ma = zMA();
    ENUM_INDICATOR_SIGNAL rsi = zRSI();
    ENUM_INDICATOR_SIGNAL sar = zSAR();
    ENUM_INDICATOR_SIGNAL stoc = zSTOC();
    ENUM_INDICATOR_SIGNAL atr = zATR();
    ENUM_INDICATOR_SIGNAL vwap = zVWAP();

//-- Open Position
    if(PositionsTotal() == 0 && OrdersTotal() == 0)
       {
        indicator_signals[0] = zIndicadorSignalNormalizer_IN(bb, MA_Operation_Mode);
        indicator_signals[1] = zIndicadorSignalNormalizer_IN(adx, ADX_Operation_Mode);
        indicator_signals[2] = zIndicadorSignalNormalizer_IN(hilo, HILO_Operation_Mode);
        indicator_signals[3] = zIndicadorSignalNormalizer_IN(macd, MACD_Operation_Mode);
        indicator_signals[4] = zIndicadorSignalNormalizer_IN(ma, MA_Operation_Mode);
        indicator_signals[5] = zIndicadorSignalNormalizer_IN(rsi, RSI_Operation_Mode);
        indicator_signals[6] = zIndicadorSignalNormalizer_IN(sar, SAR_Operation_Mode);
        indicator_signals[7] = zIndicadorSignalNormalizer_IN(stoc, STOC_Operation_Mode);
        indicator_signals[8] = zIndicadorSignalNormalizer_IN(atr, ATR_Operation_Mode);
        indicator_signals[9] = zIndicadorSignalNormalizer_IN(vwap, VWAP_Operation_Mode);

        for(int i = 0; i < 10; i++)
           {
            if(!sell && indicator_signals[i] == INDICATOR_SIGNAL_SELL)
                sell = true;
            else
                if(!buy && indicator_signals[i] == INDICATOR_SIGNAL_BUY)
                    buy = true;

            if(indicator_signals[i] == INDICATOR_SIGNAL_NEUTRAL_BLOCK
               || (ORDER_Operation_Direction == OPERATION_DIRECTION_BUY && indicator_signals[i] == INDICATOR_SIGNAL_SELL)
               || (ORDER_Operation_Direction == OPERATION_DIRECTION_SELL && indicator_signals[i] == INDICATOR_SIGNAL_BUY)
               || (buy && sell)
              )
               {
                buy = false;
                sell = false;
                return true;
               }
           }
       }
//-- Close Position
    else // if(PositionsTotal() > 0 || OrdersTotal() > 0)
       {
        ENUM_POSITION_TYPE position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

        indicator_signals[0] = zIndicadorSignalNormalizer_OUT(bb, MA_Operation_Mode);
        indicator_signals[1] = zIndicadorSignalNormalizer_OUT(adx, ADX_Operation_Mode);
        indicator_signals[2] = zIndicadorSignalNormalizer_OUT(hilo, HILO_Operation_Mode);
        indicator_signals[3] = zIndicadorSignalNormalizer_OUT(macd, MACD_Operation_Mode);
        indicator_signals[4] = zIndicadorSignalNormalizer_OUT(ma, MA_Operation_Mode);
        indicator_signals[5] = zIndicadorSignalNormalizer_OUT(rsi, RSI_Operation_Mode);
        indicator_signals[6] = zIndicadorSignalNormalizer_OUT(sar, SAR_Operation_Mode);
        indicator_signals[7] = zIndicadorSignalNormalizer_OUT(stoc, STOC_Operation_Mode);
        indicator_signals[8] = zIndicadorSignalNormalizer_OUT(atr, ATR_Operation_Mode);
        indicator_signals[9] = zIndicadorSignalNormalizer_OUT(vwap, VWAP_Operation_Mode);

        for(int i = 0; i < 10; i++)
            if((position_type == POSITION_TYPE_BUY && indicator_signals[i] == INDICATOR_SIGNAL_SELL)
               || (position_type == POSITION_TYPE_SELL && indicator_signals[i] == INDICATOR_SIGNAL_BUY)
              )
               {
                close = true;
                return true;
               }

       }

    if(ORDER_Block_New_Inputs_On_Same_Day)
       {
        ENUM_DEAL_TYPE last_deal_type = zLastDealType();

        if(last_deal_type == DEAL_TYPE_BUY && buy)
            buy = false;
        if(last_deal_type == DEAL_TYPE_SELL && sell)
            sell = false;
       }

    return true;
   }
//+------------------------------------------------------------------+
