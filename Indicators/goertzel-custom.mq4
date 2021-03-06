//+------------------------------------------------------------------+
//|                                  Goertzel browser 5.6.mq4 |
//|  based on Goertzel browser 5.5 version of mladen
//|  Jan 2014 modified by Boxter
//+------------------------------------------------------------------+
/*
- BarToCalculate specifies which is the starting bar to calculate cycles from  
(where SampleSize starts): setting it to 0 will calculate on a current (open) bar, setting 
it to any number > 0 calculates it on closed bars (which one depends on the value entered) 
- UseCosineForWaves: you can choose whether you want to use 
sine or cosine for waves "reconstruction". Cosine is the right way 
to calculate Goertzel !
- UseAdditionForSteps: One question still stays as of how previous bars phases are reconstructed : 
by addition of (2*Pi/period steps) to current phase or 
by subtraction from it in cycles (this is the correct way !), 
if parameter set to true, it will add steps to current phase, 
if set to false, it will subtract steps from current phase. 
- UseSquaredAmp: This may be useful when adding many cycles,
but may be misleading when using just 2 or 3 cycles. Use recommended. 
- UseTopCycles (sorted by largest amplit. or cycle strengths). They are not necessarily the 
waves with the largest Bartels cycle significance, but mostly they show a large significance.
If set > 1 you get a composite wave of all waves <1. Use cycle strength and Bartels >50 and 
select cycles with strength >1. Use not more than 10 cycles.
- WindowSizeFuture: is the size in bars you wish to extend to the future.

- cycle list: if true it will use up to 5 cycles you choose. You don't have to use consecutive cycles. 
E.g. you cane use 1,3,5th cycle.
- Subtract Noise is only working, when UseTopCycles < max. shown cycles in cycle list

new features Goertzel browser 5.6:
- Bartels cycle significance test for every extracted Goertzel cycle.
- smoothing of original time series data with Hodrick Prescott filter or Absolutly No Lag LWMA - no additional indis necessary !!!
- in detrending function Absolutly No Lag LWMA was added as alternative to HP algo - no additional indi necessary !!!
- added a special detrending method using a linear regression of the log 
  transformed smoothed time series data according to “Practical Implementation of Neural Network based time series” blog. 
- modified value table a bit adding Bartels values
- fixed several coding bugs with new MT4 editor
- SampleSize now = BartNoCycles*MaxCycLength+BarToCalculate; WindowSizePast: Must be >= SampleSize
- automated individual ListOfCyclesID

Note:
- UseCycleStrength is used as alternative to amplitude BEFORE Bartels test
*/

#property copyright "www.forex-tsd.com"
#property link      "www.forex-tsd.com"

#property indicator_separate_window
#property indicator_buffers     3
#property indicator_color1      White
#property indicator_color2      White
#property indicator_color3      White
#property indicator_width1      1
#property indicator_width2      1
#property indicator_width3      1
#property indicator_style1      STYLE_DOT
#property indicator_style2      STYLE_DOT
#property indicator_style3      STYLE_DOT
//property indicator_level1      0

// Bartels test for cycle significance (added by Boxter):
extern string info6             = "---Bartels Signifcance Test Settings---";
extern bool   FilterBartels     = false;
extern int    BartNoCycles      = 2; //considered cycles for significance
extern int    BartSmoothPer     = 2; // Min. Nyquist Period=2; Renko: =0
extern double BartSigLimit      = 40; 
extern bool   SortBartels       = false;

extern string info3             = "---------Cycle list settings---------";
extern bool   UseCycleList      = true;
extern int    Cycle1            = 1;
extern int    Cycle2            = 0;
extern int    Cycle3            = 0;
extern int    Cycle4            = 0;
extern int    Cycle5            = 0;
extern int    Offset            = 0;

extern string info1             = "---------Main settings---------";
extern string TimeFrame         = "Current time frame"; 
extern int    Price             = PRICE_WEIGHTED;
extern string ValTypeInfo       = "0=SMA;1=HP;2=ZLMA";
extern int    ValType           = 1;
extern int    HPsmoothPer       = 5;
extern int    ZLMAsmoothPer     = 10;
extern int    BarToCalculate    = 0;
 int    SampleSize;
extern int    StartAtCycle      = 1;
extern int    UseTopCycles      = 10;
extern bool   UseCosineForWaves   = true;
extern bool   UseAdditionForSteps = false;
extern bool   UseSquaredAmp       = true;
extern int    MaxCycLength      = 21;
extern bool   SubtractNoise     = true;
extern bool   Interpolate       = true;

extern string info2             ="---------Display settings---------";
extern int    WindowSizePast    = 110;
extern int    WindowSizeFuture  = 200;

 color  FutureLineColor         = Orange;
 int    FutureLineStyle         = STYLE_DOT;
extern int    FutureLineDisplace = 0;
extern bool   PredictionVisible   = false;
extern bool   ListOfCyclesVisible = true;
extern bool   MultiColor        = true;
 string ListOfCyclesID;
 int    ListOfCyclesCorner      = 1;
 color  ListOfCyclesTextColor   = Gray;
 color  ListOfCyclesValueColor  = White;
 
extern string info4             = "Detrend & smooth data before cycle detection";
extern bool   DetrendSmoothData = true; 
extern string DTmethodInfo      = "1=HP,2=ZLMA,3=RegLnZL";
                                  //1=DPO Hodrick Prescott Filter;
                                  //2=DPO mladen absolutely no lag lwma
                                  //3=Logarit. absolutely no lag lwma to Lin.Regression
extern int    DTmethod          = 1;
extern int    DT_HPper1         = 5;
extern int    DT_HPper2         = 20;
extern int    DT_ZLper1         = 10;
extern int    DT_ZLper2         = 40;
extern int    DT_RegZLsmoothPer = 5;

extern string info5             = "Replace Amplitude by Cycle Strength";
extern bool   UseCycleStrength  = true;


double goertzel[];
double goertzelUa[];
double goertzelUb[];
double goertzelFuture[];
double trend[];
double sourceValues[];

double workPast[][30];
double workFuture[][30];
double cycleBartelsBuffer[];
double sampleValues[];

string name;
int    ListOfCyclesWindow;
string indicatorFileName;
bool   calculateValue;
int    timeFrame;
string DT ;


//+------------------------------------------------------------------
//| init/deinit functions
//+------------------------------------------------------------------

int init(){
   Comment("");
   IndicatorDigits(6);
   IndicatorBuffers(6);
   SetIndexBuffer(0, goertzel);
   SetIndexBuffer(1, goertzelUa);
   SetIndexBuffer(2, goertzelUb);
   SetIndexBuffer(3, goertzelFuture);
   SetIndexBuffer(4, trend);
   SetIndexBuffer(5, sourceValues);   


   MaxCycLength   = MathMax(MaxCycLength,2);
   BarToCalculate = MathMax(BarToCalculate,0);
   SampleSize     = BartNoCycles*MaxCycLength+BarToCalculate;
   if (WindowSizePast < SampleSize){ 
      Alert("WindowSizePast ",WindowSizePast," < SampleSize ",SampleSize, " -> New WindowSizePast=SampleSize");
   } 
   WindowSizePast = MathMax(WindowSizePast,SampleSize);   
   
   if(ValType==0) DT = ";Native;"; 
   if(ValType==1) DT = ";HP Smoothed;";
   if(ValType==2) DT = ";ZLMA Smoothed;";
   if(DetrendSmoothData && DTmethod==1) DT = ";DPO HP;";
   if(DetrendSmoothData && DTmethod==2) DT = ";DPO ZLMA;";
   if(DetrendSmoothData && DTmethod==3) DT = ";Detrended RegLnZL;";
   indicatorFileName = WindowExpertName();
   int  chart_id = - ChartID();
   
   timeFrame      = stringToTimeFrame(TimeFrame);
   calculateValue = TimeFrame=="calculateValue";
   ListOfCyclesID  = "Goertzel;"+timeFrameToString(timeFrame)+ValType+DetrendSmoothData+DTmethod+";"+chart_id;
   if (!calculateValue) ListOfCyclesID = ListOfCyclesID;
 //  Print("------------------------------------ListOfCyclesID=",ListOfCyclesID);
 
   name = 1;
   Print (name);
   IndicatorShortName(name); 
   return(0);
}
 
int deinit(){
   string searchFor    = ListOfCyclesID+":";
   int    searchLength = StringLen(searchFor);
   for (int i=ObjectsTotal()-1; i>=0; i--){
      string oname = ObjectName(i); 
      if (StringSubstr(oname,0,searchLength) == searchFor)ObjectDelete(oname);
   }
   return(0);
}

//+------------------------------------------------------------------
//| start function
//+------------------------------------------------------------------

#define pi 3.141592653589793238462643383279502884197169399375105820974944592

int start(){
   if (Bars<WindowSizePast) { Comment("WindowSizePast ",WindowSizePast," > Bars ",Bars, " : Change !!"); return(0); }
   int counted_bars = IndicatorCounted();
   int limit,i,k,number_of_cycles;
   if(counted_bars < 0) return(-1);
   if(counted_bars > 0) counted_bars--;
   limit = MathMin(Bars-counted_bars,Bars-1);
   for(i = limit; i >= 0; i--)sourceValues[i] = iMA(NULL,0,1,0,MODE_SMA,Price,i);
   if (ArraySize(sampleValues) != SampleSize) ArrayResize(sampleValues,SampleSize); 
   ArrayInitialize(sampleValues,0); 
   
   if (calculateValue || timeFrame==Period()){
      if (MultiColor && !calculateValue && trend[limit]==-1) CleanPoint(limit,goertzelUa,goertzelUb);
      ListOfCyclesWindow = WindowFind(name);
      if (DetrendSmoothData) {
         if (DTmethod==1) iDetrend_CenteredMA(sampleValues,DT_HPper1,DT_HPper2,Price,SampleSize);  
         if (DTmethod==2) iDetrend_CenteredMA(sampleValues,DT_ZLper1,DT_ZLper2,Price,SampleSize); 
         if (DTmethod==3) iDetrend_LnZeroLagRegression(sampleValues,DT_RegZLsmoothPer,SampleSize);  
     //    if (DTmethod==3) for (i=0;i<SampleSize;i++)Print("sampleValues[",i,"]=",sampleValues[i]);    
                        
      } else {
         if (ValType==0) {
            
            for(i= 0; i < SampleSize;  i++) sampleValues[i] = sourceValues[i];
         }
         if (ValType==1) iHp(sampleValues, 0.0625/MathPow(MathSin(pi/HPsmoothPer),4),SampleSize);
         if (ValType==2) iZLMA(sampleValues,ZLMAsmoothPer,SampleSize); 
      } 
      
       
      // Print("sampleValuesSize=",ArraySize(sampleValues));  
      
      // total no. of cycles
      number_of_cycles = iGoertzel(BarToCalculate,WindowSizePast,workPast,WindowSizeFuture,
                                   workFuture,UseCosineForWaves,UseAdditionForSteps,UseSquaredAmp);
      if (ListOfCyclesVisible) showCycleList(number_of_cycles); 
      
      // past bar calc.  of composite wave
      for (i=0; i<WindowSizePast; i++) { // used bars past
         goertzel[i] = 0;
         if (UseCycleList){
            if (Cycle1 > 0) goertzel[i] += workPast[i][Cycle1-1];
            if (Cycle2 > 0) goertzel[i] += workPast[i][Cycle2-1];
            if (Cycle3 > 0) goertzel[i] += workPast[i][Cycle3-1];
            if (Cycle4 > 0) goertzel[i] += workPast[i][Cycle4-1];
            if (Cycle5 > 0) goertzel[i] += workPast[i][Cycle5-1];
         }else{
            for (k=StartAtCycle-1; k<StartAtCycle+UseTopCycles-1; k++) goertzel[i] += workPast[i][k];
            if (SubtractNoise)
               for (k = StartAtCycle+UseTopCycles-1; k<number_of_cycles; k++) goertzel[i] = goertzel[i]-workPast[i][k];
         }  
      }
      
      // future bar calc. of composite wave
      for (i=0; i<WindowSizeFuture; i++) {
         goertzelFuture[i] = 0;
         if (UseCycleList){
            if (Cycle1 > 0) goertzelFuture[i] += workFuture[i][Cycle1-1];
            if (Cycle2 > 0) goertzelFuture[i] += workFuture[i][Cycle2-1];
            if (Cycle3 > 0) goertzelFuture[i] += workFuture[i][Cycle3-1];
            if (Cycle4 > 0) goertzelFuture[i] += workFuture[i][Cycle4-1];
            if (Cycle5 > 0) goertzelFuture[i] += workFuture[i][Cycle5-1];   
         }else {
            for (k=StartAtCycle-1; k<StartAtCycle+UseTopCycles-1; k++) goertzelFuture[i] += workFuture[i][k];
            if (SubtractNoise)
               for (k = StartAtCycle+UseTopCycles-1; k<number_of_cycles; k++) goertzelFuture[i] = goertzelFuture[i]-workFuture[i][k];
         }
      }

      // Plot functions
      limit = WindowSizeFuture-1; int skip = -1;
      if (calculateValue) {
         skip=-0; limit+=1; 
         goertzelFuture[WindowSizeFuture-1]=goertzel[0];
         goertzelFuture[WindowSizeFuture+0]=goertzel[1];
         goertzelFuture[WindowSizeFuture+1]=goertzel[2];
         goertzelFuture[WindowSizeFuture+2]=goertzel[3]; 
      }
      else FutureLineDisplace=0;
      if (PredictionVisible)for (i=limit; i>0; i--){
         string cname = ListOfCyclesID+":"+"l:"+i;
         ObjectCreate(cname,OBJ_TREND,ListOfCyclesWindow,0,0);
         ObjectSet(cname,OBJPROP_TIME1, Time[0]+Period()*60*(WindowSizeFuture-i+skip)  -FutureLineDisplace);
         ObjectSet(cname,OBJPROP_TIME2, Time[0]+Period()*60*(WindowSizeFuture-i+skip+1)-FutureLineDisplace);
         ObjectSet(cname,OBJPROP_PRICE1,goertzelFuture[i]);
         ObjectSet(cname,OBJPROP_PRICE2,goertzelFuture[i-1]);
         ObjectSet(cname,OBJPROP_RAY,false);
         ObjectSet(cname,OBJPROP_COLOR,FutureLineColor);
         ObjectSet(cname,OBJPROP_STYLE,FutureLineStyle);
      }
      
      for (i=WindowSizePast-1; i>=0; i--){
         goertzelUa[i] = EMPTY_VALUE;
         goertzelUb[i] = EMPTY_VALUE;
         trend[i]      = trend[i+1];
         if (goertzel[i] > goertzel[i+1]) trend[i] =  1;
         if (goertzel[i] < goertzel[i+1]) trend[i] = -1;
         if (MultiColor && !calculateValue && trend[i]==-1) PlotPoint(i,goertzelUa,goertzelUb,goertzel);
      }           
      SetIndexDrawBegin(0,Bars-WindowSizePast+1);
      return(0);
   } 

   // MTF calc.
   limit = MathMin(Bars-1,WindowSizePast*timeFrame/Period());
   if (MultiColor && trend[limit]==-1) CleanPoint(limit,goertzelUa,goertzelUb);
   for (i=limit;i>=0; i--){
      int y  = iBarShift(NULL,timeFrame,Time[i]);

      goertzel[i] =   iCustom(NULL,timeFrame,indicatorFileName,"","calculateValue",Price,"",ValType,HPsmoothPer,
                      ZLMAsmoothPer,BarToCalculate,StartAtCycle,UseTopCycles,UseCosineForWaves,UseAdditionForSteps,
                      UseSquaredAmp,MaxCycLength,SubtractNoise,Interpolate,"",WindowSizePast,WindowSizeFuture,Period()*60,
                      PredictionVisible,ListOfCyclesVisible,false,"",UseCycleList,Cycle1,Cycle2,Cycle3,Cycle4,Cycle5,Offset,
                      "",DetrendSmoothData,DTmethodInfo,DTmethod,DT_HPper1,DT_HPper2,DT_ZLper1,DT_ZLper2,DT_RegZLsmoothPer,
                      "",UseCycleStrength,"",FilterBartels,BartNoCycles,BartSmoothPer,BartSigLimit,SortBartels,0,y);
                      
      trend[i]      = iCustom(NULL,timeFrame,indicatorFileName,"","calculateValue",Price,"",ValType,HPsmoothPer,
                      ZLMAsmoothPer,BarToCalculate,StartAtCycle,UseTopCycles,UseCosineForWaves,UseAdditionForSteps,
                      UseSquaredAmp,MaxCycLength,SubtractNoise,Interpolate,"",WindowSizePast,WindowSizeFuture,Period()*60,
                      PredictionVisible,ListOfCyclesVisible,false,"",UseCycleList,Cycle1,Cycle2,Cycle3,Cycle4,Cycle5,Offset,
                      "",DetrendSmoothData,DTmethodInfo,DTmethod,DT_HPper1,DT_HPper2,DT_ZLper1,DT_ZLper2,DT_RegZLsmoothPer,
                      "",UseCycleStrength,"",FilterBartels,BartNoCycles,BartSmoothPer,BartSigLimit,SortBartels,4,y);
      goertzelUa[i] = EMPTY_VALUE;
      goertzelUb[i] = EMPTY_VALUE;
      if (!Interpolate || y==iBarShift(NULL,timeFrame,Time[i-1])) continue; 
      interpolate(goertzel,iTime(NULL,timeFrame,y),i);
   }
   if (MultiColor) for (i=limit;i>=0;i--) if (trend[i]==-1) PlotPoint(i,goertzelUa,goertzelUb,goertzel);
   SetIndexDrawBegin(0,Bars-WindowSizePast*(timeFrame/Period())+1);
   return (0);
}

//+------------------------------------------------------------------
//| sub functions
//+------------------------------------------------------------------

//+------------------  Interpolate function-----------------------------------------------------

void interpolate(double& buffer[], datetime time, int i){
   for (int n = 1; (i+n) < Bars && Time[i+n] >= time; n++) continue;
   if (buffer[i] == EMPTY_VALUE || buffer[i+n] == EMPTY_VALUE) n=-1;
               double increment = (buffer[i+n] - buffer[i])/ n;
   for (int k = 1; k < n; k++)     buffer[i+k] = buffer[i] + k*increment;
}

//+-------------- Goertzel function-----------------------------------------------------

double  goeWork1[];
double  goeWork2[];
double  goeWork3[];
double  goeWork4[];
double  cycleLengthBuffer[];
double  cycleAmplitBuffer[];
double  cyclePhaseBuffer[];

int iGoertzel(int forBar, int numBarsPast, double& goeWorkPast[][], int numBarsFuture, double& goeWorkFuture[][], bool useCosine = true, bool useAddition = true, bool squaredAmp=true){
   int sample = MathMin(Bars-forBar,SampleSize-forBar);
   if (ArraySize(goeWork4)!=sample+1){  
       ArrayResize(goeWork1,sample+1); ArrayResize(goeWork2,sample+1);
       ArrayResize(goeWork3,sample+1); ArrayResize(goeWork4,sample+1);
   }
   if (ArraySize(cycleLengthBuffer)!=MaxCycLength+1){
      ArrayResize(cycleLengthBuffer,MaxCycLength+1);
      ArrayResize(cycleAmplitBuffer,MaxCycLength+1);
      ArrayResize(cyclePhaseBuffer ,MaxCycLength+1);
   }
   if (ArrayRange(goeWorkPast,0)  !=numBarsPast)   ArrayResize(goeWorkPast  ,numBarsPast);
   if (ArrayRange(goeWorkFuture,0)!=numBarsFuture) ArrayResize(goeWorkFuture,numBarsFuture);

   double temp1 =  sampleValues[forBar + sample-1];
   double temp2 = (sampleValues[forBar] - temp1) / (sample-1);
   double temp3;
   for (int k = sample; k>0; k--) {
       goeWork4[k] = sampleValues[forBar+k-1] - (temp1 + temp2*(sample-k));
       goeWork3[k] = 0;
   }
   goeWork3[0]=0;

   for (k = 2; k <= MaxCycLength; k++){
       double w = 0;
       double x = 0;
       double y = 0;
       double z = MathPow(k, -1);
       temp1 = 2.0 * MathCos(2.0 * pi * z);
       for (int i = sample; i > 0; i--){
           w = temp1 * x - y + goeWork4[i];
           y = x;
           x = w;
       }
       temp2 = x - y / 2.0 * temp1;
       if (temp2 == 0.0) temp2 = 0.0000001;
       temp3 = y * MathSin(2.0 * pi * z);

       if (UseCycleStrength){ //Cycle Strength  = Cycle Amplitude/ Cycle Length
                              //as described in “Decoding the Hidden Market Rhythm. 
                              //For trading it is more important to know which cycle 
                              //has the biggest influence to drive the price per bar, 
                              //and not only which cycle has the highest amplitude!
          if(squaredAmp==true)goeWork1[k] = (MathPow(temp2,2)+MathPow(temp3,2))/k;
          else                goeWork1[k] = (MathSqrt(MathPow(temp2,2)+MathPow(temp3,2)))/k;
          goeWork2[k] = MathArctan(temp3/temp2);
       } else {
          if(squaredAmp==true)goeWork1[k] =  MathPow(temp2,2)+MathPow(temp3,2);
          else                goeWork1[k] =  MathSqrt(MathPow(temp2,2)+MathPow(temp3,2));
          goeWork2[k] = MathArctan(temp3/temp2);
       }
       if (temp2 < 0.0)      goeWork2[k] += pi;
       else if (temp3 < 0.0) goeWork2[k] += 2.0 * pi;
   }
   
   for (k = 3; k < MaxCycLength; k++)
       if (goeWork1[k] > goeWork1[k+1] && goeWork1[k] > goeWork1[k-1]) goeWork3[k] = k * MathPow(10, -4);
       else  goeWork3[k] = 0.0;

   //    extract cycles
   int number_of_cycles = 0;
   for (i = 0; i<MaxCycLength+2; i++) if (goeWork3[i] > 0.0){
       cycleLengthBuffer[number_of_cycles] = MathRound(MathPow(10,4) * goeWork3[i]);
       cycleAmplitBuffer[number_of_cycles] = goeWork1[i];
       cyclePhaseBuffer [number_of_cycles] = goeWork2[i];
       number_of_cycles++;
   }   
 //  Print ("number_of_cycles Bartels=",number_of_cycles);
   
   //    order cycles acc. largest amplitude or cycle strength  
   for (i = 0; i < number_of_cycles-1; i++)
       for (k = i+1; k < number_of_cycles;   k++)
           if (cycleAmplitBuffer[k] > cycleAmplitBuffer[i]){
               y = cycleAmplitBuffer[i];
               w = cycleLengthBuffer[i];
               x = cyclePhaseBuffer[i];
               cycleAmplitBuffer[i] = cycleAmplitBuffer[k];
               cycleLengthBuffer[i] = cycleLengthBuffer[k];
               cyclePhaseBuffer[i]  = cyclePhaseBuffer[k];
               cycleAmplitBuffer[k] = y;
               cycleLengthBuffer[k] = w;
               cyclePhaseBuffer[k]  = x;    
   }
   
   // Execute Bartels test for cycle significance
   if (ArrayRange(cycleBartelsBuffer,0) != number_of_cycles) ArrayResize(cycleBartelsBuffer,number_of_cycles);
   ArrayInitialize(cycleBartelsBuffer,EMPTY_VALUE); 
   iBartelsCycleTest(number_of_cycles, cycleBartelsBuffer);  

   // order cycles acc. best Bartels prob.
   if (FilterBartels){   //Filter significant cycles
      int no_Bcycles=0, v;
      for (i = 0; i < number_of_cycles-1; i++) if (cycleBartelsBuffer[i]>BartSigLimit){ 
         cycleAmplitBuffer[no_Bcycles]    = cycleAmplitBuffer[i];
         cycleLengthBuffer[no_Bcycles]    = cycleLengthBuffer[i];
         cyclePhaseBuffer[no_Bcycles]     = cyclePhaseBuffer[i];
         cycleBartelsBuffer[no_Bcycles]   = cycleBartelsBuffer[i];
         no_Bcycles++;      
      }
      
      if (no_Bcycles==0)number_of_cycles=0;
      else {
         ArrayResize(cycleLengthBuffer,no_Bcycles);
         ArrayResize(cycleAmplitBuffer,no_Bcycles);
         ArrayResize(cyclePhaseBuffer ,no_Bcycles);
         ArrayResize(cycleBartelsBuffer,no_Bcycles);
         number_of_cycles = no_Bcycles;
      }      
      
      //Sort Bartels
      if (SortBartels && number_of_cycles >1)
         for (i = 0; i < number_of_cycles-1; i++)
           for (k = i+1; k < number_of_cycles;   k++)
            if (cycleBartelsBuffer[k] > cycleBartelsBuffer[i]){  // > because inverse Bartels percentage used
               y = cycleAmplitBuffer[i];
               w = cycleLengthBuffer[i];
               x = cyclePhaseBuffer[i];
               v = cycleBartelsBuffer[i];
               cycleAmplitBuffer[i] = cycleAmplitBuffer[k];
               cycleLengthBuffer[i] = cycleLengthBuffer[k];
               cyclePhaseBuffer[i]  = cyclePhaseBuffer[k];
               cycleBartelsBuffer[i]= cycleBartelsBuffer[k];
               cycleAmplitBuffer[k] = y;
               cycleLengthBuffer[k] = w;
               cyclePhaseBuffer[k]  = x;
               cycleBartelsBuffer[k]= v;
      } 
   }

   //    calculate waves
   for (i=0; i<number_of_cycles; i++) {
       double amplitude = cycleAmplitBuffer[i];
       // Print("amplitude[",i,"]=",amplitude);
       double phase     = cyclePhaseBuffer[i];
       int    cycle     = cycleLengthBuffer[i];
       double sign      = 1;
       if (!useAddition) sign=-1;
       
       for (k=0; k<numBarsPast; k++){
           if (useCosine)goeWorkPast[k][i] = amplitude * MathCos(phase+sign*k*2.0*pi/cycle);
           else          goeWorkPast[k][i] = amplitude * MathSin(phase+sign*k*2.0*pi/cycle);
       }
       sign *= -1;
       for (k=0; k<numBarsFuture; k++){
           if (useCosine)goeWorkFuture[numBarsFuture-k-1][i] = amplitude * MathCos(phase+sign*k*2.0*pi/cycle);
           else          goeWorkFuture[numBarsFuture-k-1][i] = amplitude * MathSin(phase+sign*k*2.0*pi/cycle);
       }
   }   
   return(number_of_cycles);
}

//+------------------------------------------------------------------
//|  functions  Display Cycle List  
//+------------------------------------------------------------------

void showCycleList(int number_of_cycles){
    deleteCycleList();
      
    //    normalize amplitude sampleValues display to < 100
    double max   = cycleAmplitBuffer[ArrayMaximum(cycleAmplitBuffer,number_of_cycles)];
    double coeff = MathMax(MathCeil(MathLog(max)/MathLog(10))-2,-4);
    
    // (c) Levabd
    GlobalVariableSet("GoertzelMaxLocalPeriod", 0);
    GlobalVariableSet("GoertzelMaxLocalPeriod_M1", 0);
    GlobalVariableSet("GoertzelMaxLocalPeriod_M5", 0);
    GlobalVariableSet("GoertzelMaxLocalPeriod_M15", 0);
    GlobalVariableSet("GoertzelMaxLocalPeriod_M30", 0);
    GlobalVariableSet("GoertzelMaxLocalPeriod_H1", 0);
    GlobalVariableSet("GoertzelMaxLocalPeriod_H4", 0);

      showCycle(1,number_of_cycles+2,-1,0,0,0); // title
      for (int i=0; i< number_of_cycles; i++) showCycle(i+2,number_of_cycles+2,cycleLengthBuffer[i],
                                                        cycleAmplitBuffer[i]/MathPow(10,coeff),      
                                                        MathMod(cyclePhaseBuffer[i],2.0*pi)*180/pi, 
                                                        cycleBartelsBuffer[i]);
      showCycle(i+2,number_of_cycles+2,-2,coeff,0,0);  //number_of_cycles+2 because of additional title line and coeff line
    
    // (c) Levabd
    int __period = Period();
    double periodCandidat2Save = GlobalVariableGet("GoertzelMaxLocalPeriod");
    switch(__period)
    {
        case 1 : periodCandidat2Save = GlobalVariableGet("GoertzelMaxLocalPeriod_M1"); break; 
        case 5 : periodCandidat2Save = GlobalVariableGet("GoertzelMaxLocalPeriod_M5"); break; 
        case 15 : periodCandidat2Save = GlobalVariableGet("GoertzelMaxLocalPeriod_M15"); break; 
        case 30 : periodCandidat2Save = GlobalVariableGet("GoertzelMaxLocalPeriod_M30"); break; 
        case 60 : periodCandidat2Save = GlobalVariableGet("GoertzelMaxLocalPeriod_H1"); break;
        case 240 : periodCandidat2Save = GlobalVariableGet("GoertzelMaxLocalPeriod_H4"); break;
        default: periodCandidat2Save = GlobalVariableGet("GoertzelMaxLocalPeriod");
    }
    // Alert(((periodCandidat2Save < 11) || (periodCandidat2Save > 21)) ? 17 : periodCandidat2Save);
    switch(__period)
    {
       case 1 : GlobalVariableSet("GoertzelPeriod_Storage_M1", ((periodCandidat2Save < 11) || (periodCandidat2Save > 21)) ? 17 : periodCandidat2Save); break; 
       case 5 : GlobalVariableSet("GoertzelPeriod_Storage_M5", ((periodCandidat2Save < 11) || (periodCandidat2Save > 21)) ? 17 : periodCandidat2Save); break; 
       case 15 : GlobalVariableSet("GoertzelPeriod_Storage_M15", ((periodCandidat2Save < 11) || (periodCandidat2Save > 21)) ? 17 : periodCandidat2Save); break; 
       case 30 : GlobalVariableSet("GoertzelPeriod_Storage_M30", ((periodCandidat2Save < 11) || (periodCandidat2Save > 21)) ? 17 : periodCandidat2Save); break; 
       case 60 : GlobalVariableSet("GoertzelPeriod_Storage_H1", ((periodCandidat2Save < 11) || (periodCandidat2Save > 21)) ? 17 : periodCandidat2Save); break;
       case 240 : GlobalVariableSet("GoertzelPeriod_Storage_H4", ((periodCandidat2Save < 11) || (periodCandidat2Save > 21)) ? 17 : periodCandidat2Save); break;
       default: GlobalVariableSet("GoertzelPeriod_Storage", ((periodCandidat2Save < 11) || (periodCandidat2Save > 21)) ? 17 : periodCandidat2Save);
    }
    
}

void deleteCycleList(){
   string searchFor    = ListOfCyclesID+":L";
   int    searchLength = StringLen(searchFor);
   for (int i=ObjectsTotal()-1; i>=0; i--){
      string oname = ObjectName(i); 
      if (StringSubstr(oname,0,searchLength) == searchFor)ObjectDelete(oname);
   }
}

double xpos1[] = {159,137,92,52,10}; // with titles
double xpos2[] = {10,52,92,137,159}; // with titles

void showCycle(int cycleNo, int totalCycles, double period, double amplitude, double phase, double BP){
// adapted and extended by Boxter
   double xpos[5]; // former [6]; incl. Bartels value
   int    ypos; 
   string Amp = "Amp"; if (UseCycleStrength) Amp = "CySt"; 
      
   if (ListOfCyclesCorner== 2 || ListOfCyclesCorner==3) 
         ypos = (totalCycles-cycleNo+1)*10;
   else  ypos = cycleNo*10;          
   if (ListOfCyclesCorner== 1 || ListOfCyclesCorner==3) //1=right upper corner, 3 right lower corner
         ArrayCopy(xpos,xpos1);
   else  ArrayCopy(xpos,xpos2);
   
   if (period==-1){    //title
      setElement(cycleNo+"-0",xpos[0],ypos,ListOfCyclesTextColor,"Rnk");
      setElement(cycleNo+"-1",xpos[1],ypos,ListOfCyclesTextColor,"Prd");
      setElement(cycleNo+"-2",xpos[2],ypos,ListOfCyclesTextColor,"Brt"); // Bartels probability
      setElement(cycleNo+"-3",xpos[3],ypos,ListOfCyclesTextColor,Amp);  
      setElement(cycleNo+"-4",xpos[4],ypos,ListOfCyclesTextColor,"Phs"); 
   }  
   
   // (c) Levabd
   int __period = Period();
   if ((cycleNo > 1) && (period >0)) { // First significant Row
      double periodCandidat2Save = MathRound(period);
      double maxLocalPeriod = GlobalVariableGet("GoertzelMaxLocalPeriod");
      switch(__period)
      {
           case 1 : maxLocalPeriod = GlobalVariableGet("GoertzelMaxLocalPeriod_M1"); break; 
           case 5 : maxLocalPeriod = GlobalVariableGet("GoertzelMaxLocalPeriod_M5"); break; 
           case 15 : maxLocalPeriod = GlobalVariableGet("GoertzelMaxLocalPeriod_M15"); break; 
           case 30 : maxLocalPeriod = GlobalVariableGet("GoertzelMaxLocalPeriod_M30"); break; 
           case 60 : maxLocalPeriod = GlobalVariableGet("GoertzelMaxLocalPeriod_H1"); break;
           case 240 : maxLocalPeriod = GlobalVariableGet("GoertzelMaxLocalPeriod_H4"); break;
           default: maxLocalPeriod = GlobalVariableGet("GoertzelMaxLocalPeriod");
      }
      // Alert(cycleNo, "; ", maxLocalPeriod);
      // Alert(periodCandidat2Save, "; ",  maxLocalPeriod, "; ", (periodCandidat2Save > maxLocalPeriod));
      periodCandidat2Save = (periodCandidat2Save > maxLocalPeriod) ? periodCandidat2Save : maxLocalPeriod;
      GlobalVariableSet("GoertzelMaxLocalPeriod", periodCandidat2Save);
      switch(__period)
      {
         case 1 : GlobalVariableSet("GoertzelMaxLocalPeriod_M1", periodCandidat2Save); break; 
         case 5 : GlobalVariableSet("GoertzelMaxLocalPeriod_M5", periodCandidat2Save); break; 
         case 15 : GlobalVariableSet("GoertzelMaxLocalPeriod_M15", periodCandidat2Save); break; 
         case 30 : GlobalVariableSet("GoertzelMaxLocalPeriod_M30", periodCandidat2Save); break; 
         case 60 : GlobalVariableSet("GoertzelMaxLocalPeriod_H1", periodCandidat2Save); break;
         case 240 : GlobalVariableSet("GoertzelMaxLocalPeriod_H4", periodCandidat2Save); break;
         default: GlobalVariableSet("GoertzelMaxLocalPeriod", periodCandidat2Save);
      }
   }
   
   if (period >0){         
      setElement(cycleNo+"-0",xpos[0],ypos,ListOfCyclesValueColor,cycleNo-1);
      setElement(cycleNo+"-1",xpos[1],ypos,ListOfCyclesValueColor,DoubleToStr(period,0));
      setElement(cycleNo+"-2",xpos[2],ypos,ListOfCyclesValueColor,DoubleToStr(BP,2)); // Bartels probability
      setElement(cycleNo+"-3",xpos[3],ypos,ListOfCyclesValueColor,DoubleToStr(amplitude,2));            
      setElement(cycleNo+"-4",xpos[4],ypos,ListOfCyclesValueColor,DoubleToStr(phase,2));
   }      
      
   if (period==-2)
      if (ListOfCyclesCorner== 1 || ListOfCyclesCorner==3)
            setElement(cycleNo+"-5",xpos[4],ypos,ListOfCyclesTextColor ,"* ampl/cyst multiplier : 10^"+DoubleToStr(amplitude,0),8);
      else  setElement(cycleNo+"-5",xpos[0],ypos,ListOfCyclesTextColor ,"* ampl/cyst multiplier : 10^"+DoubleToStr(amplitude,0),8);  
}

void setElement(string element, int x, int y, color ecolor=Silver, string text = "", int fontsize = 8, string fontname="Arial", int angle=0){
   string oname = ListOfCyclesID+":L"+element+" "+Symbol();
   ObjectCreate(oname, OBJ_LABEL, ListOfCyclesWindow, 0, 0);
      ObjectSet(oname, OBJPROP_XDISTANCE, x);
      ObjectSet(oname, OBJPROP_YDISTANCE, y);
      ObjectSet(oname, OBJPROP_BACK, FALSE);
      ObjectSet(oname, OBJPROP_CORNER, ListOfCyclesCorner);
      ObjectSet(oname, OBJPROP_ANGLE, angle);
      ObjectSetText(oname, text, fontsize, fontname, ecolor);
}

//+----------------- MTF function

string sTfTable[] = {"M1","M5","M15","M30","H1","H4","D1","W1","MN"};
int    iTfTable[] = {1,5,15,30,60,240,1440,10080,43200};

int stringToTimeFrame(string tfs){
   tfs = stringUpperCase(tfs);
   for (int i=ArraySize(iTfTable)-1; i>=0; i--)
       if (tfs==sTfTable[i] || tfs==""+iTfTable[i]) return(MathMax(iTfTable[i],Period()));
   return(Period());
}

string timeFrameToString(int tf){
   for (int i=ArraySize(iTfTable)-1; i>=0; i--) 
       if (tf==iTfTable[i]) return(sTfTable[i]);
   return("");
}

string stringUpperCase(string str){
   string s = str;
   int charac;
   for (int length=StringLen(str)-1; length>=0; length--){
      charac = StringGetChar(s, length);
      if((charac > 96 && charac < 123) || (charac > 223 && charac < 256))
         s = StringSetChar(s, length, charac - 32);
      else if(charac > -33 && charac < 0)
         s = StringSetChar(s, length, charac + 224);
   }
   return(s);
}

//+----------------- Plot function

void CleanPoint(int i,double& first[],double& second[]){
   if ((second[i]  != EMPTY_VALUE) && (second[i+1] != EMPTY_VALUE))
        second[i+1] = EMPTY_VALUE;
   else
      if ((first[i] != EMPTY_VALUE) && (first[i+1] != EMPTY_VALUE) && (first[i+2] == EMPTY_VALUE))
          first[i+1] = EMPTY_VALUE;
}

void PlotPoint(int i,double& first[],double& second[],double& from[]){
   if (first[i+1] == EMPTY_VALUE){
      if (first[i+2] == EMPTY_VALUE) {
          first[i]   = from[i];
          first[i+1] = from[i+1];
          second[i]  = EMPTY_VALUE;
      }else {
          second[i]   =  from[i];
          second[i+1] =  from[i+1];
          first[i]    = EMPTY_VALUE;
      }
   }else{
      first[i]  = from[i];
      second[i] = EMPTY_VALUE;
   }
}

//--------------Hodrick Prescott Detrending--------------------------+

void iDetrend_CenteredMA(double& output[], int period1, int period2, int price, int calcBars){
   double calcValues1[], calcValues2[];
  // calcBars = MathMin(Bars,MathMax(calcBars+period1+period2,500));
  // if (calcBars > Bars) calcBars = Bars;
   if (ArraySize(calcValues1) != calcBars) {
       ArrayResize(calcValues1 ,calcBars);
       ArrayResize(calcValues2 ,calcBars);
   }  
 //  if (ArraySize(output)!= calcBars+1) ArrayResize(output,calcBars+1);

   if (DTmethod==1){
      iHp(calcValues1,0.0625/MathPow(MathSin(pi/period1),4),calcBars);
      iHp(calcValues2,0.0625/MathPow(MathSin(pi/period2),4),calcBars);
      for(int i=0; i<calcBars; i++) output[i] = calcValues1[i]-calcValues2[i];
   }
   if (DTmethod==2){   
      iZLMA(calcValues1,period1,calcBars); 
      iZLMA(calcValues2,period2,calcBars); 
      for(i=0; i<calcBars;i++) output[i] = calcValues1[i]-calcValues2[i];
   }
}

void iHp(double& output[], double lambda, int nobs){   
   double H1 =0, H2 =0, H3 =0, H4 =0, H5 =0;
   double HH1=0, HH2=0, HH3=0, HH4=0, HH5=0;
   double HB,HC;
   double Z;
   double a[],b[],c[];
   if (ArraySize(a)!= nobs) {
       ArrayResize(a,nobs);
       ArrayResize(b,nobs);
       ArrayResize(c,nobs);
   }  
   if (ArraySize(output)!= nobs) ArrayResize(output,nobs);
   
   if (nobs <= 5) return;
   a[0]= 1.0+lambda;
   b[0]=-2.0*lambda;
   c[0]=     lambda;
   
   for(int i=1;i<nobs-2;i++){
      a[i]= 6.0*lambda+1.0;
      b[i]=-4.0*lambda;
      c[i]=     lambda;                                             
   }

   a[1]      = 1.0+lambda*5.0;
   a[nobs-1] = 1.0+lambda;
   a[nobs-2] = 1.0+lambda*5.0;
   b[nobs-2] =-2.0*lambda;
   b[nobs-1] = 0.0;
   c[nobs-2] = 0.0;
   c[nobs-1] = 0.0;
   //Forward   
   for (i=0;i<nobs;i++){
      Z=a[i]-H4*H1-HH5*HH2;
      if (Z==0) break;
      HB   = b[i];
      HH1  = H1;
      H1   = (HB-H4*H2)/Z;
      b[i] = H1;

      HC   = c[i];
      HH2  = H2;
      H2   = HC/Z;
      c[i] = H2;

      a[i] = (sourceValues[i]-HH3*HH5-H3*H4)/Z; // Print("a[",i,"]=",a[i]);
      HH3  = H3;
      H3   = a[i];
      H4   = HB-H5*HH1;
      HH5  = H5;
      H5   = HC;
   }
   //Backward
   H2 = 0;
   H1 = a[nobs-1];
   output[nobs-1]=H1; // Print("output[",nobs-1,"]=",output[nobs-1]);
   for (i=nobs-2; i>=0; i--){
      output[i]=a[i]-b[i]*H1-c[i]*H2;
      H2=H1;
      H1=output[i]; 
   }
}

//----------------------Bartels Cycle Significance Test function-------------------------------
// G= No. of Goertzel cycles
// BartNoCycles = no. of considered cycles for significance per cycle curve (usually 5, extern variable)
// BartelsProb = Bartels Probability: Used for statistical significance testing;
// check http://www.cyclesresearchinstitute.org/cycles-general/bartel.pdf

double Bvalues[];                 // time series data per cycle period
void iBartelsCycleTest(int G, double& BartelsProb[]){ 
   int k; 
   if (ArrayRange(BartelsProb,0) !=G)  ArrayResize(BartelsProb,G);
     
   for ( k=0; k<G; k++) {
      // Extract time series data per cycle considered for significance
      int bpi = MathRound(cycleLengthBuffer[k]);
      if (ArrayRange(Bvalues,0) != bpi*BartNoCycles) {ArrayResize(Bvalues,bpi*BartNoCycles);} // incl. 0 variable
      ArrayInitialize(Bvalues,EMPTY_VALUE);   
      iDetrend_LnZeroLagRegression(Bvalues,BartSmoothPer,bpi*BartNoCycles) ; 
   //   for(i=0; i<bpi*BartNoCycles; i++)Print("Bvalues[",i,"]=",Bvalues[i]);
      BartelsProb[k] = (1-iBartelsProb(bpi,BartNoCycles))*100; //reverse percentage as Bartels value
   } 
}  

double iBartelsProb(int n,int N) {  
   int t,i;
   double AvgCoeffA=0,AvgCoeffB=0,AvgIndAmplit=0,AvgAmpl,ExptAmpl,ARatio,BP;
   double teta[],vsin[],vcos[],CoeffA[],CoeffB[],IndAmplit[];
   if (ArrayRange(teta,0) !=n)      ArrayResize(teta,n);       ArrayInitialize(teta,0);
   if (ArrayRange(vsin,0) !=n)      ArrayResize(vsin,n);       ArrayInitialize(vsin,0);
   if (ArrayRange(vcos,0) !=n)      ArrayResize(vcos,n);       ArrayInitialize(vcos,0);
   if (ArrayRange(CoeffA,0) !=N)    ArrayResize(CoeffA,N);     ArrayInitialize(CoeffA,0);
   if (ArrayRange(CoeffB,0) !=N)    ArrayResize(CoeffB,N);     ArrayInitialize(CoeffB,0);  
   if (ArrayRange(IndAmplit,0)!=N)  ArrayResize(IndAmplit,N);  ArrayInitialize(IndAmplit,0);  
   
   // Calculation of sin and cos sampleValues per cycle period  
   for (i=0; i<n; i++){ 
      teta[i]=1.0*(i+1)/n*2*pi; 
      vsin[i]= MathSin(teta[i]);
      vcos[i]= MathCos(teta[i]); 
   }
   
   // Calculate individual coefficients A, B and individual amplitude 
   // (Bartels cycles are calculated either with sin or cos waves. For measuring cycle significance
   // only the no. of considered cycle periods is important, not the kind of cycle calculation. 
   // Therefore the combined sin/cos usage for calculating significance coeffs is ok)
   for (t=0; t<N; t++){  
      for(i=0; i<n; i++){ 
         CoeffA[t] += vsin[i]*Bvalues[t*n+i];  
         CoeffB[t] += vcos[i]*Bvalues[t*n+i];  
      } 
      IndAmplit[t] = MathPow(CoeffA[t],2) + MathPow(CoeffB[t],2);
   }   
   
   // Average coefficients and average individual amplitude 
   for (t=0; t<N; t++){ 
      AvgCoeffA      += CoeffA[t];
      AvgCoeffB      += CoeffB[t];
      AvgIndAmplit   += IndAmplit[t];
   }
   AvgCoeffA = AvgCoeffA/N; 
   AvgCoeffB = AvgCoeffB/N;                
   AvgAmpl = MathSqrt( MathPow(AvgCoeffA,2)+MathPow(AvgCoeffB,2) ); // Average amplitude
   
   AvgIndAmplit = MathSqrt(AvgIndAmplit/N); //Avg. Individual Ampl. or Avg.Vector
   ExptAmpl = AvgIndAmplit / MathSqrt(1.0*N);  // Expected Amplitude
   ARatio = AvgAmpl/ExptAmpl;
   BP=1/MathExp(MathPow(ARatio,2));
   return(BP);
}  

//--------------Logarithmic ZeroLagMA Values Regression Detrending --------------------------+

void iDetrend_LnZeroLagRegression(double& output[], int SmoothPer, int BarsTaken) { 
   int i;
   double RegValue[], calcValues[];
   if (ArraySize(RegValue)   != BarsTaken) ArrayResize(RegValue,BarsTaken); 
   if (ArraySize(calcValues) != BarsTaken) ArrayResize(calcValues,BarsTaken); 
   if (ArraySize(output) != BarsTaken) ArrayResize(output,BarsTaken);
   
   iZLMA(calcValues,SmoothPer,BarsTaken);
   for(i=0; i<BarsTaken; i++){calcValues[i]=MathLog(calcValues[i])*100;  }
 //      if (BarsTaken == SampleSize) Print("calcValues[",i,"]=",calcValues[i]);
       
//linear regression calc.
   double val1,val2,val3;
   double sumy=0.0;
   double sumx=0.0;
   double sumxy=0.0;
   double sumx2=0.0;
   for(i=0; i<BarsTaken; i++){
      sumy +=calcValues[i];
      sumx +=i;
      sumxy+=i*calcValues[i];
      sumx2+=i*i;
   }
   val3=sumx2*BarsTaken-sumx*sumx;
   if(val3==0.0) return;
   val2=(sumxy*BarsTaken-sumx*sumy)/val3;
   val1=(sumy-sumx*val2)/BarsTaken;
   for(i=0; i<BarsTaken; i++)RegValue[i]=val1+val2*i; // if(BarsTaken==SampleSize) Print("RegValue[",i,"]=",RegValue[i]);}
   for(i=0; i<BarsTaken; i++) output[i]=calcValues[i]-RegValue[i];// if(BarsTaken==SampleSize) Print("output[",i,"]=",output[i]);}
   
  // if(BarsTaken==SampleSize) { Print("RegSize=",ArraySize(output);}
  //Don't use RETURN keyword !! 
}

//---------------------------Absolutly No-Lag MA mladen by mladen - Forex TSD
// http://www.forex-tsd.com/elite-section/3580-elite-indicators-252.html#post381102
// limited to ArraySize output[] = BarsTaken

void iZLMA (double& output[],int SmoothPer,int BarsTaken){ 
   double sum,sumw,weight;
   double lwma1[];
   int i,k;
   int limit=BarsTaken-1;
   if (ArraySize(lwma1) != BarsTaken) ArrayResize(lwma1,BarsTaken);
   ArrayInitialize(lwma1,EMPTY_VALUE);
   if (ArraySize(output) != BarsTaken) ArrayResize(output,BarsTaken);
   
   for(i=limit; i>=0; i--){
      for(k=0, sum=0, sumw=0; k<SmoothPer; k++) {
          weight = SmoothPer-k; sumw += weight; sum += weight*sourceValues[i+k]; 
      }
      if (sumw!=0)lwma1[i] = sum/sumw;
      else        lwma1[i] = 0;
      
   }
   
      
   for(i=0; i<=limit; i++){
      for(k=0, sum=0, sumw=0; k<SmoothPer && (i-k)>=0; k++) { 
          weight = SmoothPer-k; sumw += weight; sum += weight*lwma1[i-k]; 
      }             
      if (sumw!=0)output[i] = sum/sumw; 
      else        output[i] = 0;
    //  if (BarsTaken == SampleSize) Print("output[",i,"]=",output[i]);   
   }
   //if(BarsTaken==SampleSize)  {Print("lwma1Size=",ArraySize(lwma1),"; ZLMAsize=",ArraySize(output));}   
   //Don't use RETURN keyword !!
}

 
   