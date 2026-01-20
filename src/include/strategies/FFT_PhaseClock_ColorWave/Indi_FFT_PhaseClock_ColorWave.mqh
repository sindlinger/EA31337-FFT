/**
 * @file
 * Wrapper for IND-FFT_PhaseClock_CLOSE_SINFLIP_LEAD_v1.5_ColorWave (buffer 1 color index).
 */

#ifndef INDI_FFT_PHASECLOCK_COLORWAVE_MQH
#define INDI_FFT_PHASECLOCK_COLORWAVE_MQH

// EA31337 includes for utilities.
#include "../../classes/Chart.mqh"
#include "../../classes/Log.mqh"

// Indicator enums mirrored with FFT_ prefix to avoid conflicts.
enum FFT_FEED_SOURCE {
  FFT_FEED_ATR = 0,
  FFT_FEED_TR,
  FFT_FEED_CLOSE,
  FFT_FEED_HL2,
  FFT_FEED_HLC3,
  FFT_FEED_OHLC4,
  FFT_FEED_VOLUME,
  FFT_FEED_TICKVOLUME,
  FFT_FEED_INDICATOR
};

enum FFT_WINDOW_TYPE { FFT_WND_HANN = 0, FFT_WND_SINE, FFT_WND_SQRT_HANN, FFT_WND_KAISER };
enum FFT_BAND_SHAPE { FFT_BAND_RECT = 0, FFT_BAND_GAUSS };
enum FFT_OUTPUT_MODE { FFT_OUT_SIN = 0, FFT_OUT_COS, FFT_OUT_PHASE_RAD, FFT_OUT_PHASE_DEG };
enum FFT_PAD_MODE { FFT_PAD_ZERO = 0, FFT_PAD_MIRROR };
enum FFT_FORECAST_MODE { FFT_FC_MIRROR = 0, FFT_FC_LINREG };
enum FFT_LAG_PRESET { FFT_LAG_PRESET_CUSTOM = 0, FFT_LAG_PRESET_ZERO };

struct FFT_PhaseClock_Params {
  int lag_preset;
  int feed_source;
  int atr_period;
  ENUM_TIMEFRAMES feed_indicator_tf;
  string feed_indicator_name;
  int feed_indicator_buffer;
  int fft_size;
  int window_type;
  double kaiser_beta;
  bool causal_window;
  bool remove_dc;
  int pad_mode;
  bool one_value_per_bar;
  bool apply_bandpass;
  int cycle_bars;
  double bandwidth_pct;
  int band_shape;
  int output_mode;
  bool normalize_amp;
  double phase_offset_deg;
  double lead_bars;
  bool lead_use_cycle_omega;
  double lead_omega_smooth;
  int lead_min_cycle_bars;
  int lead_max_cycle_bars;
  bool invert_output;
  bool zero_phase_rt;
  int forecast_mode;
  int forecast_reg_bars;
  int forecast_bars;
  bool show_forecast_line;
  int forecast_draw_bars;
  color forecast_line_color;
  int forecast_line_width;
  bool hold_phase_on_low_amp;
  double low_amp_eps;
  bool show_phase_clock;
  int clock_x_offset;
  int clock_y_offset;
  int clock_radius;
  bool clock_show_ring_dots;
  int clock_ring_dots_count;
  int clock_ring_dot_size;
  color clock_ring_color;
  bool clock_show_numbers;
  int clock_numbers_size;
  color clock_numbers_color;
  bool clock_show_hand;
  int clock_hand_segments;
  int clock_hand_dot_size;
  color clock_hand_color;
  bool clock_show_center_dot;
  int clock_center_dot_size;
  color clock_center_color;
  bool clock_show_text;
  bool denoise_enable;
  int denoise_window_bars;
  double denoise_sigma;
  int denoise_future_bars;
  bool denoise_color_from_value;

  FFT_PhaseClock_Params() {
    lag_preset = FFT_LAG_PRESET_CUSTOM;
    feed_source = FFT_FEED_OHLC4;
    atr_period = 17;
    feed_indicator_tf = PERIOD_CURRENT;
    feed_indicator_name = "";
    feed_indicator_buffer = 0;
    fft_size = 65536;
    window_type = FFT_WND_SINE;
    kaiser_beta = 4.0;
    causal_window = false;
    remove_dc = false;
    pad_mode = FFT_PAD_MIRROR;
    one_value_per_bar = false;
    apply_bandpass = true;
    cycle_bars = 52;
    bandwidth_pct = 200.0;
    band_shape = FFT_BAND_GAUSS;
    output_mode = FFT_OUT_SIN;
    normalize_amp = false;
    phase_offset_deg = 315.0;
    lead_bars = 10.0;
    lead_use_cycle_omega = true;
    lead_omega_smooth = 1000.0;
    lead_min_cycle_bars = 9;
    lead_max_cycle_bars = 0;
    invert_output = true;
    zero_phase_rt = true;
    forecast_mode = FFT_FC_MIRROR;
    forecast_reg_bars = 32;
    forecast_bars = 0;
    show_forecast_line = false;
    forecast_draw_bars = 0;
    forecast_line_color = clrOrange;
    forecast_line_width = 1;
    hold_phase_on_low_amp = true;
    low_amp_eps = 1e-9;
    show_phase_clock = false;
    clock_x_offset = 110;
    clock_y_offset = 55;
    clock_radius = 26;
    clock_show_ring_dots = true;
    clock_ring_dots_count = 60;
    clock_ring_dot_size = 10;
    clock_ring_color = clrSilver;
    clock_show_numbers = true;
    clock_numbers_size = 10;
    clock_numbers_color = clrSilver;
    clock_show_hand = true;
    clock_hand_segments = 9;
    clock_hand_dot_size = 12;
    clock_hand_color = clrRed;
    clock_show_center_dot = true;
    clock_center_dot_size = 12;
    clock_center_color = clrWhite;
    clock_show_text = true;
    denoise_enable = true;
    denoise_window_bars = 128;
    denoise_sigma = 1.0;
    denoise_future_bars = 0;
    denoise_color_from_value = true;
  }
};

class Indi_FFT_PhaseClock_ColorWave {
 private:
  static const string INDICATOR_SHORTNAME;
  string symbol;
  ENUM_TIMEFRAMES tf;
  string path;
  int handle;
  FFT_PhaseClock_Params params;
  bool params_ready;

  void LogError(string _msg) {
    PrintFormat("[Indi:FFT_PhaseClock_ColorWave] %s", _msg);
  }

#ifdef __MQL5__
  bool IsDenoiseIndicatorPath(const string &_path) {
    string lower = _path;
    StringToLower(lower);
    return StringFind(lower, "denoise") >= 0;
  }

  int CreateHandleForPath(const string &_path) {
    if (IsDenoiseIndicatorPath(_path)) {
      return iCustom(symbol, tf, _path,
                     params.lag_preset,
                     params.feed_source,
                     params.atr_period,
                     params.feed_indicator_tf,
                     params.feed_indicator_name,
                     params.feed_indicator_buffer,
                     params.fft_size,
                     params.window_type,
                     params.kaiser_beta,
                     params.causal_window,
                     params.remove_dc,
                     params.pad_mode,
                     params.one_value_per_bar,
                     params.apply_bandpass,
                     params.cycle_bars,
                     params.bandwidth_pct,
                     params.band_shape,
                     params.output_mode,
                     params.normalize_amp,
                     params.phase_offset_deg,
                     params.lead_bars,
                     params.lead_use_cycle_omega,
                     params.lead_omega_smooth,
                     params.lead_min_cycle_bars,
                     params.lead_max_cycle_bars,
                     params.invert_output,
                     params.zero_phase_rt,
                     params.forecast_mode,
                     params.forecast_reg_bars,
                     params.forecast_bars,
                     params.show_forecast_line,
                     params.forecast_draw_bars,
                     params.forecast_line_color,
                     params.forecast_line_width,
                     params.hold_phase_on_low_amp,
                     params.low_amp_eps,
                     params.show_phase_clock,
                     params.clock_x_offset,
                     params.clock_y_offset,
                     params.clock_radius,
                     params.clock_show_ring_dots,
                     params.clock_ring_dots_count,
                     params.clock_ring_dot_size,
                     params.clock_ring_color,
                     params.clock_show_numbers,
                     params.clock_numbers_size,
                     params.clock_numbers_color,
                     params.clock_show_hand,
                     params.clock_hand_segments,
                     params.clock_hand_dot_size,
                     params.clock_hand_color,
                     params.clock_show_center_dot,
                     params.clock_center_dot_size,
                     params.clock_center_color,
                     params.clock_show_text,
                     params.denoise_enable,
                     params.denoise_window_bars,
                     params.denoise_sigma,
                     params.denoise_future_bars,
                     params.denoise_color_from_value);
    }
    return iCustom(symbol, tf, _path,
                   params.lag_preset,
                   params.feed_source,
                   params.atr_period,
                   params.feed_indicator_tf,
                   params.feed_indicator_name,
                   params.feed_indicator_buffer,
                   params.fft_size,
                   params.window_type,
                   params.kaiser_beta,
                   params.causal_window,
                   params.remove_dc,
                   params.pad_mode,
                   params.one_value_per_bar,
                   params.apply_bandpass,
                   params.cycle_bars,
                   params.bandwidth_pct,
                   params.band_shape,
                   params.output_mode,
                   params.normalize_amp,
                   params.phase_offset_deg,
                   params.lead_bars,
                   params.lead_use_cycle_omega,
                   params.lead_omega_smooth,
                   params.lead_min_cycle_bars,
                   params.lead_max_cycle_bars,
                   params.invert_output,
                   params.zero_phase_rt,
                   params.forecast_mode,
                   params.forecast_reg_bars,
                   params.forecast_bars,
                   params.show_forecast_line,
                   params.forecast_draw_bars,
                   params.forecast_line_color,
                   params.forecast_line_width,
                   params.hold_phase_on_low_amp,
                   params.low_amp_eps,
                   params.show_phase_clock,
                   params.clock_x_offset,
                   params.clock_y_offset,
                   params.clock_radius,
                   params.clock_show_ring_dots,
                   params.clock_ring_dots_count,
                   params.clock_ring_dot_size,
                   params.clock_ring_color,
                   params.clock_show_numbers,
                   params.clock_numbers_size,
                   params.clock_numbers_color,
                   params.clock_show_hand,
                   params.clock_hand_segments,
                   params.clock_hand_dot_size,
                   params.clock_hand_color,
                   params.clock_show_center_dot,
                   params.clock_center_dot_size,
                   params.clock_center_color,
                   params.clock_show_text);
  }

  bool CreateHandle() {
    if (symbol == "" || path == "") {
      LogError("Init required before use.");
      return false;
    }
    handle = iCustom(symbol, tf, path);
    if (handle != INVALID_HANDLE) {
      return true;
    }
    ResetLastError();
    string backup_path = path;
    if (StringFind(path, "-backup") < 0) {
      backup_path = path + "-backup";
    }
    if (backup_path != path) {
      handle = iCustom(symbol, tf, backup_path);
      if (handle != INVALID_HANDLE) {
        path = backup_path;
        LogError("Using backup indicator path.");
        return true;
      }
      ResetLastError();
    }
    handle = CreateHandleForPath(path);
    if (handle == INVALID_HANDLE) {
      int err = GetLastError();
      ResetLastError();
      string alt_path = path;
      string alt_path_4ea = path;
      if (StringFind(path, "\\") < 0 && StringFind(path, "/") < 0) {
        alt_path = "Strategy-FFT_PhaseClock_ColorWave\\" + path;
        alt_path_4ea = "4EA-IND\\" + path;
      }
      if (alt_path != path) {
        handle = CreateHandleForPath(alt_path);
        if (handle != INVALID_HANDLE) {
          path = alt_path;
          return true;
        }
      }
      if (alt_path_4ea != path && alt_path_4ea != alt_path) {
        handle = CreateHandleForPath(alt_path_4ea);
        if (handle != INVALID_HANDLE) {
          path = alt_path_4ea;
          return true;
        }
      }
      int err_alt = GetLastError();
      ResetLastError();

      // Fallback: try without params (compat with older indicator builds).
      handle = iCustom(symbol, tf, path);
      if (handle != INVALID_HANDLE) {
        LogError("iCustom full params failed; using minimal params.");
        return true;
      }
      int err_min = GetLastError();
      ResetLastError();
      if (alt_path != path) {
        handle = iCustom(symbol, tf, alt_path);
        if (handle != INVALID_HANDLE) {
          path = alt_path;
          LogError("iCustom full params failed; using minimal params (alt path).");
          return true;
        }
      }
      if (alt_path_4ea != path && alt_path_4ea != alt_path) {
        handle = iCustom(symbol, tf, alt_path_4ea);
        if (handle != INVALID_HANDLE) {
          path = alt_path_4ea;
          LogError("iCustom full params failed; using minimal params (4EA-IND).");
          return true;
        }
      }
      int err_min_alt = GetLastError();
      LogError(StringFormat("iCustom failed. symbol=%s tf=%s path=%s alt=%s err=%d/%d/%d/%d",
                            symbol, EnumToString(tf), path, alt_path, err, err_alt, err_min, err_min_alt));
      ResetLastError();
      return false;
    }
    return true;
  }

  bool EnsureHandle() {
    if (handle != INVALID_HANDLE) {
      return true;
    }
    if (!params_ready) {
      LogError("Init required before use.");
      return false;
    }
    return CreateHandle();
  }

  bool BarsReady(int shift) {
    int bars = Bars(symbol, tf);
    if (bars <= shift) {
      LogError(StringFormat("Not enough bars. symbol=%s tf=%s bars=%d shift=%d",
                            symbol, EnumToString(tf), bars, shift));
      return false;
    }
    int calculated = BarsCalculated(handle);
    if (calculated > 0 && calculated <= shift) {
      LogError(StringFormat("BarsCalculated too small. symbol=%s tf=%s calculated=%d shift=%d handle=%d",
                            symbol, EnumToString(tf), calculated, shift, handle));
      return false;
    }
    return true;
  }
#endif

 public:
  Indi_FFT_PhaseClock_ColorWave()
      : symbol(""), tf(PERIOD_CURRENT), path(""), handle(INVALID_HANDLE), params(), params_ready(false) {}

  bool Init(string _symbol, ENUM_TIMEFRAMES _tf, string _path) {
    params = FFT_PhaseClock_Params();
    params_ready = true;
    symbol = _symbol;
    tf = _tf;
    path = _path;
#ifdef __MQL5__
    return CreateHandle();
#else
    LogError("MQL4 stub: indicator handle not supported.");
    return false;
#endif
  }

  bool Init(string _symbol, ENUM_TIMEFRAMES _tf, string _path, const FFT_PhaseClock_Params &_params) {
    params = _params;
    params_ready = true;
    symbol = _symbol;
    tf = _tf;
    path = _path;
#ifdef __MQL5__
    return CreateHandle();
#else
    LogError("MQL4 stub: indicator handle not supported.");
    return false;
#endif
  }

  void Release() {
#ifdef __MQL5__
    if (handle != INVALID_HANDLE) {
      IndicatorRelease(handle);
    }
#endif
    handle = INVALID_HANDLE;
  }

  bool AttachToChart(long chart_id = 0, int subwindow = 0) {
#ifdef __MQL5__
    if (!EnsureHandle()) {
      return false;
    }
    if (chart_id == 0) {
      chart_id = ChartID();
    }
    int target_subwindow = subwindow;
    if (target_subwindow <= 0) {
      // Let MT5 create a new subwindow for separate_window indicators.
      target_subwindow = 0;
    }
    bool allow_fallback = true;
    if (!ChartIndicatorAdd(chart_id, target_subwindow, handle)) {
      int err = GetLastError();
      ResetLastError();
      if (allow_fallback && ChartIndicatorAdd(chart_id, 0, handle)) {
        LogError(StringFormat("ChartIndicatorAdd failed in subwindow %d (err=%d). Attached to main/subwindow 0.",
                              target_subwindow, err));
        return true;
      }
      if (err == 0) {
        err = GetLastError();
      }
      LogError(StringFormat("ChartIndicatorAdd failed. chart=%I64d sub=%d handle=%d err=%d",
                            chart_id, target_subwindow, handle, err));
      ResetLastError();
      return false;
    }
    return true;
#else
    LogError("MQL4 stub: attach not supported.");
    return false;
#endif
  }

  bool IsBarValueValid(int shift) {
#ifdef __MQL5__
    if (!EnsureHandle()) {
      return false;
    }
    if (!BarsReady(shift)) {
      return false;
    }
    double buffer_val[];
    ArraySetAsSeries(buffer_val, true);
    int copied = CopyBuffer(handle, 0, shift, 1, buffer_val);
    if (copied < 1) {
      int err = GetLastError();
      LogError(StringFormat(
          "CopyBuffer(value) failed. symbol=%s tf=%s shift=%d handle=%d copied=%d err=%d",
          symbol, EnumToString(tf), shift, handle, copied, err));
      ResetLastError();
      return false;
    }
    if (buffer_val[0] == EMPTY_VALUE) {
      LogError(StringFormat("Value buffer EMPTY_VALUE. symbol=%s tf=%s shift=%d",
                            symbol, EnumToString(tf), shift));
      return false;
    }
    return true;
#else
    return false;
#endif
  }

  bool GetColor(int shift, int &color_out) {
#ifdef __MQL5__
    if (!EnsureHandle()) {
      return false;
    }
    if (!BarsReady(shift)) {
      return false;
    }
    double buffer_col[];
    ArraySetAsSeries(buffer_col, true);
    int copied = CopyBuffer(handle, 1, shift, 1, buffer_col);
    if (copied < 1) {
      int err = GetLastError();
      LogError(StringFormat(
          "CopyBuffer(color) failed. symbol=%s tf=%s shift=%d handle=%d copied=%d err=%d",
          symbol, EnumToString(tf), shift, handle, copied, err));
      ResetLastError();
      return false;
    }
    if (buffer_col[0] == EMPTY_VALUE) {
      LogError(StringFormat("Color buffer EMPTY_VALUE. symbol=%s tf=%s shift=%d",
                            symbol, EnumToString(tf), shift));
      return false;
    }
    color_out = (int)MathRound(buffer_col[0]);
    return true;
#else
    color_out = -1;
    return false;
#endif
  }

  bool IsGreen(int shift) {
    int color_val = -1;
    return GetColor(shift, color_val) && color_val == 0;
  }

  bool IsRed(int shift) {
    int color_val = -1;
    return GetColor(shift, color_val) && color_val == 1;
  }
};

const string Indi_FFT_PhaseClock_ColorWave::INDICATOR_SHORTNAME =
    "IND-FFT_PhaseClock_CLOSE_SINFLIP_LEAD_v1.5_ColorWave";

#endif
