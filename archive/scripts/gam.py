T=[(0,0,0,0),(0.0166,-0.0807,0.2227,-0.0751),(0.0350,-0.1760,0.4325,-0.1370),(0.0543,-0.2821,0.6302,-0.1876),(0.0739,-0.3963,0.8167,-0.2287),(0.0933,-0.5161,0.9926,-0.2616),(0.1121,-0.6395,1.1588,-0.2877),(0.1300,-0.7649,1.3159,-0.3080),(0.1469,-0.8911,1.4644,-0.3234),(0.1627,-1.0170,1.6051,-0.3347),(0.1773,-1.1420,1.7385,-0.3426),(0.1908,-1.2652,1.8650,-0.3476),(0.2031,-1.3864,1.9851,-0.3501)]
n13=0x10000/(255*255)*4; n24=0x100/255*4
def g(gamma):
    i=min(max(int(gamma*10+0.5),10),22)-10
    r=T[i]; return (n13*r[0]/4,n24*r[1]/4,n13*r[2]/4,n24*r[3]/4)
def corr(a,f,gamma):
    x=g(gamma); return a+a*(1-a)*((x[0]*f+x[1])*a+(x[2]*f+x[3]))
def ec(a,k): return a*(k+1)/(a*k+1)
def lightadj(k,c): 
    L=0.30*c[0]+0.59*c[1]+0.11*c[2]; return k*min(max(4*(0.75-L),0),1)
print("g(1.8)",g(1.8))
for f in (0.0,0.5,0.847,0.86,1.0):
  print("f=%.3f"%f, " ".join("g%.1f:%.3f"%(gm,corr(0.5,f,gm)) for gm in (1.0,1.2,1.4,1.8,2.2)))
print("crossover f where correction zero at a=0.5:")
for gm in (1.2,1.4,1.8,2.2):
  x=g(gm); 
  # (x0 f + x1)*0.5 + x2 f + x3 = 0 -> f = -(0.5x1+x3)/(0.5x0+x2)
  print(gm, -(0.5*x[1]+x[3])/(0.5*x[0]+x[2]))
c=(220/255,220/255,204/255); print("DCDCCC lightness adj k=1:",lightadj(1,c), "intensity", 0.25*c[0]+0.5*c[1]+0.25*c[2])
for gray in (0.5,0.6,0.7,0.75,0.8):
  print("gray",gray, lightadj(1.0,(gray,)*3))
# full grayscale pipeline for a range of a, black-on-white and DCDCCC
for a in (0.25,0.5,0.75):
  for gm in (1.2,1.4,1.8,2.2):
    for k in (0.0,1.0,2.5):
      print("a",a,"gm",gm,"k",k,"black:",round(corr(ec(a,lightadj(k,(0,0,0))),0,gm),3),"DCDCCC:",round(corr(ec(a,lightadj(k,c)),0.847,gm),3), "white:",round(corr(ec(a,lightadj(k,(1,1,1))),1,gm),3))
print("=== full pipeline a=0.5 (grayscale model; ClearType uses per-channel f) ===")
cols={'black':(0,0,0),'grey808080':(128/255,)*3,'DCDCCC':(220/255,220/255,204/255),'white':(1,1,1)}
for name,c in cols.items():
    f=0.25*c[0]+0.5*c[1]+0.25*c[2]
    for k in (0.0,0.5,1.0,2.0,3.0):
        print(name,"k=%.1f"%k," ".join("g%.1f:%.3f"%(gm,corr(ec(0.5,lightadj(k,c)),f,gm)) for gm in (1.0,1.4,1.8,2.2)))
print("gamma>2.2 clamps:", g(2.2)==g(3.0))
