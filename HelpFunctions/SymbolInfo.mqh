//+------------------------------------------------------------------+
//|  Normalize volume to match with the symbol max, min and steps    |
//|  Otherwise the order can be rejected                             |
//+------------------------------------------------------------------+
double zNomalizeSymbolVolume(double volume)
  {
   double
   lots_min = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN),
   lots_max = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX),
   lots_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

//-- Adjust Volume for allowable conditions
   double normalized_volume = fmin(lots_max, // Prevent too greater volume
                                   fmax(lots_min, // Prevent too smaller volume
                                        round(volume) * lots_step));// Align to Step value

   return (normalized_volume);
  }
//+------------------------------------------------------------------+
double zNomalizeSymbolPrice(double price)
  {
   double m_tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   int m_digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

   if(m_tick_size!=0)
      return(NormalizeDouble(MathRound(price/m_tick_size)*m_tick_size,m_digits));
   double normalized_price = (NormalizeDouble(price,m_digits));
   return normalized_price;
  }
//+------------------------------------------------------------------+
