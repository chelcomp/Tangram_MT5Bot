//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double zCurrentDayNetProfit()
   {
    static int zCurrentProfit_previous_HistoryDealsTotal = 0;
    static datetime zCurrentProfit_previous_processed_day = 0;
    static double net_profit = 0;

    MqlDateTime current_day_begin;
    TimeCurrent(current_day_begin);
    current_day_begin.hour = 0;
    current_day_begin.min = 0;
    current_day_begin.sec = 0;

//-- If it is a new day
    if(zCurrentProfit_previous_processed_day < StructToTime(current_day_begin))
       {
        net_profit = 0;
        zCurrentProfit_previous_processed_day = StructToTime(current_day_begin);
       }

//-- Try select the History.... but is it is not possuvle
    if(!HistorySelect(StructToTime(current_day_begin), TimeCurrent()))
        return -1;

//-- If there is no new order since the last call
    if(HistoryDealsTotal() == zCurrentProfit_previous_HistoryDealsTotal)
        return net_profit;

//-- loop only new orders since the last call
    int history_deals_total = HistoryDealsTotal();
    for(int i = zCurrentProfit_previous_HistoryDealsTotal; i < history_deals_total; i++)
       {
        //--- Get the deal ticket
        ulong ticket = HistoryDealGetTicket(i);
        //deal.time = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);
        ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(ticket, DEAL_ENTRY);
        if(entry == DEAL_ENTRY_OUT)
           {
            double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
            double commission = HistoryDealGetDouble(ticket, DEAL_COMMISSION);
            double swap = HistoryDealGetDouble(ticket, DEAL_SWAP);
            double fee = HistoryDealGetDouble(ticket, DEAL_FEE);
            net_profit += profit - commission - swap - fee;
           }
       }

    zCurrentProfit_previous_HistoryDealsTotal = HistoryDealsTotal();
    return net_profit;
   }


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int zTodayDealsTotal()
   {
    MqlDateTime current_day_begin;
    TimeCurrent(current_day_begin);
    current_day_begin.hour = 0;
    current_day_begin.min = 0;
    current_day_begin.sec = 0;

//-- Try select the History.... but is it is not possible
    if(!HistorySelect(StructToTime(current_day_begin), TimeCurrent()))
        return -1;

    int t = HistoryDealsTotal();

    return t;
   }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int zTodayClosedDealsTotal()
   {
    int history_deals_total = zTodayDealsTotal();
    int t = 0;

    for(int i = 0; i < history_deals_total; i++)
       {
        ulong deal_ticket = HistoryDealGetTicket(i);
        ENUM_DEAL_ENTRY deal_entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal_ticket, DEAL_ENTRY) ;
        if(deal_entry == DEAL_ENTRY_IN || deal_entry == DEAL_ENTRY_INOUT)
            t++;
       }
       
    if(t > 0 && PositionsTotal() > 0)
        t--;
        
    return t;
   }

//+------------------------------------------------------------------+
//|  Return Last Deal Type                                           |
//+------------------------------------------------------------------+
ENUM_DEAL_TYPE zLastDealType()
   {
    int history_deals_total = zTodayDealsTotal();

//-- Run backward the Hystory until to get a deal buy or sell
    for(uint i = history_deals_total - 2; i > 0; i--)
       {
        ulong ticket =  HistoryDealGetTicket(i);
        ENUM_DEAL_TYPE last_deal_type = (ENUM_DEAL_TYPE)HistoryDealGetInteger(ticket, DEAL_TYPE);
        if(last_deal_type == DEAL_TYPE_BUY || last_deal_type == DEAL_TYPE_SELL)
           {
            return last_deal_type;
           }
       }
    return NULL;
   }
//+------------------------------------------------------------------+
