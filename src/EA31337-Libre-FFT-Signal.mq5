//+------------------------------------------------------------------+
//|           EA31337 Libre - FFT PhaseClock ColorWave (Signal)      |
//+------------------------------------------------------------------+

/**
 * Minimal EA build that uses the signal-only FFT PhaseClock ColorWave strategy.
 * Trade execution is handled by the EA31337 core (recommended template).
 */

// Enable INPUT macros.
#include "include/define.h"

// EA31337 local classes.
#include "include/classes/EA.mqh"
#include "include/classes/Strategy.mqh"

// Strategy (full, with legs/trailing/breakeven).
#include "include/strategies/FFT_PhaseClock_ColorWave/Stg_FFT_PhaseClock_ColorWave.mqh"

// Inputs.
input int Active_Tfs = (H1B | M30B);        // Timeframes (M1=1,M2=2,M5=16,M15=256,M30=1024,H1=2048,...)
input ENUM_LOG_LEVEL Log_Level = V_DEBUG;  // Log level.
input bool Info_On_Chart = true;           // Display info on chart.

// Defines (override defaults from include/define.h if present).
#ifdef ea_name
#undef ea_name
#endif
#ifdef ea_version
#undef ea_version
#endif
#ifdef ea_desc
#undef ea_desc
#endif
#ifdef ea_link
#undef ea_link
#endif
#ifdef ea_author
#undef ea_author
#endif
#define ea_name "EA31337 Libre - FFT PhaseClock ColorWave (Signal)"
#define ea_version "1.000"
#define ea_desc "Signal-only EA31337 build with FFT PhaseClock ColorWave strategy (core executes trades)."
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

// Class variables.
EA *ea;

/* EA event handler functions */

int OnInit() {
  bool _result = true;
  EAParams ea_params(__FILE__, Log_Level);
  ea = new EA(ea_params);
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
