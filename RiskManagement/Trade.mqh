
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

input group "Setup"
input ENUM_VALUE_TYPE SET_Values_Type = VALUE_TYPE_POINTS;       // Value Type to Use

input group "Stop Loss"
input double STOP_Loss = 100;                                     // Stop Loss

input group "Take Profit"
input ENUM_ORDER_MARKET_TYPE STOP_Gain_Order_Type = ORDER_MARKET_TYPE_MARKET;   // Gain Order Type
input double STOP_Gain = 200;                                                   // Take Profit (Stop Gain)

input group "Trailing Stop"
input double TRAILING_Stop_Activation = 150;                         // Trailing Stop: Activation
input double TRAILING_Stop_Distance = 50;                            // Trailing Stop: Watermark Distance

input group "Partial Profit"
input double PARTIAL_Gain = 100;                                      // Partial: Take Profit
input double PARTIAL_Gain_Volume_Percentage = 50;                     // Partial: Percentage ( % ) of Volume
input bool   PARTIAL_Gain_Break_Even = true;                          // Partial: Enable Breakeven

static bool PARTIAL_Gain_Break_Triggered = true;                     
static bool PARTIAL_Gain_Break_Even_Activate = false; 

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
    double stop_gain_points = zNormalizeValues(STOP_Gain);
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
       && STOP_Gain > 0
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
