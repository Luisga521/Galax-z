"""Fetch the Salamander Grand Piano V3 samples build_pack.py needs (CC BY 3.0): get_samples.py DIR 13
(other layer numbers, 1-16, can follow: 4 7 9 11 15 were used to fit the velocity response)."""
import urllib.request,ssl,sys,os,concurrent.futures as cf,urllib.parse,time
ctx=ssl.create_default_context(); ctx.load_verify_locations('/etc/ssl/cert.pem')
out=sys.argv[1]; os.makedirs(out,exist_ok=True)
B='https://raw.githubusercontent.com/sfzinstruments/SalamanderGrandPiano/master/'
def g(u):
    for k in range(4):
        try: return urllib.request.urlopen(urllib.request.Request(u,headers={'User-Agent':'py'}),timeout=120,context=ctx).read()
        except Exception as e: err=e; time.sleep(2)
    raise err
lic=g(B+'LICENSE').decode('utf8','replace'); print(lic[:300].replace('\n',' ')); open(out+'/LICENSE','w').write(lic)
notes=[]
for m in range(21,109,3):
    notes.append(['C','C#','D','D#','E','F','F#','G','G#','A','A#','B'][m%12]+str(m//12-1))
def one(a):
    n,v=a; f=f'{n}v{v}.flac'; p=f'{out}/{f}'
    if os.path.exists(p) and os.path.getsize(p)>10000: return f,0
    d=g(B+'Samples/'+urllib.parse.quote(f)); open(p,'wb').write(d); return f,len(d)
jobs=[(n,v) for v in map(int,sys.argv[2:]) for n in notes]
tot=0;bad=[]
with cf.ThreadPoolExecutor(8) as ex:
    fs={ex.submit(one,j):j for j in jobs}
    for f in cf.as_completed(fs):
        try: tot+=f.result()[1]
        except Exception as e: bad.append((fs[f],str(e)))
print(len(jobs),tot,bad[:10])
