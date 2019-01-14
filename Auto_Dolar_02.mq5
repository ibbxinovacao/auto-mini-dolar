//+------------------------------------------------------------------+
//|                                                Auto_Dolar_01.mq5 |
//|                        Copyright 2018, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2018, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#include <Trade\Trade.mqh>

#define MA_MAGIC 687976954850

CTrade Trade;
input ulong INP_VOLUME = 2;
input int periodoMMe = 9;
input int deslocamentMMe = 0;
double rp = 0;
double breakeven  = 2.0;
double stopLoss = 3.0;
MqlRates rates[];
MqlTick  lastTick;
bool     Hedging = false;


//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
        // Hedging recebe "true" se a conta for hegding ou "false" se for netting:
        Hedging = ((ENUM_ACCOUNT_MARGIN_MODE)AccountInfoInteger(ACCOUNT_MARGIN_MODE) == ACCOUNT_MARGIN_MODE_RETAIL_HEDGING);
        Print("Conta Hegding: ", Hedging);
        
        // Define o ID do Robô:        
        Trade.SetExpertMagicNumber(MA_MAGIC);   
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
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
      double MMeBlue[];    // Buffer que armazena os valores da media que representa o hilo azul.
      double Macd[];       // Buffer que armazana os valores do MACD. 
      double banda_sup[];  // Buffer que armazena os valores da banda superior da Banda de Bollinger.
      double banda_inf[];  // Buffer que armazena os valores da banda inferior da Banda de Bollinger.
      double media[];      // Buffer que armazena a média da Banda de Bollinger.

      // Recupera os valores dos ultimos 5 candles:
      int copied = CopyRates(_Symbol, _Period, 0, 5, rates);
      
      // Define as propriedades das Bandas de Bollinger em 20 periodos e desvio de 2:
      int BBHandle = iBands(_Symbol, _Period, 20, 0, 2, PRICE_CLOSE);

      // Define as propriedades da média móvel exponencial de 9 periodos sem o deslocamento.
      int movingAverageBlue   = iMA(_Symbol, _Period, periodoMMe, deslocamentMMe, MODE_EMA, PRICE_CLOSE);
      // Define as propriedades do MACD Média longa de 26, média cuta de 12 e sinal de 9.
      int MaverageConvDiv     = iMACD(_Symbol, _Period, 12, 26, 9, PRICE_CLOSE);
      
      // Inverte a posição do Array para o preço mais recente ficar na posição 0.
      ArraySetAsSeries(rates, true);
      ArraySetAsSeries(MMeBlue, true);
      ArraySetAsSeries(Macd, true);
      ArraySetAsSeries(banda_sup, true);
      ArraySetAsSeries(banda_inf, true);
      ArraySetAsSeries(media, true);

      // Obtem dados do buffer de um indicador no caso das médias móveis:
      if(CopyBuffer(movingAverageBlue, 0, 0, 3, MMeBlue) != 3){
         Print("Erro CopyBuffer, Erro ao recuperar dados da MMeBlue!", GetLastError());
         return;         
      }
      if(CopyBuffer(MaverageConvDiv, 0, 0, 3, Macd) != 3){
         Print("Erro CopyBuffer, Erro ao recuperar dados do MACD!", GetLastError());
         return;      
      }
      // 0 indica a média _ 1 indica a banda superior _ 2 indica a banda iferior.
      if(CopyBuffer(BBHandle, 0, 0, 3, media) != 3 || CopyBuffer(BBHandle, 1, 0, 3, banda_sup) != 3 || CopyBuffer(BBHandle, 2, 0, 3, banda_inf) != 3){
         Print("Erro CopyBuffer, Erro ao recuperar dados da Banda de Bollinger!", GetLastError());
         return;
      }
         
      // Recupera informações no preço atual (do tick):
      if(!SymbolInfoTick(_Symbol, lastTick)){
         Print("Erro ao obter a informação do preço: ", GetLastError());
         return;
      }
      
      // Espera a abertura das bandas de Bollinger.
      if(banda_inf[1] > banda_inf[0] && banda_sup[1] < banda_sup[0])   
      {
         /*//////////////////////////////////////////////////////////////////////////////
         /                           ENTRADA NA COMPRA                                 //
         *///////////////////////////////////////////////////////////////////////////////
         if((Macd[0] > 0) && (rates[1].close > MMeBlue[1]) && (lastTick.ask > rates[1].high) && (VerificaTipoPosicao() != POSITION_TYPE_BUY) ){
            Print("Estratégia de Compra Acionada...");
            // Verifica se há posição em aberto se sim elimina a posição.
            if( (PositionsTotal() > 0) || OrdersTotal() > 0 ){
               if(!EliminaPosicao() && !EliminaOrdem()){
                  Print("Erro ao eliminar Posição ! - ", GetLastError() );
               }else{
                    RealizaCompra();
                  }
            }else{
                RealizaCompra();
             }        
         }
   
         /*//////////////////////////////////////////////////////////////////////////////
         /                           ENTRADA NA VENDA                                  //
         *///////////////////////////////////////////////////////////////////////////////      
         if((Macd[0] < 0) && (rates[1].close < MMeBlue[1]) && (lastTick.bid < rates[1].low) && (VerificaTipoPosicao() != POSITION_TYPE_SELL) ){
            Print("Estratégia de Venda Acionada...");
            // Verifica se há posição em aberto se sim elimina a posição.
            if( (PositionsTotal() > 0) || OrdersTotal() > 0 ){
               if(!EliminaPosicao() && !EliminaOrdem()){
                  Print("Erro ao eliminar Posição ! - ", GetLastError() );
               }else
                 RealizaVenda(); 
            }else
               RealizaVenda();             
         }
      }
      // Verifica se o preço atingiu o valor de realização parcial:
      if(lastTick.last == rp){
         Print("Breakeven acionado...", rp);
         // Executa Realização Parcial se a quantidade de volume for divisível por dois:
         if(INP_VOLUME%2 == 0)
            if(!RealizaParcial())
               Print("Erro de Realização Parcial !!!");
         //Executa Elevação do StopLoss:
         if(!EvoluiStop())
            Print("Erro ao Evoluir Stop !!!");
      }          
  }
//+------------------------------------------------------------------+




//+------------------------------------------------------------------+
//| Expert Realiza Venda function                                    |
//+------------------------------------------------------------------+
void RealizaVenda(){
//--- Realiza Venda se for uma conta Hedging:
   if(Hedging){
      Print("Conta Hedging !!!");
      if(SellMarket()){
         Print("Venda Acionada...");
      }else
         Print("Erro ao realizar a Venda !: ", GetLastError());
      }
//--- Realiza a Venda se for uma conta Netting:   
   else{
      Print("Conta Netting !!!");
      SellMarket();
   }
}
//+------------------------------------------------------------------+


//+------------------------------------------------------------------+
//| Expert Realiza Compra function                                   |
//+------------------------------------------------------------------+
void RealizaCompra(){
//--- Realiza Compra se for uma conta Hedging:
   if(Hedging){
      Print("Conta Hedging !!!");
      if(BuyMarket()){
         Print("Venda Acionada...");
      }else
         Print("Erro ao realizar a Venda !: ", GetLastError());
      }
//--- Realiza a Compra se for uma conta Netting:   
   else{
      Print("Conta Netting !!!");
      BuyMarket();
   }
}
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Expert Buy function                                              |
//+------------------------------------------------------------------+
bool BuyMarket(){
   Print("Compra em ask: ", lastTick.ask);
   Print("Mínima Candle ant: ", lastTick.ask - stopLoss );
   bool ok = Trade.Buy(INP_VOLUME, _Symbol, lastTick.ask, lastTick.ask - stopLoss, lastTick.ask + 4.0);
   rp = lastTick.last + breakeven;
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
   Print("Venda em bid: ", lastTick.bid);
   Print("Máxima Candle ant: ", lastTick.bid + stopLoss);
   bool ok = Trade.Sell(INP_VOLUME, _Symbol, lastTick.bid, lastTick.bid + stopLoss, lastTick.bid - 4.0);
   rp = lastTick.last - breakeven;
   if(!ok){
      int errorCode = GetLastError();
      Print("SellMarket: ", errorCode);
      ResetLastError();
   }
   return ok;
}
//+------------------------------------------------------------------+


//+------------------------------------------------------------------+
//| Expert verifica tipo Posição function                            |
//+------------------------------------------------------------------+
ENUM_POSITION_TYPE VerificaTipoPosicao(){

ENUM_POSITION_TYPE res = WRONG_VALUE;

   // Verifica a posição em uma conta Hedging:
   if(Hedging)
     {
      uint total=PositionsTotal();
      for(uint i=0; i<total; i++)
        {
         string position_symbol=PositionGetSymbol(i);
         if(_Symbol==position_symbol && MA_MAGIC == PositionGetInteger(POSITION_MAGIC))
           {
              if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY){
               res = POSITION_TYPE_BUY;
               break;
              }
              else if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL){
               res = POSITION_TYPE_SELL;
               break;
              } 
           }
        }
     }
   // Verifica a posição em um conta Netting:
   else
     {
      if(!PositionSelect(_Symbol))
         return(WRONG_VALUE);
      else{
         if(PositionGetInteger(POSITION_MAGIC) == MA_MAGIC) //---check Magic number
            if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY){
               return POSITION_TYPE_BUY;
            }
            else if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL){
               return POSITION_TYPE_SELL;
            }
         }
     }
//--- result for Hedging mode
   return(res);
}

//+------------------------------------------------------------------+


//+------------------------------------------------------------------+
//| Expert Elimina Ordem function                                    |
//+------------------------------------------------------------------+
bool EliminaOrdem(){
   bool res=false;
   uint total=OrdersTotal();
   ulong orderTicket = 0;

      for(uint i=0; i<total; i++)
        {
         orderTicket = OrderGetTicket(i);
         if(MA_MAGIC == OrderGetInteger(ORDER_MAGIC))
           {
             return Trade.OrderDelete(orderTicket);  
             break;  
           }
        }
     return res; 
}
//+------------------------------------------------------------------+



//+------------------------------------------------------------------+
//| Expert Elimina Posição function                                  |
//+------------------------------------------------------------------+
bool EliminaPosicao(){
   bool res=true;
//--- check position in Hedging mode
   if(Hedging)
     {
      uint total=PositionsTotal();
      for(uint i=0; i<total; i++)
        {
         string position_symbol=PositionGetSymbol(i);
         if(_Symbol==position_symbol && MA_MAGIC==PositionGetInteger(POSITION_MAGIC))
           {
             return(Trade.PositionClose(_Symbol));
             break;  
           }
        }
     }
//--- check position in Netting mode
   else
     {
      if(PositionSelect(_Symbol))
         if(PositionGetInteger(POSITION_MAGIC)==MA_MAGIC) //---check Magic number
         {
            return(Trade.PositionClose(_Symbol));
         }
      else{
         return false;
      }
     }
//--- result for Hedging mode
   return(res);   
}
//+------------------------------------------------------------------+


//+------------------------------------------------------------------+
//| Expert Realização Parcial function                               |
//+------------------------------------------------------------------+
bool RealizaParcial(){
   bool res=false;
//--- check position in Hedging mode
   if(Hedging)
     {
      uint total=PositionsTotal();
      for(uint i=0; i<total; i++)
        {
         string position_symbol=PositionGetSymbol(i);
         if(_Symbol == position_symbol && MA_MAGIC == PositionGetInteger(POSITION_MAGIC))
           {
             if(!Trade.PositionClosePartial(_Symbol, (INP_VOLUME/2), 150)){
               Print("Erro Real. Parcial: ", GetLastError());
               return false;
               break;
             }else{
               return true;
               break;
              }  
           }
        }
     }
//--- check position in Netting mode
   else
     {
      if(!PositionSelect(_Symbol))
         return(false);
      else{
         if(PositionGetInteger(POSITION_MAGIC) == MA_MAGIC) //---check Magic number
         {  
            Print("Magic Number: ", MA_MAGIC);
            if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY){
               if(!Trade.Sell((INP_VOLUME/2), _Symbol, lastTick.bid, NULL, NULL)){
                  Print("Erro Real. Parcial: ", GetLastError());
                  return false;
               }else
                  return true;
            }else if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL){
               if(!Trade.Buy((INP_VOLUME/2), _Symbol, lastTick.ask, NULL, NULL)){
                  Print("Erro Real. Parcial: ", GetLastError());
                  return false;
               }else
                  return true;
            }
            
         }
      }
     }
//--- result for Hedging mode
   return(res);     
}
//+------------------------------------------------------------------+



//+------------------------------------------------------------------+
//| Expert Evolui Stop function                                      |
//+------------------------------------------------------------------+
bool EvoluiStop(){
   bool res=false;
//--- check position in Hedging mode
   if(Hedging)
     {
      uint total=PositionsTotal();
      for(uint i=0; i<total; i++)
        {
         string position_symbol=PositionGetSymbol(i);
         if(_Symbol == position_symbol && MA_MAGIC == PositionGetInteger(POSITION_MAGIC))
           {
             // Recupera o preço de entrada da posição:
             double novostop = PositionGetDouble(POSITION_PRICE_OPEN);  
             // Eleva o preço de stop para o preço de entrada: 
             if(!Trade.PositionModify(_Symbol, novostop , PositionGetDouble(POSITION_TP) )){
               Print("Erro Real. Parcial: ", GetLastError());
               return false;
               break;
             }else{
               return true;
               break;
              }  
           }
        }
     }
//--- check position in Netting mode
   else
     {
      if(!PositionSelect(_Symbol))
         return(false);
      else{
         if(PositionGetInteger(POSITION_MAGIC) == MA_MAGIC) //---check Magic number
         {  
            Print("Magic Number: ", MA_MAGIC);
            // Recupera o preço de entrada da posição:
            double novostop = PositionGetDouble(POSITION_PRICE_OPEN);  
            if(!Trade.PositionModify(_Symbol, novostop , PositionGetDouble(POSITION_TP))){
               Print("Erro Real. Parcial: ", GetLastError());
               return false;
            }else
               return true;
         }
      }
     }
//--- result for Hedging mode
   return(res);      
}
//+------------------------------------------------------------------+