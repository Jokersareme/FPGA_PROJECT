"""
Summary analysis for dbg.xlsx - find optimal I for M25
"""
import openpyxl, numpy as np

wb = openpyxl.load_workbook(
    r"D:\GS\项目\FPGA\xcvu9p-flga2104-2L-e\fpga_pll_mash111_dtc_ssc\RTL\testbench\openclaw\dbg.xlsx",
    data_only=True
)
ws = wb['Sheet1']

F = np.array([ws.cell(r, 6).value for r in range(3, 25)])
H = np.array([ws.cell(r, 8).value for r in range(3, 25)])
D = np.array([ws.cell(r, 4).value for r in range(3, 25)])

def get_M25(I):
    J = D + H * I
    M = np.diff(J)
    return np.mean(M)

print("=" * 60)
print("  dbg.xlsx DTC Gain Optimization")
print("=" * 60)
print()
print("Raw data:")
print(f"  F (actual jitter) = {F.mean():.1f} +/- {F.std():.1f} ps")
print(f"  H (MASH eo) range: {H.min():.0f} ~ {H.max():.0f}")
print(f"  Correlation F,H: {np.corrcoef(F,H)[0,1]:.3f}")
print()
print(f"Current I=1.00: M25 = {get_M25(1.0):.1f} (ideal=802)")
print()

# Scan I to find M25 closest to 802
best = (1e9, None)
for I in np.arange(-0.5, 3.0, 0.001):
    m25 = get_M25(I)
    if abs(m25 - 802) < abs(best[0] - 802):
        best = (m25, I)

print(f"Best I (M25 closest to 802): I = {best[1]:.3f}")
print(f"  M25 = {best[0]:.1f}")

# RMS minimization
def get_rms_K(I):
    K = F - H * I
    return np.std(K)

best_rms = (1e9, None)
for I in np.arange(-0.5, 3.0, 0.001):
    rms = get_rms_K(I)
    if rms < best_rms[0]:
        best_rms = (rms, I)

print(f"Best I (min RMS residual jitter): I = {best_rms[1]:.3f}")
print(f"  RMS residual = {best_rms[0]:.1f} ps")
print()

# Hardware mapping
print("Hardware gain mapping:")
print("  J = D + H*I (sheet) implies:")
print("    H * I = (H * hw_gain >> 11) * TAP")
print("    I = hw_gain * 20 / 2048 = hw_gain / 102.4")
print()

# Key insight
print("Key finding:")
print("  F and H have NEGATIVE correlation (-0.707)")
print("  MASH error H goes opposite to actual jitter F")
print("  So the DTC compensation direction is correct")
print("  BUT: H ranges -1536~1280 while F ranges -555~-529")
print("  H is ~100x larger in magnitude than F's variation")
print()
print("  Without MID offset (256 taps = 5120ps baseline),")
print("  any non-zero I adds huge jitter instead of removing it.")
print("  I=0 avoids this, but then you get no DTC benefit either.")
print()
print("  Your spreadsheet needs MID offset:")
print("    J = D + 5120 + H * I")
print("    With I = 1.56 (hw_gain = 160)")

wb.close()
