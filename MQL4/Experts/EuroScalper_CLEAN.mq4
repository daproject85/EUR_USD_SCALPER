// EuroScalper_CLEAN.mq4 (Step 3)
// Externs + logger + session/open-range gating + first-entry logic
#property strict
#include <EuroScalper_Logging_Config.mqh>
#include <ES_Logger.mqh>

extern string Minimal_Deposit = "$200";
extern string Time_Frame = "Time Frame M1";
extern string Pairs = "EurUsd";
extern bool Use_Daily_Target = true;
extern double Daily_Target = 100;
extern bool Hidden_TP = true;
extern double Hiden_TP = 500;
extern double Lot = 0.01;
extern double LotMultiplikator = 1.21;
extern double TakeProfit = 34;
extern double Step = 21;
extern double Averaging = 1;
extern int MaxTrades = 31;
extern bool UseEquityStop;
extern double TotalEquityRisk = 20;
extern int Open_Hour;
extern int Close_Hour = 23;
extern bool TradeOnThursday = true;
extern int Thursday_Hour = 12;
extern bool TradeOnFriday = true;
extern int Friday_Hour = 20;
extern bool Filter_Sideway = true;
extern bool Filter_News = true;
extern bool invisible_mode = true;
extern double OpenRangePips = 1;
extern double MaxDailyRange = 20000;

// ---- Session & Open-Range Gating ----
bool ES_CanTrade_Session()
{
   int hour = TimeHour(TimeCurrent());
   if(Open_Hour > 0 && hour < Open_Hour)  return(false);
   if(Close_Hour > 0 && hour >= Close_Hour) return(false);

   int dow = DayOfWeek(); // 0=Sun … 4=Thu, 5=Fri
   // Thursday rules
   if(!TradeOnThursday && dow==4) return(false);
   if( TradeOnThursday && dow==4 && Thursday_Hour > 0 && hour >= Thursday_Hour) return(false);
   // Friday rules
   if(!TradeOnFriday && dow==5) return(false);
   if( TradeOnFriday && dow==5 && Friday_Hour > 0 && hour >= Friday_Hour) return(false);

   return(true);
}

bool ES_CanTrade_OpenRange()
{
   // Daily open-range & max-range filter
   double dOpen = iOpen(_Symbol, PERIOD_D1, 0);
   double dHigh = iHigh(_Symbol, PERIOD_D1, 0);
   double dLow  = iLow (_Symbol, PERIOD_D1, 0);
   double mid   = (Bid + Ask) * 0.5;

   double distFromOpenPts = MathAbs(mid - dOpen) / Point;
   double dayRangePts     = (dHigh - dLow) / Point;

   // Sideways filter: too close to daily open
   if(Filter_Sideway && distFromOpenPts < OpenRangePips)
      return(false);

   // Excessive daily range filter
   if(dayRangePts > MaxDailyRange)
      return(false);

   return(true);
}

bool ES_CanTradeNow()
{
   if(!ES_CanTrade_Session())   return(false);
   if(!ES_CanTrade_OpenRange()) return(false);
   return(true);
}

// ---- First Entry Logic ----
double ES_GetFirstLotSize()
{
   return(Lot);
}

int ES_OpenFirstTrade()
{
   double lots = ES_GetFirstLotSize();
   int ticket  = -1;
   int cmd     = -1;
   double price = 0;
   int slippage = 3;

   if(Close[2] > Close[1])
   {
      cmd = OP_SELL;
      price = Bid;
   }
   else
   {
      cmd = OP_BUY;
      price = Ask;
   }

   // Log before sending
   ES_Log_OrderSend_Attempt(cmd, lots, price, 0, 0);

   ticket = OrderSend(Symbol(), cmd, lots, price, slippage, 0, 0, "FirstEntry", 0, 0, clrNONE);

   // Log result
   ES_Log_OrderSend_Result(ticket);

   if(ticket > 0)
   {
      // Basket TP assignment placeholder (will be expanded later)
      ES_Log_BasketTP_Assign(0, 0);
   }

   return(ticket);
}

int init()
{
   ES_Log_OnInit();
   ES_Log_SetContext(_Symbol, Period(), 0);
   return(0);
}

int start()
{
   // Step 3: gating + first entry
   if(!ES_CanTradeNow())
      return(0);

   // Only place trade if none exists
   if(OrdersTotal() == 0)
   {
      ES_OpenFirstTrade();
   }

   return(0);
}

int deinit()
{
   ES_Log_OnDeinit();
   return(0);
}
