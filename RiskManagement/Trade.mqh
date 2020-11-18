//+------------------------------------------------------------------+
//|                                                          Tangram |
//|                        Copyright 2020, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+

enum ENUM_VALUE_TYPE
   {
    VALUE_TYPE_POINTS,      // Points/Cents
    VALUE_TYPE_PERCENTAGE   // Percentage
   };

enum ENUM_ORDER_MARKET_TYPE
   {
    ORDER_MARKET_TYPE_MARKET, // Market
    ORDER_MARKET_TYPE_LIMIT   // Limit
   };

enum ENUM_TAKE_PROFIT_TYPE
   {
    TAKE_PROFIT_TYPE_FIXED_VALUE,      // Fixed value
    TAKE_PROFIT_TYPE_TIMES_STOP_LOSS   // X Times Stop Loss
   };

input group "Setup"
input ENUM_VALUE_TYPE SET_Values_Type = VALUE_TYPE_POINTS;         // Value Type to Use

input group "Stop Loss"
input double STOP_Loss = NULL;                                     // Stop Loss

input group "Take Profit"
sinput ENUM_TAKE_PROFIT_TYPE STOP_Gain_Type = TAKE_PROFIT_TYPE_FIXED_VALUE;      // Type
input ENUM_ORDER_MARKET_TYPE STOP_Gain_Order_Type = ORDER_MARKET_TYPE_MARKET;   // Gain Order Type
input double STOP_Gain = NULL;                                                  // Take Profit (Stop Gain)

input group "Trailing Stop"
input double TRAILING_Stop_Activation = NULL;                         // Trailing Stop: Activation
input double TRAILING_Stop_Distance = NULL;                           // Trailing Stop: Watermark Distance

input group "Partial Profit"
input double PARTIAL_Gain = NULL;                                     // Partial: Take Profit
input double PARTIAL_Gain_Volume_Percentage = 50;                     // Partial: Percentage ( % ) of Volume
input bool   PARTIAL_Gain_Break_Even = true;                          // Partial: Enable Breakeven

double Fixed_STOP_Gain = 0;
static bool PARTIAL_Gain_Break_Triggered = true;
static bool PARTIAL_Gain_Break_Even_Activate = false;


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int zTradeInit()
   {
    if(STOP_Gain_Type == TAKE_PROFIT_TYPE_FIXED_VALUE)
        Fixed_STOP_Gain = STOP_Gain;
    else
        Fixed_STOP_Gain = STOP_Gain * STOP_Loss;

    if(Fixed_STOP_Gain > 0
       && PARTIAL_Gain > 0
       && Fixed_STOP_Gain <= PARTIAL_Gain)
       {
        Print("Take Profit can't be lower than Partial Take Profit");
        return (INIT_PARAMETERS_INCORRECT);
       }

    if(TRAILING_Stop_Activation > 0
       && Fixed_STOP_Gain > 0
       && MathAbs(TRAILING_Stop_Activation - TRAILING_Stop_Distance) > Fixed_STOP_Gain)
       {
        Print("Trailing Stop Activation and Distance are not compatible with the Take Profit");
        return (INIT_PARAMETERS_INCORRECT);
       }

    if(TRAILING_Stop_Activation > 0
       && Fixed_STOP_Gain > 0
       && TRAILING_Stop_Activation >= Fixed_STOP_Gain)
       {
        Print("Trailing Stop Activation can't be higher than Take Profit");
        return (INIT_PARAMETERS_INCORRECT);
       }

    if(PARTIAL_Gain > 0
       && PARTIAL_Gain_Volume_Percentage > 100)
       {
        Print("Partial Take Profit Percentage can't be higher than 100%");
        return (INIT_PARAMETERS_INCORRECT);
       }


    if(Fixed_STOP_Gain > 0
       && TRAILING_Stop_Activation > 0
       && TRAILING_Stop_Activation > Fixed_STOP_Gain)
       {
        Print("Trailing Stop Activation can't be higher than Take Profit");
        return (INIT_PARAMETERS_INCORRECT);
       }

    return(INIT_SUCCEEDED);
   }


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool zTradeCloseAllPositions()
   {
    static double zTradeCloseAllPositions_trailing_stop_whater_mark = 0;
    static ulong zTradeCloseAllPositions_previous_ticket = 0;
//-- If there is no Position: Reset flags and get out
    if(PositionsTotal() <= 0
       || zTradeCloseAllPositions_previous_ticket != PositionGetInteger(POSITION_TICKET))
       {
        zTradeCloseAllPositions_trailing_stop_whater_mark = 0;
        PARTIAL_Gain_Break_Even_Activate = false;
        PARTIAL_Gain_Break_Triggered = false;
        zTradeCloseAllPositions_previous_ticket = PositionGetInteger(POSITION_TICKET);
        if(PositionsTotal() <= 0)
            return false;
       }

//zTradeCloseAllPositions_previous_ticket = PositionGetInteger(POSITION_TICKET);

    double position_gain_points = zPositionGain();
    double stop_loss_points = zNormalizeValues(STOP_Loss);
    double stop_gain_points = zNormalizeValues(Fixed_STOP_Gain);
    double trailing_stop_activation_points = zNormalizeValues(TRAILING_Stop_Activation);
    double trailing_stop_distance_points = zNormalizeValues(TRAILING_Stop_Distance);

//-- Loss
    if(STOP_Loss > 0
       && position_gain_points < 0
       && position_gain_points <= -stop_loss_points)
       {
        return true;
       }

//-- Gain
    if(STOP_Gain_Order_Type == ORDER_MARKET_TYPE_MARKET
       && Fixed_STOP_Gain > 0
       && position_gain_points > 0
       && position_gain_points >= stop_gain_points)
       {
        return true;
       }

//-- Trailing Stop
    if(TRAILING_Stop_Activation > 0)
       {
        if(zTradeCloseAllPositions_trailing_stop_whater_mark == 0
           && position_gain_points > 0
           && position_gain_points >= trailing_stop_activation_points)
            zTradeCloseAllPositions_trailing_stop_whater_mark = position_gain_points;

        if(zTradeCloseAllPositions_trailing_stop_whater_mark > 0)
           {
            zTradeCloseAllPositions_trailing_stop_whater_mark = MathMax(position_gain_points, zTradeCloseAllPositions_trailing_stop_whater_mark);
            if(position_gain_points + trailing_stop_distance_points < zTradeCloseAllPositions_trailing_stop_whater_mark)
               {
                return true;
               }
           }
       }

//-- Partial Gain Breakeven
    if(PARTIAL_Gain_Break_Even_Activate
       && PARTIAL_Gain > 0
       && position_gain_points <= 0)
       {
        return true;
       }

    return false;
   }

//+------------------------------------------------------------------+
//|   If Return True then PARTIAL_Gain_Volume_Percentage             |
//| position should be closed                                        |
//+------------------------------------------------------------------+
bool zTradeClosePartialPositions()
   {
    if(PositionsTotal() <= 0)
        return false;

    if(PARTIAL_Gain > 0
       && !PARTIAL_Gain_Break_Triggered)
       {
        double partial_gain_points = zNormalizeValues(PARTIAL_Gain);
        double position_gain = zPositionGain();
        if(position_gain >= partial_gain_points)
           {
            PARTIAL_Gain_Break_Triggered = true;
            if(PARTIAL_Gain_Break_Even)
                PARTIAL_Gain_Break_Even_Activate = true;
            return true;
           }
       }

    return false;
   }

//+------------------------------------------------------------------+
//| if ValueType is Percentage return the equivalent in points       |
//| if ValueType is points return the same value                     |
//+------------------------------------------------------------------+
double zNormalizeValues(double value)
   {
    if(SET_Values_Type == VALUE_TYPE_POINTS)
        return value;

    double open = PositionInfo.PriceOpen();
    return open * value / 100;
   }

//+------------------------------------------------------------------+
//| Return the current position gain/loss in points/cents            |
//+------------------------------------------------------------------+
double zPositionGain()
   {
    if(PositionsTotal() > 0)
       {
        double current = PositionInfo.PriceCurrent();
        double open = PositionInfo.PriceOpen();

        if(PositionInfo.PositionType() == POSITION_TYPE_BUY)
            return current - open;

        //if(PositionInfo.PositionType() == POSITION_TYPE_SELL)
        return open - current;
       }
    return 0;
   }
//+------------------------------------------------------------------+
