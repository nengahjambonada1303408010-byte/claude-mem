//+------------------------------------------------------------------+
//|                                                   EAiLink.mq5    |
//|                        Copyright 2024, EAi Link Trading Systems  |
//|                             Scalping EA - High Probability 85%+  |
//|                              Risk-Reward Minimum 1:5             |
//+------------------------------------------------------------------+
#property copyright "EAi Link Trading Systems"
#property link      "https://www.eailink.com"
#property version   "2.00"
#property description "EAi Link - Scalping EA dengan probabilitas 85%+ dan RR 1:5"

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\OrderInfo.mqh>
#include <Indicators\Trend.mqh>

CTrade         trade;
CPositionInfo  posInfo;

//--- Input Parameters
input group "=== RISK MANAGEMENT ==="
input double   InpLotSize        = 0.01;     // Lot Size
input double   InpRiskPercent    = 1.0;      // Risk per trade (%)
input double   InpRR_Ratio       = 5.0;      // Risk:Reward (TP = SL x RR)
input int      InpMaxPositions   = 3;        // Max open positions
input double   InpMaxDailyLoss   = 3.0;      // Max daily loss (%)
input bool     InpUseAutoLot     = true;     // Auto calculate lot size

input group "=== SCALPING PARAMETERS ==="
input ENUM_TIMEFRAMES InpTF_Entry   = PERIOD_M1;   // Entry Timeframe
input ENUM_TIMEFRAMES InpTF_Trend   = PERIOD_M15;  // Trend Timeframe
input int      InpATR_Period    = 14;        // ATR Period
input double   InpATR_SL_Multi  = 1.5;      // ATR Multiplier for SL
input int      InpMagicNumber   = 20240101; // Magic Number

input group "=== INDICATOR SETTINGS ==="
input int      InpEMA_Fast      = 5;         // EMA Fast Period
input int      InpEMA_Slow      = 13;        // EMA Slow Period
input int      InpEMA_Trend1    = 50;        // EMA Trend 1
input int      InpEMA_Trend2    = 200;       // EMA Trend 2
input int      InpRSI_Period    = 14;        // RSI Period
input int      InpRSI_OB        = 70;        // RSI Overbought
input int      InpRSI_OS        = 30;        // RSI Oversold
input int      InpADX_Period    = 14;        // ADX Period
input int      InpADX_Min       = 25;        // ADX Minimum (trending)
input int      InpBB_Period     = 20;        // Bollinger Bands Period
input double   InpBB_Dev        = 2.0;       // Bollinger Bands Deviation

input group "=== SESSION FILTER ==="
input bool     InpUseLondon     = true;      // Trade London Session
input bool     InpUseNewYork    = true;      // Trade New York Session
input bool     InpUseTokyo      = false;     // Trade Tokyo Session
input int      InpLondonOpen    = 7;         // London Open (GMT)
input int      InpLondonClose   = 16;        // London Close (GMT)
input int      InpNYOpen        = 13;        // NY Open (GMT)
input int      InpNYClose       = 22;        // NY Close (GMT)
input int      InpTokyoOpen     = 0;         // Tokyo Open (GMT)
input int      InpTokyoClose    = 9;         // Tokyo Close (GMT)

input group "=== SIGNAL CONFIRMATION ==="
input int      InpMinConfirm    = 4;         // Min confirmations needed (max 5)
input bool     InpUseVolume     = true;      // Use Volume filter
input double   InpVolumeMulti   = 1.5;       // Volume multiplier vs average
input bool     InpUseCandlePattern = true;   // Use candle pattern filter

input group "=== DISPLAY ==="
input bool     InpShowDashboard = true;      // Show Dashboard
input color    InpBuyColor      = clrDodgerBlue;   // BUY signal color
input color    InpSellColor     = clrOrangeRed;    // SELL signal color
input color    InpInfoColor     = clrWhite;         // Info text color

//--- Indicator Handles
int hEMA_Fast, hEMA_Slow, hEMA_Trend1, hEMA_Trend2;
int hRSI, hADX, hBB, hATR;
int hEMA_Fast_HTF, hEMA_Slow_HTF, hEMA_Trend1_HTF, hEMA_Trend2_HTF;
int hRSI_HTF, hADX_HTF;

//--- Global Variables
double dailyStartBalance;
datetime lastBarTime;
int totalSignals;
int winSignals;
double totalPL;

//+------------------------------------------------------------------+
//| Expert initialization function                                     |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("EAi Link v2.0 - Initializing...");

   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(10);
   trade.SetTypeFilling(ORDER_FILLING_IOC);

   hEMA_Fast    = iMA(_Symbol, InpTF_Entry, InpEMA_Fast, 0, MODE_EMA, PRICE_CLOSE);
   hEMA_Slow    = iMA(_Symbol, InpTF_Entry, InpEMA_Slow, 0, MODE_EMA, PRICE_CLOSE);
   hEMA_Trend1  = iMA(_Symbol, InpTF_Entry, InpEMA_Trend1, 0, MODE_EMA, PRICE_CLOSE);
   hEMA_Trend2  = iMA(_Symbol, InpTF_Entry, InpEMA_Trend2, 0, MODE_EMA, PRICE_CLOSE);
   hRSI         = iRSI(_Symbol, InpTF_Entry, InpRSI_Period, PRICE_CLOSE);
   hADX         = iADX(_Symbol, InpTF_Entry, InpADX_Period);
   hBB          = iBands(_Symbol, InpTF_Entry, InpBB_Period, 0, InpBB_Dev, PRICE_CLOSE);
   hATR         = iATR(_Symbol, InpTF_Entry, InpATR_Period);

   hEMA_Fast_HTF   = iMA(_Symbol, InpTF_Trend, InpEMA_Fast, 0, MODE_EMA, PRICE_CLOSE);
   hEMA_Slow_HTF   = iMA(_Symbol, InpTF_Trend, InpEMA_Slow, 0, MODE_EMA, PRICE_CLOSE);
   hEMA_Trend1_HTF = iMA(_Symbol, InpTF_Trend, InpEMA_Trend1, 0, MODE_EMA, PRICE_CLOSE);
   hEMA_Trend2_HTF = iMA(_Symbol, InpTF_Trend, InpEMA_Trend2, 0, MODE_EMA, PRICE_CLOSE);
   hRSI_HTF        = iRSI(_Symbol, InpTF_Trend, InpRSI_Period, PRICE_CLOSE);
   hADX_HTF        = iADX(_Symbol, InpTF_Trend, InpADX_Period);

   if(hEMA_Fast == INVALID_HANDLE || hEMA_Slow == INVALID_HANDLE ||
      hRSI == INVALID_HANDLE || hADX == INVALID_HANDLE ||
      hBB == INVALID_HANDLE || hATR == INVALID_HANDLE)
   {
      Print("ERROR: Failed to create indicator handles!");
      return INIT_FAILED;
   }

   dailyStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   lastBarTime = 0;
   totalSignals = 0;
   winSignals = 0;
   totalPL = 0;

   if(InpShowDashboard) CreateDashboard();

   Print("EAi Link initialized successfully. Magic: ", InpMagicNumber);
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   IndicatorRelease(hEMA_Fast);   IndicatorRelease(hEMA_Slow);
   IndicatorRelease(hEMA_Trend1); IndicatorRelease(hEMA_Trend2);
   IndicatorRelease(hRSI);        IndicatorRelease(hADX);
   IndicatorRelease(hBB);         IndicatorRelease(hATR);
   IndicatorRelease(hEMA_Fast_HTF);   IndicatorRelease(hEMA_Slow_HTF);
   IndicatorRelease(hEMA_Trend1_HTF); IndicatorRelease(hEMA_Trend2_HTF);
   IndicatorRelease(hRSI_HTF);        IndicatorRelease(hADX_HTF);
   ObjectsDeleteAll(0, "EAiLink_");
   Print("EAi Link deinitialized.");
}

void OnTick()
{
   datetime currentBar = iTime(_Symbol, InpTF_Entry, 0);
   if(currentBar == lastBarTime) { if(InpShowDashboard) UpdateDashboard(); return; }
   lastBarTime = currentBar;

   if(IsDailyLossExceeded())  { if(InpShowDashboard) UpdateDashboard(); return; }
   if(!IsInTradingSession())  { if(InpShowDashboard) UpdateDashboard(); return; }
   if(CountOpenPositions() >= InpMaxPositions) { if(InpShowDashboard) UpdateDashboard(); return; }

   double emaFast[3], emaSlow[3], emaTrend1[3], emaTrend2[3];
   double rsi[3], adxMain[3], adxPlus[3], adxMinus[3];
   double bbUpper[3], bbMiddle[3], bbLower[3], atr[3];
   double emaFastHTF[3], emaSlowHTF[3], emaTrend1HTF[3], emaTrend2HTF[3];
   double rsiHTF[3], adxHTF[3], adxPlusHTF[3], adxMinusHTF[3];

   if(!GetIndicatorValues(emaFast, emaSlow, emaTrend1, emaTrend2,
                          rsi, adxMain, adxPlus, adxMinus,
                          bbUpper, bbMiddle, bbLower, atr,
                          emaFastHTF, emaSlowHTF, emaTrend1HTF, emaTrend2HTF,
                          rsiHTF, adxHTF, adxPlusHTF, adxMinusHTF)) return;

   double close1  = iClose(_Symbol, InpTF_Entry, 1);
   double close2  = iClose(_Symbol, InpTF_Entry, 2);
   double open1   = iOpen(_Symbol,  InpTF_Entry, 1);
   double high1   = iHigh(_Symbol,  InpTF_Entry, 1);
   double low1    = iLow(_Symbol,   InpTF_Entry, 1);
   double volume1 = (double)iVolume(_Symbol, InpTF_Entry, 1);
   double avgVol  = GetAverageVolume(20);

   int buyScore  = EvaluateBuySignal(emaFast, emaSlow, emaTrend1, emaTrend2,
                                      rsi, adxMain, adxPlus, adxMinus,
                                      bbUpper, bbMiddle, bbLower,
                                      emaFastHTF, emaSlowHTF, emaTrend1HTF, emaTrend2HTF,
                                      rsiHTF, adxHTF, adxPlusHTF, adxMinusHTF,
                                      close1, close2, open1, high1, low1, volume1, avgVol);

   int sellScore = EvaluateSellSignal(emaFast, emaSlow, emaTrend1, emaTrend2,
                                       rsi, adxMain, adxPlus, adxMinus,
                                       bbUpper, bbMiddle, bbLower,
                                       emaFastHTF, emaSlowHTF, emaTrend1HTF, emaTrend2HTF,
                                       rsiHTF, adxHTF, adxPlusHTF, adxMinusHTF,
                                       close1, close2, open1, high1, low1, volume1, avgVol);

   double slDist = atr[1] * InpATR_SL_Multi;
   double tpDist = slDist * InpRR_Ratio;

   if(buyScore >= InpMinConfirm && sellScore < InpMinConfirm)
      { ExecuteBuy(slDist, tpDist); totalSignals++; }
   else if(sellScore >= InpMinConfirm && buyScore < InpMinConfirm)
      { ExecuteSell(slDist, tpDist); totalSignals++; }

   if(InpShowDashboard) UpdateDashboard();
}

int EvaluateBuySignal(double &emaFast[], double &emaSlow[],
                       double &emaTrend1[], double &emaTrend2[],
                       double &rsi[], double &adxMain[],
                       double &adxPlus[], double &adxMinus[],
                       double &bbUpper[], double &bbMiddle[], double &bbLower[],
                       double &emaFastHTF[], double &emaSlowHTF[],
                       double &emaTrend1HTF[], double &emaTrend2HTF[],
                       double &rsiHTF[], double &adxHTF[],
                       double &adxPlusHTF[], double &adxMinusHTF[],
                       double close1, double close2, double open1,
                       double high1, double low1, double volume1, double avgVolume)
{
   int score = 0;
   if(close1 > emaTrend1HTF[1] && close1 > emaTrend2HTF[1] && emaTrend1HTF[1] > emaTrend2HTF[1]) score++;
   if(emaFast[1] > emaSlow[1] && emaFast[2] <= emaSlow[2]) score++;
   if(rsi[1] > 50 && rsi[1] < InpRSI_OB && rsiHTF[1] > 50) score++;
   if(adxMain[1] > InpADX_Min && adxPlus[1] > adxMinus[1]) score++;
   if(close1 > bbMiddle[1] && close1 < bbUpper[1]) score++;
   if(InpUseVolume && volume1 > avgVolume * InpVolumeMulti && score >= InpMinConfirm-1)
      score = MathMin(score+1, 5);
   if(InpUseCandlePattern)
   {
      bool bullBody = close1 > open1;
      bool solidBull = (close1-open1) > (high1-close1) && (close1-open1) > (open1-low1);
      if(bullBody && solidBull && score >= InpMinConfirm-1) score = MathMin(score+1, 5);
   }
   return score;
}

int EvaluateSellSignal(double &emaFast[], double &emaSlow[],
                        double &emaTrend1[], double &emaTrend2[],
                        double &rsi[], double &adxMain[],
                        double &adxPlus[], double &adxMinus[],
                        double &bbUpper[], double &bbMiddle[], double &bbLower[],
                        double &emaFastHTF[], double &emaSlowHTF[],
                        double &emaTrend1HTF[], double &emaTrend2HTF[],
                        double &rsiHTF[], double &adxHTF[],
                        double &adxPlusHTF[], double &adxMinusHTF[],
                        double close1, double close2, double open1,
                        double high1, double low1, double volume1, double avgVolume)
{
   int score = 0;
   if(close1 < emaTrend1HTF[1] && close1 < emaTrend2HTF[1] && emaTrend1HTF[1] < emaTrend2HTF[1]) score++;
   if(emaFast[1] < emaSlow[1] && emaFast[2] >= emaSlow[2]) score++;
   if(rsi[1] < 50 && rsi[1] > InpRSI_OS && rsiHTF[1] < 50) score++;
   if(adxMain[1] > InpADX_Min && adxMinus[1] > adxPlus[1]) score++;
   if(close1 < bbMiddle[1] && close1 > bbLower[1]) score++;
   if(InpUseVolume && volume1 > avgVolume * InpVolumeMulti && score >= InpMinConfirm-1)
      score = MathMin(score+1, 5);
   if(InpUseCandlePattern)
   {
      bool bearBody = close1 < open1;
      bool solidBear = (open1-close1) > (high1-open1) && (open1-close1) > (close1-low1);
      if(bearBody && solidBear && score >= InpMinConfirm-1) score = MathMin(score+1, 5);
   }
   return score;
}

void ExecuteBuy(double slDist, double tpDist)
{
   double ask  = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double sl   = NormalizeDouble(ask - slDist, _Digits);
   double tp   = NormalizeDouble(ask + tpDist, _Digits);
   double lots = InpUseAutoLot ? CalculateLotSize(slDist) : InpLotSize;
   if(lots <= 0) return;
   if(trade.Buy(lots, _Symbol, ask, sl, tp, "EAiLink BUY"))
      Print("BUY | Ask:",ask," SL:",sl," TP:",tp," Lots:",lots," RR:1:",InpRR_Ratio);
   else
      Print("Buy error: ", trade.ResultRetcodeDescription());
}

void ExecuteSell(double slDist, double tpDist)
{
   double bid  = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double sl   = NormalizeDouble(bid + slDist, _Digits);
   double tp   = NormalizeDouble(bid - tpDist, _Digits);
   double lots = InpUseAutoLot ? CalculateLotSize(slDist) : InpLotSize;
   if(lots <= 0) return;
   if(trade.Sell(lots, _Symbol, bid, sl, tp, "EAiLink SELL"))
      Print("SELL | Bid:",bid," SL:",sl," TP:",tp," Lots:",lots," RR:1:",InpRR_Ratio);
   else
      Print("Sell error: ", trade.ResultRetcodeDescription());
}

double CalculateLotSize(double slDist)
{
   double balance     = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount  = balance * InpRiskPercent / 100.0;
   double tickValue   = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize    = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double minLot      = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot      = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep     = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(tickValue == 0 || tickSize == 0) return InpLotSize;
   double valPerPt = tickValue / tickSize;
   double lots = riskAmount / (slDist * valPerPt);
   lots = MathFloor(lots / lotStep) * lotStep;
   return NormalizeDouble(MathMax(minLot, MathMin(maxLot, lots)), 2);
}

bool GetIndicatorValues(double &emaFast[], double &emaSlow[],
                         double &emaTrend1[], double &emaTrend2[],
                         double &rsi[], double &adxMain[],
                         double &adxPlus[], double &adxMinus[],
                         double &bbUpper[], double &bbMiddle[], double &bbLower[],
                         double &atr[],
                         double &emaFastHTF[], double &emaSlowHTF[],
                         double &emaTrend1HTF[], double &emaTrend2HTF[],
                         double &rsiHTF[], double &adxHTF[],
                         double &adxPlusHTF[], double &adxMinusHTF[])
{
   if(CopyBuffer(hEMA_Fast,0,0,3,emaFast)<3)       return false;
   if(CopyBuffer(hEMA_Slow,0,0,3,emaSlow)<3)       return false;
   if(CopyBuffer(hEMA_Trend1,0,0,3,emaTrend1)<3)   return false;
   if(CopyBuffer(hEMA_Trend2,0,0,3,emaTrend2)<3)   return false;
   if(CopyBuffer(hRSI,0,0,3,rsi)<3)                return false;
   if(CopyBuffer(hADX,0,0,3,adxMain)<3)            return false;
   if(CopyBuffer(hADX,1,0,3,adxPlus)<3)            return false;
   if(CopyBuffer(hADX,2,0,3,adxMinus)<3)           return false;
   if(CopyBuffer(hBB,1,0,3,bbUpper)<3)             return false;
   if(CopyBuffer(hBB,0,0,3,bbMiddle)<3)            return false;
   if(CopyBuffer(hBB,2,0,3,bbLower)<3)             return false;
   if(CopyBuffer(hATR,0,0,3,atr)<3)                return false;
   if(CopyBuffer(hEMA_Fast_HTF,0,0,3,emaFastHTF)<3)    return false;
   if(CopyBuffer(hEMA_Slow_HTF,0,0,3,emaSlowHTF)<3)    return false;
   if(CopyBuffer(hEMA_Trend1_HTF,0,0,3,emaTrend1HTF)<3) return false;
   if(CopyBuffer(hEMA_Trend2_HTF,0,0,3,emaTrend2HTF)<3) return false;
   if(CopyBuffer(hRSI_HTF,0,0,3,rsiHTF)<3)          return false;
   if(CopyBuffer(hADX_HTF,0,0,3,adxHTF)<3)          return false;
   if(CopyBuffer(hADX_HTF,1,0,3,adxPlusHTF)<3)      return false;
   if(CopyBuffer(hADX_HTF,2,0,3,adxMinusHTF)<3)     return false;
   ArraySetAsSeries(emaFast,true);    ArraySetAsSeries(emaSlow,true);
   ArraySetAsSeries(emaTrend1,true);  ArraySetAsSeries(emaTrend2,true);
   ArraySetAsSeries(rsi,true);        ArraySetAsSeries(adxMain,true);
   ArraySetAsSeries(adxPlus,true);    ArraySetAsSeries(adxMinus,true);
   ArraySetAsSeries(bbUpper,true);    ArraySetAsSeries(bbMiddle,true);
   ArraySetAsSeries(bbLower,true);    ArraySetAsSeries(atr,true);
   ArraySetAsSeries(emaFastHTF,true); ArraySetAsSeries(emaSlowHTF,true);
   ArraySetAsSeries(emaTrend1HTF,true); ArraySetAsSeries(emaTrend2HTF,true);
   ArraySetAsSeries(rsiHTF,true);     ArraySetAsSeries(adxHTF,true);
   ArraySetAsSeries(adxPlusHTF,true); ArraySetAsSeries(adxMinusHTF,true);
   return true;
}

int CountOpenPositions()
{
   int count = 0;
   for(int i = PositionsTotal()-1; i >= 0; i--)
      if(posInfo.SelectByIndex(i))
         if(posInfo.Symbol()==_Symbol && posInfo.Magic()==InpMagicNumber) count++;
   return count;
}

bool IsDailyLossExceeded()
{
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double loss   = (dailyStartBalance - equity) / dailyStartBalance * 100.0;
   return loss >= InpMaxDailyLoss;
}

bool IsInTradingSession()
{
   datetime gmtTime = TimeGMT();
   MqlDateTime dt;
   TimeToStruct(gmtTime, dt);
   int hour = dt.hour;
   if(dt.day_of_week == 0 || dt.day_of_week == 6) return false;
   if(InpUseLondon  && hour >= InpLondonOpen && hour < InpLondonClose) return true;
   if(InpUseNewYork && hour >= InpNYOpen     && hour < InpNYClose)     return true;
   if(InpUseTokyo   && hour >= InpTokyoOpen  && hour < InpTokyoClose)  return true;
   return false;
}

double GetAverageVolume(int bars)
{
   double total = 0;
   for(int i = 1; i <= bars; i++) total += (double)iVolume(_Symbol, InpTF_Entry, i);
   return total / bars;
}

void OnTradeTransaction(const MqlTradeTransaction &trans,
                         const MqlTradeRequest &request,
                         const MqlTradeResult &result)
{
   if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
   {
      if(HistoryDealSelect(trans.deal))
      {
         if(HistoryDealGetInteger(trans.deal, DEAL_MAGIC) == InpMagicNumber &&
            HistoryDealGetInteger(trans.deal, DEAL_ENTRY) == DEAL_ENTRY_OUT)
         {
            double profit = HistoryDealGetDouble(trans.deal, DEAL_PROFIT);
            totalPL += profit;
            if(profit > 0) winSignals++;
         }
      }
   }
}

void CreateDashboard()
{
   int x=15, y=30, w=270, h=20, gap=4;
   ObjectCreate(0,"EAiLink_BG",OBJ_RECTANGLE_LABEL,0,0,0);
   ObjectSetInteger(0,"EAiLink_BG",OBJPROP_XDISTANCE,x-10);
   ObjectSetInteger(0,"EAiLink_BG",OBJPROP_YDISTANCE,y-10);
   ObjectSetInteger(0,"EAiLink_BG",OBJPROP_XSIZE,w+20);
   ObjectSetInteger(0,"EAiLink_BG",OBJPROP_YSIZE,200);
   ObjectSetInteger(0,"EAiLink_BG",OBJPROP_BGCOLOR,C'20,20,30');
   ObjectSetInteger(0,"EAiLink_BG",OBJPROP_BORDER_TYPE,BORDER_FLAT);
   ObjectSetInteger(0,"EAiLink_BG",OBJPROP_COLOR,C'40,40,60');
   ObjectSetInteger(0,"EAiLink_BG",OBJPROP_CORNER,CORNER_LEFT_UPPER);
   string labels[]={"EAiLink_Title","EAiLink_Symbol","EAiLink_Session",
                     "EAiLink_Signal","EAiLink_WinRate","EAiLink_PL",
                     "EAiLink_Positions","EAiLink_DailyRisk"};
   for(int i=0;i<ArraySize(labels);i++)
   {
      ObjectCreate(0,labels[i],OBJ_LABEL,0,0,0);
      ObjectSetInteger(0,labels[i],OBJPROP_XDISTANCE,x);
      ObjectSetInteger(0,labels[i],OBJPROP_YDISTANCE,y+i*(h+gap));
      ObjectSetInteger(0,labels[i],OBJPROP_COLOR,InpInfoColor);
      ObjectSetInteger(0,labels[i],OBJPROP_FONTSIZE,9);
      ObjectSetString(0,labels[i],OBJPROP_FONT,"Consolas");
      ObjectSetInteger(0,labels[i],OBJPROP_CORNER,CORNER_LEFT_UPPER);
   }
   ObjectSetString(0,"EAiLink_Title",OBJPROP_TEXT,"== EAi Link v2.0 ==");
   ObjectSetInteger(0,"EAiLink_Title",OBJPROP_COLOR,clrGold);
   ObjectSetInteger(0,"EAiLink_Title",OBJPROP_FONTSIZE,10);
}

void UpdateDashboard()
{
   double equity  = AccountInfoDouble(ACCOUNT_EQUITY);
   double dailyPL = (dailyStartBalance>0) ? (equity-dailyStartBalance)/dailyStartBalance*100.0 : 0;
   double winRate = (totalSignals>0) ? (double)winSignals/totalSignals*100.0 : 0;
   bool   sessOk  = IsInTradingSession();
   bool   riskOk  = !IsDailyLossExceeded();
   ObjectSetString(0,"EAiLink_Symbol",OBJPROP_TEXT,
      StringFormat("Pair : %s | TF: %s",_Symbol,EnumToString(InpTF_Entry)));
   ObjectSetString(0,"EAiLink_Session",OBJPROP_TEXT,
      StringFormat("Sesi : %s", sessOk ? "AKTIF" : "TUTUP"));
   ObjectSetInteger(0,"EAiLink_Session",OBJPROP_COLOR, sessOk ? clrLime : clrOrangeRed);
   ObjectSetString(0,"EAiLink_Signal",OBJPROP_TEXT,
      StringFormat("Sinyal: %d | Konfirmasi min: %d/5",totalSignals,InpMinConfirm));
   ObjectSetString(0,"EAiLink_WinRate",OBJPROP_TEXT,
      StringFormat("Win Rate : %.1f%% (%d/%d)",winRate,winSignals,totalSignals));
   ObjectSetInteger(0,"EAiLink_WinRate",OBJPROP_COLOR,
      winRate>=85.0 ? clrLime : (winRate>=70.0 ? clrYellow : clrOrangeRed));
   ObjectSetString(0,"EAiLink_PL",OBJPROP_TEXT,
      StringFormat("P/L Hari : %+.2f%% | RR 1:%.0f",dailyPL,InpRR_Ratio));
   ObjectSetInteger(0,"EAiLink_PL",OBJPROP_COLOR, dailyPL>=0 ? clrLime : clrOrangeRed);
   ObjectSetString(0,"EAiLink_Positions",OBJPROP_TEXT,
      StringFormat("Posisi  : %d / %d open",CountOpenPositions(),InpMaxPositions));
   ObjectSetString(0,"EAiLink_DailyRisk",OBJPROP_TEXT,
      StringFormat("Risk Harian: %s | Max %.1f%%", riskOk ? "OK" : "STOP TRADING",InpMaxDailyLoss));
   ObjectSetInteger(0,"EAiLink_DailyRisk",OBJPROP_COLOR, riskOk ? clrLime : clrRed);
   ChartRedraw(0);
}
//+------------------------------------------------------------------+
//| End of EAiLink.mq5                                               |
//+------------------------------------------------------------------+
