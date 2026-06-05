#property copyright "Learn how to develop Expert Advisors like this (With this as one of the class projects)"
#property link      "https://www.udemy.com/course/mql5-the-complete-guide-2026-incl-5-real-life-projects/?referralCode=F17445AEBB6823B4E6B6"
#property version   "1.00"

#include <Trade\Trade.mqh>
CTrade trade;

#include <Trade\PositionInfo.mqh>
CPositionInfo pinfo;

input group "GENERAL SETTINGS"
input int magic = 4162026; // Magic Number
input double lot = 0.01; // Lotsize
input ENUM_TIMEFRAMES timeframe = PERIOD_M6; // Timeframe
input double reward = 7; // Reward to Risk
input bool use_trailing = false; // Use Trailing
input string comment = "Keltner Channels EA"; // Trade Comment

input group "KELTNER CHANNEL SETTINGS"
input int period_of_ema = 20; // Period of EMA
input int period_of_atr = 10; // Period of ATR
input double atr_multiplier = 1; // ATR Multiplier
input bool show_price_of_level = true; // Show Price of Level

input group "MOVING AVERAGE SETTINGS"
input int ma_period = 200; // MA Period
input ENUM_MA_METHOD ma_method = MODE_EMA; // MA Method
input ENUM_APPLIED_PRICE ma_price = PRICE_CLOSE; // MA Applied Price

datetime last_check_bar; 
double sl;
int handle_keltner;
int handle_ma;

int OnInit(){
   trade.SetExpertMagicNumber(magic);
   
   handle_keltner = iCustom(Symbol(),timeframe,"Free Indicators\\Keltner Channel.ex5",period_of_ema,period_of_atr,atr_multiplier,show_price_of_level);
   handle_ma = iMA(Symbol(),timeframe,ma_period,0,ma_method,ma_price);
   
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason){

}

void OnTick(){
   KeltnerChannels();
}

void KeltnerChannels(){
   int trade_index = lastPositionIndex();
   double Ask = SymbolInfoDouble(Symbol(),SYMBOL_ASK);
   double Bid = SymbolInfoDouble(Symbol(),SYMBOL_BID);
   
   if(trade_index==-1){
      if(last_check_bar==iTime(Symbol(),timeframe,0)) return;
      
      double upperKeltner[];
      double lowerKeltner[];
      CopyBuffer(handle_keltner,0,0,2,upperKeltner);
      CopyBuffer(handle_keltner,2,0,2,lowerKeltner);
      ArraySetAsSeries(upperKeltner, true);
      ArraySetAsSeries(lowerKeltner, true);
      
      double ma[];
      CopyBuffer(handle_ma,0,0,2,ma);
      ArraySetAsSeries(ma, true);
      
      double close = iClose(Symbol(),timeframe,1);
      double open = iOpen(Symbol(),timeframe,1);
      
      ENUM_POSITION_TYPE last_direction = GetLastDirection();
      
      if(open>upperKeltner[1] && close>upperKeltner[1] && close>ma[1]){//last_direction==POSITION_TYPE_SELL && 
         double stop = lowerKeltner[1];
         sl = Ask - stop;
         double target = use_trailing ? 0 : Ask + (sl*reward);
         
         bool res = trade.Buy(lot,Symbol(),Ask,stop,target,comment);
         if(!res) Print("OrderSend Error #", GetLastError());
      }else if(open<lowerKeltner[1] && close<lowerKeltner[1] && close<ma[1]){ //last_direction==POSITION_TYPE_BUY && 
         double stop = upperKeltner[1];
         sl = stop - Bid;
         double target = use_trailing ? 0 : Bid - (sl*reward);
         
         bool res = trade.Sell(lot,Symbol(),Bid,stop,target,comment);
         if(!res) Print("OrderSend Error #", GetLastError());
      }
      
      last_check_bar = iTime(Symbol(),timeframe,0);
   }else{
      if(use_trailing && pinfo.SelectByIndex(trade_index)){
         double entry = pinfo.PriceOpen();
         double current = pinfo.PriceCurrent();
         double old_sl = pinfo.StopLoss();
         
         if(pinfo.PositionType()==POSITION_TYPE_BUY && (current-old_sl)>=(2*sl)){
            double new_sl = current - sl;
            trade.PositionModify(pinfo.Ticket(),new_sl,pinfo.TakeProfit());
         }else if(pinfo.PositionType()==POSITION_TYPE_SELL && (old_sl-current)>=(2*sl)){
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

ENUM_POSITION_TYPE GetLastDirection(){
   int bars = iBars(Symbol(),timeframe) - period_of_ema; 
   double upperKeltner[];
   double lowerKeltner[];
   CopyBuffer(handle_keltner,0,0,bars,upperKeltner);
   CopyBuffer(handle_keltner,2,0,bars,lowerKeltner);
   ArraySetAsSeries(upperKeltner, true);
   ArraySetAsSeries(lowerKeltner, true);
   
   for(int i=2; i<bars-1; i++){
      double low = iLow(Symbol(),timeframe,i);
      double high = iHigh(Symbol(),timeframe,i);
      
      if(high>=upperKeltner[i]) return POSITION_TYPE_BUY;
      else if(low<=lowerKeltner[i]) return POSITION_TYPE_SELL;
   }
   
   return -1;
}