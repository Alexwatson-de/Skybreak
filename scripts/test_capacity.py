import subprocess,pathlib,time,json,os,tempfile
root=pathlib.Path(__file__).resolve().parent.parent
base=pathlib.Path(tempfile.mkdtemp(prefix='skybreak-extra-'));(base/'work').mkdir()
wire=os.environ.get('GAME_TRANSPORT','enet')
engine=os.environ.get('GODOT_BIN',str(root/'.runtime/Godot.app/Contents/MacOS/Godot'));evidence={}
for arena in range(6):
 ps=[];files=[]
 roster=[dict(id=i+1,name=f'Pilot{i+1}',team=i%2,char=i%4,token=f'capacity-{i}') for i in range(8)]
 (base/'work/capacity-roster.json').write_text(json.dumps(roster))
 def run(name,flags):
  f=open(base/f'work/cap-{name}.log','w');files.append(f)
  p=subprocess.Popen([engine,'--headless','--path',str(root/'game'),'--',*flags,f'--report={base}/work/cap-{name}.json'],stdout=f,stderr=subprocess.STDOUT);ps.append(p)
 run(f'server-{arena}',['--server',f'--transport={wire}',f'--port={29810+arena}',f'--map={arena}','--mode=1',f'--roster={base}/work/capacity-roster.json','--seconds=16'])
 time.sleep(.8)
 for i in range(8):
  run(f'{arena}-{i}', ([f'--websocket=ws://127.0.0.1:{29810+arena}'] if wire=='websocket' else ['--join=127.0.0.1',f'--port={29810+arena}'])+[f'--token=capacity-{i}','--auto','--seconds=12'])
 for p in ps:assert p.wait(timeout=35)==0
 for f in files:f.close()
 server=json.loads((base/f'work/cap-server-{arena}.json').read_text())
 assert server['metrics']['max_snapshot_bytes']<1300,server
 for i in range(8):
  client=json.loads((base/f'work/cap-{arena}-{i}.json').read_text());assert client['local_id']==i+1;assert len(client['players'])==8;assert client['metrics']['snapshots']>50
  log=(base/f'work/cap-{arena}-{i}.log').read_text();assert 'SCRIPT ERROR' not in log,log;assert 'above the MTU' not in log,log
 evidence[str(arena)]=server
 print('CAPACITY PASSED arena',arena,'transport',wire,'max payload',server['metrics']['max_snapshot_bytes'],flush=True)
(root/f'docs/capacity-{wire}-test-evidence.json').write_text(json.dumps(evidence,indent=2))
