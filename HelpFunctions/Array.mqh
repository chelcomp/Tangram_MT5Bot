//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void zArrayShift(int&  array[], const int shift)
   {
    for(int i = ArraySize(array) - 1; i > 0 ; i--)
       {
        array[i] = array[i - shift];
       }
   }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void zArrayShift(double&  array[], const int shift)
   {
    for(int i = ArraySize(array) - 1; i > 0 ; i--)
       {
        array[i] = array[i - shift];
       }
   }
//+------------------------------------------------------------------+
