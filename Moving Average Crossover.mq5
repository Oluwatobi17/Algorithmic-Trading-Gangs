#property copyright "Learn how to develop Indicator/EA like this (With this Indicator as one of the practice projects)"
#property link      "https://www.udemy.com/course/mql5-the-complete-guide-2026-incl-5-real-life-projects/?referralCode=F17445AEBB6823B4E6B6"
#property version   "1.00"
//#property icon "\\Images\\mql5_academy_logo.ico"

#include <Trade\Trade.mqh>
CTrade trade;

#include <Trade\PositionInfo.mqh>
CPositionInfo pinfo;

input group "GENERAL SETTINGS"
input int magic = 27022026; // Magic Number
input double lot = 0.01; // Lotsize
input ENUM_TIMEFRAMES timeframe = PERIOD_CURRENT; // Timeframe
input string comment = "MA Crossover EA"; // Trade Comment 

input group "FAST MA SETTINGS"
input int fast_ma = 46; // Fast MA Period
input ENUM_MA_METHOD fast_ma_method = MODE_SMA; // Fast MA Method

input group "SLOW MA SETTINGS"
input int slow_ma = 155; // Slow MA Period
input ENUM_MA_METHOD slow_ma_method = MODE_LWMA; // Slow MA Method

int handle_fast;
int handle_slow;

int OnInit(){
   trade.SetExpertMagicNumber(magic);
   
   handle_fast = iMA(Symbol(),timeframe,fast_ma,0,fast_ma_method,PRICE_CLOSE);
   handle_slow = iMA(Symbol(),timeframe,slow_ma,0,slow_ma_method,PRICE_CLOSE);
   
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason){

}

void OnTick(){
   MACrossover();
}

void MACrossover(){
   int trade_index = lastPositionIndex();
   
   double fast[]; double slow[];
   CopyBuffer(handle_fast,0,0,5,fast);
   CopyBuffer(handle_slow,0,0,5,slow);
   ArraySetAsSeries(fast,true);
   ArraySetAsSeries(slow,true);
   
   if(trade_index==-1){
      if(fast[1]>slow[1] && fast[2]<slow[2]){ // BUY
         bool res = trade.Buy(lot,Symbol(),0,0,0,comment);
         if(res==false) Print("OrderSend Error #", GetLastError());
      }else if(fast[1]<slow[1] && fast[2]>slow[2]){ // SELL
         bool res = trade.Sell(lot,Symbol(),0,0,0,comment);
         if(res==false) Print("OrderSend Error #", GetLastError());
      }
   }else{
      if(pinfo.SelectByIndex(trade_index)){
         if(pinfo.PositionType()==POSITION_TYPE_BUY && fast[1]<slow[1] && fast[2]>slow[2]){
            trade.PositionClose(pinfo.Ticket());
         }else if(pinfo.PositionType()==POSITION_TYPE_SELL && fast[1]>slow[1] && fast[2]<slow[2]){
            trade.PositionClose(pinfo.Ticket());
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