#property copyright "Learn how to develop Indicator/EA like this (With this Indicator as one of the practice projects)"
#property link      "https://www.udemy.com/course/mql5-the-complete-guide-2026-incl-5-real-life-projects/?referralCode=F17445AEBB6823B4E6B6"
#property version   "1.00"
//#property icon "\\Images\\mql5_academy_logo.ico"

#include <Trade\Trade.mqh>
CTrade trade;

#include <Trade\PositionInfo.mqh>
CPositionInfo pinfo;

enum BIAS{
   ONLY_BUY, // Only Buy
   ONLY_SELL, // Only Sell
   BUY_AND_SELL, // Buy and Sell
};

input int magic = 18022026; // Magic Number
input double lot = 0.01; // Lotsize
input BIAS direction = ONLY_BUY; // Trade Direction
input double entry_extra = 3; // Entry Extra(Pips)
input double SL_extra = 3; // Stoploss Extra(Pips)
input double reward = 1.5; // Reward to Risk
input double BE_at = 1; // Breakeven At(Pips)
input bool use_trailing = true; // Use Trailing
input string comment = "5 Minutes Scalping EA"; // Trading Comment

// TRIGGER CHART
input ENUM_TIMEFRAMES trigger_TF = PERIOD_M5; // Trigger Timeframe
input int fast_ma_period = 8; // Fast MA Period
input int moderate_ma_period = 13; // Moderate MA Period
input int slow_ma_period = 21; // Slow MA Period

input ENUM_TIMEFRAMES anchor_TF = PERIOD_H2; // Anchor Timeframe
input int fast_anchor_ma_period = 8; // Fast Anchor MA Period
input int slow_anchor_ma_period = 21; // Slow Anchor MA Period

int handle_fast_ma;
int handle_mod_ma;
int handle_slow_ma;
int handle_fast_ma_anchor;
int handle_slow_ma_anchor;

int OnInit(){
   trade.SetExpertMagicNumber(magic);
   
   handle_fast_ma = iMA(Symbol(),trigger_TF,fast_ma_period,0,MODE_EMA,PRICE_CLOSE);
   handle_mod_ma = iMA(Symbol(),trigger_TF,moderate_ma_period,0,MODE_EMA,PRICE_CLOSE);
   handle_slow_ma = iMA(Symbol(),trigger_TF,slow_ma_period,0,MODE_EMA,PRICE_CLOSE);
   handle_fast_ma_anchor = iMA(Symbol(),anchor_TF,fast_anchor_ma_period,0,MODE_EMA,PRICE_CLOSE);
   handle_slow_ma_anchor = iMA(Symbol(),anchor_TF,slow_anchor_ma_period,0,MODE_EMA,PRICE_CLOSE);
   
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason){

}

void OnTick(){
   ScalpingStrategy();
}

void ScalpingStrategy(){
   int trade_index = lastPositionOrOrderIndex();
   
   if(trade_index==-1){
      double ema8[]; double ema13[]; double ema21[];
      CopyBuffer(handle_fast_ma,0,0,5,ema8);
      CopyBuffer(handle_mod_ma,0,0,5,ema13);
      CopyBuffer(handle_slow_ma,0,0,5,ema21);
      ArraySetAsSeries(ema8,true);
      ArraySetAsSeries(ema13,true);
      ArraySetAsSeries(ema21,true);
      
      double ema8_anchor[]; double ema21_anchor[];
      CopyBuffer(handle_fast_ma_anchor,0,0,5,ema8_anchor);
      CopyBuffer(handle_slow_ma_anchor,0,0,5,ema21_anchor);
      ArraySetAsSeries(ema8_anchor,true);
      ArraySetAsSeries(ema21_anchor,true);
      
      double close_anchor = iClose(Symbol(),anchor_TF,1);
      double low = iLow(Symbol(),trigger_TF,1);
      double high = iHigh(Symbol(),trigger_TF,1);
      
      // BUY
      if((direction==ONLY_BUY || direction==BUY_AND_SELL) && ema8_anchor[1]>ema21_anchor[1] && close_anchor>ema8_anchor[1] && ema8[1]>ema13[1] && ema13[1]>ema21[1] && low<=ema8[1]){
         int highest = iHighest(Symbol(),trigger_TF,MODE_HIGH,5,1);
         double price = iHigh(Symbol(),trigger_TF,highest) + (entry_extra*_Point*10);
         double stop = iLow(Symbol(),trigger_TF,1) - (SL_extra*_Point*10);
         double sl = price - stop;
         double target = use_trailing ? 0 : (price+(reward*sl));
         datetime expiration = TimeCurrent() + (5*PeriodSeconds(trigger_TF));
         
         bool res = trade.BuyStop(lot,price,Symbol(),stop,target,ORDER_TIME_SPECIFIED,expiration,comment);
      }else if((direction==ONLY_SELL || direction==BUY_AND_SELL) && ema8_anchor[1]<ema21_anchor[1] && close_anchor<ema8_anchor[1] && ema8[1]<ema13[1] && ema13[1]<ema21[1] && high>=ema8[1]){
         int lowest = iLowest(Symbol(),trigger_TF,MODE_LOW,5,1);
         double price = iLow(Symbol(),trigger_TF,lowest) - (entry_extra*_Point*10);
         double stop = iHigh(Symbol(),trigger_TF,1) + (SL_extra*_Point*10);
         double sl = stop - price;
         double target = use_trailing ? 0 : (price - (reward*sl));
         datetime expiration = TimeCurrent() + (5*PeriodSeconds(trigger_TF));
         
         bool res = trade.SellStop(lot,price,Symbol(),stop,target,ORDER_TIME_SPECIFIED,expiration,comment);
      }
   }else{
      // BREAKEVEN OR TRAILING
      int index = lastPositionIndex();
      if(pinfo.SelectByIndex(index)){
         double curr_sl = pinfo.StopLoss();
         double entry = pinfo.PriceOpen();
         double curr_price = pinfo.PriceCurrent();
         ENUM_POSITION_TYPE pos_type = pinfo.PositionType();
         double BE = MathAbs(curr_sl-entry)*BE_at;
         
         // BREAKEVEN
         if(pos_type==POSITION_TYPE_BUY && curr_sl<entry && (curr_price-entry)>=BE){
            if(trade.PositionModify(pinfo.Ticket(),entry,pinfo.TakeProfit())){
               trade.PositionClosePartial(pinfo.Ticket(),RoundLotSize(pinfo.Volume()/2));
               return;
            }
         }else if(pos_type==POSITION_TYPE_SELL && curr_sl>entry && (entry-curr_price)>=BE){
            if(trade.PositionModify(pinfo.Ticket(),entry,pinfo.TakeProfit())){
               trade.PositionClosePartial(pinfo.Ticket(),RoundLotSize(pinfo.Volume()/2));
               return;
            }
         }
         
         // TRAILING
         if(use_trailing){
            double buy_sl = iLow(Symbol(),trigger_TF, iLowest(Symbol(),trigger_TF,MODE_LOW,3,1) );
            double sell_sl = iHigh(Symbol(),trigger_TF, iHighest(Symbol(),trigger_TF,MODE_HIGH,3,1) );
            if(pos_type==POSITION_TYPE_BUY && buy_sl>entry && buy_sl>curr_sl){
               trade.PositionModify(pinfo.Ticket(),buy_sl,pinfo.TakeProfit());
            }else if(pos_type==POSITION_TYPE_SELL && sell_sl<entry && sell_sl<curr_sl){
               trade.PositionModify(pinfo.Ticket(),sell_sl,pinfo.TakeProfit());
            }
         }
      }
   }
}

int lastPositionOrOrderIndex(){
   for(int i=PositionsTotal()-1; i>=0; i--){
      if(pinfo.SelectByIndex(i) && pinfo.Symbol()==Symbol() && pinfo.Magic()==magic) return i;
   }
   
   for(int j=OrdersTotal()-1; j>=0; j--){
      ulong ticket = OrderGetTicket(j);
      if(OrderSelect(ticket) && OrderGetString(ORDER_SYMBOL)==Symbol() && OrderGetInteger(ORDER_MAGIC)==magic) return j;
   }
   
   return -1;
}

int lastPositionIndex(){
   for(int i=PositionsTotal()-1; i>=0; i--){
      if(pinfo.SelectByIndex(i) && pinfo.Symbol()==Symbol() && pinfo.Magic()==magic) return i;
   }
   
   return -1;
}

double RoundLotSize(double lotsize){
   double step = SymbolInfoDouble(Symbol(),SYMBOL_VOLUME_STEP);
   
   return MathRound(lotsize/step) * step;
}