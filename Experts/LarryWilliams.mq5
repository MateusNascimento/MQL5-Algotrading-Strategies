/*  
--------------------------------------------------------------------------------------------------------
  TODO
- Sem dois trades no mesmo dia
- Abaixar stop loss para 0.5 AVT
- Criar sistema de error handling, logs e notificação por e-mail
- Melhorar a função Volume() para utilizar todo o capital sem dar erro de saldo     
--------------------------------------------------------------------------------------------------------
*/

// LarryWilliams.mq5
// Mateus Nascimento
// mateusnascimento.com

#property copyright "Mateus Nascimento"
#property link      "mateusnascimento.com"
#property version   "1.00"

// libraries
#include<Trade\Trade.mqh>

// input parameters
input int       MaPeriod = 3;
input int       MaTrendPeriod = 9;
input int       MaTrendLB = 2;
input int       AtrPeriod = 14;
input int       EaMagic = 10001;
input int       AssetsInStrategy = 5;

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
    
        // update indicator every bar
        if(!UpdateIndicatorsOnBar()) return;
        
        //Trend = GetTrend2(MaHigh, MaLow, 1, MaPeriod - 1);
        Trend = GetTrend10(MaTrend, 1, MaTrendLB);
    }
        
    // update indicator every tick
    if(!UpdateIndicatorsOnTick()) return;
    double LastPrice = SymbolInfoDouble(_Symbol, SYMBOL_LAST);
      
    // if there's no position, check to open one
    if(PositionSelect(_Symbol) == false){  
        
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
// UP: IsIncreasingHigh && IsIncreasingLow
// DOWN: IsDecreasingHigh && IsDecreasingLow
ENUM_TREND GetTrend(double &ArrayHigh[], double &ArrayLow[], int StartIndex, int Length){
    
    bool IsIncreasingHigh = IsIncreasing(ArrayHigh, StartIndex, Length);
    bool IsIncreasingLow = IsIncreasing(ArrayLow, StartIndex, Length);
    bool IsDecreasingHigh = IsDecreasing(ArrayHigh, StartIndex, Length);
    bool IsDecreasingLow = IsDecreasing(ArrayLow, StartIndex, Length);
    
    if(IsIncreasingHigh && IsIncreasingLow){
        return TREND_UP;
    } else if(IsDecreasingHigh && IsDecreasingLow){
        return TREND_DOWN;
    } else {
        return TREND_NONE;
    }
}

// get trend
// UP: IsIncreasingLow && !IsDecreasingHigh
// DOWN: IsDecreasingHigh && !IsIncreasingLow
ENUM_TREND GetTrend2(double &ArrayHigh[], double &ArrayLow[], int StartIndex, int Length){
    
    bool IsIncreasingHigh = IsIncreasing(ArrayHigh, StartIndex, Length);
    bool IsIncreasingLow = IsIncreasing(ArrayLow, StartIndex, Length);
    bool IsDecreasingHigh = IsDecreasing(ArrayHigh, StartIndex, Length);
    bool IsDecreasingLow = IsDecreasing(ArrayLow, StartIndex, Length);
    
    //Print(IsIncreasingHigh);
    //Print(IsIncreasingLow);
    //Print(IsDecreasingHigh);
    //Print(IsDecreasingLow);
    //Print(StartIndex);
    //Print(Length);
    
    if(IsIncreasingLow && !IsDecreasingHigh){
        return TREND_UP;
    } else if(IsDecreasingHigh && !IsIncreasingLow){
        return TREND_DOWN;
    } else {
        return TREND_NONE;
    }
}

// get trend
// UP: IsIncreasingHigh && !IsDecreasingLow
// DOWN: IsDecreasingLow && !IsIncreasingHigh
ENUM_TREND GetTrend3(double &ArrayHigh[], double &ArrayLow[], int StartIndex, int Length){
    
    bool IsIncreasingHigh = IsIncreasing(ArrayHigh, StartIndex, Length);
    bool IsIncreasingLow = IsIncreasing(ArrayLow, StartIndex, Length);
    bool IsDecreasingHigh = IsDecreasing(ArrayHigh, StartIndex, Length);
    bool IsDecreasingLow = IsDecreasing(ArrayLow, StartIndex, Length);
    
    if(IsIncreasingHigh && !IsDecreasingLow){
        return TREND_UP;
    } else if(IsDecreasingLow && !IsIncreasingHigh){
        return TREND_DOWN;
    } else {
        return TREND_NONE;
    }
}

// get trend
// UP: IsIncreasingLow
// DOWN: IsDecreasingHigh
ENUM_TREND GetTrend4(double &ArrayHigh[], double &ArrayLow[], int StartIndex, int Length){
    
    bool IsIncreasingLow = IsIncreasing(ArrayLow, StartIndex, Length);
    bool IsDecreasingHigh = IsDecreasing(ArrayHigh, StartIndex, Length);
    
    if(IsIncreasingLow){
        return TREND_UP;
    } else if(IsDecreasingHigh){
        return TREND_DOWN;
    } else {
        return TREND_NONE;
    }
}

// get trend
// UP: IsIncreasingHigh
// DOWN: IsDecreasingLow
ENUM_TREND GetTrend5(double &ArrayHigh[], double &ArrayLow[], int StartIndex, int Length){
    
    bool IsIncreasingHigh = IsIncreasing(ArrayHigh, StartIndex, Length);
    bool IsDecreasingLow = IsDecreasing(ArrayLow, StartIndex, Length);
    
    if(IsIncreasingHigh){
        return TREND_UP;
    } else if(IsDecreasingLow){
        return TREND_DOWN;
    } else {
        return TREND_NONE;
    }
}

// get trend
// UP: IsIncreasingHigh && !IsDecreasingLow
// DOWN: IsDecreasingLow && !IsIncreasingHigh
ENUM_TREND GetTrend6(double &ArrayHigh[], double &ArrayLow[], int StartIndex, int Length){
    
    bool IsIncreasingHigh = IsIncreasing(ArrayHigh, StartIndex, Length);
    bool IsDecreasingHigh = IsDecreasing(ArrayHigh, StartIndex, Length);
    
    if(IsIncreasingHigh){
        return TREND_UP;
    } else if(IsDecreasingHigh){
        return TREND_DOWN;
    } else {
        return TREND_NONE;
    }
}

// get trend
// UP: IsIncreasingLow
// DOWN: IsDecreasingLow
ENUM_TREND GetTrend7(double &ArrayHigh[], double &ArrayLow[], int StartIndex, int Length){
    
    bool IsIncreasingLow = IsIncreasing(ArrayLow, StartIndex, Length);
    bool IsDecreasingLow = IsDecreasing(ArrayLow, StartIndex, Length);
    
    if(IsIncreasingLow){
        return TREND_UP;
    } else if(IsDecreasingLow){
        return TREND_DOWN;
    } else {
        return TREND_NONE;
    }
}

ENUM_TREND GetTrend10(double &Array[], int StartIndex, int Length){

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

// open long position
bool OpenLong(){

    //double Volume = 2000;
    double Volume = Volume();
    double Price = 0;
    //double StopLoss = 0;
    double StopLoss = SymbolInfoDouble(_Symbol, SYMBOL_ASK) - (Atr[1] * 1);
    double TakeProfit = 0;
    //double TakeProfit = SymbolInfoDouble(_Symbol, SYMBOL_BID) + (Atr[1] * 2);
    
    bool result = trade.Buy(Volume, _Symbol, Price, StopLoss, TakeProfit, NULL); 
    
    if(result){
        Print("Long position opened! Price ", SymbolInfoDouble(_Symbol, SYMBOL_ASK), ", SL ", StopLoss);
        return true;
    } else {
        if(trade.ResultRetcode() == TRADE_RETCODE_NO_MONEY){
            Volume = Volume - 100;
            result = trade.Buy(Volume, _Symbol, Price, StopLoss, TakeProfit, NULL);
            if(result){
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

    //double Volume = 2000;
    double Volume = Volume();
    double Price = 0;
    //double StopLoss = 0;
    double StopLoss = SymbolInfoDouble(_Symbol, SYMBOL_BID) + (Atr[1] * 1);       
    double TakeProfit = 0;
    //double TakeProfit = SymbolInfoDouble(_Symbol, SYMBOL_BID) - (Atr[1] * 2);
    
    bool result = trade.Sell(Volume, _Symbol, Price, StopLoss, TakeProfit, NULL); 
    
    if(result){
        Print("Short position opened!  Price ", SymbolInfoDouble(_Symbol, SYMBOL_BID), ", SL ", StopLoss);
        return true;
    } else {
        if(trade.ResultRetcode() == TRADE_RETCODE_NO_MONEY){
            Volume = Volume - 100;
            result = trade.Sell(Volume, _Symbol, Price, StopLoss, TakeProfit, NULL);
            if(result){
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

