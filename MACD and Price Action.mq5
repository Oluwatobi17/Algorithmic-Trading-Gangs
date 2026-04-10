#property copyright "Learn how to develop Indicator/EA like this (With this Indicator as one of the practice projects)"
#property link      "https://www.udemy.com/course/mql5-the-complete-guide-2026-incl-5-real-life-projects/?referralCode=F17445AEBB6823B4E6B6"
#property version   "1.00"
//#property icon "\\Images\\mql5_academy_logo.ico"

#include <Trade\Trade.mqh>
CTrade trade;

#include <Trade\PositionInfo.mqh>
CPositionInfo pinfo;

input int magic = 272026; // Magic Number
input double lot = 0.01; // Lotsize
input ENUM_TIMEFRAMES low_TF = PERIOD_M15; // Lower Timeframe
input ENUM_TIMEFRAMES high_TF = PERIOD_H1; // Higher Timeframe
input double extra_sl = 5; // Extra Stoploss(Pips)
input double reward = 3; // Reward to Risk
input string comment = "MACD + Price Action EA"; // Trade Comment

input int fast_ema = 12; // Fast EMA
input int slow_ema = 26; // Slow EMA
input int macd_sma = 9; // MACD SMA
input ENUM_APPLIED_PRICE macd_price = PRICE_CLOSE; // MACD Applied Price

input bool use_breakeven = true; // Use Breakeven
input double breakeven_at = 1; // Breakeven At Ratio
input double breakeven_extra = 5; // Breakeven Extra(Pips)

input bool use_martingale = false;// Use Martingale
input double martingale_distance = 20; // Martingale Distance(Pips)
input double martingale_multiplier = 1; // Multiplier
input double martingale_BE = 1; // Martingale Breakeven($)

#resource "\\Indicators\\Examples\\ZigZag.ex5"


// VARIABLES
datetime last_entry = 0;
int handle_macd;
int handle_zigzag;

int OnInit(){
   trade.SetExpertMagicNumber(magic);
   
   handle_macd = iMACD(Symbol(),low_TF,fast_ema,slow_ema,macd_sma,macd_price);
   handle_zigzag = iCustom(Symbol(),high_TF,"::Examples\\ZigZag.ex5");
   
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason){

}

void OnTick(){
   MACD_Price_Action( Symbol() );
}

void MACD_Price_Action(string pair){
   int trade_index = lastOrderIndex();
   double Ask = SymbolInfoDouble(pair,SYMBOL_ASK);
   double Bid = SymbolInfoDouble(pair,SYMBOL_BID);
   
   if(trade_index==-1){
      if(last_entry==iTime(Symbol(),low_TF,0)) return;
      
      int res = RecentZigHigh();
      int sup = RecentZigLow();
      double resistance = iHigh(pair,high_TF,res);
      double support = iLow(pair,high_TF,sup);
      
      double macd[]; double signal[];
      CopyBuffer(handle_macd,0,0,5,macd);
      CopyBuffer(handle_macd,1,0,5,signal);
      ArraySetAsSeries(macd,true);
      ArraySetAsSeries(signal,true);
      
      double low = iLow(pair,high_TF,0);
      double high = iHigh(pair,high_TF,0);
      double low1 = iLow(pair,high_TF,1);
      double high1 = iHigh(pair,high_TF,1);
      double low2 = iLow(pair,high_TF,2);
      double high2 = iHigh(pair,high_TF,2);
      
      double extra = extra_sl*_Point*10;
      
      if(macd[1]>signal[1] && macd[2]<signal[2] && macd[1]<0 && ((low<=support && high>=support) || (low1<=support && high1>=support) || (low2<=support && high2>=support))){
         double stop = NearestSwingLow() - extra;
         double sl = Ask - stop;
         double target = Ask + (reward*sl);
         if(use_martingale) stop = 0;
         
         bool res = trade.Buy(lot,pair,Ask,stop,target,comment);
         if(res) last_entry = iTime(pair,low_TF,0);
         else Print("OrderSend Error #", GetLastError());
      }else if(macd[1]<signal[1] && macd[2]>signal[2] && macd[1]>0 && ((low<=resistance && high>=resistance) || (low1<=resistance && high1>=resistance) || (low2<=resistance && high2>=resistance))){
         double stop = NearestSwingHigh() + extra;
         double sl = stop - Bid;
         double target = Bid - (reward*sl);
         if(use_martingale) stop = 0;
         
         bool res = trade.Sell(lot,pair,Bid,stop,target,comment);
         if(res) last_entry = iTime(pair,low_TF,0);
         else Print("OrderSend Error #", GetLastError());
      }
   }else{
      int count = TotalPositions();
      
      if(pinfo.SelectByIndex(trade_index)){
         double current = pinfo.PriceCurrent();
         double entry = pinfo.PriceOpen();
         double old_sl = pinfo.StopLoss();
         int pos_type = pinfo.PositionType();
         
         // BREAKEVEN
         if(use_breakeven && count==1){
            double BE = MathAbs(old_sl-entry)*breakeven_at;
            double commission = breakeven_extra*_Point*10;
            
            if(pos_type==POSITION_TYPE_BUY && (current-entry)>=BE && old_sl<entry){
               bool res = trade.PositionModify(pinfo.Ticket(),entry+commission,pinfo.TakeProfit());
               if(!res) Print("OrderModify failed. Error #", GetLastError());
            }else if(pos_type==POSITION_TYPE_SELL && (entry-current)>=BE && old_sl>entry){
               bool res = trade.PositionModify(pinfo.Ticket(),entry-commission,pinfo.TakeProfit());
               if(!res) Print("OrderModify failed. Error #", GetLastError());
            }
         }
         
         // MARTINGALE
         if(use_martingale){
            double mart = -1*martingale_distance*_Point*10; // -0.0010
            double new_lot = RoundLotsize(lot*MathPow(martingale_multiplier,count));
            
            if(pos_type==POSITION_TYPE_BUY && (current-entry)<=mart){
               trade.Buy(new_lot,pair,Ask,0,0,comment);
            }else if(pos_type==POSITION_TYPE_SELL && (entry-current)<=mart){
               trade.Sell(new_lot,pair,Bid,0,0,comment);
            }
            
            // BREAKEVEN
            if(count>1 && TotalProfit()>=martingale_BE) CloseAllPositions();
         }
      }
   }
}

// ============================ SPECIAL FUNCTIONS ============================ 
int lastOrderIndex(){
   for(int i=PositionsTotal()-1; i>=0; i--){
      if(pinfo.SelectByIndex(i) && pinfo.Symbol()==Symbol() && pinfo.Magic()==magic) return i;
   }
   
   return -1;
}

double RoundLotsize(double lotsize){
   double step = SymbolInfoDouble(Symbol(),SYMBOL_VOLUME_STEP);
   
   return MathRound(lotsize/step)*step;
}

int TotalPositions(){
   int count = 0;
   for(int i=PositionsTotal()-1; i>=0; i--){
      if(pinfo.SelectByIndex(i) && pinfo.Symbol()==Symbol() && pinfo.Magic()==magic) count++;
   }
   
   return count;
}

double TotalProfit(){
   double profit = 0;
   for(int i=PositionsTotal()-1; i>=0; i--){
      if(pinfo.SelectByIndex(i) && pinfo.Symbol()==Symbol() && pinfo.Magic()==magic){
         profit += pinfo.Profit();
      }
   }
   
   return profit;
}

void CloseAllPositions(){
   for(int i=PositionsTotal()-1; i>=0; i--){
      if(pinfo.SelectByIndex(i) && pinfo.Symbol()==Symbol() && pinfo.Magic()==magic) trade.PositionClose(pinfo.Ticket());
   }
}

int RecentZigHigh(){
   int bars = iBars(Symbol(),high_TF);
   bool lastest_seen = false;
   
   double zigzag[];
   CopyBuffer(handle_zigzag,0,0,bars,zigzag);
   ArraySetAsSeries(zigzag,true);
   
   for(int i=1; i<bars; i++){
      double high = iHigh(Symbol(),high_TF,i);
      if(high==zigzag[i] && lastest_seen==false){
         lastest_seen = true;
         continue;
      }
      
      if(lastest_seen && high==zigzag[i]) return i;
   }
   
   return -1;
}

int RecentZigLow(){
   int bars = iBars(Symbol(),high_TF);
   bool lastest_seen = false;
   
   double zigzag[];
   CopyBuffer(handle_zigzag,0,0,bars,zigzag);
   ArraySetAsSeries(zigzag,true);
   
   for(int i=1; i<bars; i++){
      double low = iLow(Symbol(),high_TF,i);
      if(low==zigzag[i] && lastest_seen==false){
         lastest_seen = true;
         continue;
      }
      
      if(lastest_seen && low==zigzag[i]) return i;
   }
   
   return -1;
}

double NearestSwingLow(){
   int bars = iBars(Symbol(),low_TF);
   
   for(int i=1; i<bars; i++){
      double low0 = iLow(Symbol(),low_TF,i); // RIGHT
      double low1 = iLow(Symbol(),low_TF,i+1); // MIDDLE
      double low2 = iLow(Symbol(),low_TF,i+2); // LEFT
      
      if(low1<low0 && low1<low2) return low1;
   }
   
   return -1;
}

double NearestSwingHigh(){
   int bars = iBars(Symbol(),low_TF);
   
   for(int i=1; i<bars; i++){
      double high0 = iHigh(Symbol(),low_TF,i); // RIGHT
      double high1 = iHigh(Symbol(),low_TF,i+1); // MIDDLE
      double high2 = iHigh(Symbol(),low_TF,i+2); // LEFT
      
      if(high1>high0 && high1>high2) return high1;
   }
   
   return -1;
}