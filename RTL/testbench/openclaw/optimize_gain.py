"""
Find optimal DTC gain (I2) - fixed analysis
Key insight: spreadsheet J = D + H*I has NO constant offset (MID)
So the systematic offset needs separate treatment
"""
import openpyxl
import numpy as np

wb = openpyxl.load_workbook(
    r"D:\GS\项目\FPGA\xcvu9p-flga2104-2L-e\fpga_pll_mash111_dtc_ssc\RTL\testbench\openclaw\dbg.xlsx",
    data_only=True
)
ws = wb['Sheet1']

F = np.array([ws.cell(r, 6).value for r in range(3, 25)])
H = np.array([ws.cell(r, 8).value for r in range(3, 25)])
D = np.array([ws.cell(r, 4).value for r in range(3, 25)])
B = np.array([ws.cell(r, 2).value for r in range(3, 25)])

print("Data analysis:")
print(f"  F range: {F.min():.1f} to {F.max():.1f}, mean={F.mean():.1f}, std={F.std():.1f}")
print(f"  H range: {H.min():.0f} to {H.max():.0f}")
print(f"  Correlation F,H: {np.corrcoef(F, H)[0,1]:.3f}")

# The period jitter after DTC = M[n] - 802
# M[n] = J[n] - J[n-1] = (D[n]-D[n-1]) + I*(H[n]-H[n-1])
# Ideal period = 802ps (B[n]-B[n-1])

# For DTC to cancel period jitter:
# Want (D[n]-D[n-1]) + I*(H[n]-H[n-1]) = 802
# I*(H[n]-H[n-1]) = 802 - (D[n]-D[n-1])

# Compute from data:
dD = np.diff(D)  # actual periods
dH = np.diff(H)  # MASH deltas
target = 802 - dD  # desired compensation per period

print(f"\nDelta analysis:")
print(f"  Delta-D range: {dD.min():.1f} to {dD.max():.1f}, mean={dD.mean():.1f}")
print(f"  Delta-H range: {dH.min():.0f} to {dH.max():.0f}")
print(f"  Target(I*dH) range: {target.min():.1f} to {target.max():.1f}")

# Optimal I: minimize sum((I*dH - target)^2)
# I = sum(target * dH) / sum(dH^2)
I_opt = np.sum(target * dH) / np.sum(dH * dH)
print(f"\nOptimal I (period-based): I = {I_opt:.3f}")

# Alternative: minimize RMS of K = F - H*I with offset
# K = F - H*I, but F has systematic offset ~ -538.8
# Better model: F = C + H*I (where C = constant offset)
# K = F - C - H*I (residual after removing constant + modulated comp)

# Find I that minimizes var(K) where C = mean(F - H*I)
# Equivalent to: minimize var(F - H*I)
# I = cov(F, H) / var(H)
I_var = np.cov(F, H)[0,1] / np.var(H)
print(f"\nOptimal I (minimize variance of F-H*I): I = {I_var:.3f}")

# Scan I and show metrics
def metrics(I):
    J = D + H * I
    K = F - H * I  # residual jitter
    M = np.diff(J, prepend=J[0])[1:]  # period
    return {
        'RMS_K': np.std(K),
        'mean_K': np.mean(K),
        'mean_M': np.mean(M),
        'std_M': np.std(M),
        'M25': np.mean(M),
    }

print(f"\n=== Gain scan ===")
for I_test in np.arange(-2.0, 3.01, 0.1):
    m = metrics(I_test)
    print(f"  I={I_test:+5.2f}:  RMS_K={m['RMS_K']:6.1f}  mean_K={m['mean_K']:7.1f}  M25={m['M25']:7.1f}  std_M={m['std_M']:6.1f}")

# More refined scan around the minimum
print(f"\n=== Fine scan around optimum ===")
best_rms_K = 1e9
best_I_K = 0
for I_test in np.arange(-0.5, 1.51, 0.01):
    m = metrics(I_test)
    if m['RMS_K'] < best_rms_K:
        best_rms_K = m['RMS_K']
        best_I_K = I_test

print(f"Best I for RMS_K: I = {best_I_K:.3f} (RMS_K = {best_rms_K:.1f}ps)")

# Also check specific I values that were mentioned
print(f"\n=== Specific candidates ===")
for I_test in [0, 0.68, 0.99, 1.0, 1.03, 1.07, 1.1, 2.09]:
    m = metrics(I_test)
    print(f"  I={I_test:5.2f}:  RMS_K={m['RMS_K']:6.1f}  mean_K={m['mean_K']:7.1f}  M25={m['M25']:7.1f}  std_M={m['std_M']:6.1f}")

# Hardware mapping
print(f"\n=== Hardware gain ===")
print(f"Spreadsheet I -> HW gain = I * 2048 / 20 = I * 102.4")
for I_test in [best_I_K, I_opt, I_var, 0.68, 1.0, 1.03, 1.07]:
    hw = I_test * 102.4
    print(f"  I={I_test:.3f} -> hw_gain={hw:.0f}")

wb.close()
