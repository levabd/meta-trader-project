//+------------------------------------------------------------------+
//|                                  Goertzel-Dfilter-Expert_ind.mq4 |
//|                                           Copyright 2017, Levabd |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2017, Levabd"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict
#property indicator_chart_window

#property indicator_buffers 3
#property indicator_color1 clrLightBlue
#property indicator_color2 clrRed
#property indicator_color3 clrYellow
#property indicator_width1 1
#property indicator_width2 1
#property indicator_width3 1

extern string arr_set="Arrow settings";
extern int arrow_indent=22;
extern int up_arrow_code=233;
extern int down_arrow_code=234;
extern int stop_arrow_code=251;

extern string emp1="///////////////////////////////////////";
extern string al_set="Alerts settings";
extern bool use_alert=false;
extern string up_alert="UP";
extern string down_alert="DOWN";
extern string stop_alert="STOP";

double up_arr[];
double stop_arr[];
double down_arr[];
int prev_bars;
int manual_prev_calculated = 0;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- indicator buffers mapping
   
   SetIndexBuffer(0,up_arr);
   SetIndexStyle(0,DRAW_ARROW);
   SetIndexArrow(0,up_arrow_code);
   SetIndexLabel(0,"UP arrow");

   SetIndexBuffer(1,down_arr);
   SetIndexStyle(1,DRAW_ARROW);
   SetIndexArrow(1,down_arrow_code);
   SetIndexLabel(1,"DOWN arrow");
   
   SetIndexBuffer(2,stop_arr);
   SetIndexStyle(2,DRAW_ARROW);
   SetIndexArrow(2,stop_arrow_code);
   SetIndexLabel(2,"STOP arrow");   
   //---
   return(INIT_SUCCEEDED);
}

void DrawArrow(bool Up, int all, int counted)
{
   // Alert(all, ", ", counted);
   for(int i = all - counted; i >= 0; i--)
   {
      if(i > Bars - 20) i = Bars - 20;

      if(i == 0)
      {
         up_arr[i] = EMPTY_VALUE;
         down_arr[i] = EMPTY_VALUE;
      }

      if(Up) up_arr[i] = Low[i] - arrow_indent * Point; //up arrow
      if(!Up) down_arr[i] = High[i] + arrow_indent * Point; //down arrow
   }
}

void DrawArrowStop(int all, int counted)
{
   for(int i = all - counted; i >= 0; i--)
   {
      if(i > Bars - 20) i = Bars - 20;

      if(i == 0) stop_arr[i] = EMPTY_VALUE;

      stop_arr[i] = High[i] + arrow_indent * Point; //stop arrow
   }
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
   //---
   //no bars
   if(Bars<20) return(rates_total);

   int Dfilter2Indicator_H4 = GlobalVariableGet("Dfilter2Indicator_H4");
   int Dfilter2Indicator_H1 = GlobalVariableGet("Dfilter2Indicator_H1");
   
   if ((Dfilter2Indicator_H4 == 0) || (Dfilter2Indicator_H1 == 0)) return(rates_total);
   
   //history update
   int all = rates_total;
   int counted = manual_prev_calculated;
   if(all - counted > 1)
   {
      ArrayInitialize(up_arr, EMPTY_VALUE);
      ArrayInitialize(down_arr, EMPTY_VALUE);
      ArrayInitialize(stop_arr, EMPTY_VALUE);
      counted = 0;
   } else 
   {
      if ((Dfilter2Indicator_H4 == -1) && (Dfilter2Indicator_H1 == -1)){
         //Alert("Sell");
         DrawArrow(false, all, counted);
      } else if ((Dfilter2Indicator_H4 == 1) && (Dfilter2Indicator_H1 == 1)){
         //Alert("Buy");
         DrawArrow(true, all, counted);
      } else {
         DrawArrowStop(all, counted);
         //Alert("Close");
      }
   }
   
   manual_prev_calculated = rates_total;
   
   //new bar
   if(Bars == prev_bars) return(rates_total);
   prev_bars = Bars;
   
   //--- return value of prev_calculated for next call
   return(rates_total);
}
//+------------------------------------------------------------------+
