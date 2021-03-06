/*
 * <<< ЦИФРОВЫЕ ФИЛЬТРЫ ДЛЯ METATRADER 5 >>>
 *
 * Файл DF.dll следует положить в "\MetaTrader5\MQL5\Libraries\"
 * Внимание! Для работы DF.dll требуется три дополнительных DLL 
 * содержащих блок математической обработки - bdsp.dll, lapack.dll, mkl_support.dll,
 * которые должны быть установлены в "C:\Windows\System32\" для 32-х разрядных операционных систем Windows
 * или в "C:\Windows\SysWOW64\" для 64-х разрядных операционных систем Windows
 *
 * Перед использованием убедитесь:
 * 
 * 1. что установлен пункт "Разрешить импорт DLL" в настройках Меню->Сервис->Настройки->Советники
 * 2. Что в директории "C:\Windows\System32\" или в "C:\Windows\SysWOW64\" имеются 
 * Bdsp.dll, lapack.dll, mkl_support.dll - вспомогательные математические библиотеки
 *
 * Описание входных параметров:
 * 
 * Ftype -  Тип фильтра: 0 - ФНЧ (FATL/SATL/KGLP), 1 - ФВЧ (KGHP), 
 *          2 - полосовой (RBCI/KGBP), 3 - режекторный (KGBS)
 * P1 -     Период отсечки P1, бар
 * D1 -     Период отсечки переходного процесса D1, бар
 * A1 -     Затухание в полосе задержки А1, дБ
 * P2 -     Период отсечки P2, бар
 * D2 -     Период отсечки переходного процесса D2, бар
 * A2 -     Затухание в полосе задержки А2, дБ
 * Ripple - Биения в полосе пропускания, дБ
 * Delay -  Задержка, бар
 *
 * Для ФНЧ и ФВЧ значения параметрой P2,D2,A2 игнорируются
 * Условия работы:
 * ФНЧ: P1>D1
 * ФВЧ: P1<D1
 * Полосовой и режекторный: D2>P2>P1>D1
 */
//+------------------------------------------------------------------+
//|         Digital Low Pass (FATL/SATL, KGLP) Filter    DFilter.mq4 | 
//|                    Digital Filter: Copyright (c) Sergey Ilyukhin |
//|                           Moscow, qpo@mail.ru  http://fx.qrz.ru/ |
//|                              MQL5 CODE: 2010,   Nikolay Kositsin |
//|                              Khabarovsk,   farria@mail.redcom.ru | 
//+------------------------------------------------------------------+

#property strict 

//---- авторство индикатора
#property copyright "2005, Sergey Ilyukhin, Moscow"
//---- ссылка на сайт автора
#property link      "http://fx.qrz.ru/"
//---- номер версии индикатора
#property version   "1.00"

//---- отрисовка индикатора в основном окне
//#property indicator_chart_window
//---- отрисовка индикатора в отдельном окне
#property indicator_separate_window

//---- для расчета и отрисовки индикатора использован один буфер
#property indicator_buffers 1
//---- использовано всего одно графическое построение
#property indicator_plots   1
//---- отрисовка индикатора в виде линии
#property indicator_type1   DRAW_LINE
//---- в качестве цвета линии индикатора использован синий цвет
#property indicator_color1  Lime
//---- линия индикатора - непрерывная кривая
#property indicator_style1  STYLE_SOLID
//---- толщина линии индикатора равна 2
#property indicator_width1  2
//---- отображение метки индикатора
#property indicator_label1  "DFilter"

//---- объявление и инициализация перечисления типов цифровых фильтров
enum FType_ //Тип фильтра
  {
   LPF, //ФНЧ (FATL/SATL/KGLP)
   HPE, //ФВЧ (KGHP)
   BPF, //полосовой (RBCI/KGBP)
   SPF, //режекторный (KGBS)
  };

//---- входные параметры индикатора
input FType_ FType = LPF; // Тип фильтра
                        //0 - ФНЧ (FATL/SATL/KGLP), 1 - ФВЧ (KGHP), 2 - полосовой (RBCI/KGBP), 3 - режекторный (KGBS)
input int    P1 = 28;       // Период отсечки 1, бар
input int    D1 = 19;       // Период отсечки переходного процесса 1, бар
input int    A1 = 10;       // Затухание в полосе задержки 1, дБ
input int    P2 = 0;        // Период отсечки 2, бар
input int    D2 = 0;        // Период отсечки переходного процесса 2, бар
input int    A2 = 10;        // Затухание в полосе задержки 2, дБ
input int    Delay = 0;       // Задержка, бар
input double Ripple = 0.08;   // Биения в полосе пропускания, дБ 
input int    FILTERShift = 0; //сдвиг мувинга по горизонтали в барах 

//---- импорт DLL файла
#import "DF.dll"
int DigitalFilter(int FType,int P1,int D1,int A1,int P2,int D2,int A2,double Ripple,int Delay,double &array[]);
#import

//---- объявление и инициализация переменной для хранения количества расчетных баров
int FILTERPeriod;

//---- объявление динамического массива, который будет в 
// дальнейшем использован в качестве индикаторного буфера
double ExtLineBuffer[];

//---- объявление и инициализация массива для коэффициентов цифрового фильтра
double BaseFILTERTable[];

double closePrices[];

// Для заполнения фильтров
double filterValues[];
int startBar, finishBar;


int currentBarNumber;
double prevSignificantValue, currentSignificantValue, currentValue;

//+------------------------------------------------------------------------------------------+
//| Вычисление коэфициентов цифрового фильтра и определение размера буфера BaseFILTERTable[] |
//+------------------------------------------------------------------------------------------+  
void Initialise(int currentGoertzelPeriod)
{
   // Clear variables
   double Array[1500];
   ArrayFree(ExtLineBuffer);
   ArrayFree(BaseFILTERTable);
   
   SetIndexEmptyValue(0,0.0);
   SetIndexBuffer(0, ExtLineBuffer, INDICATOR_DATA); // превращение динамического массива ExtLineBuffer в индикаторный буфер
   PlotIndexSetInteger(0, PLOT_SHIFT, 0); // осуществление сдвига индикатора по горизонтали на FILTERShift
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, 0); // осуществление сдвига начала отсчета отрисовки индикатора
   
   string shortname; // инициализации переменной для короткого имени индикатора
   StringConcatenate(shortname, "FILTER(", FILTERShift, ")");
   PlotIndexSetString(0, PLOT_LABEL, shortname); // создание метки для отображения в DataWindow
   IndicatorSetString(INDICATOR_SHORTNAME, shortname); // создание имени для отображения в отдельном подокне и во всплывающей подсказке
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits+1); // определение точности отображения значений индикатора
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, 0.0); // запрет на отрисовку индикатором пустых значений

   FType_ MFType = BPF;
   int MA1 = 10;
   int MA2 = 10;
   int MDelay = 0;
   double MRipple = 0.08;
   int MFILTERShift = 0;
   int MP1 = currentGoertzelPeriod - 1;
   int MD1 = currentGoertzelPeriod - 2;
   int MP2 = currentGoertzelPeriod;
   int MD2 = currentGoertzelPeriod + 1;

   FILTERPeriod = DigitalFilter(MFType, MP1, MD1, MA1, MP2, MD2, MA2, MRipple, MDelay, Array);
   
   // изменение размера буфера FILTERTable[] под требуемое количество коэффициетов цифрового фильтра
   if (FILTERPeriod <= 0) {
      Print("Входные параметры некорректны. Работа индикатора невозможна!");
   }
   
   SetIndexShift(0, FILTERPeriod - 1);
     
   // копируем данные из временного массива размером 1500 в основной массив с размером FILTERPeriod
   ArrayCopy(BaseFILTERTable, Array, 0, 0, FILTERPeriod);
   
   //Alert(currentGoertzelPeriod, ", ", BaseFILTERTable[0]);
   
   GlobalVariableSet("UsedGoertzelPeriod", currentGoertzelPeriod);
   int period = Period();
   switch(period)
   {
      case 1 : GlobalVariableSet("UsedGoertzelPeriod_M1", currentGoertzelPeriod); break; 
      case 5 : GlobalVariableSet("UsedGoertzelPeriod_M5", currentGoertzelPeriod); break; 
      case 15 : GlobalVariableSet("UsedGoertzelPeriod_M15", currentGoertzelPeriod); break; 
      case 30 : GlobalVariableSet("UsedGoertzelPeriod_M30", currentGoertzelPeriod); break; 
      case 60 : GlobalVariableSet("UsedGoertzelPeriod_H1", currentGoertzelPeriod); break;
      case 240 : GlobalVariableSet("UsedGoertzelPeriod_H4", currentGoertzelPeriod); break;
      default: GlobalVariableSet("UsedGoertzelPeriod", currentGoertzelPeriod);
   }
}

void CalculateIndicator(int first, int amount, double &FILTERTable[])
{
   double FILTER;
    
   startBar = first;
   finishBar = amount - 1;
   int index = 0;
   
   // Clear and prepare array
   ArrayResize(filterValues, amount - first, amount - first);
   ArrayFill(filterValues, 0, ArraySize(filterValues), 0);
   
   // string debug = "";
   
   for (int bar = first; bar < amount; bar++, index++)
   {
      /*if (index == 9){
         StringAdd(debug, "Filter = ");
      }*/
   
      //---- формула для вычисления цифрового фильтра
      FILTER = 0.0;
      for(int iii = 0; iii < FILTERPeriod; iii++){
         FILTER += FILTERTable[iii] * closePrices[bar - iii];
         
         /*if (index == 9){
            StringAdd(debug, "FILTERTable[" + IntegerToString(iii) + "](" + DoubleToString(FILTERTable[iii]) + ") * closePrices[" + IntegerToString(bar - iii) + "](" + DoubleToString(closePrices[bar - iii]) + ") + ");
         }*/
         /*if (((amount - 1) != first) && (bar == first + 9)){
            Print(usedGoertzelPeriod, "[", bar - iii, "]: ", close[bar - iii]);
         }*/
      }
      
      /*if (index == 9){
         StringAdd(debug, " = " + FILTER);
         Alert(debug);
         Print(debug);
      }*/
          
      filterValues[index] = FILTER;
   }
}

int Calculate(int rates_total, int prev_calculated, int usedGoertzelPeriod)
{
   int first;
   int amount = 0;
   
   double FILTERTable[];
   ArrayCopy(FILTERTable, BaseFILTERTable, 0, 0, WHOLE_ARRAY);
   
   ArraySetAsSeries(FILTERTable, true);
   //ArraySetAsSeries(ExtLineBuffer,true);
   
   // Alert(usedGoertzelPeriod, ", ", FILTERTable[0]);

   //---- проверка количества баров на достаточность для расчета
   if(rates_total < FILTERPeriod-1)
      return(0);


   //---- расчет стартового номера first для цикла пересчета баров
   if(prev_calculated > rates_total || prev_calculated <= 0) // проверка на первый старт расчета индикатора
   {
      first = FILTERPeriod - 1; // стартовый номер для расчета всех баров
      amount = rates_total;
   }
   else 
   {
      first = FILTERPeriod - 1; // стартовый номер для расчета новых баров
      amount = FILTERPeriod;
   }
   
   //if (amount - first > 1) Alert(first, ", ", amount, ", ", amount - first, ", ", Bars);   
   CalculateIndicator(first, amount, FILTERTable);
   
   int index = 0;
   
   // Alert(filterValues[0]);   
   
   if (finishBar - startBar > 1){ // Обновился период
      prevSignificantValue = filterValues[2];
      currentSignificantValue = filterValues[1];
      currentValue = filterValues[0];
      currentBarNumber = Bars;
   } else {
      if (Bars > currentBarNumber){
         prevSignificantValue = currentSignificantValue;
         currentSignificantValue = currentValue;
         currentBarNumber = Bars;
      }
      currentValue = filterValues[0];
   }
   
   for (int bar = startBar; bar < finishBar + 1; bar++, index++) {
      ExtLineBuffer[bar] = filterValues[index];
   }
   
   int period = Period();
   switch(period)
   {
      case 1 : GlobalVariableSet("Dfilter2Indicator_M1", (prevSignificantValue > currentSignificantValue) ? -1 : 1); break; 
      case 5 : GlobalVariableSet("Dfilter2Indicator_M5", (prevSignificantValue > currentSignificantValue) ? -1 : 1); break; 
      case 15 : GlobalVariableSet("Dfilter2Indicator_M15", (prevSignificantValue > currentSignificantValue) ? -1 : 1); break; 
      case 30 : GlobalVariableSet("Dfilter2Indicator_M30", (prevSignificantValue > currentSignificantValue) ? -1 : 1); break; 
      case 60 : GlobalVariableSet("Dfilter2Indicator_H1", (prevSignificantValue > currentSignificantValue) ? -1 : 1); break;
      case 240 : GlobalVariableSet("Dfilter2Indicator_H4", (prevSignificantValue > currentSignificantValue) ? -1 : 1); break;
      default: GlobalVariableSet("Dfilter2Indicator", (prevSignificantValue > currentSignificantValue) ? -1 : 1);
   }
   
   // Alert(period, ", ", (prevSignificantValue > currentSignificantValue) ? -1 : 1);

   return(rates_total);
}

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+  
int OnInit()
{
   int period = Period();
   int currentGoertzelPeriod = GlobalVariableGet("GoertzelPeriod_Storage");
   switch(period)
   {
       case 1 : currentGoertzelPeriod = GlobalVariableGet("GoertzelPeriod_Storage_M1"); break; 
       case 5 : currentGoertzelPeriod = GlobalVariableGet("GoertzelPeriod_Storage_M5"); break; 
       case 15 : currentGoertzelPeriod = GlobalVariableGet("GoertzelPeriod_Storage_M15"); break; 
       case 30 : currentGoertzelPeriod = GlobalVariableGet("GoertzelPeriod_Storage_M30"); break; 
       case 60 : currentGoertzelPeriod = GlobalVariableGet("GoertzelPeriod_Storage_H1"); break;
       case 240 : currentGoertzelPeriod = GlobalVariableGet("GoertzelPeriod_Storage_H4"); break;
       default: currentGoertzelPeriod = GlobalVariableGet("GoertzelPeriod_Storage");
   }
   Initialise(currentGoertzelPeriod);
   
   //----
   return(INIT_SUCCEEDED);
}
  
  
//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
   int period = Period();
   int currentGoertzelPeriod = GlobalVariableGet("GoertzelPeriod_Storage");
   switch(period)
   {
       case 1 : currentGoertzelPeriod = GlobalVariableGet("GoertzelPeriod_Storage_M1"); break; 
       case 5 : currentGoertzelPeriod = GlobalVariableGet("GoertzelPeriod_Storage_M5"); break; 
       case 15 : currentGoertzelPeriod = GlobalVariableGet("GoertzelPeriod_Storage_M15"); break; 
       case 30 : currentGoertzelPeriod = GlobalVariableGet("GoertzelPeriod_Storage_M30"); break; 
       case 60 : currentGoertzelPeriod = GlobalVariableGet("GoertzelPeriod_Storage_H1"); break;
       case 240 : currentGoertzelPeriod = GlobalVariableGet("GoertzelPeriod_Storage_H4"); break;
       default: currentGoertzelPeriod = GlobalVariableGet("GoertzelPeriod_Storage");
   }
   int usedGoertzelPeriod = GlobalVariableGet("UsedGoertzelPeriod");
   switch(period)
   {
       case 1 : usedGoertzelPeriod = GlobalVariableGet("UsedGoertzelPeriod_M1"); break; 
       case 5 : usedGoertzelPeriod = GlobalVariableGet("UsedGoertzelPeriod_M5"); break; 
       case 15 : usedGoertzelPeriod = GlobalVariableGet("UsedGoertzelPeriod_M15"); break; 
       case 30 : usedGoertzelPeriod = GlobalVariableGet("UsedGoertzelPeriod_M30"); break; 
       case 60 : usedGoertzelPeriod = GlobalVariableGet("UsedGoertzelPeriod_H1"); break;
       case 240 : usedGoertzelPeriod = GlobalVariableGet("UsedGoertzelPeriod_H4"); break;
       default: usedGoertzelPeriod = GlobalVariableGet("UsedGoertzelPeriod");
   }
   
   ArrayCopy(closePrices, close, 0, 0, WHOLE_ARRAY);
             
   if (currentGoertzelPeriod != usedGoertzelPeriod) {
      Print("Период герцеля(таймфрейм ", period, " минут) был изменен на ", currentGoertzelPeriod);
      
      Initialise(currentGoertzelPeriod);
      
      return(Calculate(rates_total, 0, usedGoertzelPeriod)); // New Init (prev_calculated = 0)
   } else {  
      return(Calculate(rates_total, prev_calculated, usedGoertzelPeriod));
   }
}
//+------------------------------------------------------------------+
