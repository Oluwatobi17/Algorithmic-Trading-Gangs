#property copyright "Learn how to develop Expert Advisors like this (With this as one of the class projects)"
#property link      "https://www.udemy.com/course/mql5-the-complete-guide-2026-incl-5-real-life-projects/?referralCode=F17445AEBB6823B4E6B6"
#property version   "1.00"

#include <Trade\Trade.mqh>
CTrade trade;

#include <Trade\PositionInfo.mqh>
CPositionInfo pinfo;

input group "GENERAL SETTINGS"
input int magic = 4142026; // Magic Number
input double lot = 0.01; // Lotsize
input ENUM_TIMEFRAMES timeframe = PERIOD_H4; // Timeframe
input double extra_sl = 20; // Extra Stoploss(Pips)
input bool use_trailing = true; // Use Trailing
input string comment = "Bollinger + RSI EA"; // Trade Comment

input group "BOLLINGER BANDS SETTINGS"
input int bb_period = 14; // BB Period
input double bb_deviation = 2; // BB Deviation
input ENUM_APPLIED_PRICE bb_price = PRICE_CLOSE; // BB Applied Price

input group "RSI SETTINGS"
input int rsi_period = 14; // RSI Period
input ENUM_APPLIED_PRICE rsi_price = PRICE_CLOSE; // RSI Applied Price

int handle_bb;
int handle_rsi;
double sl;
datetime last_entry = 0;

int OnInit(){
   trade.SetExpertMagicNumber(magic);
   
   handle_bb = iBands(Symbol(),timeframe,bb_period,0,bb_deviation,bb_price);
   handle_rsi = iRSI(Symbol(),timeframe,rsi_period,rsi_price);

   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason){

}

void OnTick(){
   BollingerBandRSI();
}

void BollingerBandRSI(){
   int trade_index = lastPositionIndex();
   double Ask = SymbolInfoDouble(Symbol(),SYMBOL_ASK);
   double Bid = SymbolInfoDouble(Symbol(),SYMBOL_BID);
   
   double upperBB[]; double lowerBB[];
   CopyBuffer(handle_bb,1,0,5,upperBB);
   CopyBuffer(handle_bb,2,0,5,lowerBB);
   ArraySetAsSeries(upperBB, true);
   ArraySetAsSeries(lowerBB, true);
   
   if(trade_index==-1){
      if(last_entry==iTime(Symbol(),timeframe,0)) return;
      double rsi[];
      CopyBuffer(handle_rsi,0,0,5,rsi);
      ArraySetAsSeries(rsi, true);
      
      double low = iLow(Symbol(),timeframe,1);
      double high = iHigh(Symbol(),timeframe,1);
      double close = iClose(Symbol(),timeframe,1);
      
      if(low<=lowerBB[1] && rsi[1]>50 && rsi[2]<50 && close>lowerBB[1]){
         double stop = MathMin(iLow(Symbol(),timeframe,1), iLow(Symbol(),timeframe,2)) - (extra_sl*_Point*10);
         sl = Ask - stop;
         
         bool res = trade.Buy(lot,Symbol(),Ask,stop,0,comment);
         if(res==false) Print("OrderSend Error #", GetLastError());
         else last_entry = iTime(Symbol(),timeframe,0);
      }else if(high>=upperBB[1] && rsi[1]<50 && rsi[2]>50 && close<upperBB[1]){
         double stop = MathMax(iHigh(Symbol(),timeframe,1), iHigh(Symbol(),timeframe,2)) + (extra_sl*_Point*10);
         sl = stop - Bid;
         
         bool res = trade.Sell(lot,Symbol(),Bid,stop,0,comment);
         if(res==false) Print("OrderSend Error #", GetLastError());
         else last_entry = iTime(Symbol(),timeframe,0);
      }
   }else{
      if(pinfo.SelectByIndex(trade_index)){
         ENUM_POSITION_TYPE pos_type = pinfo.PositionType();
         double current = pinfo.PriceCurrent();
         double entry = pinfo.PriceOpen();
         double old_sl = pinfo.StopLoss();
         
         if(!use_trailing){ // TAKEPROFIT
            if(pos_type==POSITION_TYPE_BUY && Ask>=upperBB[0]){
               bool res = trade.PositionClose(pinfo.Ticket());
               return;
            }else if(pos_type==POSITION_TYPE_SELL && Bid<=lowerBB[0]){
               bool res = trade.PositionClose(pinfo.Ticket());
               return;
            }
         }
         
         if(use_trailing){
            if(pos_type==POSITION_TYPE_BUY && (current-old_sl)>=(2*sl)){
               double new_sl = current - sl;
               bool res = trade.PositionModify(pinfo.Ticket(),new_sl,pinfo.TakeProfit());
            }else if(pos_type==POSITION_TYPE_SELL && (old_sl-current)>=(2*sl)){
               double new_sl = current + sl;
               bool res = trade.PositionModify(pinfo.Ticket(),new_sl,pinfo.TakeProfit());
            }
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