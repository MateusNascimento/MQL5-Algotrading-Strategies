/*  
--------------------------------------------------------------------------------------------------------
  TODO
- Melhorar questão da orientação a objeto
- Criar sistema de error handling, logs e notificação por e-mail

--------------------------------------------------------------------------------------------------------
*/

// LarryWilliams.mq5
// Mateus Nascimento
// mateusnascimento.com

#property copyright "Mateus Nascimento"
#property link      "mateusnascimento.com"
#property version   "3.00"

// libraries
#include <Trade\Trade.mqh>

// input parameters
input int       MaPeriod = 3;
input int       MaTrendPeriod = 12;
input int       MaTrendLB = 4;
input int       AtrPeriod = 14;
input int       EaMagic = 10001;
input int       AssetsInStrategy = 5;
input double    StopLossSize = 1;

// other variables
int MaHighHandle;
int MaLowHandle;
int MaTrendHandle;
int AtrHandle;
double MaHigh[];
double MaLow[];
double MaTrend[];
double MaHighSignal[1];
double MaLowSignal[1];
double Atr[2];
datetime LastTrade;

// enums
enum ENUM_TREND {
    TREND_UP,
    TREND_DOWN,
    TREND_NONE
};

// objects
CTrade  trade;

// expert initialization function
int OnInit(){
    
    // define indicators handles
    MaHighHandle = iMA(_Symbol, _Period, MaPeriod, 0, MODE_SMA, PRICE_HIGH);      
    MaLowHandle = iMA(_Symbol, _Period, MaPeriod, 0, MODE_SMA, PRICE_LOW);
    MaTrendHandle = iMA(_Symbol, _Period, MaTrendPeriod, 0, MODE_SMA, PRICE_CLOSE);
    AtrHandle = iATR(_Symbol, _Period, AtrPeriod);
    
    // set arrays as time series
    ArraySetAsSeries(MaHigh, true);
    ArraySetAsSeries(MaLow, true);
    ArraySetAsSeries(MaTrend, true);
    
    // config CTrade
    trade.SetExpertMagicNumber(EaMagic);
    trade.SetTypeFilling(ORDER_FILLING_RETURN);
    
    return(INIT_SUCCEEDED);
    
}
// expert deinitialization function
void OnDeinit(const int reason){
    IndicatorRelease(MaHighHandle);
    IndicatorRelease(MaLowHandle);
    IndicatorRelease(MaTrendHandle);
    IndicatorRelease(AtrHandle);    
}

// expert tick function
void OnTick(){

   // new bar = update trend
    static ENUM_TREND Trend;
    if(IsNewBar()){
    
        Print(IsAnyOrderOpened());
    
        // update indicator every bar
        if(!UpdateIndicatorsOnBar()) return;
        
        Trend = GetTrend(MaTrend, 1, MaTrendLB);
    }
        
    // update indicator every tick
    if(!UpdateIndicatorsOnTick()) return;
    double LastPrice = SymbolInfoDouble(_Symbol, SYMBOL_LAST);
    
    // if last trade wasnt on current bar
    if(!(LastTrade == iTime(_Symbol, _Period, 0))){
       
        // if there's no position or order opened, check to open one
        if(PositionSelect(_Symbol) == false && IsAnyOrderOpened() == false){  
            
            // if there's a trend defined
            if(Trend != TREND_NONE){
                        
                // if trend is up
                if(Trend == TREND_UP){
                    // if price < MaLow
                    if(LastPrice < MaLowSignal[0]){
                        if(!OpenLong()) return;                        
                    }        
                // if trend is down
                } else if(Trend == TREND_DOWN){
                    // if price > MaHigh
                    if(LastPrice > MaHighSignal[0]){
                        if(!OpenShort()) return;
                    }
                }
            }    
        // if there's a position, check to close it    
        } else {
            if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY){
                // if price > MaHigh
                if(LastPrice > MaHighSignal[0]){
                    if(!CloseLong()) return;
                }                
            } else if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL){
                // if price < MaLow
                if(LastPrice < MaLowSignal[0]){
                    if(!CloseShort()) return;
                }
            }         
        }
    }             
}

// ***** CUSTOM FUNCTIONS ***** //

// close long position
bool CloseLong(){
    
    bool result = trade.PositionClose(_Symbol);
        
    if(result){
    Print("Long position closed!");
        return result;
    } else {
        Alert("Error when closing long position! Code: ", trade.ResultRetcode(), ", Description: ", trade.ResultRetcodeDescription());
        return result;
    }
}

// close short position
bool CloseShort(){
    
    bool result = trade.PositionClose(_Symbol);
        
    if(result){
        Print("Short position closed!");
        return result;
    } else {
        Alert("Error when closing short position! Code: ", trade.ResultRetcode(), ", Description: ", trade.ResultRetcodeDescription());
        return result;
    }
}

// get trend
// UP: IsIncreasing
// DOWN: IsDecreasing
ENUM_TREND GetTrend(double &Array[], int StartIndex, int Length){

    bool IsIncreasing = IsIncreasing(Array, StartIndex, Length);
    bool IsDecreasing = IsDecreasing(Array, StartIndex, Length);
    
    if(IsIncreasing){
        return TREND_UP;
    } else if(IsDecreasing){
        return TREND_DOWN;
    } else {
        return TREND_NONE;
    }

}

// check order or position open
bool IsAnyOrderOpened(){  
    for(int i = OrdersTotal()-1; i >= 0; i--){
        if(OrderSelect(OrderGetTicket(i))){
            if(OrderGetString(ORDER_SYMBOL) == _Symbol){
                return true;
            }
        }       
    }    
    return false;
}

// check if a Array is decreasing, given a certain length
bool IsDecreasing(double &Array[], int StartIndex, int Length){
    bool result = true;
    for(int i = StartIndex; i < Length + StartIndex; i++){
        if(Array[i] >= Array[i + 1]){
            result = false;
        }        
    }
    return result;
}

// check if a Array is increasing, given a certain length
bool IsIncreasing(double &Array[], int StartIndex, int Length){
    bool result = true;
    for(int i = StartIndex; i < Length + StartIndex; i++){
        if(Array[i] <= Array[i + 1]){
            result = false;
        }        
    }
    return result;
}

// Check if is a new bar
bool IsNewBar(){    
    static datetime OldTime;
    datetime CurrentTime = iTime(_Symbol, _Period, 0);
    
    if(OldTime == CurrentTime){
        return false;
    } else {
        OldTime = CurrentTime;
        return true;
    }        
}

// return amount of money in symbol (pending orders + position)
double MoneyInSymbol(){
    double Money = 0;
    if(PositionSelect(_Symbol) == true) Money = Money + (PositionGetDouble(POSITION_PRICE_OPEN) * PositionGetDouble(POSITION_VOLUME));    
    for(int i = OrdersTotal()-1; i >= 0; i--){
        if(OrderSelect(OrderGetTicket(i))){
            if(OrderGetString(ORDER_SYMBOL) == _Symbol){
                Money = Money + (OrderGetDouble(ORDER_PRICE_OPEN) * OrderGetDouble(ORDER_VOLUME_CURRENT));
            }
        }       
    }
    return Money;    
}

// open long position
bool OpenLong(){

    double Volume = Volume();
    double Price = 0;
    double StopLoss = SymbolInfoDouble(_Symbol, SYMBOL_ASK) - (Atr[1] * StopLossSize);
    double TakeProfit = 0;
    //double TakeProfit = SymbolInfoDouble(_Symbol, SYMBOL_BID) + (Atr[1] * 2);
    
    // double check looking for opened positions or orders
    double MoneyInSymbol = MoneyInSymbol();
    if(MoneyInSymbol > 0){
        Alert("Error when opening long position! Symbol has already $", MoneyInSymbol, " on positions or pendings orders.");
        return false;   
    }
    
    bool result = trade.Buy(Volume, _Symbol, Price, StopLoss, TakeProfit, NULL); 
    
    if(result){
        Print("Long position opened! Price ", SymbolInfoDouble(_Symbol, SYMBOL_ASK), ", SL ", StopLoss);
        return true;
    } else {
        if(trade.ResultRetcode() == TRADE_RETCODE_NO_MONEY){
            Volume = Volume - 100;
            result = trade.Buy(Volume, _Symbol, Price, StopLoss, TakeProfit, NULL);
            if(result){
                LastTrade = iTime(_Symbol, _Period, 0);
                Print("Long position opened!  Price ", SymbolInfoDouble(_Symbol, SYMBOL_BID), ", SL ", StopLoss);
                return true;
            }
        }
        Alert("Error when opening long position! Code: ", trade.ResultRetcode(), ", Description: ", trade.ResultRetcodeDescription());
        return false;
    }
}

// open short position
bool OpenShort(){

    double Volume = Volume();
    double Price = 0;
    double StopLoss = SymbolInfoDouble(_Symbol, SYMBOL_BID) + (Atr[1] * StopLossSize);       
    double TakeProfit = 0;
    //double TakeProfit = SymbolInfoDouble(_Symbol, SYMBOL_BID) - (Atr[1] * 2);
    
    // double check looking for opened positions or orders
    double MoneyInSymbol = MoneyInSymbol();
    if(MoneyInSymbol > 0){
        Alert("Error when opening short position! Symbol has already $", MoneyInSymbol, " on positions or pendings orders.");
        return false;   
    }
    
    bool result = trade.Sell(Volume, _Symbol, Price, StopLoss, TakeProfit, NULL); 
    
    if(result){
        Print("Short position opened!  Price ", SymbolInfoDouble(_Symbol, SYMBOL_BID), ", SL ", StopLoss);
        return true;
    } else {
        if(trade.ResultRetcode() == TRADE_RETCODE_NO_MONEY){
            Volume = Volume - 100;
            result = trade.Sell(Volume, _Symbol, Price, StopLoss, TakeProfit, NULL);
            if(result){
                LastTrade = iTime(_Symbol, _Period, 0);
                Print("Short position opened!  Price ", SymbolInfoDouble(_Symbol, SYMBOL_BID), ", SL ", StopLoss);
                return true;
            }            
        }        
        Alert("Error when opening short position! Code: ", trade.ResultRetcode(), ", Description: ", trade.ResultRetcodeDescription());
        return false;
    }
}

// update indicators on bar
bool UpdateIndicatorsOnBar(){
    
    // updating and checking for erros
    if( CopyBuffer(MaHighHandle, 0, 0, MaPeriod + 1, MaHigh)        < 0 ||
        CopyBuffer(MaLowHandle, 0, 0, MaPeriod + 1, MaLow)          < 0 ||
        CopyBuffer(AtrHandle, 0, 0, 2, Atr)                         < 0 ||
        CopyBuffer(MaTrendHandle, 0, 0, MaTrendLB + 2, MaTrend)     < 0 ){        
        Alert("Error updating indicators 'on bar'! Code: ", GetLastError());
        return false;
    } else {
        return true;
    }
}

// update indicators on tick
bool UpdateIndicatorsOnTick(){
    int res1 = CopyBuffer(MaHighHandle, 0, 0, 1, MaHighSignal);
    int res2 = CopyBuffer(MaLowHandle, 0, 0, 1, MaLowSignal);
    
    // check for erros
    if(res1 < 0 || res2 < 0){
        Alert("Error updating indicators 'on tick'! Code: ", GetLastError());
        return false;
    } else {
        return true;
    }
}

double Volume(){
    double AccountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    double LastPrice = SymbolInfoDouble(_Symbol, SYMBOL_LAST);
    //double Volume = MathFloor((AccountBalance / LastPrice / 100)  - 1) * 100;
    double Volume = MathFloor(AccountBalance / LastPrice / AssetsInStrategy / 100) * 100;
    Volume = NormalizeDouble(Volume, 2);
    return Volume;
}

