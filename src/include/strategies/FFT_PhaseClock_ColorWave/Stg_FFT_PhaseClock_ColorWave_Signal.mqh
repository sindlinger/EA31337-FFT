/**
 * @file
 * Signal-only FFT PhaseClock ColorWave strategy (EA31337 core handles trade execution).
 */

#include "Indi_FFT_PhaseClock_ColorWave.mqh"

// User input params (signal-only, unique names to avoid collisions).
INPUT_GROUP("FFT PhaseClock Signal: bitwise filtros (entrada)");
// OPEN filter bits (SignalOpenFilterMethod):
INPUT bool FFT_Signal_OpenFilter_NoSameBarOrder = true;   // 1: abre só se NÃO há ordem na mesma barra
INPUT bool FFT_Signal_OpenFilter_InTrend = false;         // 2: abre só se estiver em tendência
INPUT bool FFT_Signal_OpenFilter_IsPivot = false;         // 4: abre só se for pivot
INPUT bool FFT_Signal_OpenFilter_NoOppositeOrder = false; // 8: abre só se NÃO há ordem oposta aberta
INPUT bool FFT_Signal_OpenFilter_IsPeak = false;          // 16: abre só se estiver em pico
INPUT bool FFT_Signal_OpenFilter_NoBetterOrder = false;   // 32: abre só se NÃO há ordem melhor
INPUT bool FFT_Signal_OpenFilter_EquityCond = false;      // 64: abre só se condição de equity 1% permitir

INPUT_GROUP("FFT PhaseClock Signal: bitwise filtros (saída)");
// CLOSE filter bits (SignalCloseFilterMethod):
INPUT bool FFT_Signal_CloseFilter_NoSameBarOrder = false; // 1: fecha se NÃO há ordem na barra
INPUT bool FFT_Signal_CloseFilter_NotTrend = true;        // 2: fecha se NÃO estiver em tendência
INPUT bool FFT_Signal_CloseFilter_NotPivot = true;        // 4: fecha se NÃO for pivot
INPUT bool FFT_Signal_CloseFilter_BreakHL = true;         // 8: fecha se abertura rompeu H/L anterior
INPUT bool FFT_Signal_CloseFilter_IsPeak = true;          // 16: fecha se estiver em pico
INPUT bool FFT_Signal_CloseFilter_HasBetterOrder = false; // 32: fecha se há ordem melhor
INPUT bool FFT_Signal_CloseFilter_EquityCond = false;     // 64: fecha se condição de equity 1% acionar

INPUT_GROUP("FFT PhaseClock Signal: execução (core)");
INPUT double FFT_Signal_LotSize = 0.10;              // Lot size
INPUT double FFT_Signal_MaxSpread = 4.0;             // Max spread to trade (pips)
INPUT int FFT_Signal_TickFilterMethod = 0;           // Tick filter method
INPUT int FFT_Signal_SignalOpenFilterTime = 3;       // Signal open filter time (bars)

INPUT_GROUP("FFT PhaseClock Signal: fechamento (core)");
INPUT float FFT_Signal_OrderCloseLoss = 0;    // Order close loss (pips)
INPUT float FFT_Signal_OrderCloseProfit = 0;  // Order close profit (pips)
INPUT int FFT_Signal_OrderCloseTime = 0;      // Order close time in mins (>0) or bars (<0)

// Close method/level are not used by this signal-only strategy; keep them fixed to avoid UI confusion.
const int FFT_SIGNAL_CLOSE_METHOD = 0;
const float FFT_SIGNAL_CLOSE_LEVEL = 0.0f;

INPUT_GROUP("FFT PhaseClock Signal: fechamento (horário)");
// Bitwise (GMT sessions): 1=Chicago,2=Frankfurt,4=HongKong,8=London,16=NewYork,32=Sydney,64=Tokyo,128=Wellington.
INPUT int FFT_Signal_SignalCloseFilterTime = 0;      // Filtro horário de fechamento (bitwise sessões GMT)

INPUT_GROUP("FFT PhaseClock Signal: stop method (bitwise)");
INPUT bool FFT_Signal_Stop_UseIndiPeak = false;        // 1: usa pico do indicador
INPUT bool FFT_Signal_Stop_UseIndiValue = false;       // 2: usa valor do indicador
INPUT bool FFT_Signal_Stop_UsePrice = false;           // 4: usa preco
INPUT bool FFT_Signal_Stop_UsePricePeak = false;       // 8: usa high/low (pico)
INPUT bool FFT_Signal_Stop_UsePivot = false;           // 16: usa pivots (R1/S1)
INPUT bool FFT_Signal_Stop_AddPriceDiff = false;       // 32: soma diferenca de preco
INPUT bool FFT_Signal_Stop_AddRange = false;           // 64: soma range do candle

INPUT_GROUP("FFT PhaseClock Signal: target method (bitwise)");
INPUT bool FFT_Signal_Target_UseIndiPeak = false;      // 1: usa pico do indicador
INPUT bool FFT_Signal_Target_UseIndiValue = false;     // 2: usa valor do indicador
INPUT bool FFT_Signal_Target_UsePrice = false;         // 4: usa preco
INPUT bool FFT_Signal_Target_UsePricePeak = false;     // 8: usa high/low (pico)
INPUT bool FFT_Signal_Target_UsePivot = false;         // 16: usa pivots (R1/S1)
INPUT bool FFT_Signal_Target_AddPriceDiff = false;     // 32: soma diferenca de preco
INPUT bool FFT_Signal_Target_AddRange = false;         // 64: soma range do candle

INPUT_GROUP("FFT PhaseClock Signal: levels (barras/%)");
INPUT float FFT_Signal_PriceStopLevel = 0;           // Price stop level (barras/%)
INPUT float FFT_Signal_PriceProfitLevel = 0;         // Price profit level (barras/%)

INPUT_GROUP("FFT PhaseClock Signal: indicator params");
INPUT string FFT_Signal_IndicatorPath =
    "4EA-IND\\IND-FFT_PhaseClock_CLOSE_SINFLIP_LEAD_v1.5_ColorWave";  // Indicator path
INPUT ENUM_TIMEFRAMES FFT_Signal_MainTF = PERIOD_H1;     // Main timeframe
INPUT ENUM_TIMEFRAMES FFT_Signal_ConfirmTF = PERIOD_M30; // Confirmation timeframe
INPUT int FFT_Signal_MainShift = 0;                      // Main shift
INPUT int FFT_Signal_ConfirmShift = 1;                   // Confirm shift
INPUT bool FFT_Signal_AttachIndicator = true;            // Attach main indicator to chart
INPUT int FFT_Signal_IndicatorSubwindow = 0;             // Subwindow (0 = auto)
INPUT bool FFT_Signal_Ind_InvertOutput = true;         // Invert output (vertical wave flip)

INPUT_GROUP("FFT PhaseClock Signal: feed/janela");
INPUT FFT_FEED_SOURCE FFT_Signal_Ind_FeedSource = FFT_FEED_OHLC4;
INPUT int FFT_Signal_Ind_AtrPeriod = 17;
INPUT ENUM_TIMEFRAMES FFT_Signal_Ind_FeedIndicatorTF = PERIOD_CURRENT;
INPUT string FFT_Signal_Ind_FeedIndicatorName = "";
INPUT int FFT_Signal_Ind_FeedIndicatorBuffer = 0;
INPUT int FFT_Signal_Ind_FFTSize = 65536;
INPUT FFT_WINDOW_TYPE FFT_Signal_Ind_WindowType = FFT_WND_SINE;
INPUT bool FFT_Signal_Ind_CausalWindow = false;
INPUT bool FFT_Signal_Ind_RemoveDC = false;
INPUT FFT_PAD_MODE FFT_Signal_Ind_PadMode = FFT_PAD_MIRROR;
INPUT bool FFT_Signal_Ind_OneValuePerBar = false;

INPUT_GROUP("FFT PhaseClock Signal: bandpass");
INPUT bool FFT_Signal_Ind_ApplyBandpass = true;
INPUT int FFT_Signal_Ind_CycleBars = 52;
INPUT double FFT_Signal_Ind_BandwidthPct = 200.0;
INPUT FFT_BAND_SHAPE FFT_Signal_Ind_BandShape = FFT_BAND_GAUSS;

INPUT_GROUP("FFT PhaseClock Signal: saída/lead");
INPUT FFT_OUTPUT_MODE FFT_Signal_Ind_OutputMode = FFT_OUT_SIN;
INPUT bool FFT_Signal_Ind_NormalizeAmp = false;
INPUT double FFT_Signal_Ind_PhaseOffsetDeg = 315.0;
INPUT double FFT_Signal_Ind_LeadBars = 10.0;
INPUT bool FFT_Signal_Ind_LeadUseCycleOmega = true;
INPUT double FFT_Signal_Ind_LeadOmegaSmooth = 1000.0;
INPUT int FFT_Signal_Ind_LeadMinCycleBars = 9;
INPUT int FFT_Signal_Ind_LeadMaxCycleBars = 0;

INPUT_GROUP("FFT PhaseClock Signal: zero phase/futuro");
INPUT bool FFT_Signal_Ind_ZeroPhaseRT = true;
INPUT FFT_FORECAST_MODE FFT_Signal_Ind_ForecastMode = FFT_FC_MIRROR;
INPUT int FFT_Signal_Ind_ForecastRegBars = 32;
INPUT int FFT_Signal_Ind_ForecastBars = 0;

INPUT_GROUP("FFT PhaseClock Signal: denoise (DLL)");
INPUT bool FFT_Signal_Ind_DenoiseEnable = true;
INPUT int FFT_Signal_Ind_DenoiseWindowBars = 128;
INPUT double FFT_Signal_Ind_DenoiseSigma = 1.0;
INPUT int FFT_Signal_Ind_DenoiseFutureBars = 0;
INPUT bool FFT_Signal_Ind_DenoiseColorFromValue = true;

// Struct with default strategy values.
struct Stg_FFT_PhaseClock_ColorWave_Signal_Params_Defaults : StgParams {
  Stg_FFT_PhaseClock_ColorWave_Signal_Params_Defaults()
      : StgParams(0, BuildOpenFilterMethod(), 0, 0, FFT_SIGNAL_CLOSE_METHOD, BuildCloseFilterMethod(),
                  FFT_SIGNAL_CLOSE_LEVEL, BuildPriceStopMethod(), FFT_Signal_PriceStopLevel,
                  FFT_Signal_TickFilterMethod, (float)FFT_Signal_MaxSpread, 0) {
    Set(STRAT_PARAM_LS, FFT_Signal_LotSize);
    Set(STRAT_PARAM_SOFT, FFT_Signal_SignalOpenFilterTime);
    Set(STRAT_PARAM_OCL, FFT_Signal_OrderCloseLoss);
    Set(STRAT_PARAM_OCP, FFT_Signal_OrderCloseProfit);
    Set(STRAT_PARAM_OCT, FFT_Signal_OrderCloseTime);
    Set(STRAT_PARAM_SCFT, FFT_Signal_SignalCloseFilterTime);
    Set(STRAT_PARAM_PPM, BuildPriceProfitMethod());
    Set(STRAT_PARAM_PPL, FFT_Signal_PriceProfitLevel);
  }

  int BuildOpenFilterMethod() {
    int method = 0;
    if (FFT_Signal_OpenFilter_NoSameBarOrder) method |= 1;
    if (FFT_Signal_OpenFilter_InTrend) method |= 2;
    if (FFT_Signal_OpenFilter_IsPivot) method |= 4;
    if (FFT_Signal_OpenFilter_NoOppositeOrder) method |= 8;
    if (FFT_Signal_OpenFilter_IsPeak) method |= 16;
    if (FFT_Signal_OpenFilter_NoBetterOrder) method |= 32;
    if (FFT_Signal_OpenFilter_EquityCond) method |= 64;
    return method;
  }

  int BuildCloseFilterMethod() {
    int method = 0;
    if (FFT_Signal_CloseFilter_NoSameBarOrder) method |= 1;
    if (FFT_Signal_CloseFilter_NotTrend) method |= 2;
    if (FFT_Signal_CloseFilter_NotPivot) method |= 4;
    if (FFT_Signal_CloseFilter_BreakHL) method |= 8;
    if (FFT_Signal_CloseFilter_IsPeak) method |= 16;
    if (FFT_Signal_CloseFilter_HasBetterOrder) method |= 32;
    if (FFT_Signal_CloseFilter_EquityCond) method |= 64;
    return method;
  }

  int BuildPriceStopMethod() {
    int method = 0;
    if (FFT_Signal_Stop_UseIndiPeak) method |= 1;
    if (FFT_Signal_Stop_UseIndiValue) method |= 2;
    if (FFT_Signal_Stop_UsePrice) method |= 4;
    if (FFT_Signal_Stop_UsePricePeak) method |= 8;
    if (FFT_Signal_Stop_UsePivot) method |= 16;
    if (FFT_Signal_Stop_AddPriceDiff) method |= 32;
    if (FFT_Signal_Stop_AddRange) method |= 64;
    return method;
  }

  int BuildPriceProfitMethod() {
    int method = 0;
    if (FFT_Signal_Target_UseIndiPeak) method |= 1;
    if (FFT_Signal_Target_UseIndiValue) method |= 2;
    if (FFT_Signal_Target_UsePrice) method |= 4;
    if (FFT_Signal_Target_UsePricePeak) method |= 8;
    if (FFT_Signal_Target_UsePivot) method |= 16;
    if (FFT_Signal_Target_AddPriceDiff) method |= 32;
    if (FFT_Signal_Target_AddRange) method |= 64;
    return method;
  }
};

class Stg_FFT_PhaseClock_ColorWave_Signal : public Strategy {
 public:
  Stg_FFT_PhaseClock_ColorWave_Signal(StgParams &_sparams, TradeParams &_tparams, ChartParams &_cparams,
                                      string _name = "")
      : Strategy(_sparams, _tparams, _cparams, _name) {
    last_main_color = -1;
    last_eval_tick_msc = 0;
    last_eval_signal = 0;
  }

  static Stg_FFT_PhaseClock_ColorWave_Signal *Init(ENUM_TIMEFRAMES _tf = NULL, EA *_ea = NULL) {
    Stg_FFT_PhaseClock_ColorWave_Signal_Params_Defaults defaults;
    StgParams _stg_params(defaults);
    ChartParams _cparams(_tf, _Symbol);
    TradeParams _tparams;
    Strategy *_strat =
        new Stg_FFT_PhaseClock_ColorWave_Signal(_stg_params, _tparams, _cparams, "FFT_PhaseClock_ColorWave_Signal");
    return _strat;
  }

  ~Stg_FFT_PhaseClock_ColorWave_Signal() {
    indi_main.Release();
    indi_confirm.Release();
  }

  FFT_PhaseClock_Params BuildIndicatorParams() {
    FFT_PhaseClock_Params p;
    p.feed_source = FFT_Signal_Ind_FeedSource;
    p.atr_period = FFT_Signal_Ind_AtrPeriod;
    p.feed_indicator_tf = FFT_Signal_Ind_FeedIndicatorTF;
    p.feed_indicator_name = FFT_Signal_Ind_FeedIndicatorName;
    p.feed_indicator_buffer = FFT_Signal_Ind_FeedIndicatorBuffer;
    p.fft_size = FFT_Signal_Ind_FFTSize;
    p.window_type = FFT_Signal_Ind_WindowType;
    p.causal_window = FFT_Signal_Ind_CausalWindow;
    p.remove_dc = FFT_Signal_Ind_RemoveDC;
    p.pad_mode = FFT_Signal_Ind_PadMode;
    p.one_value_per_bar = FFT_Signal_Ind_OneValuePerBar;
    p.apply_bandpass = FFT_Signal_Ind_ApplyBandpass;
    p.cycle_bars = FFT_Signal_Ind_CycleBars;
    p.bandwidth_pct = FFT_Signal_Ind_BandwidthPct;
    p.band_shape = FFT_Signal_Ind_BandShape;
    p.output_mode = FFT_Signal_Ind_OutputMode;
    p.normalize_amp = FFT_Signal_Ind_NormalizeAmp;
    p.phase_offset_deg = FFT_Signal_Ind_PhaseOffsetDeg;
    p.lead_bars = FFT_Signal_Ind_LeadBars;
    p.lead_use_cycle_omega = FFT_Signal_Ind_LeadUseCycleOmega;
    p.lead_omega_smooth = FFT_Signal_Ind_LeadOmegaSmooth;
    p.lead_min_cycle_bars = FFT_Signal_Ind_LeadMinCycleBars;
    p.lead_max_cycle_bars = FFT_Signal_Ind_LeadMaxCycleBars;
    p.invert_output = FFT_Signal_Ind_InvertOutput;
    p.zero_phase_rt = FFT_Signal_Ind_ZeroPhaseRT;
    p.forecast_mode = FFT_Signal_Ind_ForecastMode;
    p.forecast_reg_bars = FFT_Signal_Ind_ForecastRegBars;
    p.forecast_bars = FFT_Signal_Ind_ForecastBars;
    p.denoise_enable = FFT_Signal_Ind_DenoiseEnable;
    p.denoise_window_bars = FFT_Signal_Ind_DenoiseWindowBars;
    p.denoise_sigma = FFT_Signal_Ind_DenoiseSigma;
    p.denoise_future_bars = FFT_Signal_Ind_DenoiseFutureBars;
    p.denoise_color_from_value = FFT_Signal_Ind_DenoiseColorFromValue;
    return p;
  }

  void OnInit() {
    string indi_path = FFT_Signal_IndicatorPath;
    if (indi_path == "") {
      indi_path = "4EA-IND\\IND-FFT_PhaseClock_CLOSE_SINFLIP_LEAD_v1.5_ColorWave-backup";
      LogInfo("FFT_Signal_IndicatorPath vazio; usando padrão 4EA-IND (backup).");
    }
    LogInfo(StringFormat("Init indicadores: path=%s mainTF=%s confirmTF=%s", indi_path, EnumToString(FFT_Signal_MainTF),
                         EnumToString(FFT_Signal_ConfirmTF)));
    FFT_PhaseClock_Params params = BuildIndicatorParams();
    bool ok_main = indi_main.Init(_Symbol, FFT_Signal_MainTF, indi_path, params);
    bool ok_confirm = indi_confirm.Init(_Symbol, FFT_Signal_ConfirmTF, indi_path, params);
    if (!ok_main) {
      LogInfo(StringFormat("Falha Init main. path=%s tf=%s err=%d", indi_path, EnumToString(FFT_Signal_MainTF),
                           GetLastError()));
    }
    if (!ok_confirm) {
      LogInfo(StringFormat("Falha Init confirm. path=%s tf=%s err=%d", indi_path, EnumToString(FFT_Signal_ConfirmTF),
                           GetLastError()));
    }
    if (FFT_Signal_AttachIndicator) {
      if (!indi_main.AttachToChart(0, FFT_Signal_IndicatorSubwindow)) {
        LogInfo("Falha ao anexar indicador principal no chart.");
      }
    }
  }

  bool SignalOpen(ENUM_ORDER_TYPE _cmd, int _method, float _level = 0.0f, int _shift = 0) {
#ifdef __MQL4__
    return false;
#else
    int signal = EvaluateSignalCached();
    if (signal == 0) {
      return false;
    }
    if (signal > 0 && _cmd == ORDER_TYPE_BUY) {
      return true;
    }
    if (signal < 0 && _cmd == ORDER_TYPE_SELL) {
      return true;
    }
    return false;
#endif
  }

 private:
  Indi_FFT_PhaseClock_ColorWave indi_main;
  Indi_FFT_PhaseClock_ColorWave indi_confirm;

  int last_main_color;
  long last_eval_tick_msc;
  int last_eval_signal;

  void LogInfo(string _msg) { PrintFormat("[Stg:FFT_PhaseClock_ColorWave_Signal] %s", _msg); }

  long GetTickMsc() {
    MqlTick tick;
    if (SymbolInfoTick(_Symbol, tick)) {
      return (long)tick.time_msc;
    }
    return (long)TimeCurrent();
  }

  int EvaluateSignalCached() {
    long tick_msc = GetTickMsc();
    if (tick_msc == last_eval_tick_msc) {
      return last_eval_signal;
    }
    last_eval_tick_msc = tick_msc;
    last_eval_signal = EvaluateSignal();
    return last_eval_signal;
  }

  int EvaluateSignal() {
    int main_color = -1;
    int confirm_color = -1;

    if (FFT_Signal_MainShift == 0 && !indi_main.IsBarValueValid(FFT_Signal_MainShift)) {
      LogInfo("Main TF shift 0 invalid (OneValuePerBar likely true). No signal.");
      return 0;
    }
    if (!indi_main.GetColor(FFT_Signal_MainShift, main_color)) {
      return 0;
    }
    if (!indi_confirm.GetColor(FFT_Signal_ConfirmShift, confirm_color)) {
      return 0;
    }
    if ((main_color != 0 && main_color != 1) || (confirm_color != 0 && confirm_color != 1)) {
      return 0;
    }

    if (last_main_color == -1) {
      last_main_color = main_color;
      return 0;
    }

    bool confirm_ok = (main_color == confirm_color);
    int signal = 0;
    if (confirm_ok && main_color != last_main_color) {
      if (main_color == 0 && last_main_color == 1) {
        signal = 1;
      } else if (main_color == 1 && last_main_color == 0) {
        signal = -1;
      }
    }

    last_main_color = main_color;
    return signal;
  }
};
