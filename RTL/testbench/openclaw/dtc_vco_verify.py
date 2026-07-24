import numpy as np
TVCO=1600.0;NMAX=1024;HALF=512
DTC_RES=0.1  # ps per code step (高精度)

def mash(n,f,w=10):
    m=(1<<w)-1;s1=s2=s3=0;y2d=y3d=y3dd=0
    e=np.zeros((3,n),dtype=np.int32);dl=np.zeros(n,dtype=np.int32)
    for i in range(n):
        s1=f+(s1&m)-((s1>>w)&1);e[0,i]=s1&m;y1=(s1>>w)&1
        s2=e[0,i]+(s2&m)-((s2>>w)&1);e[1,i]=s2&m;y2=(s2>>w)&1
        s3=e[1,i]+(s3&m)-((s3>>w)&1);e[2,i]=s3&m;y3=(s3>>w)&1
        dl[i]=y1+(y2-y2d)+(y3-2*y3d+y3dd)
        y2d=y2;y3dd=y3d;y3d=y3
    return e,dl

N=5000;W=300
# 不同 DTC tap 分辨率
resolutions=[10.0, 1.0, 0.1, 0.01]

print(f"DTC补偿验证 - N=5000, 预热{W}拍")
print(f"VCO周期={TVCO}ps, 1分数步={TVCO/NMAX:.4f}ps")
print(f"DTC分辨率从 10ps/tap 到 0.01ps/tap")
print()

for Ni,Fr in [(50,128),(50,256),(50,384),(50,512),(71,213)]:
    e,dl=mash(N,Fr);R=Ni+Fr/NMAX
    idl=np.arange(N)*R*TVCO
    act=np.cumsum(Ni+dl.astype(float))*TVCO
    raw=act-idl
    es=e[2].astype(float)-HALF
    c=np.zeros(N)
    for i in range(2,N):
        diff2=es[i]-2*es[i-1]+es[i-2]
        c[i]=+diff2/NMAX*TVCO  # 理论补偿量(ps)
    
    rs=np.std(raw[W:]);rp=np.ptp(raw[W:])
    
    out=f"{Ni}+{Fr}/1024  raw_std={rs:.1f} raw_pp={rp:.1f}"
    for res in resolutions:
        # 量化到 DTC tap 分辨率
        c_q=np.round(c/res)*res  # 量化
        cmp=act+c_q-idl
        cs=np.std(cmp[W:]);cp=np.ptp(cmp[W:])
        out+=f"  {res:5.2f}ps: {cs:.1f}({rs/cs:.2f}x)"
    print(out)
