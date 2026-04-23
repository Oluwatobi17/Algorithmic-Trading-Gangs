#property copyright "Learn how to develop Expert Advisors like this (With this as one of the class projects)"
#property link      "https://www.udemy.com/course/mql5-the-complete-guide-2026-incl-5-real-life-projects/?referralCode=F17445AEBB6823B4E6B6"
#property version   "1.00"
//#property icon "\\Images\\mql5_academy_logo.ico"

#include <Trade\Trade.mqh>
CTrade trade;

#include <Trade\PositionInfo.mqh>
CPositionInfo pinfo;

input group "GENERAL SETTINGS"
input int magic = 3132026; // Magic Number
input double lot = 0.01; // Lotsize
input ENUM_TIMEFRAMES timeframe = PERIOD_CURRENT; // Timeframe
input double extra_sl = 15; // Extra Stoploss(Pips)
input string comment = "First 50k EA"; // Trade Comment

input group "BOLLINGER BAND SETTINGS"
input int bb_period = 20; // Bollinger Band Period
input double bb_deviation = 2; // Bollinger Band Period

input group "MA SETTINGS"
input int ma_period = 9; // MA Period
input ENUM_MA_METHOD ma_method = MODE_SMA; // MA Method

int handle_bb;
int handle_ma;
double sl;
datetime last_entry = 0;

int OnInit(){
   trade.SetExpertMagicNumber(magic);
   
   handle_bb = iBands(Symbol(),timeframe,bb_period,0,bb_deviation,PRICE_CLOSE);
   handle_ma = iMA(Symbol(),timeframe,ma_period,0,ma_method,PRICE_CLOSE);
   
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason){

}

void OnTick(){
   First50k();
}

void First50k(){
   int trade_index = lastPositionIndex();
   double Ask = SymbolInfoDouble(Symbol(),SYMBOL_ASK);
   double Bid = SymbolInfoDouble(Symbol(),SYMBOL_BID);
   
   double ma[];
   CopyBuffer(handle_ma,0,0,5,ma);
   ArraySetAsSeries(ma,true);
   
   double upperBand[]; double lowerBand[]; double midBand[];
   CopyBuffer(handle_bb,1,0,5,upperBand);
   CopyBuffer(handle_bb,2,0,5,lowerBand);
   CopyBuffer(handle_bb,0,0,5,midBand);
   ArraySetAsSeries(upperBand,true);
   ArraySetAsSeries(lowerBand,true);
   ArraySetAsSeries(midBand,true);
      
   
   if(trade_index==-1){
      if(last_entry==iTime(Symbol(),timeframe,0)) return;
      
      if(upperBand[1]>upperBand[2] && lowerBand[1]<lowerBand[2]){
         double close1 = iClose(Symbol(),timeframe,1);
         double close2 = iClose(Symbol(),timeframe,2);
         double extra = extra_sl*_Point*10;
         
         if(ma[1]<midBand[1] && close2<lowerBand[2] && close1>lowerBand[1]){
            double stop = iLow(Symbol(),timeframe,iLowest(Symbol(),timeframe,MODE_LOW,2,1)) - extra;
            sl = Ask - stop;
            
            bool res = trade.Buy(lot,Symbol(),Ask,stop,0,"TP1-"+comment);
            if(res && trade.Buy(lot,Symbol(),Ask,stop,0,"TP2-"+comment)){
               res = trade.Buy(lot,Symbol(),Ask,stop,0,"TP3-"+comment);
               
               if(res) last_entry = iTime(Symbol(),timeframe,0);
            }
         }else if(ma[1]>midBand[1] && close2>upperBand[2] && close1<upperBand[1]){
            double stop = iHigh(Symbol(),timeframe,iHighest(Symbol(),timeframe,MODE_HIGH,2,1)) + extra;
            sl = stop - Bid;
            
            bool res = trade.Sell(lot,Symbol(),Bid,stop,0,"TP1-"+comment);
            if(res && trade.Sell(lot,Symbol(),Bid,stop,0,"TP2-"+comment)){
               res = trade.Sell(lot,Symbol(),Bid,stop,0,"TP3-"+comment);
               
               if(res) last_entry = iTime(Symbol(),timeframe,0);
            }
         }
      }
   }else{
      for(int i=PositionsTotal()-1; i>=0; i--){
         if(pinfo.SelectByIndex(i) && pinfo.Symbol()==Symbol() && pinfo.Magic()==magic){
            string com = pinfo.Comment();
            ENUM_POSITION_TYPE pos_type = pinfo.PositionType();
            double current = pinfo.PriceCurrent();
            double entry = pinfo.PriceOpen();
            double old_sl = pinfo.StopLoss();
            
            // TAKEPROFIT 1,2,3
            if(pos_type==POSITION_TYPE_BUY){
               if(StringFind(com,"TP1-")!=-1 && Bid>=ma[1]) trade.PositionClose(pinfo.Ticket());
               else if(StringFind(com,"TP2-")!=-1 && Bid>=midBand[1]) trade.PositionClose(pinfo.Ticket());
               else if(StringFind(com,"TP3-")!=-1 && Bid>=upperBand[1]) trade.PositionClose(pinfo.Ticket());
            }else if(pos_type==POSITION_TYPE_SELL){
               if(StringFind(com,"TP1-")!=-1 && Ask<=ma[1]) trade.PositionClose(pinfo.Ticket());
               else if(StringFind(com,"TP2-")!=-1 && Ask<=midBand[1]) trade.PositionClose(pinfo.Ticket());
               else if(StringFind(com,"TP3-")!=-1 && Ask<=lowerBand[1]) trade.PositionClose(pinfo.Ticket());
            }
            
            // TRAILING
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
}

int lastPositionIndex(){
   for(int i=PositionsTotal()-1; i>=0; i--){
      if(pinfo.SelectByIndex(i) && pinfo.Symbol()==Symbol() && pinfo.Magic()==magic) return i;
   }
   
   return -1;
}