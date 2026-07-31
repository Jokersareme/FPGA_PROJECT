# eo_jitter_v2.py — 正确对齐 pipeline 后的抖动分析
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

def sim_correct(eo_start, eo_sel, gain=50):
    '''正确对齐: 边沿 N 的周期误差来自 ds[N-1] (经过delta_sigma_d1+p_counter)
       补偿边沿 N 用 c3 来自跟 ds[N-1] 同周期的 e3'''
    comp=np.zeros(n)
    e3p=[0]*10; Ec=[0,0,0]
    c3_at_negedge=[0,0,0]  # c3 在 negedge 的值
    
    for i in range(1,n):
        e3p=[es3[i-1]]+e3p[:-1]  # e3p[0]=es3[i-1]
        
        # 计算当前 negedge 的 comp_3rd
        if eo_start==0:
            c3=e3p[0]-2*e3p[1]+e3p[2]  # r1: es3[i-1]-2*es3[i-2]+es3[i-3]
        else:
            c3=e3p[1]-2*e3p[2]+e3p[3]  # r2: es3[i-2]-2*es3[i-3]+es3[i-4]
        
        # E_combined at negedge
        if eo_sel==0: ec=c3
        elif eo_sel==1: Ec=[c3]+Ec[:-1]; ec=Ec[0]
        elif eo_sel==2: Ec=[c3]+Ec[:-1]; ec=Ec[1]
        else: Ec=[c3]+Ec[:-1]; ec=Ec[2]
        
        # ec 在 negedge i 可用
        # dtc_code_pipe 在 posedge i 锁存
        # dtc_code_d1 在 negedge dtc_out 锁存
        # DTC 延迟下一个 Fout 边沿
        
        # 边沿 i 的周期来自 ds[i-1] (MASH在posedge i-1, affect周期i-1->i)
        # 边沿 i 的补偿来自 ec at negedge i-1 (上一negedge的数据)
        # ec at negedge i-1 来自 c3 at negedge i-1
        
        if i==1: comp[i]=0
        else:
            # edge i 用 ec 来自 negedge i-1
            # 但我用 c3 at negedge i-2... 因为还有 pipeline
            # 实际: ec at negedge i-1 -> posedge i dtc_code_pipe 
            # -> negedge dtc_out dtc_code_d1 -> 延迟边沿 i+1
            code=int(prev_ec*gain/2048)+256
            code=max(0,min(511,code))
            comp[i]=code*20  # 延迟边沿 i
        prev_ec=ec
        prev_c3=c3
    
    edge=actual+comp
    pj=np.diff(edge)-Tref
    s=np.std(pj[warm:]-np.mean(pj[warm:]))
    return s

print("抖动分析 (正确 pipeline 对齐):")
print(f"{'配置':>15} {'gain=50':>10} {'gain=100':>10} {'gain=150':>10} {'gain=200':>10}")
print("-" * 55)
for label,es,esel in [('r1+eo0',0,0),('r1+eo1',0,1),('r2+eo0',1,0),('r2+eo1',1,1)]:
    vals=[]
    for g in [50,100,150,200]:
        s=sim_correct(es,esel,g)
        vals.append(s)
    print(f"{label:>15} {vals[0]:>10.1f} {vals[1]:>10.1f} {vals[2]:>10.1f} {vals[3]:>10.1f}")
print(f"\n无补偿: {ref:.1f}ps")
