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

// Define constantes de sinal para compra ou venda:
#define SINAL_BUY 1
#define SINAL_SELL 2

CTrade Trade;
input ulong INP_VOLUME  = 1;
double stepTS     = 2.5;     

double   rp          = 0;
double   breakeven   = 0;
double   stopLoss    = 2.0;
MqlRates rates[];
MqlTick  lastTick;
bool     Hedging     = false;
bool     be_ativo;
bool     pos_aberta;     

// Variáveis globais de preço:
double preco;     // preço de entrada em uma operação.
double preco_sl;  // preço do stoploss em uma operação.
double preco_tp;  // preço do takeprofit em uma operação.

// Inputs de hora:
MqlDateTime horaAtual; 
input int horaInicio    = 10; // Hora em que o robô começa operar.
input int minutoInicio  = 30; // Minutos em que o robô começa operar.
input int horaFim       = 16; // Hora em que o robô para de operar.
input int minutoFim     = 15; // Minuto em que o robô para de operar.
input int horaFecha     = 17; // Hora em que o robô fecha todas posições abertas.
input int minutoFecha   = 20; // Minuto em que o robô fecha todas as posições abertas.  

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
        
        // Verifica a consistência da hora inserida:
        if(horaInicio > horaFim || horaFim > horaFecha){
            Alert("Erro: Hora de Negociação Inconsistente! ");
            return(INIT_FAILED);
        }
        if(horaInicio == horaFim && minutoInicio > minutoFim){
            Alert("Erro: Hora de Negociação Inconsistente! ");
            return(INIT_FAILED);            
        }
        if(horaFim == horaFecha && minutoFim >= minutoFecha){
            Alert("Erro: Hora de Negociação Inconsistente! ");
            return(INIT_FAILED);
        }          
//---
   return(INIT_SUCCEEDED);
  }
 //+-----------------------------------------------------------------+
 
  
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
      
  }
//+------------------------------------------------------------------+
  
  
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
      double MMa20[];        // Buffer que armazena os valores da média de 20 periodos. 
      double MMa200[];       // Buffer que armazena os valores da media de 200 periodos.
      
      // Define as propriedades da média móvel exponencial de 9 periodos e deslocamento de 1.
      int movingAverage20 = iMA(_Symbol, PERIOD_M5, 20, 1, MODE_SMA, PRICE_CLOSE);
      // Define as propriedades da média móvel exponencial de 9 periodos sem o deslocamento.
      int movingAverage200 = iMA(_Symbol, PERIOD_M5, 200, 1, MODE_SMA, PRICE_CLOSE);
      
      // Recupera os valores dos ultimos 5 candles:
      int copied = CopyRates(_Symbol, PERIOD_M5, 0, 5, rates);

      // Inverte a posição do Array para o preço mais recente ficar na posição 0.
      ArraySetAsSeries(rates, true);
      ArraySetAsSeries(MMa20, true);
      ArraySetAsSeries(MMa200, true);

      // Obtem dados do buffer de um indicador no caso das médias móveis:
      if(CopyBuffer(movingAverage20, 0, 0, 3, MMa20) != 3){
         Print("Erro CopyBuffer, Erro ao recuperar dados da MMa20!", GetLastError());
         return;
      }
      if(CopyBuffer(movingAverage200, 0, 0, 3, MMa200) != 3){
         Print("Erro CopyBuffer, Erro ao recuperar dados da MMa200!", GetLastError());
         return;         
      }
      
      // Recupera informações no preço atual (do tick):
      if(!SymbolInfoTick(_Symbol, lastTick)){
         Print("Erro ao obter a informação do preço: ", GetLastError());
         return;
      }
      if(!PosicaoAberta())
         be_ativo = false;
      
      /*//////////////////////////////////////////////////////////////////////////////
      /                           ENTRADA NA COMPRA                                 //
      *///////////////////////////////////////////////////////////////////////////////
      if( RegrasCandle(MMa20) == SINAL_BUY && RegrasMedia(MMa20) == SINAL_BUY &&  HoraNegociacao() && (VerificaTipoPosicao() != POSITION_TYPE_BUY)){
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
      if( RegrasCandle(MMa20) == SINAL_SELL && RegrasMedia(MMa20) == SINAL_SELL && HoraNegociacao() && (VerificaTipoPosicao() != POSITION_TYPE_SELL)){
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
      
      if(PosicaoAberta()){
         if(VerificaTipoPosicao() == POSITION_TYPE_BUY){
            // Verifica se o preço atingiu ou rompeu o valor de breakeven:
            if(lastTick.last >= breakeven){
               ManipulaStop();
            }
         }
         if(VerificaTipoPosicao() == POSITION_TYPE_SELL ){
            // Verifica se o preço atingiu ou rompeu o valor de breakeven:
            if(lastTick.last <= breakeven){
               ManipulaStop();
            }
         }
      }
      if(HoraFechamento()){
         EliminaPosicao();
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
         Print("Compra Acionada...");
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
   NormalizaPreco(lastTick.ask, rates[1].low, NULL);
   bool ok = Trade.Buy(INP_VOLUME, _Symbol, preco, preco_sl, NULL);
   breakeven = lastTick.last + stepTS;
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
   NormalizaPreco(lastTick.bid, rates[1].high, NULL);   
   bool ok = Trade.Sell(INP_VOLUME, _Symbol, preco, preco_sl, NULL);
   breakeven = lastTick.last - stepTS;
   if(!ok){
      int errorCode = GetLastError();
      Print("SellMarket: ", errorCode);
      ResetLastError();
   }
   return ok;
}
//+------------------------------------------------------------------+


//+------------------------------------------------------------------+
//| Expert Verifica Posições abertas function                        |
//+------------------------------------------------------------------+
void ManipulaStop(){
   Print("Breakeven acionado...", breakeven);
   if(PosicaoAberta() && !be_ativo){
      //Executa Elevação do StopLoss:
      if(!EvoluiStop())
         Print("Erro ao Evoluir Stop !!!");
      }else if(PosicaoAberta() && be_ativo){
         TraillingStop(lastTick.last);
      }   
}
//+------------------------------------------------------------------+


//+------------------------------------------------------------------+
//| Expert Verifica Posições abertas function                        |
//+------------------------------------------------------------------+
bool PosicaoAberta(){
   int posicao = PositionsTotal();
   for(int index = 0; index < posicao; index++){
      string symbol = PositionGetSymbol(index);
      ulong magic = PositionGetInteger(POSITION_MAGIC);
      if(symbol == _Symbol && magic == MA_MAGIC){
         return true;
         break;
      }
      else
         return false;
   }
   return false;
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
         if(_Symbol == position_symbol && MA_MAGIC == PositionGetInteger(POSITION_MAGIC))
           {
             ulong positionTicket = PositionGetTicket(i);  
             return(Trade.PositionClose(positionTicket));
             break;  
           }
        }
     }
//--- check position in Netting mode
   else
     {
      if(PositionSelect(_Symbol))
         if(PositionGetInteger(POSITION_MAGIC) == MA_MAGIC) //---check Magic number
         {
            ulong positionTicket = PositionGetInteger(POSITION_TICKET);
            return(Trade.PositionClose(positionTicket));
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
   bool res = false;
//--- check position in Hedging mode
   if(Hedging)
     {
      uint total = PositionsTotal();
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
      for(uint index=0; index < total; index++)
        {
         string position_symbol=PositionGetSymbol(index);
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
               be_ativo = true;
               if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY){
                  breakeven = breakeven + stepTS;   
               }
               else if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL){
                  breakeven = breakeven - stepTS;
               }
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
            }else{
               be_ativo = true;
               if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY){
                  breakeven = breakeven + stepTS;
               }
               else if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL){
                  breakeven = breakeven - stepTS;
               }
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
//| Expert Hora de Negociação function                               |
//+------------------------------------------------------------------+
bool HoraNegociacao(){
   TimeToStruct(TimeCurrent(), horaAtual);
   //Comment("Hora Atual: ", horaAtual.hour,":", horaAtual.min);
   if(horaAtual.hour >= horaInicio && horaAtual.hour <= horaFim)
   {  
      if(horaAtual.hour == horaInicio )
      { 
         if(horaAtual.min >= minutoInicio){
            return true;         
         }
         else{
            return false;
         }
      }
      if(horaAtual.hour == horaFim){
         if(horaAtual.min <= minutoFim){
            return true;
         }
         else{
            return false;
         }
      }
      return true;
   }
   return false;
}
//+------------------------------------------------------------------+


//+------------------------------------------------------------------+
//| Expert Hora Fechamento function                                  |
//+------------------------------------------------------------------+
bool HoraFechamento(){
   TimeToStruct(TimeCurrent(), horaAtual);
   if(horaAtual.hour >= horaFecha){
      if(horaAtual.hour == horaFecha){
         if(horaAtual.min >= minutoFecha){
            return true;
         }
         else
            return false;
      }
      return true;
   }
   return false;
}
//+------------------------------------------------------------------+


//+------------------------------------------------------------------+
//| Expert Normaliza Preço function                                  |
//+------------------------------------------------------------------+
void NormalizaPreco(double _preco, double _sl, double _tp){
   if(_preco != NULL)
      preco    = NormalizeDouble(_preco, _Digits);
   if(_sl != NULL)
      preco_sl = NormalizeDouble(_sl, _Digits);
   if(_tp != NULL)
      preco_tp = NormalizeDouble(_tp, _Digits);
}
//+------------------------------------------------------------------+


//+------------------------------------------------------------------+
//| Expert Trailling Stop function                                   |
//+------------------------------------------------------------------+
void TraillingStop(double _preco){
   int posicao = PositionsTotal();
   for(int index = 0; index < posicao; index++){
      string symbol = PositionGetSymbol(index);
      ulong magic = PositionGetInteger(POSITION_MAGIC);
      if(symbol == _Symbol && magic == MA_MAGIC){
         ulong positionTicket    = PositionGetTicket(index);
         double stopLossCorrent  = PositionGetDouble(POSITION_SL);
         if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY){
            breakeven = breakeven + stepTS;
            double novoSL = NormalizeDouble(stopLossCorrent + stepTS, _Digits);
            if(_preco >= novoSL){
               if(Trade.PositionModify(positionTicket, novoSL, NULL)){
               }else
                  Print("Erro ao evoluir o Stop:", GetLastError());
            }
         }else if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL){
            breakeven = breakeven - stepTS;
            double novoSL = NormalizeDouble(stopLossCorrent - stepTS, _Digits);
            if(_preco <= novoSL){
               if(Trade.PositionModify(positionTicket, novoSL, NULL)){
                  Print("Stop evoluido com sucesso !");
               }else
                  Print("Erro ao evoluir o Stop:", GetLastError());
            }
         }
      }         
   }
}
//+------------------------------------------------------------------+


//+------------------------------------------------------------------+
//| Expert Regras de Candles function                                |
//+------------------------------------------------------------------+
int RegrasCandle(double &MMa20[]){  
   if(rates[0].close > rates[1].close && rates[0].close > MMa20[0] > MMa20[1] )
      return SINAL_BUY;
   else if(rates[0].close < rates[1].close && rates[0].close < MMa20[0] && MMa20[0] < MMa20[1])
      return SINAL_SELL;
  return 0;
}
//+------------------------------------------------------------------+


//+------------------------------------------------------------------+
//| Expert Regras de Média function                                  |
//+------------------------------------------------------------------+
int RegrasMedia(double &MMa20[]){
   if(MMa20[0] > MMa20[1] && rates[0].close > MMa20[0])
      return SINAL_BUY;
   else if(MMa20[0] < MMa20[1] && rates[0].close < MMa20[0])
      return SINAL_SELL;
   return 0;
}
//+------------------------------------------------------------------+




