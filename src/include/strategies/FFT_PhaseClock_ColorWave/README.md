# Strategy FFT PhaseClock ColorWave

Strategy repo for EA31337 based on the custom indicator `IND-FFT_PhaseClock_CLOSE_SINFLIP_LEAD_v1.5_ColorWave`.
It reads the color buffer (0=green, 1=red), applies MTF confirmation, and trades two legs with reversal, partial, trailing, and break-even.

Signal-only variant: `Stg_FFT_PhaseClock_ColorWave_Signal` generates signals but lets the EA31337 core handle trade execution.
It exposes the main indicator tuning inputs (feed source, FFT size/window, bandpass, lead, and zero-phase options),
plus an optional guard to block new entries when a position is already open.

## Description

- Signal source: indicator buffer 1 (color index).
- MTF rule: Main TF H1 shift 0 + Confirm TF M30 shift 1.
- Entry only on color transition (red->green buy, green->red sell).
- Reverse behavior: netting uses 2x volume to flip, hedging falls back to close-and-reopen when needed.
- The indicator is configured as `indicator_separate_window` and draws two colors (green/red).

## Dependencies

- EA31337-classes (framework) available in `MQL5/Include/EA31337-classes`.
- Indicator installed/compiled in `MQL5/Indicators`:
  - `4EA-IND/IND-FFT_PhaseClock_CLOSE_SINFLIP_LEAD_v1.5_ColorWave.mq5`
    -> `4EA-IND/IND-FFT_PhaseClock_CLOSE_SINFLIP_LEAD_v1.5_ColorWave.ex5`.
  - The indicator short name is `FFT_PhaseClock_CLOSE_SINFLIP_LEAD_v1.5_ColorWave` (used for subwindow lookup).
- If your source is under `MQL5/Files/4EA/4EA-IND`, copy or junction that folder into `MQL5/Indicators/4EA-IND`.
- Indicator includes:
  - `spectralib/SpectralHilbert.mqh`.
- Optional feed indicator (if `FeedSource=FEED_INDICATOR`):
  - `Sandbox\Kalman3DRTS\Kalman3DRTSZeroPhase_v3.1` (default in indicator).

## Notes and assumptions

- The indicator input `OneValuePerBar` must be **false** for shift 0 to be valid. If it is true, bar 0 is treated as no signal and a log is printed.
- MQL4 is a stub (compiles but does not trade).

## Inputs (main)

- `FFT_IndicatorPath`: indicator path (no extension). Default: `4EA-IND\\IND-FFT_PhaseClock_CLOSE_SINFLIP_LEAD_v1.5_ColorWave`.
- `FFT_MainTF`, `FFT_ConfirmTF`, `FFT_MainShift`, `FFT_ConfirmShift`.
- `FFT_StopPips`, `FFT_BaseLot`, `FFT_Leg1LotMult`, `FFT_Leg2LotMult`.
- `FFT_TP1_R`, `FFT_TP2_R`, `FFT_PartialClose_R`, `FFT_PartialCloseFraction`.
- `FFT_EnableTrailing`, `FFT_TrailingDistancePips`, `FFT_TrailingStepPips`, `FFT_TrailingStartR`.
- `FFT_EnableBreakEven`, `FFT_BreakEvenTrigger_R`, `FFT_BreakEvenBufferPips`.
- `FFT_ReverseMode` (NETTING_STYLE or CLOSE_AND_REOPEN).
- `FFT_MaxSpread`, `FFT_MaxSlippage`.

## Inputs (indicator filters)

The strategy forwards the indicator inputs via `iCustom`. All parameters are prefixed with `FFT_Ind_` and mirror the
indicator defaults. This includes the peak window mode (`FFT_Ind_CausalWindow`), bandpass settings, zero-phase mode,
and stability filters. If you only need a few filters, you can leave the rest at default values.

## Backtest (MT5)

1. Copy the strategy repo folder into `MQL5/Experts` or your EA31337 strategies path.
2. Ensure `EA31337-classes` is available under `MQL5/Include`.
3. Install and compile the indicator `4EA-IND/IND-FFT_PhaseClock_CLOSE_SINFLIP_LEAD_v1.5_ColorWave` in `MQL5/Indicators`.
4. Open Strategy Tester:
   - Expert: `Stg_FFT_PhaseClock_ColorWave`.
   - Symbol: your target symbol.
   - Period: any (logic uses H1 and M30 internally).
   - If using EA31337-Libre: select `EA_Strategy=STRAT_FFT_PHASECLOCK_COLORWAVE`.
   - Signal-only variant: `EA_Strategy=STRAT_FFT_PHASECLOCK_COLORWAVE_SIGNAL`.
5. Verify logs:
   - `[Stg:FFT_PhaseClock_ColorWave]` for signal/trade management.
   - `[Indi:FFT_PhaseClock_ColorWave]` for indicator handle/CopyBuffer issues.

## References

- EA31337 input parameters: https://github.com/EA31337/EA31337/wiki/Input-parameters
- EA31337 discussion (indicator->strategy patterns): https://github.com/orgs/EA31337/discussions/389
