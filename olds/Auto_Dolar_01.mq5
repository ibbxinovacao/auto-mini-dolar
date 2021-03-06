//+------------------------------------------------------------------+
//|                                                Auto_Dolar_01.mq5 |
//|                                            Mateus Salmazo Takaki |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Mateus Salmazo Takaki"
#property link      "https://www.mql5.com"
#property version   "1.00"
#include <Trade\Trade.mqh>

input ulong INP_VOLUME        = 1;

CTrade Trade;
MqlRates    rates[];
MqlTick     tick;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
      EventSetTimer(2);
      ArraySetAsSeries(rates,true);
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+  

  
  
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
      EventKillTimer();
  }
//+------------------------------------------------------------------+



//+------------------------------------------------------------------+
//| Expert timer function                                             |
//+------------------------------------------------------------------+  
void OnTimer(){
      /*
      static datetime PrevBars=0;
      datetime timeCandle=iTime(_Symbol,_Period,5);
      Print("Hora da abertura: ",timeCandle);
      */ 
}    
//+------------------------------------------------------------------+  


  
  
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//--- 
      //EaBandsBollinger();
//--- we work only at the time of the birth of new bar
      static datetime PrevBars=0;
      datetime time_0=iTime(_Symbol,_Period,0);
      if(time_0==PrevBars)
         return;
      PrevBars=time_0;
//---
      
      int copied = CopyRates(_Symbol, _Period, 0, 5, rates);
      if(copied < 3){ 
      Print("*****Menos de 3 candles*****");                    // Verifica se recuperou informações de ao menos 3 candles.
         return;
      }

      if(OrdersTotal() >= 1){
         Print("*****Ordem já existe*****");                // Verifica se tem alguma ordem pendênte.
         return;
      }      

      if(PositionsTotal() >= 1){
         Print("*****Já está posicionado 2*****");           // Verifica se o cliente está posicionado.
         return;
      }      

      if(!SymbolInfoTick(_Symbol, tick)){
         Print("*****Não foi possível pegar o preço corrente*****");  // Verifica os dados atuais (correntes) de mercado.
         return;
      }
      
      if(BuyStrategy()){
         Print("******Entrou no BuyMarket******");
         ClosePosition(POSITION_TYPE_SELL);
         BuyMarket();
         Print("********Saiu do BuyMarket******");
      }
      if(SellStrategy()){
         Print("******Entrou no SellMarket******");
         ClosePosition(POSITION_TYPE_BUY);
         SellMarket();
         Print("********Saiu no SellMarket******");
      }   
    
  }
//+------------------------------------------------------------------+



//+------------------------------------------------------------------+
//| Expert Buy Strategy function                                     |
//+------------------------------------------------------------------+
bool BuyStrategy(){
   bool buy = false;
   if(rates[1].high < rates[0].high)
      buy = true;
   return buy;

}
//+------------------------------------------------------------------+


//+------------------------------------------------------------------+
//| Expert Sell Strategy function                                    |
//+------------------------------------------------------------------+
bool SellStrategy(){
   bool sell = false;
   if(rates[1].low > rates[0].low)
      sell = true;
   return sell;
}
//+------------------------------------------------------------------+


//+------------------------------------------------------------------+
//| Expert Buy function                                              |
//+------------------------------------------------------------------+
bool BuyMarket(){
   
   bool ok = Trade.Buy(INP_VOLUME, _Symbol);
   if(!ok){
      int errorCode = GetLastError();
      Print("BuyMarket: ", errorCode);
      ResetLastError();
   }
   return ok;
}
//+------------------------------------------------------------------+



//+------------------------------------------------------------------+
//| Expert Sell function                                             |
//+------------------------------------------------------------------+
bool SellMarket(){
   
   bool ok = Trade.Sell(INP_VOLUME, _Symbol);
   if(!ok){
      int errorCode = GetLastError();
      Print("SellMarket: ", errorCode);
      ResetLastError();
   }
   return ok;
}
//+------------------------------------------------------------------+


//+------------------------------------------------------------------+
//| Expert BuyStop function                                          |
//+------------------------------------------------------------------+
bool BuyStop(double _price_stop){
   
   bool ok = Trade.BuyStop(INP_VOLUME, _price_stop, _Symbol );
   if(!ok){
      int errorCode = GetLastError();
      Print("BuyStop: ", errorCode);
      ResetLastError();
   }
   return ok;
}
//+------------------------------------------------------------------+



//+------------------------------------------------------------------+
//| Expert SellStop function                                         |
//+------------------------------------------------------------------+
bool SellStop(double _price_stop){
   
   bool ok = Trade.SellStop(INP_VOLUME, _price_stop, _Symbol );
   if(!ok){
      int errorCode = GetLastError();
      Print("SellStop: ", errorCode);
      ResetLastError();
   }
   return ok;
}
//+------------------------------------------------------------------+





//+------------------------------------------------------------------+
//| Expert SellLimit function                                        |
//+------------------------------------------------------------------+
bool SellLimit(double _price_limit){
   
   bool ok = Trade.SellLimit(INP_VOLUME, _price_limit, _Symbol );
   if(!ok){
      int errorCode = GetLastError();
      Print("SellLimit: ", errorCode);
      ResetLastError();
   }
   return ok;
}
//+------------------------------------------------------------------+





//+------------------------------------------------------------------+
//| Expert BuyLimit function                                         |
//+------------------------------------------------------------------+
bool BuyLimit(double _price_limit){
   
   bool ok = Trade.BuyLimit(INP_VOLUME, _price_limit, _Symbol );
   if(!ok){
      int errorCode = GetLastError();
      Print("BuyLimit: ", errorCode);
      ResetLastError();
   }
   return ok;
}
//+------------------------------------------------------------------+




//+------------------------------------------------------------------+
//| Expert VerificaOrdens function                                   |
//+------------------------------------------------------------------+
void VerificaOrdens(){
   int ordensTotal   =   OrdersTotal();
   ulong orderTicket = 0;
   for(int index = 0; index < ordensTotal; index++){
   orderTicket = OrderGetTicket(index);
         if(OrderSelect(orderTicket)){
            if( (OrderGetInteger(ORDER_TYPE) != 2) || ((OrderGetInteger(ORDER_TYPE) != 3)) )
               CloseOrders();
         }
   }

}
//+------------------------------------------------------------------+





//+------------------------------------------------------------------+
//| Expert CloseOrders function                                      |
//+------------------------------------------------------------------+
void CloseOrders(){
   ulong orderTicket = 0;
   while(OrdersTotal() != 0){
      orderTicket = OrderGetTicket(0);
      Trade.OrderDelete(orderTicket);
   }
}
//+------------------------------------------------------------------+



//+------------------------------------------------------------------+
//| Expert ClosePositions function                                      |
//+------------------------------------------------------------------+
void ClosePosition(const ENUM_POSITION_TYPE pos_type){
   
}
//+------------------------------------------------------------------+





//+------------------------------------------------------------------+
//| Expert BandsBollingerStrategy function                           |
//+------------------------------------------------------------------+
void EaBandsBollinger(){
      int copied = CopyRates(_Symbol, _Period, 0, 3, rates);
      
      int BBHandle = iBands(_Symbol, _Period, 20, 0, 2, PRICE_CLOSE);
      
      double banda_sup[];
      double banda_inf[];
      double media[];
      
      ArraySetAsSeries(rates, true);
      ArraySetAsSeries(banda_sup, true);
      ArraySetAsSeries(banda_inf, true);
      ArraySetAsSeries(media, true);
      
      CopyBuffer(BBHandle, 0, 0, 3, media);        // 0 indica a média.
      CopyBuffer(BBHandle, 1, 0, 3, banda_sup);    // 1 indica a banda superior.
      CopyBuffer(BBHandle, 2, 0, 3, banda_inf);    // 2 indica a banda iferior.
      
      //Estratégia PAULA
      PositionSelect(_Symbol);
      ulong type       = PositionGetInteger(POSITION_TYPE);          //type 0: Comprado | 1: Vendido.
      
      if( (rates[1].low < banda_inf[1]) && (rates[0].high > banda_inf[0]) && type != 0 ){
         //Comment("BUY...");
         BuyMarket();                     // Compra no ASK
         SellStop(rates[1].low);          // Stop na mínima do candle anterior
         SellLimit(media[0]);             // Sell limite na media 
      }
      
      if( (rates[1].high > banda_sup[1]) && (rates[0].low < banda_sup[0]) && type != 1 ){
         //Comment("SELL...");
         SellMarket();                    // Vende no BID
         BuyStop(rates[1].high);          // Stop na máxima do candle anterior.
         BuyLimit(media[0]);              // Buy limit na média
      }
      
      VerificaOrdens();
}