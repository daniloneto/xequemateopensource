#include <Trade\Trade.mqh>
CTrade trade;

#property script_show_inputs 
//--- SIM ou NÃO
enum SIM_NAO
  { 
   SIM=1,     // SIM
   NAO=0,     // NÃO
  }; 

// Configurações Base
input string                  configs_base = "Configurações Base";//Configurações Base
input string                  nome_ea = "XM - Open Source"; //Nome do EA
input ENUM_TIMEFRAMES         tempo_grafico = PERIOD_M15; //Tempo Gráfico
input ulong                   magicNum = 123456;//Magic Number
input SIM_NAO                 exibir_logs_grafico = SIM; //Exibir Logs no gráfico?
//cor do log
// tipo da janela móvel de resultados
input ENUM_ORDER_TYPE_FILLING preenchimento = ORDER_FILLING_RETURN;//Tipo do preenchimento de ordens à mercado
input ENUM_ORDER_TYPE_FILLING preenchimento_ordens_pendentes = ORDER_FILLING_RETURN;//Tipo do preenchimento de ordens pendentes
input ENUM_ORDER_TYPE_TIME    validade_ordens_pendentes = ORDER_TIME_DAY;//Tipo da validade das ordens pendentes

// Simulador de Custos Operacionais
input string                  custos_operacionais = "*** Custos Operacionais ***";//*** Custos Operacionais ***
input double                  custo_operacional_fixo_por_contrato = 0.48;//Custo operacional fixo por contrato
//custo operacional fixo por ordem
//exportação de dados do BT
//id do setup para hedge analyzer

// Parâmetros da Estratégia
input string                  parametros_estrategia = "*** Parâmetros da Estratégia ***";//*** Parâmetros da Estratégia ***
input int                     ma_periodo = 15; //Período da Média Móvel
input int                     distancia_media = 800; //Distância da Média em pontos
input int                     distancia_ordem_limit = 50; //Distância da ordem Limit
input int                     tempo_validade_ordem_limit = 900; //Tempo validade ordem limit [segundos] (0=Off)
input int                     numero_contratos = 1; //Número de contratos
input SIM_NAO                 filtro_gap = NAO; //[FILTRO GAP] Não operar dias com GAP maior que

// Parâmetros de Saída
input string                  parametros_saida = "*** Parâmetros de Saída ***";//*** Parâmetros de Saída ***
input SIM_NAO                 fechar_operacao_tensao = SIM; //Fechar Operação pela Tensão?
input double                  percentual_tensao_saida = 0; //% Tensão p/ saída

// Stops iniciais
input string                  stops_iniciais = "*** Stops Iniciais ***";//*** Stops Iniciais ***
input int                     stop_loss = 1200; //Stop Loss em pontos (SL)
input int                     stop_gain = 5000; //Stop Gain em pontos (TP)

// Janela de Operações
input string                  janela_operacoes = "*** Janela de Operações ***"; //*** Janela de Operações ***
input SIM_NAO                 marcar_horarios_linhas_verticais = SIM; //Marcar horários c/ linhas verticais no gráfico?
//dias da semana permitidos
//operar de segunda-feira
//operar de terça-feira
//operar de quarta-feira
//operar de quinta-feira
//operar de sexta-feira
//operar de sábado
//operar de domingo

// Período Diário
input string                  periodo_diario = "Período Diário"; //Período Diário
input string                  horario_inicial_abrir_posicoes = "09:30"; //Horário inicial permitido p/ abrir posições
input string                  horario_final_abrir_posicoes = "12:00"; //Horário final permitido p/ abrir posições

// Fechamento Diário
input string                  fechamento_diario = "Fechamento Diário"; //Fechamento Diário
input SIM_NAO                 fechar_posicoes_final_dia = SIM; //Fechar posições no final de cada dia?
input string                  horario_fechar_todas_posicoes = "13:00"; //Horário para fechar todas as posições em aberto

// Alertas e Notificações
input string                  alertas_notificacoes = "Alertas e Notificações"; //Alertas e Notificações
input SIM_NAO                 exibir_alerta_mt5_novas_posicoes = NAO; // Exibir um alerta no MT5 ao abrir novas posições?
input SIM_NAO                 enviar_notificacao_smartphone_primeiro_tick = SIM; // Notificação no Smartphone no primeiro tick do dia? 
input SIM_NAO                 enviar_notificacao_smartphone_novas_posicoes = SIM;// Notificação no Smartphone ao abrir novas posições? 
input SIM_NAO                 enviar_notificacao_smartphone_fechar_posicoes = SIM;// Notificação no Smartphone ao fechar posições? 
input SIM_NAO                 enviar_notificacao_smartphone_perda_conexao_corretora = SIM;// Notificação no Smartphone ao perder conexão com a corretora? 


input int                     ma_desloc = 0;//Deslocamento da Média
input ENUM_MA_METHOD          ma_metodo = MODE_SMA;//Método Média Móvel
input ENUM_APPLIED_PRICE      ma_preco = PRICE_CLOSE;//Preço para Média

input ulong                   desvPts = 50;//Desvio em Pontos


input double                  lote = 5.0;//Volume
input double                  stopLoss = 5;//Stop Loss
input double                  takeProfit = 5;//Take Profit

double                        smaArray[];
int                           smaHandle;

bool                          posAberta;

MqlTick                       ultimoTick;
MqlRates                      rates[];

MqlDateTime Time;

datetime                      inicio_dia;
datetime                      inicio_abertura;
datetime                      final_abertura;
datetime                      fechamento_posicoes;

int OnInit(){

   smaHandle = iMA(_Symbol, _Period, ma_periodo, ma_desloc, ma_metodo, ma_preco);
   if(smaHandle==INVALID_HANDLE)
      {
         Print("Erro ao criar média móvel - erro", GetLastError());
         return(INIT_FAILED);
      }
   ArraySetAsSeries(smaArray, true);
   ArraySetAsSeries(rates, true);
   
   trade.SetTypeFilling(preenchimento);
   trade.SetDeviationInPoints(desvPts);
   trade.SetExpertMagicNumber(magicNum);
   
   // Removendo o grid
   ChartSetInteger(0,CHART_SHOW_GRID,false);
   
   // Retorna operação com sucesso
   return(INIT_SUCCEEDED);

}

void OnTick()
  {               
      if(!SymbolInfoTick(Symbol(),ultimoTick))
         {
            Alert("Erro ao obter informações de Preços: ", GetLastError());
            return;
         }
         
      if(CopyRates(_Symbol, _Period, 0, 3, rates)<0)
         {
            Alert("Erro ao obter as informações de MqlRates: ", GetLastError());
            return;
         }
      
      if(CopyBuffer(smaHandle, 0, 0, 3, smaArray)<0)
         {
            Alert("Erro ao copiar dados da média móvel: ", GetLastError());
            return;
         }
         
      // Verifica a configuração de marcação dos horários com linhas verticais
      TimeToStruct (rates[0].time, Time);      
      if (marcar_horarios_linhas_verticais == SIM && Time.hour == 9 && Time.min == 0){
         
         // Recupera a data atual para utilizar nas variáveis das linhas de cada dia         
         string CurrDate = TimeToString(TimeCurrent(), TIME_DATE);

         // Plota a barra inicial do dia
         inicio_dia = StringToTime(CurrDate + " 09:00:00");
         ObjectCreate(0,"VerticalInicio"+CurrDate,OBJ_VLINE,0,inicio_dia,0); 
         ObjectSetInteger(0,"VerticalInicio"+CurrDate,OBJPROP_COLOR,clrSteelBlue);         
         ObjectSetInteger(0,"VerticalInicio"+CurrDate,OBJPROP_STYLE,STYLE_DOT);
         
         // Plota a barra inicial de abertura de posições
         inicio_abertura = StringToTime(CurrDate + " " + horario_inicial_abrir_posicoes + ":00");
         ObjectCreate(0,"VerticalInicioAbrirPosicoes"+CurrDate,OBJ_VLINE,0,inicio_abertura,0); 
         ObjectSetInteger(0,"VerticalInicioAbrirPosicoes"+CurrDate,OBJPROP_COLOR,clrMediumSpringGreen);         
         ObjectSetInteger(0,"VerticalInicioAbrirPosicoes"+CurrDate,OBJPROP_STYLE,STYLE_DOT);
         
         // Plota a barra final de abertura de posições
         final_abertura = StringToTime(CurrDate + " " + horario_final_abrir_posicoes + ":00");
         ObjectCreate(0,"VerticalFinalAbrirPosicoes"+CurrDate,OBJ_VLINE,0,final_abertura,0); 
         ObjectSetInteger(0,"VerticalFinalAbrirPosicoes"+CurrDate,OBJPROP_COLOR,clrSteelBlue);         
         ObjectSetInteger(0,"VerticalFinalAbrirPosicoes"+CurrDate,OBJPROP_STYLE,STYLE_DOT);
         
         // Plota a barra final de fechamento de todas as posições
         fechamento_posicoes = StringToTime(CurrDate + " " + horario_fechar_todas_posicoes + ":00");
         ObjectCreate(0,"VerticalFinalFecharPosicoes"+CurrDate,OBJ_VLINE,0,fechamento_posicoes,0); 
         ObjectSetInteger(0,"VerticalFinalFecharPosicoes"+CurrDate,OBJPROP_COLOR,clrTomato);
         ObjectSetInteger(0,"VerticalFinalFecharPosicoes"+CurrDate,OBJPROP_STYLE,STYLE_DOT);
         
      }
      
      
      
      // Gerencia as barras de distância à média
      ObjectDelete(0, "HorizontalTop");
      ObjectDelete(0, "HorizontalBottom");
      
      //MqlDateTime struct_inicio_abertura,struct_final_abertura;
      //TimeToStruct(inicio_abertura,struct_inicio_abertura);
      //TimeToStruct(final_abertura,struct_final_abertura);
      
      if ((TimeCurrent() > inicio_abertura || TimeCurrent() == inicio_abertura) && TimeCurrent() < final_abertura){
         Comment(""+smaArray[0]);
         // Define os valores das barras superior e inferior
         int barra_superior = smaArray[0] + distancia_media;
         int barra_inferior = smaArray[0] - distancia_media;
         
         //Comment("Barra Superior: " + barra_superior + "\n" + "Barra Inferior: " + barra_inferior);
         
         // Adiciona a barra superior
         ObjectDelete(0, "HorizontalTop");
         ObjectCreate(0,"HorizontalTop",OBJ_HLINE,0,rates[0].time,barra_superior);
         ObjectSetInteger(0,"HorizontalTop",OBJPROP_COLOR,clrRed);        
         
         // Adiciona a barra inferior
         ObjectDelete(0, "HorizontalBottom");
         ObjectCreate(0,"HorizontalBottom",OBJ_HLINE,0,rates[0].time,barra_inferior);
         ObjectSetInteger(0,"HorizontalBottom",OBJPROP_COLOR,clrBlue);
         
      }
      
      
      
              
         
//      posAberta = false;
//      for(int i = PositionsTotal()-1; i>=0; i--)
//         {
//            string symbol = PositionGetSymbol(i);
//            ulong magic = PositionGetInteger(POSITION_MAGIC);
//            if(symbol == _Symbol && magic==magicNum)
//               {  
//                  posAberta = true;
//                  break;
//               }
//         }
//      
//      if(ultimoTick.last>smaArray[0] && rates[1].close>rates[1].open && !posAberta)
//         {            
//            if(trade.Buy(lote, _Symbol, ultimoTick.ask, ultimoTick.ask-stopLoss, ultimoTick.ask+takeProfit, ""))
//               {
//                  Print("Ordem de Compra - sem falha. ResultRetcode: ", trade.ResultRetcode(), ", RetcodeDescription: ", trade.ResultRetcodeDescription());
//               }
//            else
//               {
//                  Print("Ordem de Compra - com falha. ResultRetcode: ", trade.ResultRetcode(), ", RetcodeDescription: ", trade.ResultRetcodeDescription());
//               }
//         }
//      else if(ultimoTick.last<smaArray[0] && rates[1].close<rates[1].open && !posAberta)
//         {
//            if(trade.Sell(lote, _Symbol, ultimoTick.bid, ultimoTick.bid+stopLoss, ultimoTick.bid-takeProfit, ""))
//               {
//                  Print("Ordem de Venda - sem falha. ResultRetcode: ", trade.ResultRetcode(), ", RetcodeDescription: ", trade.ResultRetcodeDescription());
//               }
//            else
//               {
//                  Print("Ordem de Venda - com falha. ResultRetcode: ", trade.ResultRetcode(), ", RetcodeDescription: ", trade.ResultRetcodeDescription());
//               }
//         }   
  }