// EuroScalper_CLEAN.mq4 (Step 3 - parity fix: slippage=5 & magic filename)
// Externs + logger + session/open-range gating + first-entry logic
#define ES_RUN_TAG "CLEAN"
#property strict
#include <EuroScalper_Logging_Config.mqh>
#include <ES_Logger.mqh>
input int Magic = 101111;

bool BasketTPUpdatePending = false;


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
// Basket/grid tracking flags
bool   g_buyBasket   = false;   // analogous to I_b_18
bool   g_sellBasket  = false;   // analogous to I_b_19
bool   g_allowGrid   = false;   // analogous to I_b_22
double g_lastBuyPrice  = 0.0;   // price of most recent buy
double g_lastSellPrice = 0.0;   // price of most recent sell
bool   g_useVolFilter = true;   // mimic I_b_20 baseline behaviour

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
   if(!Filter_Sideway)
      return(true);
   if(OpenRangePips <= 0 || MaxDailyRange <= 0)
      return(true);

   int today = DayOfYear();
   double dayOpen = 0.0;
   int bars = iBars(_Symbol, PERIOD_M1);
   for(int i=0; i<bars; i++)
   {
      datetime t = iTime(_Symbol, PERIOD_M1, i);
      if(TimeDayOfYear(t) != today)
         break;
      dayOpen = iOpen(_Symbol, PERIOD_M1, i);
   }

   double upper = NormalizeDouble(dayOpen + OpenRangePips * Point, _Digits);
   double lower = NormalizeDouble(dayOpen - OpenRangePips * Point, _Digits);
   double price = Close[0];
   double upperLimit = NormalizeDouble(upper + MaxDailyRange * Point, _Digits);
   double lowerLimit = NormalizeDouble(lower - MaxDailyRange * Point, _Digits);

   if((price > upper && price < upperLimit) ||
      (price < lower && price > lowerLimit))
      return(true);

   return(false);
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

double ES_ComputeVWAP(const int magicNumber)
{
   double sumLots = 0.0;
   double sumPx   = 0.0;
   int total = OrdersTotal();
   for(int i=0; i<total; i++)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != Symbol()) continue;
      if(OrderMagicNumber() != magicNumber) continue;
      int t = OrderType();
      if(t!=OP_BUY && t!=OP_SELL) continue; // market positions only
      double lots = OrderLots();
      sumLots += lots;
      sumPx   += OrderOpenPrice() * lots;
   }
   if(sumLots > 0.0) return (sumPx / sumLots);
   return (0.0);
}
int ES_OpenFirstTrade()
{
   double lots = ES_GetFirstLotSize();
   int    cmd  = -1;
   double price = 0;
   const int SLIPPAGE = 5; // baseline parity

   if(Close[2] > Close[1]) { cmd = OP_SELL; price = Bid; }
   else                    { cmd = OP_BUY;  price = Ask; }

   int ticket = (int)ES_Log_OrderSend(Symbol(), cmd, lots, price, SLIPPAGE,
                                 0, 0, StringConcatenate(Symbol(),"-Euro Scalper-0"), Magic, 0, clrNONE);

   if(ticket > 0)
   {
      RefreshRates();
      BasketTPUpdatePending = true;
   }
   return(ticket);
}

void ES_UpdateBasketTP()
{
   if(!BasketTPUpdatePending)
      return;

   int dir = ES_BasketDirection();
   if(dir!=OP_BUY && dir!=OP_SELL)
      return;

   double vwap = NormalizeDouble(ES_ComputeVWAP(Magic), _Digits);
   double tpdist = TakeProfit * Point;
   double basket_tp = NormalizeDouble((dir==OP_BUY) ? (vwap + tpdist) : (vwap - tpdist), _Digits);

   // log assignment prior to issuing any order modifications so that
   // `BASKET_TP_ASSIGN` precedes `ORDER_MODIFY_*` events in the log
   ES_Log_Event_TPAssign(vwap, basket_tp);

   int total = OrdersTotal();
   for(int i=0; i<total; i++)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol()!=Symbol())      continue;
      if(OrderMagicNumber()!=Magic)    continue;
      if(OrderType()!=dir)             continue;
      if(MathAbs(OrderTakeProfit() - basket_tp) <= Point)
         continue;
      double open_price = OrderOpenPrice();
      ES_Log_OrderModify(OrderTicket(), open_price, OrderStopLoss(), basket_tp, 0, 65535);
   }

   BasketTPUpdatePending = false;
}

// ---- Grid Add Helpers ----
int ES_BasketDirection()
{
   int total = OrdersTotal();
   for(int i=0; i<total; i++)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol()!=Symbol())      continue;
      if(OrderMagicNumber()!=Magic)    continue;
      int t = OrderType();
      if(t==OP_BUY || t==OP_SELL)
         return(t);
   }
   return(-1);
}

int ES_CountTrades(const int cmd)
{
   int count=0;
   int total=OrdersTotal();
   for(int i=0;i<total;i++)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol()!=Symbol())      continue;
      if(OrderMagicNumber()!=Magic)    continue;
      if(OrderType()==cmd)             count++;
   }
   return(count);
}

double ES_LastOpenPrice(const int cmd)
{
   double price=0;
   datetime latest=0;
   int total=OrdersTotal();
   for(int i=0;i<total;i++)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol()!=Symbol())      continue;
      if(OrderMagicNumber()!=Magic)    continue;
      if(OrderType()!=cmd)             continue;
      if(OrderOpenTime()>latest)
      {
         latest=OrderOpenTime();
         price=OrderOpenPrice();
      }
   }
   return(price);
}

double ES_LastLotSize(const int cmd)
{
   double lots=Lot;
   datetime latest=0;
   int total=OrdersTotal();
   for(int i=0;i<total;i++)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol()!=Symbol())      continue;
      if(OrderMagicNumber()!=Magic)    continue;
      if(OrderType()!=cmd)             continue;
      if(OrderOpenTime()>latest)
      {
         latest=OrderOpenTime();
         lots=OrderLots();
      }
   }
   return(lots);
}

double ES_NextLotSize(const int cmd)
{
   int count = ES_CountTrades(cmd);
   if(count==0) return(Lot);

   double lastLot = ES_LastLotSize(cmd);
   if(count >= Averaging)
      return( NormalizeDouble(lastLot * LotMultiplikator, 2) );
   return(lastLot);
}

void ES_TryGridAdd()
{
   int dir = ES_BasketDirection();
   if(dir!=OP_BUY && dir!=OP_SELL) return;

   int existing = ES_CountTrades(dir);
   if(existing >= MaxTrades) return;

   // set basket flags based on direction
   g_buyBasket  = (dir==OP_BUY);
   g_sellBasket = (dir==OP_SELL);

   // determine last price and distance from current quotes
   double lastPrice = (dir==OP_BUY) ? g_lastBuyPrice : g_lastSellPrice;
   if(lastPrice <= 0.0)
      lastPrice = ES_LastOpenPrice(dir);
   double dist = (dir==OP_BUY) ? (lastPrice - Ask) : (Bid - lastPrice);

   // check grid permission (distance + optional volume filter)
   if(!g_allowGrid)
   {
      bool cond = (dist >= Step * Point);
      if(g_useVolFilter)
         cond = cond && (Volume[0] < 5);
      if(cond)
         g_allowGrid = true;
   }
   if(!g_allowGrid) return;

   double lots = ES_NextLotSize(dir);
   double price = (dir==OP_BUY) ? Ask : Bid;
   string comment = StringFormat("%s-Euro Scalper-%d", Symbol(), existing);
   int ticket = (int)ES_Log_OrderSend(Symbol(), dir, lots, price, 5,
                                      0,0, comment, Magic, 0, clrNONE);
   if(ticket>0)
   {
      RefreshRates();
      BasketTPUpdatePending = true;
      g_allowGrid = false;
      if(dir==OP_BUY)
      {
         g_buyBasket   = true;
         g_sellBasket  = false;
         g_lastBuyPrice = price;
      }
      else
      {
         g_buyBasket   = false;
         g_sellBasket  = true;
         g_lastSellPrice = price;
      }
   }
}

int init()
{
   // Use the CLEAN run tag, open the logger once, then attach
   // symbol/period/magic context without creating a placeholder file.
   ES_Log_RunTag = ES_RUN_TAG;
   ES_Log_OnInit();
   ES_Log_SetContext(_Symbol, Period(), Magic);
   return(0);
}

int start()
{
   if(!ES_CanTradeNow())
      return(0);

   if(OrdersTotal() == 0)
      ES_OpenFirstTrade();
   else
      ES_TryGridAdd();

   if(BasketTPUpdatePending)
      ES_UpdateBasketTP();
   return(0);
}

int deinit()
{
   ES_Log_OnDeinit();
   return(0);
}
