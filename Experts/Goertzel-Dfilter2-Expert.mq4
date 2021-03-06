//+------------------------------------------------------------------+
//|                                     Goertzel-Dfilter2-Expert.mq4 |
//|                                           Copyright 2017, Levabd |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2017, Levabd"
#property link      ""
#property version   "1.00"
#property strict

#define MAGICMA  20171021

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
string            my_symbol;    // переменная для хранения символа
double            lot_size;     // переменная для хранения минимального объема совершаемой сделки

extern color   BuyColor           = clrCornflowerBlue;
extern color   SellColor          = clrSalmon;

int OnInit()
{
//---
   //--- сохраним текущий символ графика для дальнейшей работы советника именно на этом символе
   my_symbol=Symbol();
   lot_size=1.0;
   
   
   Alert(my_symbol);
   Alert(MarketInfo(my_symbol, MODE_TRADEALLOWED));
   /*if (MarketInfo(my_symbol, MODE_TRADEALLOWED) <= 0) {
      return(INIT_SUCCEEDED);
   }*/
   
   Alert("Test1");
//---
   return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
//---
   
}

void Buy()
{ 
   // Пробежим по всем ордерам
   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {   
         // Если ордер наш   
         if(OrderSymbol() == my_symbol && OrderMagicNumber() == MAGICMA)
         {
            // Закрываем ордер на продажу
            if(OrderType() == OP_SELL){
               OrderClose(OrderTicket(), OrderLots(), Ask, 3, SellColor);
            }
            
            // Не трогаем ордер на покупку
            if(OrderType() == OP_BUY) return;
         }
      }
   }
   
   int res = OrderSend(my_symbol, OP_BUY, lot_size, Ask, 3, Ask - 15*Point, Ask + 15*Point, "Goertzel-Dfilter Buy order", MAGICMA, 0, BuyColor);
   if (res < 0)
   {
      Print("Error when opening a BUY order #", GetLastError());
      Sleep(10000);
      return;
   }
}

void Sell()
{ 
   // Пробежим по всем ордерам
   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {   
         // Если ордер наш   
         if(OrderSymbol() == my_symbol && OrderMagicNumber() == MAGICMA)
         {
            // Закрываем ордер на покупку
            if(OrderType() == OP_BUY){
               OrderClose(OrderTicket(), OrderLots(), Bid, 3, BuyColor);
            }
            
            // Не трогаем ордер на покупку
            if(OrderType() == OP_SELL) return;
         }
      }
   }
   
   int res = OrderSend(my_symbol, OP_SELL, lot_size, Bid, 3, Bid - 15*Point, Bid + 15*Point, "Goertzel-Dfilter Sell order", MAGICMA, 0, SellColor);
   if (res < 0)
   {
      Print("Error when opening a SELL order #", GetLastError());
      Sleep(10000);
      return;
   }
}

void CloseOrders()
{ 
   // Пробежим по всем ордерам
   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {   
         // Если ордер наш   
         if(OrderSymbol() == my_symbol && OrderMagicNumber() == MAGICMA)
         {
            // Закрываем ордера на продажу
            if(OrderType() == OP_SELL){
               OrderClose(OrderTicket(), OrderLots(), Ask, 3, SellColor);  
            }
            
            // Закрываем ордера на покупку
            if(OrderType() == OP_BUY){
               OrderClose(OrderTicket(), OrderLots(), Bid, 3, BuyColor);  
            }
         }
      }
   }
}


//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
//---
   //Alert("Test");
   // проверяем открыт ли рынок для текущего инструмента.
   /*if (MarketInfo(my_symbol, MODE_TRADEALLOWED) <= 0) {
      return;
   }*/
    
   int Dfilter2Indicator_H4 = GlobalVariableGet("Dfilter2Indicator_H4");
   int Dfilter2Indicator_H1 = GlobalVariableGet("Dfilter2Indicator_H1");
   int CB_SSA_H1 = GlobalVariableGet("CB_SSA_H1");
   int CB_SSA_H4 = GlobalVariableGet("CB_SSA_H4");
   
   if ((Dfilter2Indicator_H4 == -1) && (Dfilter2Indicator_H1 == -1) && (CB_SSA_H1 == -1) && (CB_SSA_H4 == -1)){
      Sell();
   } else if ((Dfilter2Indicator_H4 == 1) && (Dfilter2Indicator_H1 == 1) && (CB_SSA_H1 == 1) && (CB_SSA_H4 == 1)){
      Buy();
   } else {
      CloseOrders();
   }
   
   /*if ((Dfilter2Indicator_H4 == -1) && (Dfilter2Indicator_H1 == -1)){
      Alert("Sell");
   } else if ((Dfilter2Indicator_H4 == 1) && (Dfilter2Indicator_H1 == 1)){
      Alert("Buy");
   } else {
      Alert("Close");
   }*/
}
//+------------------------------------------------------------------+
