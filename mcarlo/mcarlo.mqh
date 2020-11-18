//+------------------------------------------------------------------+
//|                                                       mcarlo.mqh |
//|                        Copyright 2018, MetaQuotes Software Corp. |
//|                                              http://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2018, MetaQuotes Software Corp."
#property link      "http://www.mql5.com"
//+------------------------------------------------------------------+
#include <Math\Stat\Uniform.mqh>
#define NADD 30
#define NSAMPLES 10000       // Number of samples in Monte Carlo method
//#define ndealsmin 5          // Minimal number of deals

enum ENUM_MONTECARLO_OPT
   {
    MONTECARLO_OPT_MEAN_SD  = 1,     // Total profit mean + standard deviation parameter
    MONTECARLO_OPT_MED_INTQ = 2,     // Total profit median + interquartile range parameter
    MONTECARLO_OPT_RMND_ABS = 3,     // Total profit with absolute drawdown restriction parameter         |
    MONTECARLO_OPT_RMND_REL = 4,     // Total profit with relative drawdown restriction parameter         |
    MONTECARLO_OPT_FRW_WMW  = 5,     // WMW parameter (Forward)
    MONTECARLO_OPT_FRW_WMW_PRF = 6,  // WMW + total profit parameter (Forward)
    MONTECARLO_OPT_ALL = 7,          // All
   };

sinput ENUM_MONTECARLO_OPT noptpr = MONTECARLO_OPT_ALL; // Optimization parameter variant
sinput double ndealsmin = 30;                                // Minimal number of Deals
sinput double rmndmin = 0.3;                                 // Drawdown restriction [0.0 - 1.0]
sinput double fwdsh = 0.5;                                   // Share of deals in "future" [0.0, 1.0]
//+------------------------------------------------------------------+
//|base function                                                     |
//+------------------------------------------------------------------+
double optpr()
   {
    double k[];
    if(!setks(k))
        return 0.0;
    if(ArraySize(k) < ndealsmin)
        return 0.0;
    MathSrand(GetTickCount());
    switch(noptpr)
       {
        case MONTECARLO_OPT_MEAN_SD:
            return mean_sd(k);
        case MONTECARLO_OPT_MED_INTQ:
            return med_intq(k);
        case MONTECARLO_OPT_RMND_ABS:
            return rmnd_abs(k);
        case MONTECARLO_OPT_RMND_REL:
            return rmnd_rel(k);
        case MONTECARLO_OPT_FRW_WMW:
            return frw_wmw(k);
        case MONTECARLO_OPT_FRW_WMW_PRF:
            return frw_wmw_prf(k);
        default:
            return (mean_sd(k)
                    + med_intq(k)
                    + rmnd_abs(k)
                    + rmnd_rel(k)
                    + frw_wmw(k)
                    + frw_wmw_prf(k)
                   ) / 6.0;

       }
    return 0.0;
   }
//+------------------------------------------------------------------+
//|total profit mean + standard deviation parameter                  |
//+------------------------------------------------------------------+
double mean_sd(double &k[])
   {
    double km[], cn[NSAMPLES];
    int nk = ArraySize(k);
    ArrayResize(km, nk);
    for(int n = 0; n < NSAMPLES; ++n)
       {
        sample(k, km);
        cn[n] = 1.0;
        for(int i = 0; i < nk; ++i)
            cn[n] *= km[i];
        cn[n] -= 1.0;
       }
    double deviation = MathStandardDeviation(cn);
    deviation = deviation > 0 ? deviation : 1;
    return MathMean(cn) / deviation;
   }
//+------------------------------------------------------------------+
//|total profit median + interquartile range parameter               |
//+------------------------------------------------------------------+
double med_intq(double &k[])
   {
    double km[], cn[NSAMPLES];
    int nk = ArraySize(k);
    ArrayResize(km, nk);
    for(int n = 0; n < NSAMPLES; ++n)
       {
        sample(k, km);
        cn[n] = 1.0;
        for(int i = 0; i < nk; ++i)
            cn[n] *= km[i];
        cn[n] -= 1.0;
       }
    ArraySort(cn);
    double part = (cn[(int)(0.75 * NSAMPLES)] - cn[(int)(0.25 * NSAMPLES)]);
    part = part > 0 ? part : 1;
    return cn[(int)(0.5 * NSAMPLES)] / part;
   }
//+------------------------------------------------------------------+
//|total profit with absolute drawdown restriction parameter         |
//+------------------------------------------------------------------+
double rmnd_abs(double &k[])
   {
    if(rmndmin <= 0.0 || rmndmin >= 1.0)
        return 0.0;
    double km[], cn[NSAMPLES];
    int nk = ArraySize(k);
    ArrayResize(km, nk);
    for(int n = 0; n < NSAMPLES; ++n)
       {
        sample(k, km);
        cn[n] = 1.0;
        for(int i = 0; i < nk; ++i)
           {
            cn[n] *= km[i];
            if(cn[n] < rmndmin)
                break;
           }
        cn[n] -= 1.0;
       }
    return MathMean(cn);
   }
//+------------------------------------------------------------------+
//|total profit with relative drawdown restriction parameter         |
//+------------------------------------------------------------------+
double rmnd_rel(double &k[])
   {
    if(rmndmin <= 0.0 || rmndmin >= 1.0)
        return 0.0;
    double km[], cn[NSAMPLES], x;
    int nk = ArraySize(k);
    ArrayResize(km, nk);
    for(int n = 0; n < NSAMPLES; ++n)
       {
        sample(k, km);
        x = cn[n] = 1.0;
        for(int i = 0; i < nk; ++i)
           {
            cn[n] *= km[i];
            if(cn[n] > x)
                x = cn[n];
            else
                if(cn[n] / x < rmndmin)
                    break;
           }
        cn[n] -= 1.0;
       }
    return MathMean(cn);
   }
//+------------------------------------------------------------------+
//|WMW parameter                                                     |
//+------------------------------------------------------------------+
double frw_wmw(double &k[])
   {
    if(fwdsh <= 0.0 || fwdsh >= 1.0)
        return 0.0;
    int nk = ArraySize(k), nkf = (int)(fwdsh * nk), nkp = nk - nkf;
    if(nkf < ndealsmin || nkp < ndealsmin)
        return 0.0;
    double u = 0.0;
    for(int i = 0; i < nkp; ++i)
        for(int j = 0; j < nkf; ++j)
            if(k[i] > k[nkp + j])
                ++u;
    return 1.0 - MathAbs(1.0 - 2.0 * u / (nkf * nkp));
   }
//+------------------------------------------------------------------+
//|WMW + total profit parameter                                      |
//+------------------------------------------------------------------+
double frw_wmw_prf(double &k[])
   {
    int nk = ArraySize(k);
    double prf = 1.0;
    for(int n = 0; n < nk; ++n)
        prf *= k[n];
    prf -= 1.0;
    if(prf > 0.0)
        prf *= frw_wmw(k);
    return prf;
   }
//+------------------------------------------------------------------+
//|Generates a random sample                                         |
//+------------------------------------------------------------------+
void sample(double &a[], double &b[])
   {
    int ner;
    double dnc;
    int na = ArraySize(a);
    for(int i = 0; i < na; ++i)
       {
        dnc = MathRandomUniform(0, na, ner);
        if(!MathIsValidNumber(dnc))
           {
            Print("MathIsValidNumber(dnc) error ", ner);
            ExpertRemove();
           }
        int nc = (int)dnc;
        if(nc == na)
            nc = na - 1;
        b[i] = a[nc];
       }
   }
//+------------------------------------------------------------------+
//|Calculates profits array                                          |
//+------------------------------------------------------------------+
bool setks(double &k[])
   {
    if(!HistorySelect(0, TimeCurrent()))
        return false;
    uint nhd = HistoryDealsTotal();
    int nk = 0;
    ulong hdticket;
    double capital = TesterStatistics(STAT_INITIAL_DEPOSIT);

    long hdtype;
    double hdcommission, hdswap, hdprofit, hdprofit_full;
    for(uint n = 0; n < nhd; ++n)
       {
        capital = capital > 0 ? capital : 1;
        hdticket = HistoryDealGetTicket(n);
        if(hdticket == 0)
            continue;

        if(!HistoryDealGetInteger(hdticket, DEAL_TYPE, hdtype))
            return false;
        if(hdtype != DEAL_TYPE_BUY && hdtype != DEAL_TYPE_SELL)
            continue;

        hdcommission = HistoryDealGetDouble(hdticket, DEAL_COMMISSION);
        hdswap = HistoryDealGetDouble(hdticket, DEAL_SWAP);
        hdprofit = HistoryDealGetDouble(hdticket, DEAL_PROFIT);
        if(hdcommission == 0.0 && hdswap == 0.0 && hdprofit == 0.0)
            continue;

        ++nk;
        ArrayResize(k, nk, NADD);
        hdprofit_full = hdcommission + hdswap + hdprofit;
        k[nk - 1] = 1.0 + hdprofit_full / capital;
        capital += hdprofit_full;
       }
    return true;
   }
//+------------------------------------------------------------------+
