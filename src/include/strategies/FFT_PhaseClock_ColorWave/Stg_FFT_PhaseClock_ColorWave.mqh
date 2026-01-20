/**
 * @file
 * Implements FFT PhaseClock ColorWave strategy based on indicator color transitions.
 */

#include "Indi_FFT_PhaseClock_ColorWave.mqh"
#include "../../classes/Order.mqh"
#include "../../classes/SymbolInfo.mqh"

// User input params.
INPUT_GROUP("FFT PhaseClock: strategy params");
INPUT double FFT_BaseLot = 0.10;             // Base lot size
INPUT double FFT_StopPips = 100;             // Stop loss distance (pips)
INPUT double FFT_Leg1LotMult = 1.0;          // LEG1 lot multiplier
INPUT double FFT_Leg2LotMult = 1.0;          // LEG2 lot multiplier
INPUT double FFT_TP1_R = 1.0;                // LEG1 TP in R
INPUT double FFT_TP2_R = 3.0;                // LEG2 TP in R
INPUT double FFT_PartialClose_R = 2.0;       // LEG2 partial close at R
INPUT double FFT_PartialCloseFraction = 0.5; // LEG2 partial close fraction
INPUT bool FFT_EnableTrailing = true;        // Enable trailing for LEG2
INPUT double FFT_TrailingDistancePips = 0;   // Trailing distance (pips, 0 = StopPips)
INPUT double FFT_TrailingStepPips = 1;       // Trailing step (pips)
INPUT double FFT_TrailingStartR = 0.0;       // Trailing starts at R
INPUT bool FFT_EnableBreakEven = true;       // Enable break-even on LEG2
INPUT double FFT_BreakEvenTrigger_R = 1.0;   // Break-even trigger (R)
INPUT double FFT_BreakEvenBufferPips = 0;    // Break-even buffer (pips)
INPUT double FFT_MaxSpread = 4.0;            // Max spread to trade (pips)
INPUT int FFT_MaxSlippage = 10;              // Max slippage (points)
INPUT int FFT_SignalOpenFilterMethod = 1;    // Signal open filter method (bitwise)
INPUT int FFT_SignalOpenFilterTime = 3;      // Signal open filter time (bars)
INPUT int FFT_SignalCloseFilterMethod = 30;  // Signal close filter method (bitwise)

INPUT_GROUP("FFT PhaseClock: indicator params");
INPUT string FFT_IndicatorPath = "4EA-IND\\IND-FFT_PhaseClock_CLOSE_SINFLIP_LEAD_v1.5_ColorWave"; // Indicator path
INPUT ENUM_TIMEFRAMES FFT_MainTF = PERIOD_H1;     // Main timeframe
INPUT ENUM_TIMEFRAMES FFT_ConfirmTF = PERIOD_M30; // Confirmation timeframe
INPUT int FFT_MainShift = 0;                      // Main shift
INPUT int FFT_ConfirmShift = 1;                   // Confirm shift
INPUT bool FFT_AttachIndicator = true;            // Attach main indicator to chart
INPUT int FFT_IndicatorSubwindow = 0;             // Subwindow (0 = auto)

INPUT_GROUP("FFT PhaseClock: feed/janela");
INPUT FFT_FEED_SOURCE FFT_Ind_FeedSource = FFT_FEED_OHLC4;
INPUT int FFT_Ind_AtrPeriod = 17;
INPUT ENUM_TIMEFRAMES FFT_Ind_FeedIndicatorTF = PERIOD_CURRENT;
INPUT string FFT_Ind_FeedIndicatorName = "";
INPUT int FFT_Ind_FeedIndicatorBuffer = 0;
INPUT int FFT_Ind_FFTSize = 65536;
INPUT FFT_WINDOW_TYPE FFT_Ind_WindowType = FFT_WND_KAISER;
INPUT double FFT_Ind_KaiserBeta = 8.0;
INPUT bool FFT_Ind_CausalWindow = false;
INPUT bool FFT_Ind_RemoveDC = true;
INPUT FFT_PAD_MODE FFT_Ind_PadMode = FFT_PAD_MIRROR;
INPUT bool FFT_Ind_OneValuePerBar = false;

INPUT_GROUP("FFT PhaseClock: bandpass");
INPUT bool FFT_Ind_ApplyBandpass = true;
INPUT int FFT_Ind_CycleBars = 52;
INPUT double FFT_Ind_BandwidthPct = 80.0;
INPUT FFT_BAND_SHAPE FFT_Ind_BandShape = FFT_BAND_GAUSS;

INPUT_GROUP("FFT PhaseClock: saída/lead");
INPUT FFT_OUTPUT_MODE FFT_Ind_OutputMode = FFT_OUT_SIN;
INPUT bool FFT_Ind_NormalizeAmp = false;
INPUT double FFT_Ind_PhaseOffsetDeg = 315.0;
INPUT double FFT_Ind_LeadBars = 10.0;
INPUT bool FFT_Ind_LeadUseCycleOmega = true;
INPUT double FFT_Ind_LeadOmegaSmooth = 1000.0;
INPUT int FFT_Ind_LeadMinCycleBars = 9;
INPUT int FFT_Ind_LeadMaxCycleBars = 0;
INPUT bool FFT_Ind_InvertOutput = true;  // Invert output (vertical wave flip)
INPUT bool FFT_Ind_HoldPhaseOnLowAmp = true;
INPUT double FFT_Ind_LowAmpEps = 1e-6;

INPUT_GROUP("FFT PhaseClock: zero phase/futuro");
INPUT bool FFT_Ind_ZeroPhaseRT = true;
INPUT FFT_FORECAST_MODE FFT_Ind_ForecastMode = FFT_FC_MIRROR;
INPUT int FFT_Ind_ForecastRegBars = 32;
INPUT int FFT_Ind_ForecastBars = 0;

INPUT_GROUP("FFT PhaseClock: denoise (DLL)");
INPUT bool FFT_Ind_DenoiseEnable = true;
INPUT int FFT_Ind_DenoiseWindowBars = 128;
INPUT double FFT_Ind_DenoiseSigma = 1.0;
INPUT int FFT_Ind_DenoiseFutureBars = 0;
INPUT bool FFT_Ind_DenoiseColorFromValue = true;

// Reverse mode.
enum ENUM_REVERSE_MODE {
  REVERSE_NETTING_STYLE = 0,
  REVERSE_CLOSE_AND_REOPEN = 1
};

INPUT_GROUP("FFT PhaseClock: reversal params");
INPUT ENUM_REVERSE_MODE FFT_ReverseMode = REVERSE_NETTING_STYLE; // Reverse mode

// Struct with default strategy values.
struct Stg_FFT_PhaseClock_ColorWave_Params_Defaults : StgParams {
  Stg_FFT_PhaseClock_ColorWave_Params_Defaults()
      : StgParams(0, FFT_SignalOpenFilterMethod, 0, 0, 0, FFT_SignalCloseFilterMethod, 0, 0, 0, 0, (float)FFT_MaxSpread,
                  0) {
    Set(STRAT_PARAM_LS, FFT_BaseLot);
    Set(STRAT_PARAM_SOFT, FFT_SignalOpenFilterTime);
  }
};

class Stg_FFT_PhaseClock_ColorWave : public Strategy {
 public:
  Stg_FFT_PhaseClock_ColorWave(StgParams &_sparams, TradeParams &_tparams, ChartParams &_cparams, string _name = "")
      : Strategy(_sparams, _tparams, _cparams, _name) {
    last_main_color = -1;
    last_eval_tick_msc = 0;
    last_eval_signal = 0;
    last_signal_tick_msc = 0;
    last_signal_dir = 0;
    last_trade_tick_msc = 0;
    net_ticket = 0;
    net_leg1_volume = 0.0;
    net_leg2_volume = 0.0;
    net_leg1_closed = false;
    net_leg2_partial = false;
    net_be_done = false;
  }

  static Stg_FFT_PhaseClock_ColorWave *Init(ENUM_TIMEFRAMES _tf = NULL, EA *_ea = NULL) {
    Stg_FFT_PhaseClock_ColorWave_Params_Defaults defaults;
    StgParams _stg_params(defaults);
    ChartParams _cparams(_tf, _Symbol);
    TradeParams _tparams;
    Strategy *_strat = new Stg_FFT_PhaseClock_ColorWave(_stg_params, _tparams, _cparams, "FFT_PhaseClock_ColorWave");
    return _strat;
  }

  ~Stg_FFT_PhaseClock_ColorWave() {
    indi_main.Release();
    indi_confirm.Release();
  }

  FFT_PhaseClock_Params BuildIndicatorParams() {
    FFT_PhaseClock_Params p;
    p.feed_source = FFT_Ind_FeedSource;
    p.atr_period = FFT_Ind_AtrPeriod;
    p.feed_indicator_tf = FFT_Ind_FeedIndicatorTF;
    p.feed_indicator_name = FFT_Ind_FeedIndicatorName;
    p.feed_indicator_buffer = FFT_Ind_FeedIndicatorBuffer;
    p.fft_size = FFT_Ind_FFTSize;
    p.window_type = FFT_Ind_WindowType;
    p.kaiser_beta = FFT_Ind_KaiserBeta;
    p.causal_window = FFT_Ind_CausalWindow;
    p.remove_dc = FFT_Ind_RemoveDC;
    p.pad_mode = FFT_Ind_PadMode;
    p.one_value_per_bar = FFT_Ind_OneValuePerBar;
    p.apply_bandpass = FFT_Ind_ApplyBandpass;
    p.cycle_bars = FFT_Ind_CycleBars;
    p.bandwidth_pct = FFT_Ind_BandwidthPct;
    p.band_shape = FFT_Ind_BandShape;
    p.output_mode = FFT_Ind_OutputMode;
    p.normalize_amp = FFT_Ind_NormalizeAmp;
    p.phase_offset_deg = FFT_Ind_PhaseOffsetDeg;
    p.lead_bars = FFT_Ind_LeadBars;
    p.lead_use_cycle_omega = FFT_Ind_LeadUseCycleOmega;
    p.lead_omega_smooth = FFT_Ind_LeadOmegaSmooth;
    p.lead_min_cycle_bars = FFT_Ind_LeadMinCycleBars;
    p.lead_max_cycle_bars = FFT_Ind_LeadMaxCycleBars;
    p.invert_output = FFT_Ind_InvertOutput;
    p.hold_phase_on_low_amp = FFT_Ind_HoldPhaseOnLowAmp;
    p.low_amp_eps = FFT_Ind_LowAmpEps;
    p.zero_phase_rt = FFT_Ind_ZeroPhaseRT;
    p.forecast_mode = FFT_Ind_ForecastMode;
    p.forecast_reg_bars = FFT_Ind_ForecastRegBars;
    p.forecast_bars = FFT_Ind_ForecastBars;
    p.denoise_enable = FFT_Ind_DenoiseEnable;
    p.denoise_window_bars = FFT_Ind_DenoiseWindowBars;
    p.denoise_sigma = FFT_Ind_DenoiseSigma;
    p.denoise_future_bars = FFT_Ind_DenoiseFutureBars;
    p.denoise_color_from_value = FFT_Ind_DenoiseColorFromValue;
    return p;
  }

  void OnInit() {
    string indi_path = FFT_IndicatorPath;
    if (indi_path == "") {
      indi_path = "4EA-IND\\IND-FFT_PhaseClock_CLOSE_SINFLIP_LEAD_v1.5_ColorWave-backup";
      LogInfo("FFT_IndicatorPath vazio; usando padrão 4EA-IND (backup).");
    }
    LogInfo(StringFormat("Init indicadores: path=%s mainTF=%s confirmTF=%s",
                         indi_path, EnumToString(FFT_MainTF), EnumToString(FFT_ConfirmTF)));
    FFT_PhaseClock_Params params = BuildIndicatorParams();
    bool ok_main = indi_main.Init(_Symbol, FFT_MainTF, indi_path, params);
    if (!ok_main) {
      LogInfo(StringFormat("Falha Init main. path=%s tf=%s err=%d",
                           indi_path, EnumToString(FFT_MainTF), GetLastError()));
    }
    bool ok_confirm = indi_confirm.Init(_Symbol, FFT_ConfirmTF, indi_path, params);
    if (!ok_confirm) {
      LogInfo(StringFormat("Falha Init confirm. path=%s tf=%s err=%d",
                           indi_path, EnumToString(FFT_ConfirmTF), GetLastError()));
    }
    if (FFT_AttachIndicator) {
      if (!indi_main.AttachToChart(0, FFT_IndicatorSubwindow)) {
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

  bool SignalCloseFilter(ENUM_ORDER_TYPE _cmd, int _method = 0, int _shift = 0) {
    bool _result = Strategy::SignalCloseFilter(_cmd, _method, _shift);
    if (!_result && _method != 0 && logger.GetLevel() >= V_DEBUG) {
      int _m = (int)MathAbs((double)_method);
      string _blocked = "";
      if (METHOD(_m, 0) && trade.HasBarOrder(_cmd)) _blocked += "1(hasBarOrder) ";
      if (METHOD(_m, 1) && IsTrend(_cmd)) _blocked += "2(inTrend) ";
      if (METHOD(_m, 2) && trade.IsPivot(_cmd)) _blocked += "4(isPivot) ";
      if (METHOD(_m, 3) && !(Open[_shift] > High[_shift + 1] || Open[_shift] < Low[_shift + 1]))
        _blocked += "8(noBreakHL) ";
      if (METHOD(_m, 4) && !trade.IsPeak(_cmd)) _blocked += "16(notPeak) ";
      if (METHOD(_m, 5) && !trade.HasOrderBetter(_cmd)) _blocked += "32(noBetter) ";
      if (METHOD(_m, 6) &&
          !trade.CheckCondition(TRADE_COND_ACCOUNT,
                                _method > 0 ? ACCOUNT_COND_EQUITY_01PC_HIGH : ACCOUNT_COND_EQUITY_01PC_LOW))
        _blocked += "64(equityCond) ";
      if (_blocked != "") {
        LogInfo(StringFormat("Close blocked by flags: %s cmd=%d scfm=%d", _blocked, (int)_cmd, _method));
      }
    }
    return _result;
  }

  bool SignalClose(ENUM_ORDER_TYPE _cmd, int _method = 0, float _level = 0.0f, int _shift = 0) {
    return false;
  }

#ifdef __MQL5__
  bool ExecuteTradeSignal(ENUM_ORDER_TYPE _cmd) {
    if (last_signal_dir == 0) {
      return false;
    }
    if (FFT_StopPips <= 0) {
      LogInfo("StopPips must be > 0.");
      return false;
    }
    if ((_cmd == ORDER_TYPE_BUY && last_signal_dir < 0) || (_cmd == ORDER_TYPE_SELL && last_signal_dir > 0)) {
      return false;
    }
    if (last_trade_tick_msc == last_signal_tick_msc) {
      return false;
    }
    if (!IsSpreadOk()) {
      LogInfo("Spread filter blocked trade.");
      return false;
    }

    bool hedging = IsHedging();
    PositionSnapshot net_pos;
    bool has_net = GetNetPosition(net_pos);
    if (!hedging && has_net && !IsPositionOurs(net_pos.magic)) {
      LogInfo("Netting position magic mismatch; skipping trade.");
      return false;
    }

    if (!hedging && has_net) {
      if (net_pos.dir == _cmd) {
        LogInfo("Signal in same direction; skipping.");
        return false;
      }
      return ReverseNetting(net_pos, _cmd);
    }

    if (hedging) {
      if (HasOppositePosition(_cmd)) {
        if (FFT_ReverseMode == REVERSE_NETTING_STYLE) {
          LogInfo("Hedging detected; fallback to CLOSE_AND_REOPEN.");
        }
        if (!CloseAllPositions()) {
          LogInfo("Failed to close positions for reversal.");
          return false;
        }
      } else if (HasSameDirectionPosition(_cmd)) {
        LogInfo("Existing position in same direction; skipping.");
        return false;
      }
    }

    bool opened = OpenNewPositions(_cmd, hedging);
    if (opened) {
      last_trade_tick_msc = last_signal_tick_msc;
    }
    return opened;
  }

  void ManagePositions() {
    if (FFT_StopPips <= 0) {
      return;
    }
    if (IsHedging()) {
      ManageHedgingPositions();
    } else {
      ManageNettingPosition();
    }
  }
#endif

 private:
  struct PositionSnapshot {
    bool has_position;
    ENUM_ORDER_TYPE dir;
    double volume;
    double price_open;
    double sl;
    double tp;
    ulong ticket;
    long magic;
    string comment;
  };

  Indi_FFT_PhaseClock_ColorWave indi_main;
  Indi_FFT_PhaseClock_ColorWave indi_confirm;

  int last_main_color;
  long last_eval_tick_msc;
  int last_eval_signal;
  long last_signal_tick_msc;
  int last_signal_dir;
  long last_trade_tick_msc;

  ulong net_ticket;
  double net_leg1_volume;
  double net_leg2_volume;
  bool net_leg1_closed;
  bool net_leg2_partial;
  bool net_be_done;

  void LogInfo(string _msg) {
    PrintFormat("[Stg:FFT_PhaseClock_ColorWave] %s", _msg);
  }

#ifndef __MQL4__
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
    if (last_eval_signal != 0) {
      last_signal_dir = last_eval_signal;
      last_signal_tick_msc = tick_msc;
    }
    return last_eval_signal;
  }

  int EvaluateSignal() {
    int main_color = -1;
    int confirm_color = -1;

    if (FFT_MainShift == 0 && !indi_main.IsBarValueValid(FFT_MainShift)) {
      LogInfo("Main TF shift 0 invalid (OneValuePerBar likely true). No signal.");
      return 0;
    }
    if (!indi_main.GetColor(FFT_MainShift, main_color)) {
      return 0;
    }
    if (!indi_confirm.GetColor(FFT_ConfirmShift, confirm_color)) {
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

  bool IsHedging() {
    long mode = AccountInfoInteger(ACCOUNT_MARGIN_MODE);
    return (mode == ACCOUNT_MARGIN_MODE_RETAIL_HEDGING);
  }

  bool IsPositionOurs(long magic) {
    return magic == Get<long>(STRAT_PARAM_ID);
  }

  double PipSize() {
    int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    if (digits == 3 || digits == 5) {
      return point * 10.0;
    }
    return point;
  }

  double NormalizePrice(double price) {
    int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
    return NormalizeDouble(price, digits);
  }

  int VolumeDigits() {
    double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    if (step <= 0.0) {
      return 2;
    }
    int digits = 0;
    while (step < 1.0 && digits < 8) {
      step *= 10.0;
      digits++;
    }
    return digits;
  }

  double NormalizeVolume(double volume) {
    double min_vol = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double max_vol = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    if (volume < min_vol) {
      return 0.0;
    }
    if (volume > max_vol) {
      volume = max_vol;
    }
    double steps = MathFloor((volume - min_vol) / step + 1e-8);
    double normalized = min_vol + steps * step;
    int vol_digits = VolumeDigits();
    return NormalizeDouble(normalized, vol_digits);
  }

  double CalcEntryPrice(ENUM_ORDER_TYPE cmd) {
    if (cmd == ORDER_TYPE_BUY) {
      return SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    }
    return SymbolInfoDouble(_Symbol, SYMBOL_BID);
  }

  double CalcSL(ENUM_ORDER_TYPE cmd, double entry_price, double stop_pips) {
    double dist = stop_pips * PipSize();
    double sl = entry_price + (cmd == ORDER_TYPE_BUY ? -dist : dist);
    return NormalizePrice(sl);
  }

  double CalcTP(ENUM_ORDER_TYPE cmd, double entry_price, double tp_pips) {
    double dist = tp_pips * PipSize();
    double tp = entry_price + (cmd == ORDER_TYPE_BUY ? dist : -dist);
    return NormalizePrice(tp);
  }

  bool AdjustStopLevel(ENUM_ORDER_TYPE cmd, double price_current, double &sl) {
    double stop_level = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    double freeze_level =
        SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL) * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    if (freeze_level > 0 && MathAbs(price_current - sl) < freeze_level) {
      LogInfo("Freeze level prevents SL update.");
      return false;
    }
    if (stop_level <= 0) {
      return true;
    }
    if (cmd == ORDER_TYPE_BUY && (price_current - sl) < stop_level) {
      sl = NormalizePrice(price_current - stop_level);
    }
    if (cmd == ORDER_TYPE_SELL && (sl - price_current) < stop_level) {
      sl = NormalizePrice(price_current + stop_level);
    }
    return true;
  }

  bool AdjustTakeProfit(ENUM_ORDER_TYPE cmd, double price_current, double &tp) {
    double stop_level = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    double freeze_level =
        SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL) * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    if (freeze_level > 0 && MathAbs(price_current - tp) < freeze_level) {
      LogInfo("Freeze level prevents TP update.");
      return false;
    }
    if (stop_level <= 0) {
      return true;
    }
    if (cmd == ORDER_TYPE_BUY && (tp - price_current) < stop_level) {
      tp = NormalizePrice(price_current + stop_level);
    }
    if (cmd == ORDER_TYPE_SELL && (price_current - tp) < stop_level) {
      tp = NormalizePrice(price_current - stop_level);
    }
    return true;
  }

  bool IsSpreadOk() {
    if (FFT_MaxSpread <= 0) {
      return true;
    }
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double spread_pips = (ask - bid) / PipSize();
    return spread_pips <= FFT_MaxSpread;
  }

  bool GetNetPosition(PositionSnapshot &out) {
    out.has_position = false;
    if (!PositionSelect(_Symbol)) {
      return false;
    }
    out.has_position = true;
    out.ticket = (ulong)PositionGetInteger(POSITION_TICKET);
    out.volume = PositionGetDouble(POSITION_VOLUME);
    out.price_open = PositionGetDouble(POSITION_PRICE_OPEN);
    out.sl = PositionGetDouble(POSITION_SL);
    out.tp = PositionGetDouble(POSITION_TP);
    out.magic = (long)PositionGetInteger(POSITION_MAGIC);
    out.comment = PositionGetString(POSITION_COMMENT);
    ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
    out.dir = ptype == POSITION_TYPE_BUY ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
    return true;
  }

  bool HasOppositePosition(ENUM_ORDER_TYPE cmd) {
    int total = PositionsTotal();
    for (int i = 0; i < total; i++) {
      ulong ticket = PositionGetTicket(i);
      if (!PositionSelectByTicket(ticket)) {
        continue;
      }
      if (PositionGetString(POSITION_SYMBOL) != _Symbol) {
        continue;
      }
      if (!IsPositionOurs((long)PositionGetInteger(POSITION_MAGIC))) {
        continue;
      }
      ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if (cmd == ORDER_TYPE_BUY && ptype == POSITION_TYPE_SELL) {
        return true;
      }
      if (cmd == ORDER_TYPE_SELL && ptype == POSITION_TYPE_BUY) {
        return true;
      }
    }
    return false;
  }

  bool HasSameDirectionPosition(ENUM_ORDER_TYPE cmd) {
    int total = PositionsTotal();
    for (int i = 0; i < total; i++) {
      ulong ticket = PositionGetTicket(i);
      if (!PositionSelectByTicket(ticket)) {
        continue;
      }
      if (PositionGetString(POSITION_SYMBOL) != _Symbol) {
        continue;
      }
      if (!IsPositionOurs((long)PositionGetInteger(POSITION_MAGIC))) {
        continue;
      }
      ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if (cmd == ORDER_TYPE_BUY && ptype == POSITION_TYPE_BUY) {
        return true;
      }
      if (cmd == ORDER_TYPE_SELL && ptype == POSITION_TYPE_SELL) {
        return true;
      }
    }
    return false;
  }

  bool CloseAllPositions() {
    bool ok = true;
    int total = PositionsTotal();
    for (int i = total - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if (!PositionSelectByTicket(ticket)) {
        continue;
      }
      if (PositionGetString(POSITION_SYMBOL) != _Symbol) {
        continue;
      }
      if (!IsPositionOurs((long)PositionGetInteger(POSITION_MAGIC))) {
        continue;
      }
      double volume = PositionGetDouble(POSITION_VOLUME);
      ok &= ClosePositionPartial(ticket, volume, "ReverseClose");
    }
    return ok;
  }

  bool ReverseNetting(PositionSnapshot &net_pos, ENUM_ORDER_TYPE cmd) {
    if (FFT_ReverseMode == REVERSE_CLOSE_AND_REOPEN) {
      if (!ClosePositionPartial(net_pos.ticket, net_pos.volume, "ReverseClose")) {
        return false;
      }
      bool opened = OpenNewPositions(cmd, false);
      if (opened) {
        last_trade_tick_msc = last_signal_tick_msc;
      }
      return opened;
    }

    double reverse_volume = NormalizeVolume(net_pos.volume * 2.0);
    if (reverse_volume <= 0) {
      LogInfo("Reverse volume invalid.");
      return false;
    }
    string comment = StringFormat("%s#REV", GetName());
    double entry = CalcEntryPrice(cmd);
    double sl = CalcSL(cmd, entry, FFT_StopPips);
    double tp = CalcTP(cmd, entry, FFT_TP2_R * FFT_StopPips);
    bool sent = SendOrder(cmd, reverse_volume, sl, tp, comment);
    if (sent) {
      // Refresh netting state after reversal.
      PositionSnapshot new_pos;
      if (GetNetPosition(new_pos)) {
        UpdateNettingState(new_pos);
      }
      last_trade_tick_msc = last_signal_tick_msc;
    }
    return sent;
  }

  bool OpenNewPositions(ENUM_ORDER_TYPE cmd, bool hedging) {
    double base_lot = FFT_BaseLot;
    double lot1 = NormalizeVolume(base_lot * FFT_Leg1LotMult);
    double lot2 = NormalizeVolume(base_lot * FFT_Leg2LotMult);
    if (lot1 <= 0 || lot2 <= 0) {
      LogInfo("Lot size too small; check BaseLot and multipliers.");
      return false;
    }

    double entry = CalcEntryPrice(cmd);
    double stop_pips = FFT_StopPips;
    double tp1_pips = FFT_TP1_R * FFT_StopPips;
    double tp2_pips = FFT_TP2_R * FFT_StopPips;
    double sl = CalcSL(cmd, entry, stop_pips);
    double tp1 = CalcTP(cmd, entry, tp1_pips);
    double tp2 = CalcTP(cmd, entry, tp2_pips);

    if (hedging) {
      bool ok1 = SendOrder(cmd, lot1, sl, tp1, StringFormat("%s#L1", GetName()));
      bool ok2 = SendOrder(cmd, lot2, sl, tp2, StringFormat("%s#L2", GetName()));
      return ok1 && ok2;
    }

    double total = NormalizeVolume(lot1 + lot2);
    if (total <= 0) {
      LogInfo("Total lot size invalid for netting.");
      return false;
    }
    bool ok = SendOrder(cmd, total, sl, tp2, StringFormat("%s#NET", GetName()));
    if (ok) {
      PositionSnapshot net_pos;
      if (GetNetPosition(net_pos)) {
        UpdateNettingState(net_pos);
      }
    }
    return ok;
  }

  void UpdateNettingState(PositionSnapshot &net_pos) {
    net_ticket = net_pos.ticket;
    double total_mult = FFT_Leg1LotMult + FFT_Leg2LotMult;
    if (total_mult <= 0) {
      total_mult = 1.0;
    }
    net_leg1_volume = NormalizeVolume(net_pos.volume * (FFT_Leg1LotMult / total_mult));
    net_leg2_volume = NormalizeVolume(net_pos.volume * (FFT_Leg2LotMult / total_mult));
    net_leg1_closed = false;
    net_leg2_partial = false;
    net_be_done = false;
  }

  bool SendOrder(ENUM_ORDER_TYPE cmd, double volume, double sl, double tp, string comment) {
    if (volume <= 0) {
      return false;
    }
    MqlTradeRequest req;
    MqlTradeResult res;
    ZeroMemory(req);
    ZeroMemory(res);
    req.action = TRADE_ACTION_DEAL;
    req.symbol = _Symbol;
    req.magic = (ulong)Get<long>(STRAT_PARAM_ID);
    req.volume = volume;
    req.type = cmd;
    req.deviation = FFT_MaxSlippage;
    req.price = CalcEntryPrice(cmd);
    if (sl > 0 && AdjustStopLevel(cmd, req.price, sl)) {
      req.sl = sl;
    }
    if (tp > 0 && AdjustTakeProfit(cmd, req.price, tp)) {
      req.tp = tp;
    }
    req.comment = comment;
    req.type_filling = Order::GetOrderFilling(_Symbol);

    bool ok = OrderSend(req, res);
    if (!ok || (res.retcode != TRADE_RETCODE_DONE && res.retcode != TRADE_RETCODE_PLACED)) {
      LogInfo(StringFormat("OrderSend failed. cmd=%d vol=%.2f ret=%d err=%d",
                           cmd, volume, res.retcode, GetLastError()));
      ResetLastError();
      return false;
    }
    return true;
  }

  bool ClosePositionPartial(ulong ticket, double volume, string reason) {
    if (!PositionSelectByTicket(ticket)) {
      return false;
    }
    ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
    string symbol = PositionGetString(POSITION_SYMBOL);
    MqlTradeRequest req;
    MqlTradeResult res;
    ZeroMemory(req);
    ZeroMemory(res);
    req.action = TRADE_ACTION_DEAL;
    req.position = ticket;
    req.symbol = symbol;
    req.magic = (ulong)PositionGetInteger(POSITION_MAGIC);
    req.volume = volume;
    req.type = (ptype == POSITION_TYPE_BUY) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
    req.price = (req.type == ORDER_TYPE_BUY) ? SymbolInfoDouble(symbol, SYMBOL_ASK)
                                             : SymbolInfoDouble(symbol, SYMBOL_BID);
    req.deviation = FFT_MaxSlippage;
    req.comment = StringFormat("%s#%s", GetName(), reason);
    req.type_filling = Order::GetOrderFilling(symbol);

    bool ok = OrderSend(req, res);
    if (!ok || (res.retcode != TRADE_RETCODE_DONE && res.retcode != TRADE_RETCODE_PLACED)) {
      LogInfo(StringFormat("Partial close failed. ticket=%s vol=%.2f ret=%d err=%d",
                           IntegerToString((long)ticket), volume, res.retcode, GetLastError()));
      ResetLastError();
      return false;
    }
    return true;
  }

  bool ModifyPositionSLTP(ulong ticket, double sl, double tp) {
    if (sl <= 0 && tp <= 0) {
      return false;
    }
    if (!PositionSelectByTicket(ticket)) {
      return false;
    }
    double cur_price = PositionGetDouble(POSITION_PRICE_CURRENT);
    ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
    ENUM_ORDER_TYPE cmd = ptype == POSITION_TYPE_BUY ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
    if (sl > 0 && !AdjustStopLevel(cmd, cur_price, sl)) {
      return false;
    }
    bool ok = Order::OrderModify(ticket, 0, sl, tp, 0);
    if (!ok) {
      LogInfo(StringFormat("OrderModify failed. ticket=%s err=%d", IntegerToString((long)ticket), GetLastError()));
      ResetLastError();
    }
    return ok;
  }

  double ProfitPips(PositionSnapshot &pos) {
    double current = (pos.dir == ORDER_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                                 : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double diff = (pos.dir == ORDER_TYPE_BUY) ? (current - pos.price_open) : (pos.price_open - current);
    return diff / PipSize();
  }

  void ManageNettingPosition() {
    PositionSnapshot pos;
    if (!GetNetPosition(pos) || !pos.has_position) {
      ResetNettingState();
      return;
    }
    if (!IsPositionOurs(pos.magic)) {
      return;
    }

    if (pos.ticket != net_ticket) {
      UpdateNettingState(pos);
    }

    double profit_pips = ProfitPips(pos);
    if (!net_leg1_closed && profit_pips >= (FFT_TP1_R * FFT_StopPips)) {
      double close_vol = NormalizeVolume(net_leg1_volume);
      if (close_vol > 0 && close_vol < pos.volume) {
        if (ClosePositionPartial(pos.ticket, close_vol, "NET_L1")) {
          net_leg1_closed = true;
        }
      }
    }

    if (!net_leg2_partial && profit_pips >= (FFT_PartialClose_R * FFT_StopPips)) {
      double close_vol = NormalizeVolume(net_leg2_volume * FFT_PartialCloseFraction);
      if (close_vol > 0 && close_vol < pos.volume) {
        if (ClosePositionPartial(pos.ticket, close_vol, "NET_L2_PART")) {
          net_leg2_partial = true;
        }
      }
    }

    ApplyProtectionToPosition(pos, true);
  }

  void ResetNettingState() {
    net_ticket = 0;
    net_leg1_volume = 0.0;
    net_leg2_volume = 0.0;
    net_leg1_closed = false;
    net_leg2_partial = false;
    net_be_done = false;
  }

  void ManageHedgingPositions() {
    PositionSnapshot leg2;
    bool has_leg2 = FindLegPosition("#L2", leg2);
    if (has_leg2) {
      double profit_pips = ProfitPips(leg2);
      double expected_leg2 = NormalizeVolume(FFT_BaseLot * FFT_Leg2LotMult);
      if (profit_pips >= (FFT_PartialClose_R * FFT_StopPips)) {
        double close_vol = NormalizeVolume(expected_leg2 * FFT_PartialCloseFraction);
        if (close_vol > 0 && close_vol < leg2.volume) {
          ClosePositionPartial(leg2.ticket, close_vol, "L2_PART");
        }
      }
      ApplyProtectionToPosition(leg2, true);
    }
  }

  bool FindLegPosition(string tag, PositionSnapshot &out) {
    int total = PositionsTotal();
    for (int i = 0; i < total; i++) {
      ulong ticket = PositionGetTicket(i);
      if (!PositionSelectByTicket(ticket)) {
        continue;
      }
      if (PositionGetString(POSITION_SYMBOL) != _Symbol) {
        continue;
      }
      long magic = (long)PositionGetInteger(POSITION_MAGIC);
      if (!IsPositionOurs(magic)) {
        continue;
      }
      string comment = PositionGetString(POSITION_COMMENT);
      if (StringFind(comment, tag) < 0) {
        continue;
      }
      ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      out.has_position = true;
      out.ticket = ticket;
      out.volume = PositionGetDouble(POSITION_VOLUME);
      out.price_open = PositionGetDouble(POSITION_PRICE_OPEN);
      out.sl = PositionGetDouble(POSITION_SL);
      out.tp = PositionGetDouble(POSITION_TP);
      out.magic = magic;
      out.comment = comment;
      out.dir = ptype == POSITION_TYPE_BUY ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
      return true;
    }
    return false;
  }

  void ApplyProtectionToPosition(PositionSnapshot &pos, bool is_leg2) {
    if (!is_leg2) {
      return;
    }

    double profit_pips = ProfitPips(pos);
    double stop_pips = FFT_StopPips;
    double be_trigger = FFT_BreakEvenTrigger_R * stop_pips;

    double sl_target = pos.sl;
    bool sl_change = false;

    if (FFT_EnableBreakEven && profit_pips >= be_trigger) {
      double be_buffer = FFT_BreakEvenBufferPips * PipSize();
      double be_sl = pos.price_open + (pos.dir == ORDER_TYPE_BUY ? be_buffer : -be_buffer);
      if (pos.dir == ORDER_TYPE_BUY) {
        if (sl_target < be_sl || sl_target == 0.0) {
          sl_target = be_sl;
          sl_change = true;
        }
      } else {
        if (sl_target > be_sl || sl_target == 0.0) {
          sl_target = be_sl;
          sl_change = true;
        }
      }
    }

    if (FFT_EnableTrailing) {
      double start_r = FFT_TrailingStartR * stop_pips;
      double trail_dist = (FFT_TrailingDistancePips > 0 ? FFT_TrailingDistancePips : stop_pips);
      double trail_step = FFT_TrailingStepPips;
      if (profit_pips >= start_r) {
        double price_current = (pos.dir == ORDER_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                                           : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
        double trail_sl =
            price_current + (pos.dir == ORDER_TYPE_BUY ? -trail_dist * PipSize() : trail_dist * PipSize());
        if (pos.dir == ORDER_TYPE_BUY) {
          if (trail_sl > sl_target || sl_target == 0.0) {
            if (trail_step <= 0 || (trail_sl - sl_target) >= trail_step * PipSize()) {
              sl_target = trail_sl;
              sl_change = true;
            }
          }
        } else {
          if (trail_sl < sl_target || sl_target == 0.0) {
            if (sl_target == 0.0 || trail_step <= 0 || (sl_target - trail_sl) >= trail_step * PipSize()) {
              sl_target = trail_sl;
              sl_change = true;
            }
          }
        }
      }
    }

    if (sl_change) {
      sl_target = NormalizePrice(sl_target);
      if (sl_target != pos.sl) {
        ModifyPositionSLTP(pos.ticket, sl_target, pos.tp);
      }
    }
  }
#endif
};
