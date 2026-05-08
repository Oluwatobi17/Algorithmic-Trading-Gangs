#property copyright "Learn how to develop Indicator/EA like this (With this Indicator as one of the practice projects)"
#property link      "https://www.udemy.com/course/mql5-the-complete-guide-2026-incl-5-real-life-projects/?referralCode=F17445AEBB6823B4E6B6"
#property version   "1.00"

#include <Trade\Trade.mqh>
CTrade trade;

#include <Trade\PositionInfo.mqh>
CPositionInfo pinfo;

input group "GENERAL SETTINGS"
input int magic = 4242026; // Magic Number
input double lot = 0.01; // Lotsize
input double reward = 5; // Reward To Risk
input ENUM_TIMEFRAMES timeframe = PERIOD_M30; // Timeframe
input bool use_trailing = false; // Use Trailing
input double extra_sl = 30; // Extra Stoploss(Pips)
input string comment = "CCI + MA Crossover EA"; // Trade Comment

input group "CCI SETTINGS"
input int cci_period = 7; // CCI Period
input ENUM_APPLIED_PRICE cci_price = PRICE_TYPICAL; // CCI Applied Price

input group "MA SETTINGS"
input int fast_ma_period = 10; // Fast MA Period
input int slow_ma_period = 30; // Slow MA Period
input ENUM_MA_METHOD ma_method = MODE_EMA; // MA Method
input ENUM_APPLIED_PRICE ma_price = PRICE_CLOSE; // MA Applied Price

int handle_cci;
int handle_fast;
int handle_slow;
double sl;
datetime last_entry;

int OnInit(){
   trade.SetExpertMagicNumber(magic);
   
   handle_cci = iCCI(Symbol(),timeframe,cci_period,cci_price);
   handle_fast = iMA(Symbol(),timeframe,fast_ma_period,0,ma_method,ma_price);
   handle_slow = iMA(Symbol(),timeframe,slow_ma_period,0,ma_method,ma_price);

   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason){

}

void OnTick(){
   CCI_MA();
}

void CCI_MA(){
   int trade_index = lastPositionIndex();
   double Ask = SymbolInfoDouble(Symbol(),SYMBOL_ASK);
   double Bid = SymbolInfoDouble(Symbol(),SYMBOL_BID);
   
   if(trade_index==-1){
      if(last_entry==iTime(Symbol(),timeframe,0)) return;
      
      double fast[]; double slow[];
      CopyBuffer(handle_fast,0,0,5,fast);
      CopyBuffer(handle_slow,0,0,5,slow);
      ArraySetAsSeries(fast,true);
      ArraySetAsSeries(slow,true);
      
      double cci[];
      CopyBuffer(handle_cci,0,0,5,cci);
      ArraySetAsSeries(cci, true);
      
      double low = iLow(Symbol(),timeframe,1);
      double high = iHigh(Symbol(),timeframe,1);
      double extra = extra_sl*_Point*10;
      
      if(fast[1]>slow[1] && cci[1]>-100 && cci[2]<-100 && low<=fast[1]){
         double stop = iLow(Symbol(),timeframe,iLowest(Symbol(),timeframe,MODE_LOW,2,1)) - extra;
         sl = Ask - stop;
         double target = use_trailing ? 0 : Ask + (reward*sl);
         
         bool res = trade.Buy(lot,Symbol(),Ask,stop,target,comment);
         if(!res) Print("OrderSend Error #", GetLastError());
         else last_entry = iTime(Symbol(),timeframe,0);
      }else if(fast[1]<slow[1] && cci[1]<100 && cci[2]>100 && high>=fast[1]){
         double stop = iHigh(Symbol(),timeframe,iHighest(Symbol(),timeframe,MODE_HIGH,2,1)) + extra;
         sl = stop - Bid;
         double target = use_trailing ? 0 : Bid - (reward*sl);
         
         bool res = trade.Sell(lot,Symbol(),Bid,stop,target,comment);
         if(!res) Print("OrderSend Error #", GetLastError());
         else last_entry = iTime(Symbol(),timeframe,0);
      }
   }else{
      if(use_trailing && pinfo.SelectByIndex(trade_index)){
         double entry = pinfo.PriceOpen();
         double current = pinfo.PriceCurrent();
         double old_sl = pinfo.StopLoss();
         ENUM_POSITION_TYPE type = pinfo.PositionType();
         
         if(type==POSITION_TYPE_BUY && (current-old_sl)>=(2*sl)){
            double new_sl = current - sl;
            trade.PositionModify(pinfo.Ticket(),new_sl,pinfo.TakeProfit());
         }else if(type==POSITION_TYPE_SELL && (old_sl-current)>=(2*sl)){
            double new_sl = current + sl;
            trade.PositionModify(pinfo.Ticket(),new_sl,pinfo.TakeProfit());
         }
      }
   }
}

int lastPositionIndex(){
   for(int i=PositionsTotal()-1; i>=0; i--){
      if(pinfo.SelectByIndex(i) && pinfo.Symbol()==Symbol() && pinfo.Magic()==magic) return i;
   }
   
   return -1;
}