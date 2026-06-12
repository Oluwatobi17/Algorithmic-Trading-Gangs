#property copyright "Learn how to develop Expert Advisors like this (With this as one of the class projects)"
#property link      "https://www.udemy.com/course/mql5-the-complete-guide-2026-incl-5-real-life-projects/?referralCode=F17445AEBB6823B4E6B6"
#property version   "1.00"

#include <Trade\Trade.mqh>
CTrade trade;

#include <Trade\PositionInfo.mqh>
CPositionInfo pinfo;

input group "GENERAL SETTINGS"
input int magic = 4192026; // Magic Number
input double lot = 0.01; // Lotsize
input ENUM_TIMEFRAMES timeframe = PERIOD_M30; // Timeframe
input double sharpness = 0.8; // Previous Trend Sharpness
input string comment = "Bill William Alligator Strategy EA"; // Trade Comment

input group "ALLIGATOR SETTINGS"
input int jaw_period = 13; // Jaw Period
input int jaw_shift = 8; // Jaw Shift
input int teeth_period = 8; // Teeth Period
input int teeth_shift = 5; // Teeth Shift 
input int lip_period = 5; // Lip Period
input int lip_shift = 3; // Lip Shift
input ENUM_MA_METHOD alligator_method = MODE_SMMA; // Method
input ENUM_APPLIED_PRICE alligator_price = PRICE_MEDIAN; // Applied Price

input group "TREND MOVING AVERAGE"
input bool use_trend_filter = false; // Use Trend Filter
input int ma_period = 200; // MA Period
input ENUM_MA_METHOD ma_method = MODE_EMA; // MA Method
input ENUM_APPLIED_PRICE ma_price = PRICE_CLOSE; // MA Applied Price

int handle_alligator;
int handle_ma;
datetime last_check;

int OnInit(){
   trade.SetExpertMagicNumber(magic);
   
   handle_alligator = iAlligator(Symbol(),timeframe,jaw_period,jaw_shift,teeth_period,teeth_shift,lip_period,lip_shift,alligator_method,alligator_price);
   if(use_trend_filter) handle_ma = iMA(Symbol(),timeframe,ma_period,0,ma_method,ma_price);

   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason){

}

void OnTick(){
   if(last_check==iTime(Symbol(),timeframe,0)) return;
   
   Alligator();
   
   last_check = iTime(Symbol(),timeframe,0);
}

void Alligator(){
   int trade_index = lastPositionIndex();
   double Ask = SymbolInfoDouble(Symbol(),SYMBOL_ASK);
   double Bid = SymbolInfoDouble(Symbol(),SYMBOL_BID);
   
   double lips[]; double teeth[]; double jaws[];
   CopyBuffer(handle_alligator,0,0,5,jaws);
   CopyBuffer(handle_alligator,1,0,5,teeth);
   CopyBuffer(handle_alligator,2,0,5,lips);
   ArraySetAsSeries(jaws, true);
   ArraySetAsSeries(teeth, true);
   ArraySetAsSeries(lips, true);
   
   if(trade_index==-1){
      double ma[];
      if(use_trend_filter){
         CopyBuffer(handle_ma,0,0,5,ma);
         ArraySetAsSeries(ma, true);
      }
      
      double close = iClose(Symbol(),timeframe,1);
      
      if((!use_trend_filter || close>ma[1]) && lips[1]<teeth[1] && teeth[1]<jaws[1] && close>teeth[1] && WasBearish()){
         bool res = trade.Buy(lot,Symbol(),Ask,0,0,comment);
         
         if(res==false) Print("OrderSend Error #", GetLastError());
      }else if((!use_trend_filter || close<ma[1]) && lips[1]>teeth[1] && teeth[1]>jaws[1] && close<teeth[1] && WasBullish()){
         bool res = trade.Sell(lot,Symbol(),Bid,0,0,comment);
         
         if(res==false) Print("OrderSend Error #", GetLastError());
      }
   }else{
      if(pinfo.SelectByIndex(trade_index)){
         double close = iClose(Symbol(),timeframe,1);
         
         if(pinfo.PositionType()==POSITION_TYPE_BUY && close<=lips[1]) trade.PositionClose(pinfo.Ticket());
         else if(pinfo.PositionType()==POSITION_TYPE_SELL && close>=lips[1]) trade.PositionClose(pinfo.Ticket());
      }
   }
}

int lastPositionIndex(){
   for(int i=PositionsTotal()-1; i>=0; i--){
      if(pinfo.SelectByIndex(i) && pinfo.Symbol()==Symbol() && pinfo.Magic()==magic) return i;
   }
   
   return -1;
}

bool WasBearish(){
   int bars = iBars(Symbol(),timeframe);
   
   double lips[]; double teeth[]; double jaws[];
   CopyBuffer(handle_alligator,0,0,bars,jaws);
   CopyBuffer(handle_alligator,1,0,bars,teeth);
   CopyBuffer(handle_alligator,2,0,bars,lips);
   ArraySetAsSeries(jaws, true);
   ArraySetAsSeries(teeth, true);
   ArraySetAsSeries(lips, true);
   
   double bear = 0; 
   double total = 1.0;
   
   for(int i=2; i<bars; i++){
      bool valid = lips[i]<teeth[i] && teeth[i]<jaws[i];
      
      if(valid==false) break;
      
      double high = iHigh(Symbol(),timeframe,i);
      
      if(high<lips[i]) bear++;
      
      total++;
   }
   
   double percent = bear/total;
   
   return percent>=sharpness;
}

bool WasBullish(){
   int bars = iBars(Symbol(),timeframe);
   
   double lips[]; double teeth[]; double jaws[];
   CopyBuffer(handle_alligator,0,0,bars,jaws);
   CopyBuffer(handle_alligator,1,0,bars,teeth);
   CopyBuffer(handle_alligator,2,0,bars,lips);
   ArraySetAsSeries(jaws, true);
   ArraySetAsSeries(teeth, true);
   ArraySetAsSeries(lips, true);
   
   double bull = 0; 
   double total = 1.0;
   
   for(int i=2; i<bars; i++){
      bool valid = lips[i]>teeth[i] && teeth[i]>jaws[i];
      
      if(valid==false) break;
      
      double low = iLow(Symbol(),timeframe,i);
      
      if(low>lips[i]) bull++;
      
      total++;
   }
   
   double percent = bull/total;
   
   return percent>=sharpness;
}