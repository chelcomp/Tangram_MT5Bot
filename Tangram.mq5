//+------------------------------------------------------------------+
//|                                                          Tangram |
//|                        Copyright 2020, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|  PROPERTIES                                                      |
//+------------------------------------------------------------------+
#property version "100.005"
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
#include "mcarlo/mcarlo.mqh"

static bool g_is_new_candle, g_daily_risk_triggered;
static int g_day_trade_count = 0;
static ulong g_magic_number = -1;

datetime g_trial_date = D'2020.12.31';

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   if(TimeCurrent() >= g_trial_date)
     {
      MessageBox("Demo expired","Warning !");
      Print("This bot version is expired.");
      return(INIT_FAILED);
     }

   if(MQLInfoInteger(MQL_OPTIMIZATION) || MQLInfoInteger(MQL_FORWARD))
      ChartSetSymbolPeriod(0, _Symbol, PERIOD_M1);
   else
      ChartSetSymbolPeriod(0, _Symbol, TimeFrame);

   ENUM_ACCOUNT_TRADE_MODE trade_mode=(ENUM_ACCOUNT_TRADE_MODE)AccountInfoInteger(ACCOUNT_TRADE_MODE);
   if(trade_mode== ACCOUNT_TRADE_MODE_DEMO)
      Print("This is a demo account");
   else
      if(!MQLInfoInteger(MQL_OPTIMIZATION) && !MQLInfoInteger(MQL_FORWARD))
        {
         Print("This is NOT a demo account or it is NOT in Optmimization mode");
         Print("This bot is ony for study propose and can't be used in real account");
         Print("Stoping...");
         return(INIT_FAILED);
        }

//--- prepare trade class to control positions if hedging mode is active
//ExtHedging = ((ENUM_ACCOUNT_MARGIN_MODE)AccountInfoInteger(ACCOUNT_MARGIN_MODE) == ACCOUNT_MARGIN_MODE_RETAIL_HEDGING);
   Trade.SetExpertMagicNumber(SETTING_MagicNumber);
   Trade.SetMarginMode();
   Trade.SetTypeFillingBySymbol(Symbol());
   g_magic_number = Trade.RequestMagic();

   int init_status[20];
   ArrayInitialize(init_status, INIT_SUCCEEDED);

   init_status[0] = zTradeInit();
   init_status[1] = zDailyInit();

   bool use_heikin_ashi = GRAPH_Type == GRAPH_TYPE_HEIKINASHI;
//zHAInit(TimeFrame);
   init_status[2] = zBBInit(TimeFrame, use_heikin_ashi);
   init_status[3] = zHiLoInit(TimeFrame, use_heikin_ashi);
   init_status[4] = zMACDInit(TimeFrame, use_heikin_ashi);
   init_status[5] = zMAInit(TimeFrame, use_heikin_ashi);
   init_status[6] = zRSIInit(TimeFrame, use_heikin_ashi);

   init_status[7] = zADXInit(TimeFrame);
   init_status[8] = zSARInit(TimeFrame);
   init_status[9] = zSTOCInit(TimeFrame);
   init_status[10] = zATRInit(TimeFrame);
   init_status[11] = zVWAPInit(TimeFrame);



   for(int i = 0; i < ArraySize(init_status) ; i++)
     {
      if(init_status[i] != INIT_SUCCEEDED)
        {
         return init_status[i];
        }
     }

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
void OnTesterInit()
  {
   zATROnTesterInit();
   zVWAPOnTesterInit();
   zSTOCOnTesterInit();
   zSAROnTesterInit();
   zRSIOnTesterInit();
   zMAOnTesterInit();
   zMACDOnTesterInit();
   zHILOOnTesterInit();
   zBBOnTesterInit();
   zADXOnTesterInit();
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTesterDeinit(void)
  {

  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double OnTester(void)
  {
   if(MQLInfoInteger(MQL_OPTIMIZATION) || MQLInfoInteger(MQL_FORWARD))
     {
      return optpr();         // optimization parameter
     }
   return 0;
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//+------------------------------------------------------------------+
//| TRIAL VERION VERIFICATION                                        |
//+------------------------------------------------------------------+
   if(TimeCurrent() >= g_trial_date)
     {
      MessageBox("Demo expired","Warning !");
      Print("This bot version is expired. Please contact the developer to get a new version.");
      ExpertRemove();
     }

   g_is_new_candle = zIsNewCandle(TimeFrame);
   if(PositionsTotal() <= 0 && !g_is_new_candle)
      return;

   PositionInfo.Select(_Symbol);
   bool buy = false, sell = false, close = false;

   zResetDailyVariables();

//-- Check Daily Risk Archievement
   if(!g_daily_risk_triggered)
      g_daily_risk_triggered = zDailyRiskEvent(g_magic_number);

   if(g_daily_risk_triggered)
     {
      zCancelAllPendingOrders();
      zCloseAllOpenPositions();
      return;
     }

//-- Normal Close
   close = zTradeCloseAllPositions();
   bool can_reverse = zCanReversePosition();
   bool can_open_position_time_window = zCanOpenPositionTimeWindow();

   if(!close && g_is_new_candle)
      zIndicatorsSignal(buy, sell, close);

   if(can_open_position_time_window && can_reverse)
     {
      if((buy || sell) && OUT_Use_Reverse)
        {
         bool reverse_order_creates = zReversePosition(buy, sell);
         if(reverse_order_creates)
            return;
        }
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
   if(PositionsTotal() == 0 && OrdersTotal() == 0
      && can_open_position_time_window
      && (buy || sell))
     {
      //-- Check to Block_New_Inputs_On_Same_Day
      if((buy || sell) && ORDER_Block_New_Inputs_On_Same_Day)
        {
         ENUM_DEAL_TYPE last_deal_type = zLastDealType(g_magic_number);

         if(last_deal_type == DEAL_TYPE_BUY && buy)
            buy = false;
         if(last_deal_type == DEAL_TYPE_SELL && sell)
            sell = false;
        }

      if(buy || sell)
         zCreateOrder(buy, sell);
     }
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
      g_day_trade_count++;
     }
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
   volume *= zMartigaleMultiplier();

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
int zMartigaleMultiplier()
  {
   static int zMartigaleMultipler = 1;
   if(OUT_Martingale_Times > 0)
     {
      if(zMartigaleMultipler <= OUT_Martingale_Times)
        {
         int history_deals_total = zTodayDealsTotal(g_magic_number);
         ulong ticket = HistoryDealGetTicket(history_deals_total - 1);
         double last_profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
         if(ticket > 0 && last_profit < 0)
           {
            zMartigaleMultipler++;
            return zMartigaleMultipler;
           }
        }

      zMartigaleMultipler = 1;
     }

//-- No Martigale return always 1
   return zMartigaleMultipler;
  }

//+------------------------------------------------------------------+
//|  Add another Order in reverse to the current position            |
//+------------------------------------------------------------------+
bool zReversePosition(bool buy, bool sell)
  {
   if(!OUT_Use_Reverse
      || PositionsTotal() <= 0)
      return false;

   double volume = ORDER_Volume;
   volume *= zMartigaleMultiplier();
   volume += PositionInfo.Volume();
   volume  = zNomalizeSymbolVolume(volume);

   Trade.SetDeviationInPoints(ULONG_MAX);
   if(PositionInfo.PositionType() == POSITION_TYPE_SELL && buy)
      return Trade.Buy(volume);

   if(PositionInfo.PositionType() == POSITION_TYPE_BUY && sell)
      return Trade.Sell(volume);

   return false;
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
ENUM_INDICATOR_SIGNAL zIndicadorSignalNormalizer_IN(ENUM_INDICATOR_SIGNAL indicator_signal, ENUM_INDICATOR_SIGNAL indicator_filter, ENUM_INDICATOR_OPERATION_MODE indicator_mode)
  {
   if(indicator_mode == INDICATOR_OPERATION_MODE_IN || indicator_mode == INDICATOR_OPERATION_MODE_BOTH)
     {
      if(indicator_filter == INDICATOR_FILTER_ALLOW)
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
void zIndicatorsSignal(bool & buy, bool & sell, bool & close)
  {
   buy = false;
   sell = false;
   close = false;

   if(!g_is_new_candle)
      return;

   ENUM_INDICATOR_SIGNAL indicator_signals[];
   ArrayResize(indicator_signals, 10);
   ArrayInitialize(indicator_signals, (int)INDICATOR_SIGNAL_NEUTRAL_ALLOW);

   ENUM_INDICATOR_SIGNAL bb = zBB();

   ENUM_INDICATOR_SIGNAL adx = zADX();
   ENUM_INDICATOR_SIGNAL adx_filter = zADXFilter();

   ENUM_INDICATOR_SIGNAL hilo = zHILO();
   ENUM_INDICATOR_SIGNAL macd = zMACD();
   ENUM_INDICATOR_SIGNAL macd_filter = zMACDFilter();

   ENUM_INDICATOR_SIGNAL ma = zMA();
   ENUM_INDICATOR_SIGNAL rsi = zRSI();
   ENUM_INDICATOR_SIGNAL sar = zSAR();
   ENUM_INDICATOR_SIGNAL stoc = zSTOC();
   ENUM_INDICATOR_SIGNAL atr = zATR();
   ENUM_INDICATOR_SIGNAL vwap = zVWAP();

//-- Open Position
   if((PositionsTotal() == 0 && OrdersTotal() == 0)
      || OUT_Use_Reverse)
     {
      indicator_signals[0] = zIndicadorSignalNormalizer_IN(bb, BB_Operation_Mode);
      indicator_signals[1] = zIndicadorSignalNormalizer_IN(adx, adx_filter, ADX_Operation_Mode);
      indicator_signals[2] = zIndicadorSignalNormalizer_IN(hilo, HILO_Operation_Mode);
      indicator_signals[3] = zIndicadorSignalNormalizer_IN(macd, macd_filter, MACD_Operation_Mode);
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
            break;
           }
        }
     }
//-- Close Position
   if(PositionsTotal() > 0 || OrdersTotal() > 0)
     {
      ENUM_POSITION_TYPE position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

      indicator_signals[0] = zIndicadorSignalNormalizer_OUT(bb, BB_Operation_Mode);
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
        {
         if(OUT_Close_Position_By_Indicator == CLOSE_POSITION_BY_INDICATOR_ALL) // Out by All indicator
           {
            if(indicator_signals[i] != INDICATOR_SIGNAL_NEUTRAL_BLOCK && indicator_signals[i] != INDICATOR_SIGNAL_NEUTRAL_ALLOW)
              {
               close = true;
               if((position_type == POSITION_TYPE_BUY && indicator_signals[i] == INDICATOR_SIGNAL_BUY)
                  || (position_type == POSITION_TYPE_SELL && indicator_signals[i] == INDICATOR_SIGNAL_SELL)
                  )
                 {
                  close = false;
                  continue;
                 }
              }
           }
         else // OUT_Close_Position_By_Indicator == CLOSE_POSITION_BY_INDICATOR_ANY
           {
            if((position_type == POSITION_TYPE_BUY && indicator_signals[i] == INDICATOR_SIGNAL_SELL)
               || (position_type == POSITION_TYPE_SELL && indicator_signals[i] == INDICATOR_SIGNAL_BUY)
              )
              {
               close = true;
               break;
              }
           }
        }
     }
   /*
       if(ORDER_Block_New_Inputs_On_Same_Day)
          {
           ENUM_DEAL_TYPE last_deal_type = zLastDealType();

           if(last_deal_type == DEAL_TYPE_BUY && buy)
               buy = false;
           if(last_deal_type == DEAL_TYPE_SELL && sell)
               sell = false;
          }
   */
   return ;
  }
//+------------------------------------------------------------------+
