import numpy as np
import matplotlib.pyplot as plt

TVCO=1600;NMAX=1024;HALF=512
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

Ni,Fr=71,213
N=500;W=100
e,dl=mash(N+W,Fr);R=Ni+Fr/NMAX
es=e[2].astype(float)-HALF

idl=np.arange(N)*R*TVCO
act=np.cumsum((Ni+dl[W:W+N]).astype(float))*TVCO

c=np.zeros(N)
for i in range(2,N):
    c[i]=+(es[W+i]-2*es[W+i-1]+es[W+i-2])/NMAX*TVCO
cmp=act+c

# 找第一个 delta=1 的整数跳变附近
delta = dl[W:W+N]
jump = np.where(delta==1)[0]
if len(jump)>0:
    z = max(0,jump[0]-3)  # zoom start: 3 edges before first jump
else:
    z = 10

zoom = slice(z, z+15)

def clk_wave(edges, t_max, step=50):
    t=np.arange(0,t_max,step)
    y=np.ones_like(t)
    for e in edges:
        y[t>=e]*=-1
    return t,(y+1)/2

t_max = idl[zoom][-1]+idl[0]
ti,iy=clk_wave(idl[zoom],t_max,10)
ta,ay=clk_wave(act[zoom],t_max,10)
tc,cy=clk_wave(cmp[zoom],t_max,10)

fig,ax=plt.subplots(figsize=(18,6))
ax.plot(ti,iy+2.0,color='#2196F3',drawstyle='steps-post',linewidth=2.5,label='Ideal')
ax.plot(ta,ay+1.0,color='#FF5722',drawstyle='steps-post',linewidth=2.5,label='Actual')
ax.plot(tc,cy,color='#4CAF50',drawstyle='steps-post',linewidth=2.5,label='Compensated')

# 找出实际边沿偏离理想的区域
for i in range(z, z+15):
    err=act[i]-idl[i]
    if abs(err)>50:  # >50ps error
        ax.annotate(f'{err:.0f}ps', (idl[i],1.0),fontsize=7,color='#FF5722',rotation=90,ha='center')

ax.set_yticks([0.5,1.5,2.5])
ax.set_yticklabels(['Compensated','Actual','Ideal'])
ax.set_xlabel('Time (ps)')
ax.set_title(f'Integer Transition Zoom - R={Ni}+{Fr}/{NMAX}={R:.4f}')
ax.legend(loc='upper right')
ax.grid(True,alpha=0.2)
plt.tight_layout()
plt.savefig('dtc_zoom.png',dpi=150)
print(f"Chart: dtc_zoom.png")
print(f"\nZoom around edge {z}-{z+14}:")
print(f"{'edge':>5s} {'delta':>6s} {'ideal(ps)':>10s} {'actual(ps)':>10s} {'comp(ps)':>10s} {'err_raw':>8s} {'err_cmp':>8s}")
for i in range(z,z+15):
    print(f"{i:5d} {delta[i]:6d} {idl[i]:10.0f} {act[i]:10.0f} {cmp[i]:10.0f} {act[i]-idl[i]:8.0f} {cmp[i]-idl[i]:8.0f}")
plt.show()
