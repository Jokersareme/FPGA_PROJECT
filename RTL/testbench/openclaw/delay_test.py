import numpy as np
TVCO=1600;NMAX=1024;HALF=512
def mash(n,f,w=10):
    m=(1<<w)-1
    s1=s2=s3=0;y2d=y3d=y3dd=0
    e=np.zeros((3,n),dtype=np.int32);dl=np.zeros(n,dtype=np.int32)
    for i in range(n):
        s1=f+(s1&m)-((s1>>w)&1);e[0,i]=s1&m;y1=(s1>>w)&1
        s2=e[0,i]+(s2&m)-((s2>>w)&1);e[1,i]=s2&m;y2=(s2>>w)&1
        s3=e[1,i]+(s3&m)-((s3>>w)&1);e[2,i]=s3&m;y3=(s3>>w)&1
        dl[i]=y1+(y2-y2d)+(y3-2*y3d+y3dd)
        y2d=y2;y3dd=y3d;y3d=y3
    return e,dl

for Ni,Fr in [(50,128),(50,256),(50,384),(50,512),(71,213)]:
    e,dl=mash(10000,Fr);R=Ni+Fr/NMAX
    idl=np.arange(10000)*R*TVCO
    act=np.cumsum(Ni+dl.astype(float))*TVCO
    raw=np.std((act-idl)[300:])
    es=e[2].astype(float)-HALF
    c=np.zeros(10000)
    for i in range(2,10000):
        c[i]=+(es[i]-2*es[i-1]+es[i-2])/NMAX*TVCO
    r=[raw]
    for d in range(4):
        s=np.roll(c,d);s[:d]=0
        r.append(np.std((act+s-idl)[300:]))
    print(f"{Ni}+{Fr}/1024  raw={r[0]:.0f}  d0={r[1]:.0f}  d1={r[2]:.0f}  d2={r[3]:.0f}  d3={r[4]:.0f}")
