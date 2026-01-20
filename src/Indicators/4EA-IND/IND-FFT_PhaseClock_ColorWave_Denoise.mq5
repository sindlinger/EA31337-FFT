//+------------------------------------------------------------------+
//|  FFT PhaseClock ColorWave Denoise wrapper                         |
//|  Wraps IND-FFT_PhaseClock_CLOSE_SINFLIP_LEAD_v1.5_ColorWave        |
//|  and applies FFT denoise via external DLL.                         |
//+------------------------------------------------------------------+
#property strict
#property indicator_chart_window
#property indicator_plots 1
#property indicator_buffers 2

// ---- Inputs (must match original indicator parameter order) ----
input int              lag_preset = 0;
input int              feed_source = 0;
input int              atr_period = 17;
input ENUM_TIMEFRAMES  feed_indicator_tf = PERIOD_CURRENT;
input string           feed_indicator_name = "";
input int              feed_indicator_buffer = 0;
input int              fft_size = 65536;
input int              window_type = 1;
input double           kaiser_beta = 4.0;
input bool             causal_window = false;
input bool             remove_dc = false;
input int              pad_mode = 1;
input bool             one_value_per_bar = false;
input bool             apply_bandpass = true;
input int              cycle_bars = 52;
input double           bandwidth_pct = 200.0;
input int              band_shape = 1;
input int              output_mode = 0;
input bool             normalize_amp = false;
input double           phase_offset_deg = 315.0;
input double           lead_bars = 10.0;
input bool             lead_use_cycle_omega = true;
input double           lead_omega_smooth = 1000.0;
input int              lead_min_cycle_bars = 9;
input int              lead_max_cycle_bars = 0;
input bool             invert_output = true;
input bool             zero_phase_rt = true;
input int              forecast_mode = 0;
input int              forecast_reg_bars = 32;
input int              forecast_bars = 0;
input bool             show_forecast_line = false;
input int              forecast_draw_bars = 0;
input color            forecast_line_color = clrOrange;
input int              forecast_line_width = 1;
input bool             hold_phase_on_low_amp = true;
input double           low_amp_eps = 1e-9;
input bool             show_phase_clock = false;
input int              clock_x_offset = 110;
input int              clock_y_offset = 55;
input int              clock_radius = 26;
input bool             clock_show_ring_dots = true;
input int              clock_ring_dots_count = 60;
input int              clock_ring_dot_size = 10;
input color            clock_ring_color = clrSilver;
input bool             clock_show_numbers = true;
input int              clock_numbers_size = 10;
input color            clock_numbers_color = clrSilver;
input bool             clock_show_hand = true;
input int              clock_hand_segments = 9;
input int              clock_hand_dot_size = 12;
input color            clock_hand_color = clrRed;
input bool             clock_show_center_dot = true;
input int              clock_center_dot_size = 12;
input color            clock_center_color = clrWhite;
input bool             clock_show_text = true;

// ---- Denoise params (extra) ----
input bool   denoise_enable = true;         // Enable FFT denoise
input int    denoise_window_bars = 128;     // Window length (bars)
input double denoise_sigma = 1.0;           // PSD threshold multiplier
input int    denoise_future_bars = 0;       // Use future bars (lookahead)
input bool   denoise_color_from_value = true; // Recolor from denoised value

// Base indicator path (the original FFT indicator)
input string base_indicator_path = "IND-EA31337\\IND-FFT_PhaseClock_CLOSE_SINFLIP_LEAD_v1.5_ColorWave";

// ---- DLL import ----
#import "fft_denoise.dll"
int CausalFFT(const double &close[], int n, double sigma,
              double &ffilt_out[], int ffilt_len,
              double &closehat_out[], int closehat_len,
              double &next_hat_out);
#import

// ---- Internal state ----
int handle_src = INVALID_HANDLE;
string base_path = "";

double buf_val[];
double buf_col[];
double src_val[];
double src_col[];

double win[];
double ffilt[];
double closehat[];

int CreateSrcHandle(string path) {
  int h = iCustom(_Symbol, _Period, path,
                  lag_preset,
                  feed_source,
                  atr_period,
                  feed_indicator_tf,
                  feed_indicator_name,
                  feed_indicator_buffer,
                  fft_size,
                  window_type,
                  kaiser_beta,
                  causal_window,
                  remove_dc,
                  pad_mode,
                  one_value_per_bar,
                  apply_bandpass,
                  cycle_bars,
                  bandwidth_pct,
                  band_shape,
                  output_mode,
                  normalize_amp,
                  phase_offset_deg,
                  lead_bars,
                  lead_use_cycle_omega,
                  lead_omega_smooth,
                  lead_min_cycle_bars,
                  lead_max_cycle_bars,
                  invert_output,
                  zero_phase_rt,
                  forecast_mode,
                  forecast_reg_bars,
                  forecast_bars,
                  show_forecast_line,
                  forecast_draw_bars,
                  forecast_line_color,
                  forecast_line_width,
                  hold_phase_on_low_amp,
                  low_amp_eps,
                  show_phase_clock,
                  clock_x_offset,
                  clock_y_offset,
                  clock_radius,
                  clock_show_ring_dots,
                  clock_ring_dots_count,
                  clock_ring_dot_size,
                  clock_ring_color,
                  clock_show_numbers,
                  clock_numbers_size,
                  clock_numbers_color,
                  clock_show_hand,
                  clock_hand_segments,
                  clock_hand_dot_size,
                  clock_hand_color,
                  clock_show_center_dot,
                  clock_center_dot_size,
                  clock_center_color,
                  clock_show_text);
  if (h == INVALID_HANDLE) {
    int err = GetLastError();
    ResetLastError();
    // Fallback: try default params (base indicator defaults).
    h = iCustom(_Symbol, _Period, path);
    if (h != INVALID_HANDLE) {
      PrintFormat("[IND-FFT-Denoise] Fallback to default params for base indicator. err=%d path=%s", err, path);
    }
  }
  return h;
}

int EnsureSrcHandle() {
  if (handle_src != INVALID_HANDLE) return handle_src;
  base_path = base_indicator_path;
  if (base_path == "") {
    base_path = "IND-EA31337\\IND-FFT_PhaseClock_CLOSE_SINFLIP_LEAD_v1.5_ColorWave";
  }
  handle_src = CreateSrcHandle(base_path);
  if (handle_src != INVALID_HANDLE) return handle_src;

  string alt_path = base_path;
  string alt_path_4ea = base_path;
  if (StringFind(base_path, "\\") < 0 && StringFind(base_path, "/") < 0) {
    alt_path = "Strategy-FFT_PhaseClock_ColorWave\\" + base_path;
    alt_path_4ea = "4EA-IND\\" + base_path;
  }
  if (alt_path != base_path) {
    handle_src = CreateSrcHandle(alt_path);
    if (handle_src != INVALID_HANDLE) return handle_src;
  }
  if (alt_path_4ea != base_path && alt_path_4ea != alt_path) {
    handle_src = CreateSrcHandle(alt_path_4ea);
    if (handle_src != INVALID_HANDLE) return handle_src;
  }
  if (base_path != "4EA-IND\\IND-FFT_PhaseClock_CLOSE_SINFLIP_LEAD_v1.5_ColorWave") {
    handle_src = CreateSrcHandle("4EA-IND\\IND-FFT_PhaseClock_CLOSE_SINFLIP_LEAD_v1.5_ColorWave");
    if (handle_src != INVALID_HANDLE) return handle_src;
  }
  return INVALID_HANDLE;
}

int OnInit() {
  SetIndexBuffer(0, buf_val, INDICATOR_DATA);
  SetIndexBuffer(1, buf_col, INDICATOR_COLOR_INDEX);
  PlotIndexSetInteger(0, PLOT_DRAW_TYPE, DRAW_COLOR_LINE);
  PlotIndexSetInteger(0, PLOT_COLOR_INDEXES, 2);
  PlotIndexSetInteger(0, PLOT_LINE_COLOR, 0, clrLime);
  PlotIndexSetInteger(0, PLOT_LINE_COLOR, 1, clrRed);
  IndicatorSetString(INDICATOR_SHORTNAME, "FFT PhaseClock Denoise");

  ArraySetAsSeries(buf_val, true);
  ArraySetAsSeries(buf_col, true);

  if (EnsureSrcHandle() == INVALID_HANDLE) {
    Print("[IND-FFT-Denoise] Failed to create source indicator handle.");
    return INIT_FAILED;
  }
  return INIT_SUCCEEDED;
}

int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[]) {
  if (EnsureSrcHandle() == INVALID_HANDLE) return 0;

  if (rates_total <= 0) return 0;

  ArrayResize(src_val, rates_total);
  ArrayResize(src_col, rates_total);
  ArraySetAsSeries(src_val, true);
  ArraySetAsSeries(src_col, true);

  int copied_val = CopyBuffer(handle_src, 0, 0, rates_total, src_val);
  if (copied_val <= 0) return 0;
  int copied_col = CopyBuffer(handle_src, 1, 0, rates_total, src_col);

  if (!denoise_enable) {
    for (int i = 0; i < rates_total; ++i) {
      buf_val[i] = src_val[i];
      if (copied_col > 0) {
        buf_col[i] = src_col[i];
      } else {
        buf_col[i] = (src_val[i] >= 0.0 ? 0.0 : 1.0);
      }
    }
    return rates_total;
  }

  int W = denoise_window_bars;
  if (W < 4) W = 4;
  int F = denoise_future_bars;
  if (F < 0) F = 0;
  if (F >= W) F = W - 1;

  if (ArraySize(win) != W) {
    ArrayResize(win, W);
    ArrayResize(ffilt, W);
    ArrayResize(closehat, W);
  }

  int last = rates_total - W + F;
  for (int i = 0; i < rates_total; ++i) {
    if (i < F || i > last || src_val[i] == EMPTY_VALUE) {
      buf_val[i] = src_val[i];
      if (copied_col > 0) {
        buf_col[i] = src_col[i];
      } else {
        buf_col[i] = (src_val[i] >= 0.0 ? 0.0 : 1.0);
      }
      continue;
    }

    for (int j = 0; j < W; ++j) {
      int shift = (i - F) + (W - 1 - j);
      win[j] = src_val[shift];
    }

    double next_hat = 0.0;
    int rc = CausalFFT(win, W, denoise_sigma, ffilt, W, closehat, W, next_hat);
    if (rc != 0) {
      buf_val[i] = src_val[i];
      if (copied_col > 0) {
        buf_col[i] = src_col[i];
      } else {
        buf_col[i] = (src_val[i] >= 0.0 ? 0.0 : 1.0);
      }
      continue;
    }

    int idx = W - 1 - F;
    double v = closehat[idx];
    buf_val[i] = v;
    if (denoise_color_from_value) {
      buf_col[i] = (v >= 0.0 ? 0.0 : 1.0);
    } else if (copied_col > 0) {
      buf_col[i] = src_col[i];
    } else {
      buf_col[i] = (v >= 0.0 ? 0.0 : 1.0);
    }
  }

  return rates_total;
}
