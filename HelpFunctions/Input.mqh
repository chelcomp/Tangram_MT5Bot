//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void zDisableInput(string input_name)
   {
    bool enable;
    double value, start, step, stop;
    ParameterGetRange(input_name, enable, value, start, step, stop);
    ParameterSetRange(input_name, false, value, start, step, stop);
   }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void zSetInputRangeStop(string input_name, double stop)
   {
    bool enable;
    double value, start, step, old_stop;
    ParameterGetRange(input_name, enable, value, start, step, old_stop);
    if(old_stop > stop)
        ParameterSetRange(input_name, enable, value, start, step, stop);
   }
//+------------------------------------------------------------------+
