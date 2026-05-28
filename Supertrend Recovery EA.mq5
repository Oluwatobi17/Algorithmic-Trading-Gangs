#property copyright "Learn how to develop Expert Advisors like this (With this as one of the class projects)"
#property link      "https://www.udemy.com/course/mql5-the-complete-guide-2026-incl-5-real-life-projects/?referralCode=F17445AEBB6823B4E6B6"
#property version   "1.00"

#include <Trade\Trade.mqh>
CTrade trade;

#include <Trade\PositionInfo.mqh>
CPositionInfo pinfo;

input int magic = 2232026; // Magic Number
input double lot = 0.01; // Starting Lotsize
input double lot_multiplier = 2; // Lot Multiplier
input double hedge_breakeven = 1; // Hedge Breakeven($)
input string comment = "Supertrend Recovery EA"; // Trade Comment

input bool use_trailing = true; // Use Trailing
input double trailing_start = 100; // Trailing Start(Pips)
input double trailing_step = 100; // Trailing Step(Pips)

int handle_super;

int OnInit(){
   handle_super = iCustom(Symbol(),PERIOD_CURRENT,"Supertrend (1).ex5");
   
   trade.SetExpertMagicNumber(magic);

   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason){

}

void OnTick(){
   SuperTrendRecovery(Symbol());
}

int SuperTrendRecovery(string pair){
   int trade_index = lastPositionOrOrder();
   double sup_buy[]; double sup_sell[];
   CopyBuffer(handle_super,0,0,5,sup_buy);
   CopyBuffer(handle_super,1,0,5,sup_sell);
   ArraySetAsSeries(sup_buy,true);
   ArraySetAsSeries(sup_sell,true);
   
   if(trade_index==-1){ // SEARCHING FOR NEW POSITIONS
      if(sup_buy[1]!=EMPTY_VALUE) return trade.Buy(lot,pair,0,0,0,comment);
      else if(sup_sell[1]!=EMPTY_VALUE) return trade.Sell(lot,pair,0,0,0,comment);
   }else{ // MANAGE POSITIONS/ORDERS
      int filled = TotalPositions();
      double trail_target = trailing_start*_Point*10;
      double trail_step = trailing_step*_Point*10;
      
      if(filled==1 && pinfo.SelectByIndex(trade_index)){
         double old_sl = pinfo.StopLoss();
         ENUM_POSITION_TYPE pos_type = pinfo.PositionType();
         double profit = pinfo.Profit();
         
         if(use_trailing){
            if(pos_type==POSITION_TYPE_BUY && (pinfo.PriceCurrent()-pinfo.PriceOpen())>=trail_target && (old_sl==0 || old_sl<pinfo.PriceOpen())){
               double new_sl = pinfo.PriceCurrent() - trail_step;
               
               return trade.PositionModify(pinfo.Ticket(),new_sl,pinfo.TakeProfit());
            }else if(pos_type==POSITION_TYPE_BUY && (pinfo.PriceCurrent()-pinfo.PriceOpen())>=trail_target && old_sl>=pinfo.PriceOpen() && (pinfo.PriceCurrent()-old_sl)>=(2*trail_step)){
               double new_sl = pinfo.PriceCurrent() - trail_step;
               
               return trade.PositionModify(pinfo.Ticket(),new_sl,pinfo.TakeProfit());
            }else if(pos_type==POSITION_TYPE_SELL && (pinfo.PriceOpen()-pinfo.PriceCurrent())>=trail_target && (old_sl==0 || old_sl>pinfo.PriceOpen())){
               double new_sl = pinfo.PriceCurrent() + trail_step;
               
               return trade.PositionModify(pinfo.Ticket(),new_sl,pinfo.TakeProfit());
            }else if(pos_type==POSITION_TYPE_SELL && (pinfo.PriceOpen()-pinfo.PriceCurrent())>=trail_target && old_sl<=pinfo.PriceOpen() && (old_sl-pinfo.PriceCurrent())>=(2*trail_step)){
               double new_sl = pinfo.PriceCurrent() + trail_step;
               
               return trade.PositionModify(pinfo.Ticket(),new_sl,pinfo.TakeProfit());
            }
         }
         
         // CLOSING AT OPPOSITE SIGNAL
         if(pos_type==POSITION_TYPE_BUY && sup_sell[1]!=EMPTY_VALUE){
            if(profit>0) return trade.PositionClose(pinfo.Ticket());
            else return trade.Sell(lot*lot_multiplier,pair,0,0,0,comment); 
         }else if(pos_type==POSITION_TYPE_SELL && sup_buy[1]!=EMPTY_VALUE){
            if(profit>0) return trade.PositionClose(pinfo.Ticket());
            else return trade.Buy(lot*lot_multiplier,pair,0,0,0,comment);
         }
      }
      
      // CLOSING CYCLE AT BREAKEVEN AFTER HEDGING
      if(filled>1 && TotalProfit()>=hedge_breakeven){
         CloseAllTrades();
         return -1;
      }
      
      if(filled>1 && TotalPending()==0 && pinfo.SelectByIndex(trade_index)){
         ENUM_POSITION_TYPE pos_type = pinfo.PositionType();
         double new_vol = pinfo.Volume()*lot_multiplier;
         
         if(pos_type==POSITION_TYPE_BUY && pinfo.SelectByIndex( lastDirectionIndex(POSITION_TYPE_SELL) )){
            double entry = pinfo.PriceOpen();
            
            return trade.SellStop(new_vol,entry,pair,0,0,ORDER_TIME_GTC,0,comment);
         }else if(pos_type==POSITION_TYPE_SELL && pinfo.SelectByIndex( lastDirectionIndex(POSITION_TYPE_BUY) )){
            double entry = pinfo.PriceOpen();
            
            return trade.BuyStop(new_vol,entry,pair,0,0,ORDER_TIME_GTC,0,comment);
         }
      }
   }
   
   return -1;
}

// ============================================================
int lastPositionOrOrder(){
   for(int i=PositionsTotal()-1; i>=0; i--){
      if(pinfo.SelectByIndex(i) && pinfo.Symbol()==Symbol() && pinfo.Magic()==magic) return i;
   }
   
   for(int j=OrdersTotal()-1; j>=0; j--){
      ulong ticket = OrderGetTicket(j);
      if(OrderSelect(ticket) && OrderGetString(ORDER_SYMBOL)==Symbol() && OrderGetInteger(ORDER_MAGIC)==magic) return j;
   }
   
   return -1;
}

int lastDirectionIndex(ENUM_POSITION_TYPE type){
   for(int i=PositionsTotal()-1; i>=0; i--){
      if(pinfo.SelectByIndex(i) && pinfo.Symbol()==Symbol() && pinfo.Magic()==magic && type==pinfo.PositionType()) return i;
   }
   
   return -1;
}

int TotalPending(){
   int count = 0;
   
   for(int j=OrdersTotal()-1; j>=0; j--){
      ulong ticket = OrderGetTicket(j);
      if(OrderSelect(ticket) && OrderGetString(ORDER_SYMBOL)==Symbol() && OrderGetInteger(ORDER_MAGIC)==magic) count++;
   }
   
   return count;
}

int TotalPositions(){
   int count = 0;
   
   for(int i=PositionsTotal()-1; i>=0; i--){
      if(pinfo.SelectByIndex(i) && pinfo.Symbol()==Symbol() && pinfo.Magic()==magic) count++;
   }
   
   return count;
}

int TotalProfit(){
   double profit = 0;
   
   for(int i=PositionsTotal()-1; i>=0; i--){
      if(pinfo.SelectByIndex(i) && pinfo.Symbol()==Symbol() && pinfo.Magic()==magic) profit += pinfo.Profit();
   }
   
   return profit;
}

void CloseAllTrades(){
   for(int i=PositionsTotal()-1; i>=0; i--){
      if(pinfo.SelectByIndex(i) && pinfo.Symbol()==Symbol() && pinfo.Magic()==magic) trade.PositionClose(pinfo.Ticket());
   }
   
   for(int j=OrdersTotal()-1; j>=0; j--){
      ulong ticket = OrderGetTicket(j);
      if(OrderSelect(ticket) && OrderGetString(ORDER_SYMBOL)==Symbol() && OrderGetInteger(ORDER_MAGIC)==magic) trade.OrderDelete(ticket);
   }
}