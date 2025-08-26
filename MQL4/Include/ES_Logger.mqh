
// === Added: Run tag for log filename (BASELINE/CLEAN) ===
#ifndef ES_RUN_TAG
#define ES_RUN_TAG "RUN"
#endif
string ES_Log_RunTag = ES_RUN_TAG;
// ================================================
// ES_Logger.mqh - logging & wrappers for EuroScalper
#property strict

// ===== Order type (human-readable) =====
string ES_OrderTypeToReadable(const int op)
{
   switch(op)
   {
      case OP_BUY:       return "BUY";
      case OP_SELL:      return "SELL";
      case OP_BUYLIMIT:  return "BUY LIMIT";
      case OP_SELLLIMIT: return "SELL LIMIT";
      case OP_BUYSTOP:   return "BUY STOP";
      case OP_SELLSTOP:  return "SELL STOP";
      default:           return "-1";
   }
}

string ES_OrderTypeCell(const int op)
{
   return ES_OrderTypeToReadable(op);
}

#include <EuroScalper_Logging_Config.mqh>

int     ES_log_handle = INVALID_HANDLE;
string  ES_log_path   = "";
string  ES_log_symbol = "";
int     ES_log_period = 0;
int     ES_log_magic  = 0;
bool    ES_log_ready  = false;

string ES_TimeToStr(datetime t) { return TimeToString(t, TIME_DATE|TIME_SECONDS); }

void ES_Log_OpenFile() {
   if(!ES_Log_Enable) return;
   // Construct path: MQL4/Files/EuroScalperLogs/<Symbol>_<Magic>_<YYYYMMDD_HHMMSS>.csv
   string dt = TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES|TIME_SECONDS);
   // Normalize filename: replace ':' and ' ' with '_'
   for(int i=0; i<StringLen(dt); i++) {
      ushort ch = StringGetCharacter(dt, i);
      if(ch==':' || ch==' ') dt = StringSubstr(dt,0,i) + "_" + StringSubstr(dt,i+1);
   }
   string fname = "EuroScalperLogs/" + ES_log_symbol + "_" + dt + "_" + ES_Log_RunTag + ".csv";
   ES_log_path = fname;
   int flags = FILE_CSV|FILE_WRITE|FILE_READ|FILE_SHARE_WRITE|FILE_SHARE_READ;
   ES_log_handle = FileOpen(ES_log_path, flags, ';');
   if(ES_log_handle==INVALID_HANDLE) { return; }
   // header
   FileWrite(ES_log_handle,
      "timestamp","event","symbol","period","magic",
      "bid","ask","spread",
      "ticket","order_type","lots","price","sl","tp","slip","result","error",
      "floating_pl","closed_pl_today",
      "vwap","basket_tp",
      "note"
   );
   FileFlush(ES_log_handle);
   ES_log_ready = true;
}

void ES_Log_OnInit() {
   if(!ES_Log_Enable) return;
   ES_log_symbol = _Symbol;
   ES_log_period = Period();
   // magic may not be known yet; set when available
   ES_Log_OpenFile();
}

void ES_Log_OnDeinit() {
   if(ES_log_handle!=INVALID_HANDLE) {
      FileFlush(ES_log_handle);
      FileClose(ES_log_handle);
      ES_log_handle = INVALID_HANDLE;
   }
}

void ES_Log_SetContext(string sym, int per, int magic) {
   if(!ES_Log_Enable) return;
   ES_log_symbol = sym;
   ES_log_period = per;
   ES_log_magic  = magic;
   if(ES_log_handle==INVALID_HANDLE) ES_Log_OpenFile();
}

double ES_CurrentFloatingPL() {
   double pl=0;
   for(int i=OrdersTotal()-1;i>=0;i--) if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) {
      if(OrderSymbol()==ES_log_symbol && OrderMagicNumber()==ES_log_magic) {
         if(OrderType()==OP_BUY || OrderType()==OP_SELL) pl += OrderProfit()+OrderSwap()+OrderCommission();
      }
   }
   return pl;
}

double ES_ClosedPL_Today() {
   double pl=0;
   datetime daystart = iTime(ES_log_symbol, PERIOD_D1, 0);
   for(int i=OrdersHistoryTotal()-1;i>=0;i--) if(OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) {
      if(OrderSymbol()==ES_log_symbol && OrderMagicNumber()==ES_log_magic) {
         if(OrderCloseTime()>=daystart && OrderType()<=OP_SELL) pl += OrderProfit()+OrderSwap()+OrderCommission();
      }
   }
   return pl;
}

void ES_Log_Write(string event, int ticket, int op, double lots, double price, double sl, double tp, int slip, int result_code, int err, string note) {
   if(!ES_Log_Enable || !ES_log_ready || ES_log_handle==INVALID_HANDLE) return;
   double bid=MarketInfo(ES_log_symbol, MODE_BID);
   double ask=MarketInfo(ES_log_symbol, MODE_ASK);
   double spr=MarketInfo(ES_log_symbol, MODE_SPREAD);
   double floating = ES_CurrentFloatingPL();
   double closed   = ES_ClosedPL_Today();
   // We don't recompute VWAP/basket_tp here; they are optionally provided via dedicated events
   FileWrite(ES_log_handle,
      ES_TimeToStr(TimeCurrent()), event, ES_log_symbol, IntegerToString(ES_log_period), IntegerToString(ES_log_magic),
      DoubleToString(bid, _Digits), DoubleToString(ask, _Digits), DoubleToString(spr, 0),
      IntegerToString(ticket), ES_OrderTypeCell(op), DoubleToString(lots, 2), DoubleToString(price, _Digits), DoubleToString(sl, _Digits), DoubleToString(tp, _Digits), IntegerToString(slip),
      IntegerToString(result_code), IntegerToString(err),
      DoubleToString(floating, 2), DoubleToString(closed, 2),
      "", "", // vwap, basket_tp (unused here)
      note
   );
   if(ES_Log_FlushEvery>0) FileFlush(ES_log_handle);
}

void ES_Log_Event_Double(string event, string key, double val) {
   string note = key + "=" + DoubleToString(val,2);
   ES_Log_Write(event, 0, -1, 0, 0, 0, 0, 0, 1, 0, note);
}

void ES_Log_Event_EquityStop(double dd_amt, double risk_frac, double peak_eq, double floating) {
   string note = "dd=" + DoubleToString(dd_amt,2) + "; risk_frac=" + DoubleToString(risk_frac,2) + "; peak=" + DoubleToString(peak_eq,2) + "; floating=" + DoubleToString(floating,2);
   ES_Log_Write("EQUITY_STOP_HIT", 0, -1, 0, 0, 0, 0, 0, 1, 0, note);
}

void ES_Log_Event_TPAssign(double vwap, double basket_tp) {
   if(!ES_Log_Enable || !ES_log_ready || ES_log_handle==INVALID_HANDLE) return;
   double bid=MarketInfo(ES_log_symbol, MODE_BID);
   double ask=MarketInfo(ES_log_symbol, MODE_ASK);
   double spr=MarketInfo(ES_log_symbol, MODE_SPREAD);
   double floating = ES_CurrentFloatingPL();
   double closed   = ES_ClosedPL_Today();
   FileWrite(ES_log_handle,
      ES_TimeToStr(TimeCurrent()), "BASKET_TP_ASSIGN", ES_log_symbol, IntegerToString(ES_log_period), IntegerToString(ES_log_magic),
      DoubleToString(bid, _Digits), DoubleToString(ask, _Digits), DoubleToString(spr, 0),
      IntegerToString(0), "-1", "", "", "", "", IntegerToString(0),
      IntegerToString(1), IntegerToString(0),
      DoubleToString(floating, 2), DoubleToString(closed, 2),
      DoubleToString(vwap, _Digits), DoubleToString(basket_tp, _Digits),
      ""
   );
   if(ES_Log_FlushEvery>0) FileFlush(ES_log_handle);
}

// ---------- Wrappers ----------

int ES_Log_OrderSend(string symbol, int cmd, double volume, double price, int slippage, double stoploss, double takeprofit, string comment, int magic, datetime expiration, color arrow_color) {
   if(ES_log_magic==0) ES_log_magic = magic;
   ES_Log_Write("ORDER_SEND_ATTEMPT", 0, cmd, volume, price, stoploss, takeprofit, slippage, 0, 0, comment);
   ResetLastError();
   int ticket = OrderSend(symbol, cmd, volume, price, slippage, stoploss, takeprofit, comment, magic, expiration, arrow_color);
   int err = GetLastError();
   ES_Log_Write("ORDER_SEND_RESULT", ticket, cmd, volume, price, stoploss, takeprofit, slippage, ticket>0?1:0, err, comment);
   return ticket;
}

bool ES_Log_OrderClose(int ticket, double lots, double price, int slippage, color arrow_color) {
   ResetLastError();
   int op = -1; double sl=0; double tp=0; double openprice=0;
   if(OrderSelect(ticket, SELECT_BY_TICKET)) { op=OrderType(); sl=OrderStopLoss(); tp=OrderTakeProfit(); openprice=OrderOpenPrice(); }
   ES_Log_Write("ORDER_CLOSE_ATTEMPT", ticket, op, lots, price, sl, tp, slippage, 0, 0, "");
   bool ok = OrderClose(ticket, lots, price, slippage, arrow_color);
   int err = GetLastError();
   ES_Log_Write("ORDER_CLOSE_RESULT", ticket, op, lots, price, sl, tp, slippage, ok?1:0, err, "");
   return ok;
}

bool ES_Log_OrderModify(int ticket, double price, double stoploss, double takeprofit, datetime expiration, color arrow_color) {
   ResetLastError();
   int op = -1; double openprice=0;
   if(OrderSelect(ticket, SELECT_BY_TICKET)) { op=OrderType(); openprice=OrderOpenPrice(); }
   ES_Log_Write("ORDER_MODIFY_ATTEMPT", ticket, op, OrderLots(), price, stoploss, takeprofit, 0, 0, 0, "");
   bool ok = OrderModify(ticket, price, stoploss, takeprofit, expiration, arrow_color);
   int err = GetLastError();
   ES_Log_Write("ORDER_MODIFY_RESULT", ticket, op, OrderLots(), price, stoploss, takeprofit, 0, ok?1:0, err, "");
   return ok;
}
