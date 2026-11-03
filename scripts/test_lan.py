import subprocess,time,pathlib,json,os,tempfile
root=pathlib.Path(__file__).resolve().parent.parent
base=pathlib.Path(tempfile.mkdtemp(prefix='skybreak-lan-'));(base/'work').mkdir()
engine=os.environ.get('GODOT_BIN',str(root/'.runtime/Godot.app/Contents/MacOS/Godot'))
processes=[];handles=[]
def run(name,flags):
 f=open(base/f'work/lan-{name}.log','w');handles.append(f)
 p=subprocess.Popen([engine,'--headless','--path',str(root/'game'),'--',*flags,f'--report={base}/work/lan-{name}.json'],stdout=f,stderr=subprocess.STDOUT);processes.append(p);return p
h=run('host',['--host','--port=29802','--map=2','--mode=1','--bots=1','--auto','--start-after=5','--seconds=17'])
time.sleep(.8)
s=run('scan',['--scan','--seconds=2']);s.wait(timeout=5)
scan=json.loads((base/'work/lan-scan.json').read_text());assert scan['discovered'],'LAN discovery failed'
a=run('a',['--join=127.0.0.1','--port=29802','--auto','--name=LanAlpha','--seconds=12'])
b=run('b',['--join=127.0.0.1','--port=29802','--auto','--name=LanBravo','--seconds=12'])
for p in processes:assert p.wait(timeout=25)==0
for f in handles:f.close()
reports={name:json.loads((base/f'work/lan-{name}.json').read_text()) for name in ['host','scan','a','b']}
for name in ['a','b']:
 r=reports[name];assert r['phase']=='match';assert len(r['players'])==4;assert r['metrics']['snapshots']>100;assert r['metrics']['shots']>0
for name in ['host','a','b']:
 log=(base/f'work/lan-{name}.log').read_text();assert 'SCRIPT ERROR' not in log,log;assert 'above the MTU' not in log,log
(root/'docs/lan-test-evidence.json').write_text(json.dumps(reports,indent=2))
print('LAN TEST PASSED: UDP discovery, host + 2 native clients + bot, TDM, readiness, snapshots, shooting')
