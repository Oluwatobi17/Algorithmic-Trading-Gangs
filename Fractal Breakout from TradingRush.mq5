#property copyright "Learn how to develop Expert Advisors like this (With this as one of the class projects)"
#property link      "https://www.udemy.com/course/mql5-the-complete-guide-2026-incl-5-real-life-projects/?referralCode=F17445AEBB6823B4E6B6"
#property version   "1.00"

#include <Trade\trade.mqh>
CTrade trade;

#include <Trade\PositionInfo.mqh>
CPositionInfo pinfo;

input group "GENERAL SETTINGS"
input int magic = 4112026; // Magic Number
input double lot = 0.01; // Lotsize
input ENUM_TIMEFRAMES timeframe = PERIOD_H4; // Timeframe
input double reward = 3.5; // Reward to Risk
input bool use_trailing = true; // Use Trailing
input string comment = "Fractal Breakout EA"; // Trade Comment

input group "MOVING AVERAGE SETTINGS"
input int ma_period = 200; // MA Period
input ENUM_MA_METHOD ma_method = MODE_EMA; // MA Method
input ENUM_APPLIED_PRICE ma_price = PRICE_CLOSE; // MA Applied Price

double sl;
datetime last_entry;
datetime last_check;
int handle_fractals;
int handle_ma;

int OnInit(){
   trade.SetExpertMagicNumber(magic);
   
   handle_fractals = iFractals(Symbol(),timeframe);
   handle_ma = iMA(Symbol(),timeframe,ma_period,0,ma_method,ma_price);
   
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason){

}

void OnTick(){
   FractalBreakout();
}

void FractalBreakout(){
   int trade_index = lastPositionIndex();
   double Ask = SymbolInfoDouble(Symbol(),SYMBOL_ASK);
   double Bid = SymbolInfoDouble(Symbol(),SYMBOL_BID);
   
   if(trade_index==-1){
      if(last_entry==iTime(Symbol(),timeframe,0)) return;
      if(last_check==iTime(Symbol(),timeframe,0)) return;
      
      int fractal_up_index = GetRecentFractalsUp();
      int fractal_dn_index = GetRecentFractalsDown();
      if(fractal_dn_index==-1 || fractal_up_index==-1) return;
      
      double high = iHigh(Symbol(),timeframe,fractal_up_index);
      double low = iLow(Symbol(),timeframe,fractal_dn_index);
      
      int bars = MathMax(fractal_dn_index, fractal_up_index)+3;
      double ma[];
      CopyBuffer(handle_ma,0,0,bars,ma);
      ArraySetAsSeries(ma, true);
      
      double close = iClose(Symbol(),timeframe,1);
      
      if(close>high && close>ma[1] && low>ma[fractal_dn_index]){
         double stop = low;
         sl = Ask - stop;
         double target = use_trailing ? 0 : Ask + (reward*sl);
         
         bool res = trade.Buy(lot,Symbol(),Ask,stop,target,comment);
         if(res==false) Print("OrderSend Error #", GetLastError());
         else last_entry = iTime(Symbol(),timeframe,0);
      }else if(close<low && close<ma[1] && high<ma[fractal_up_index]){
         double stop = high;
         sl = stop - Bid;
         double target = use_trailing ? 0 : Bid - (reward*sl);
         
         bool res = trade.Sell(lot,Symbol(),Bid,stop,target,comment);
         if(res==false) Print("OrderSend Error #", GetLastError());
         else last_entry = iTime(Symbol(),timeframe,0);
      }
      
      last_check = iTime(Symbol(),timeframe,0);
   }else{
      if(use_trailing && pinfo.SelectByIndex(trade_index)){
         double entry = pinfo.PriceOpen();
         double old_sl = pinfo.StopLoss();
         double current = pinfo.PriceCurrent();
         ENUM_POSITION_TYPE pos_type = pinfo.PositionType();
         
         if(pos_type==POSITION_TYPE_BUY && (current-old_sl)>=(2*sl)){
            double new_sl = current - sl;
            trade.PositionModify(pinfo.Ticket(),new_sl,pinfo.TakeProfit());
         }else if(pos_type==POSITION_TYPE_SELL && (old_sl-current)>=(2*sl)){
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

int GetRecentFractalsUp(){
   int bars = iBars(Symbol(),timeframe);
   double fractal_up[];
   CopyBuffer(handle_fractals,0,0,bars,fractal_up);
   ArraySetAsSeries(fractal_up, true);
   
   for(int i=2; i<bars; i++){
      double high = iHigh(Symbol(),timeframe,i);
      if(fractal_up[i]==high) return i;
   }
   
   return -1;
}

int GetRecentFractalsDown(){
   int bars = iBars(Symbol(),timeframe);
   double fractal_dn[];
   CopyBuffer(handle_fractals,1,0,bars,fractal_dn);
   ArraySetAsSeries(fractal_dn, true);
   
   for(int i=2; i<bars; i++){
      double low = iLow(Symbol(),timeframe,i);
      if(fractal_dn[i]==low) return i;
   }
   
   return -1;
}