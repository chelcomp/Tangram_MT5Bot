//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsHedging()
   {
    ENUM_ACCOUNT_MARGIN_MODE margin_mode = (ENUM_ACCOUNT_MARGIN_MODE)AccountInfoInteger(ACCOUNT_MARGIN_MODE);
    return(margin_mode == ACCOUNT_MARGIN_MODE_RETAIL_HEDGING);
   }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsNetting()
   {
    ENUM_ACCOUNT_MARGIN_MODE margin_mode = (ENUM_ACCOUNT_MARGIN_MODE)AccountInfoInteger(ACCOUNT_MARGIN_MODE);
    return(margin_mode == ACCOUNT_MARGIN_MODE_RETAIL_NETTING);
   }
//+------------------------------------------------------------------+
