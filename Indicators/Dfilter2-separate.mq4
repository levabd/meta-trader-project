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
#property indicator_color1  DarkViolet
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
input FType_ FType=LPF; // Тип фильтра
                        //0 - ФНЧ (FATL/SATL/KGLP), 1 - ФВЧ (KGHP), 2 - полосовой (RBCI/KGBP), 3 - режекторный (KGBS)
input int    P1 = 28;       // Период отсечки 1, бар
input int    D1 = 19;       // Период отсечки переходного процесса 1, бар
input int    A1 = 40;       // Затухание в полосе задержки 1, дБ
input int    P2 = 0;        // Период отсечки 2, бар
input int    D2 = 0;        // Период отсечки переходного процесса 2, бар
input int    A2 = 0;        // Затухание в полосе задержки 2, дБ
input int    Delay=0;       // Задержка, бар
input double Ripple=0.08;   // Биения в полосе пропускания, дБ 
input int    FILTERShift=0; //сдвиг мувинга по горизонтали в барах 

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
double FILTERTable[];
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+  
int OnInit()
  {
 
//---- превращение динамического массива ExtLineBuffer в индикаторный буфер
   SetIndexBuffer(0,ExtLineBuffer,INDICATOR_DATA);
   
//---- осуществление сдвига индикатора по горизонтали на FILTERShift
   PlotIndexSetInteger(0,PLOT_SHIFT,0);
//---- осуществление сдвига начала отсчета отрисовки индикатора
   PlotIndexSetInteger(0,PLOT_DRAW_BEGIN,FILTERPeriod);
//---- инициализации переменной для короткого имени индикатора
   string shortname;
   StringConcatenate(shortname,"FILTER(",FILTERShift,")");
//--- создание метки для отображения в DataWindow
   PlotIndexSetString(0,PLOT_LABEL,shortname);
//--- создание имени для отображения в отдельном подокне и во всплывающей подсказке
   IndicatorSetString(INDICATOR_SHORTNAME,shortname);
//--- определение точности отображения значений индикатора
   IndicatorSetInteger(INDICATOR_DIGITS,_Digits+1);
//--- запрет на отрисовку индикатором пустых значений
   PlotIndexSetDouble(0,PLOT_EMPTY_VALUE,0.0);
//---- Вычисление коэфициентов цифрового фильтра и определение размера буфера FILTERTable[]
   double Array[1500];
   FILTERPeriod=DigitalFilter(FType,P1,D1,A1,P2,D2,A2,Ripple,Delay,Array);
//----  изменение размера буфера FILTERTable[] под требуемое количество коэффициетов цифрового фильтра
   if(FILTERPeriod<=0)
     {
      Print("Входные параметры некорректны. Работа индикатора невозможна!");
      return (INIT_PARAMETERS_INCORRECT);
     }
     SetIndexShift(0,FILTERPeriod-1);
     
//---- копируем данные из временного массива размером 1500 в основной массив с размером FILTERPeriod
   ArrayCopy(FILTERTable,Array,0,0,FILTERPeriod);
//----
   //Alert("On Init");
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
   
   int amount=0;
   ArraySetAsSeries(FILTERTable,true);
   //ArraySetAsSeries(ExtLineBuffer,true);

   //---- проверка количества баров на достаточность для расчета
   if(rates_total<FILTERPeriod-1)
      return(0);

   //---- объявления локальных переменных 
   int first,bar,iii;
   double FILTER;

   //---- расчет стартового номера first для цикла пересчета баров
   if(prev_calculated>rates_total || prev_calculated<=0) // проверка на первый старт расчета индикатора
   {
      first=FILTERPeriod-1 ; // стартовый номер для расчета всех баров
      amount=rates_total;
   }
   else 
   {
      first=FILTERPeriod-1; // стартовый номер для расчета новых баров
      amount=FILTERPeriod;
   }
   
   
   for(bar=first; bar<amount; bar++)
   {
      //---- формула для вычисления цифрового фильтра
      FILTER=0.0;
      for(iii=0; iii<FILTERPeriod; iii++)
         FILTER+=FILTERTable[iii] *close[bar-iii];

      //---- Инициализация ячейки индикаторного буфера полученным значением FILTER
      ExtLineBuffer[bar]=FILTER;
   }

   //----     
   return(rates_total);
}
//+------------------------------------------------------------------+
