//+------------------------------------------------------------------+
//|                                                          Tangram |
//|                        Copyright 2020, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+

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
    TimeToStruct(value, dt);
    string aux = StringFormat("1970.01.01 %02d:%02d", dt.hour, dt.min);
    datetime x = StringToTime(aux);
    return StringToTime(aux);
   }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsTheSameDay(datetime day1, datetime day2)
   {
    return day(day1) == day(day2) && mounth(day1) == mounth(day2);
   }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int day(datetime day)
   {
    MqlDateTime _day;
    TimeToStruct(day, _day);
    return _day.day;
   }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int mounth(datetime day)
   {
    MqlDateTime _day;
    TimeToStruct(day, _day);
    return _day.day;
   }
//+------------------------------------------------------------------+
