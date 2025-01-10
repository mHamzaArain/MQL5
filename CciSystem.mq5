#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

#include <Trade/Trade.mqh>



input group "Trade Settings"
input double lotSize = 0.01;
input int tpPoints = 150;
input int partialClosePoints = 70;
// input double partialPercentage = 50;
input double partialCloseFactor = 0.5; 
input int slPoints = 300;
input int breakEvenTriggerPoints= 50;
input int breakEvenBufferPoints= 5;

input group "CCI"
input ENUM_TIMEFRAMES cciTimeframe = PERIOD_CURRENT;
input int cciPeriods = 14;
input ENUM_APPLIED_PRICE cciAppliedPrice = PRICE_TYPICAL;
input double cciBuyLevel = -200;
input double cciSellLevel = 200;

input group "MA"
input bool isMAFileter = true;
input ENUM_TIMEFRAMES MATimeframe = PERIOD_H1;
input int MAPeriod = 50;
input ENUM_MA_METHOD MAMethod = MODE_SMA;
input ENUM_APPLIED_PRICE MAAppliedPrice = PRICE_CLOSE; 

int handleCci;
int handleMA;

int barsTotal;

CTrade trade;


int OnInit() {
   barsTotal = iBars(_Symbol, cciTimeframe);

   handleCci = iCCI(_Symbol, cciTimeframe, cciPeriods, cciAppliedPrice);
   handleMA = iMA(_Symbol, MATimeframe, MAPeriod, 0, MAMethod, MAAppliedPrice);

   OnTick();

   return(INIT_SUCCEEDED);
}

void OnTick() {
   // Bid
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   bid = NormalizeDouble(bid, _Digits);

   // Ask
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   ask = NormalizeDouble(ask, _Digits);


   for(int i=PositionsTotal()-1; i>=0; i--) {
      ulong posTicket = PositionGetTicket(i);  // ulong = Unsigned Long Value

      if(PositionSelectByTicket(posTicket)) {
         double posOpenPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         double posVolume = PositionGetDouble(POSITION_VOLUME);
         double posTP = PositionGetDouble(POSITION_TP);
         double posSL = PositionGetDouble(POSITION_SL);
         ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE) PositionGetInteger(POSITION_TYPE); 
         
         // Break Even Stop 
         if(posType == POSITION_TYPE_BUY) {
            if(bid > posOpenPrice + breakEvenTriggerPoints * _Point) {
               double sl = posOpenPrice + breakEvenBufferPoints * _Point;
               sl = NormalizeDouble(sl, _Digits);

               if(sl > posSL) {
                  if(trade.PositionModify(posTicket, sl, posTP)) {
                     Print("POS ", posTicket, "close partially");
                  }
               }
            }
         }
         else if(posType == POSITION_TYPE_SELL) {
            if(ask < posOpenPrice - breakEvenTriggerPoints * _Point) {
               double sl = posOpenPrice - breakEvenBufferPoints * _Point;
               sl = NormalizeDouble(sl, _Digits);

               if(sl <  posSL) {
                  if(trade.PositionModify(posTicket, sl, posTP)) {
                     Print("POS ", posTicket, "close partially");
                  }
               }
            }
         }

         // Partial Close
         if(posVolume== lotSize) {
            double lotsToClose = posVolume * partialCloseFactor;
            lotsToClose = NormalizeDouble(lotsToClose, 2);

            if(posType == POSITION_TYPE_BUY) {
               if(bid > posOpenPrice + partialClosePoints * _Point) {
                  if(trade.PositionClosePartial(posTicket, lotsToClose)) {
                     Print("POS ", posTicket, "close partially");
                  }
               }
            }
            else if(posType == POSITION_TYPE_SELL) {
               if(ask < posOpenPrice - partialClosePoints * _Point) {
                  if(trade.PositionClosePartial(posTicket, lotsToClose)) {
                     Print("POS ", posTicket, "close partially");
                  }
               }
            }
         }  
      }
   }



   // Buy/Sell Conditions
   int bars = iBars(_Symbol, cciTimeframe);
   if (barsTotal < bars) {
      bars = barsTotal;
   
      double cci[];
      CopyBuffer(handleCci,   // Indicator handle 
                        0,    // buffer number
                        1,    // Start postion
                        2,    // count
                        cci   // array
         );
         
      double ma[];
      CopyBuffer(handleMA, 0, 0, 1, ma);
      
      if(cci[1] < cciBuyLevel && cci[0] > cciBuyLevel) {
         Comment("Buy");
            
         if (isMAFileter || ask > ma[0]) {
            double tp = ask + tpPoints * _Point;  
            tp = NormalizeDouble(tp, _Digits);  
            
            double sl = ask - slPoints * _Point;
            sl = NormalizeDouble(sl, _Digits);
              
            trade.Buy(lotSize, _Symbol, ask, sl, tp, "CCI Buy");
         }           
      }
      else if(cci[1] > cciBuyLevel && cci[0] < cciBuyLevel) {
         Comment("SEll");

         if (isMAFileter || bid < ma[0]) {
            double tp = bid - tpPoints * _Point;  
            tp = NormalizeDouble(tp, _Digits);  
               
            double sl = bid + slPoints * _Point;
            sl = NormalizeDouble(sl, _Digits);
              
            trade.Buy(lotSize, _Symbol, bid, sl, tp, "CCI Sell");
         }
      } 
      Comment("cci[0]: ", cci[0]);
   }
}
