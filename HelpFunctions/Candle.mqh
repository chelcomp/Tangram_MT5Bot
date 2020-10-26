//+------------------------------------------------------------------+
//| Return if the current tick is the first one on the candle        |
//+------------------------------------------------------------------+
bool zIsNewCandle(ENUM_TIMEFRAMES timeframe)
   {
    static datetime previous_tick_time = 0;
    datetime current_open_tick_time = (datetime)SeriesInfoInteger(Symbol(), timeframe, SERIES_LASTBAR_DATE);
    if(previous_tick_time == 0)
       {
        previous_tick_time = current_open_tick_time;
        return(false);
       }
    if(previous_tick_time != current_open_tick_time)
       {
        previous_tick_time = current_open_tick_time;
        return(true);
       }
    return(false);
   }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double zOpenDayRate()
   {
    double open_day_rate = iOpen(_Symbol, PERIOD_D1, 0);
    return open_day_rate;
   }
//+------------------------------------------------------------------+
