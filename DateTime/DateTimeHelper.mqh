
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int DateTimeCompare(datetime begin, datetime end)
   {
    if(begin < end)
        return -1;
    if(begin == end)
        return 0;
    return 1;
   }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool DateTimeBetween(datetime reference, datetime begin, datetime end)
   {
    if(DateTimeCompare(reference, begin) >= 0
       && DateTimeCompare(reference, end) <= 0)
        return true;
    return false;
   }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
datetime DateTime2Time(datetime value)
   {
    MqlDateTime dt;
    TimeToStruct(value,dt);
    string aux = StringFormat("1970.01.01 %02d:%02d", dt.hour, dt.min);
    datetime x = StringToTime(aux);
    return StringToTime(aux);
   }

//+------------------------------------------------------------------+
