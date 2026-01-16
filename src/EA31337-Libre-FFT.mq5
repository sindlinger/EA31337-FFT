//+------------------------------------------------------------------+
//|                 EA31337 Libre - FFT PhaseClock ColorWave         |
//+------------------------------------------------------------------+

/**
 * Minimal EA build that only includes FFT PhaseClock ColorWave strategy.
 * This avoids thousands of unused inputs from the full Libre build.
 */

// Enable INPUT macros.
#include "include/define.h"

// EA31337 local classes.
#include "include/classes/EA.mqh"
#include "include/classes/Strategy.mqh"

// Strategy (local).
#include "include/strategies/FFT_PhaseClock_ColorWave/Stg_FFT_PhaseClock_ColorWave.mqh"

// Inputs.
input int Active_Tfs = (H1B | M30B);        // Timeframes (M1=1,M2=2,M5=16,M15=256,M30=1024,H1=2048,...)
input ENUM_LOG_LEVEL Log_Level = V_INFO;   // Log level.
input bool Info_On_Chart = true;           // Display info on chart.

// Defines.
#define ea_name "EA31337 Libre - FFT PhaseClock ColorWave"
#define ea_version "1.000"
#define ea_desc "Minimal EA31337 build with FFT PhaseClock ColorWave strategy only."
#define ea_link "https://github.com/EA31337/Strategy-FFT_PhaseClock_ColorWave"
#define ea_author "EA31337 Ltd"

// Properties.
#property version ea_version
#ifdef __MQL4__
#property description ea_name
#property description ea_desc
#endif
#property link ea_link
#property copyright "Copyright 2016-2023, EA31337 Ltd"

#ifdef __MQL5__
class EA_FFT_PhaseClock : public EA {
 public:
  EA_FFT_PhaseClock(EAParams &_params) : EA(_params) {}

  virtual bool TradeRequest(ENUM_ORDER_TYPE _cmd, string _symbol = NULL, Strategy *_strat = NULL) {
    if (_strat == NULL) {
      return EA::TradeRequest(_cmd, _symbol, _strat);
    }
    if (_strat.GetName() == "FFT_PhaseClock_ColorWave") {
      Stg_FFT_PhaseClock_ColorWave *stg = (Stg_FFT_PhaseClock_ColorWave *)_strat;
      return stg.ExecuteTradeSignal(_cmd);
    }
    return EA::TradeRequest(_cmd, _symbol, _strat);
  }

  virtual EAProcessResult ProcessTick() {
    EAProcessResult result = EA::ProcessTick();
    for (DictStructIterator<long, Ref<Strategy>> iter = strats.Begin(); iter.IsValid(); ++iter) {
      Strategy *strat = iter.Value().Ptr();
      if (strat.GetName() == "FFT_PhaseClock_ColorWave") {
        Stg_FFT_PhaseClock_ColorWave *stg = (Stg_FFT_PhaseClock_ColorWave *)strat;
        stg.ManagePositions();
      }
    }
    return result;
  }
};
#else
typedef EA EA_FFT_PhaseClock;
#endif

// Class variables.
EA_FFT_PhaseClock *ea;

/* EA event handler functions */

int OnInit() {
  bool _result = true;
  EAParams ea_params(__FILE__, Log_Level);
  ea = new EA_FFT_PhaseClock(ea_params);
  _result &= ea.StrategyAdd<Stg_FFT_PhaseClock_ColorWave>(Active_Tfs);
  return (_result ? INIT_SUCCEEDED : INIT_FAILED);
}

void OnTick() {
  ea.ProcessTick();
  if (Info_On_Chart && !ea.GetTerminal().IsOptimization()) {
    ea.UpdateInfoOnChart();
  }
}

void OnDeinit(const int reason) { Object::Delete(ea); }
