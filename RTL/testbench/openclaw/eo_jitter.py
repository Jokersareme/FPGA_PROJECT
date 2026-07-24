# eo_jitter.py — 计算 eo_start + eo_sel 不同组合下的时钟抖动
import numpy as np
TVCO=1600; N_MAX=1024; HALF=512; W=10; Nint=71; Frac=213; Tref=(Nint+Frac/N_MAX)*TVCO
n=5000; warm=50

def efm(frac,n):
    mask=(1<<W)-1;sr=0;y=np.zeros(n,dtype=np.int32);e=np.zeros(n,dtype=np.int32)
    for i in range(n):
        f=int(frac[i]) if hasattr(frac,'__len__') else int(frac)
        s=f+(sr&mask)-((sr>>W)&1);sr=s&((1<<(W+1))-1);e[i]=sr&mask;y[i]=(sr>>W)&1
    return y,e

y1,e1=efm(Frac,n);y2,e2=efm(e1,n);y3,e3=efm(e2,n)
y2d=np.roll(y2,1);y2d[0]=0;y3d=np.roll(y3,1);y3d[0]=0;y3dd=np.roll(y3,2);y3dd[0:2]=0
ds=y1+(y2-y2d)+(y3-2*y3d+y3dd)
actual=np.cumsum((Nint+ds).astype(np.float64))*TVCO
es3=e3.astype(np.float64)-HALF
ref=2026.21

def sim(eo_start, eo_sel, gain=50):
    comp=np.zeros(n);prev_c=0
    e3p=[0]*10; Ec=[0,0,0]
    for i in range(1,n):
        e3p=[es3[i-1]]+e3p[:-1]
        if eo_start==0:
            c3=e3p[0]-2*e3p[1]+e3p[2]
        else:
            c3=e3p[1]-2*e3p[2]+e3p[3]
        if eo_sel==0: ec=c3
        elif eo_sel==1: Ec=[c3]+Ec[:-1]; ec=Ec[0]
        elif eo_sel==2: Ec=[c3]+Ec[:-1]; ec=Ec[1]
        else: Ec=[c3]+Ec[:-1]; ec=Ec[2]
        if i==1: comp[i]=0
        else:
            code=int(prev_ec*gain/2048)+256
            code=max(0,min(511,code))
            comp[i]=code*20
        prev_ec=ec
    edge=actual+comp
    pj=np.diff(edge)-Tref
    s=np.std(pj[warm:]-np.mean(pj[warm:]))
    return s

print("时钟抖动对比 (std ps):")
print(f"{'配置':>15} {'gain=50':>10} {'gain=100':>10} {'gain=150':>10} {'gain=200':>10} {'gain=300':>10} {'best':>10}")
print("-" * 75)

for label, eo_start, eo_sel in [("r1+eo0",0,0),("r1+eo1",0,1),("r2+eo0",1,0),("r2+eo1",1,1)]:
    best=(99999,0)
    vals=[]
    for g in [50,100,150,200,300]:
        s=sim(eo_start,eo_sel,g)
        vals.append(s)
        if s<best[0]: best=(s,g)
    print(f"{label:>15} {vals[0]:>10.1f} {vals[1]:>10.1f} {vals[2]:>10.1f} {vals[3]:>10.1f} {vals[4]:>10.1f} gain={best[1]:>3} std={best[0]:.1f}")

print()
print(f"无补偿: {ref:.1f}ps")
print(f"参考PY(0-lag): 2.0ps (998x)")
