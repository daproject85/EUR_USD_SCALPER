// EuroScalper_CLEAN.mq4 (Step 3 - parity fix: slippage=5 & magic filename)
// Externs + logger + session/open-range gating + first-entry logic
#property strict
#include <EuroScalper_Logging_Config.mqh>
#include <ES_Logger.mqh>

#define ES_MAGIC 1 // baseline hard-coded magic

extern string Minimal_Deposit = "$200";
extern string Time_Frame = "Time Frame M1";
extern string Pairs = "EurUsd";
extern bool   Use_Daily_Target = true;
extern double Daily_Target = 100;
extern bool   Hidden_TP = true;
extern double Hiden_TP = 500;
extern double Lot = 0.01;
extern double LotMultiplikator = 1.21;
extern double TakeProfit = 34;
extern double Step = 21;
extern double Averaging = 1;
extern int    MaxTrades = 31;
extern bool   UseEquityStop = false;
extern double TotalEquityRisk = 20;
extern int    Open_Hour = 0;
extern int    Close_Hour = 23;
extern bool   TradeOnThursday = true;
extern int    Thursday_Hour = 12;
extern bool   TradeOnFriday = true;
extern int    Friday_Hour = 20;
extern bool   Filter_Sideway = true;
extern bool   Filter_News = true;
extern bool   invisible_mode = true;
extern double OpenRangePips = 1;
extern double MaxDailyRange = 20000;

// ---- Session & Open-Range Gating ----
bool ES_CanTrade_Session()
{
   int hour = TimeHour(TimeCurrent());
   if(Open_Hour > 0 && hour < Open_Hour)  return(false);
   if(Close_Hour > 0 && hour >= Close_Hour) return(false);

   int dow = DayOfWeek();
   if(!TradeOnThursday && dow==4) return(false);
   if( TradeOnThursday && dow==4 && Thursday_Hour > 0 && hour >= Thursday_Hour) return(false);
   if(!TradeOnFriday && dow==5) return(false);
   if( TradeOnFriday && dow==5 && Friday_Hour > 0 && hour >= Friday_Hour) return(false);

   return(true);
}

bool ES_CanTrade_OpenRange()
{
   double dOpen = iOpen(_Symbol, PERIOD_D1, 0);
   double dHigh = iHigh(_Symbol, PERIOD_D1, 0);
   double dLow  = iLow (_Symbol, PERIOD_D1, 0);
   double mid   = (Bid + Ask) * 0.5;

   double distFromOpenPts = MathAbs(mid - dOpen) / Point;
   double dayRangePts     = (dHigh - dLow) / Point;

   if(Filter_Sideway && distFromOpenPts < OpenRangePips)
      return(false);
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

void ES_UpdateBasketTP()
{
   double sumPriceLots = 0.0;
   double sumLots      = 0.0;
   int    dir          = -1;

   for(int i=OrdersTotal()-1; i>=0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol()!=_Symbol || OrderMagicNumber()!=ES_MAGIC) continue;
      if(OrderType()!=OP_BUY && OrderType()!=OP_SELL) continue;

      sumPriceLots += OrderOpenPrice() * OrderLots();
      sumLots      += OrderLots();
      dir = OrderType();
   }

   if(sumLots <= 0) return;

   double vwap = NormalizeDouble(sumPriceLots / sumLots, _Digits);
   double basket_tp;

   if(dir == OP_BUY)
      basket_tp = vwap + TakeProfit * _Point;
   else if(dir == OP_SELL)
      basket_tp = vwap - TakeProfit * _Point;
   else
      return;

   ES_Log_Event_TPAssign(vwap, basket_tp);

   for(int i=OrdersTotal()-1; i>=0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol()!=_Symbol || OrderMagicNumber()!=ES_MAGIC) continue;
      if(OrderType()!=OP_BUY && OrderType()!=OP_SELL) continue;

      ES_Log_OrderModify(OrderTicket(), vwap, OrderStopLoss(), basket_tp, 0, clrNONE);
   }
}

int ES_OpenFirstTrade()
{
   double lots = ES_GetFirstLotSize();
   int    cmd  = -1;
   double price = 0;
   const int SLIPPAGE = 5; // baseline parity

   if(Close[2] > Close[1]) { cmd = OP_SELL; price = Bid; }
   else                    { cmd = OP_BUY;  price = Ask; }

   int ticket = ES_Log_OrderSend(Symbol(), cmd, lots, price, SLIPPAGE,
                                 0, 0, Symbol()+"-Euro Scalper-0", ES_MAGIC, 0, clrNONE);

   if(ticket > 0)
      ES_UpdateBasketTP();

   return(ticket);
}

int init()
{
   // Set context BEFORE opening the log so magic appears in filename
   ES_Log_SetContext(_Symbol, Period(), ES_MAGIC);
   ES_Log_OnInit();
   return(0);
}

int start()
{
   if(!ES_CanTradeNow())
      return(0);

   if(OrdersTotal() == 0)
      ES_OpenFirstTrade();

   return(0);
}

int deinit()
{
   ES_Log_OnDeinit();
   return(0);
}
