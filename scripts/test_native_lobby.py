import subprocess,pathlib,time,re,json,os,tempfile
root=pathlib.Path(__file__).resolve().parent.parent
base=pathlib.Path(tempfile.mkdtemp(prefix='skybreak-extra-'));(base/'work').mkdir()
engine=os.environ.get('GODOT_BIN',str(root/'.runtime/Godot.app/Contents/MacOS/Godot'))
logs=[];processes=[]
def launch(name,cmd,**kwargs):
 f=open(base/f'work/{name}.log','w');logs.append(f);p=subprocess.Popen(cmd,stdout=f,stderr=subprocess.STDOUT,**kwargs);processes.append(p);return p
try:
 env=dict(os.environ,PORT='3019',GAME_PORT_BASE='29730',GODOT_BIN=engine)
 service=launch('raw-lobby-server',['node','dist/index.js'],cwd=root/'backend',env=env);time.sleep(.8)
 host=launch('raw-lobby-host',[engine,'--headless','--path',str(root/'game'),'--','--online=http://127.0.0.1:3019','--create','--auto','--name=NativeHost','--seconds=19',f'--report={base}/work/raw-host.json'])
 code=''
 for i in range(70):
  text=(base/'work/raw-lobby-host.log').read_text();match=re.search(r'ROOM_CODE ([A-Z2-9]{6})',text)
  if match:code=match.group(1);break
  time.sleep(.1)
 assert code,(base/'work/raw-lobby-host.log').read_text()
 client=launch('raw-lobby-client',[engine,'--headless','--path',str(root/'game'),'--','--online=http://127.0.0.1:3019',f'--room={code}','--auto','--name=NativeJoin','--drop-lobby-at=5','--seconds=16',f'--report={base}/work/raw-client.json'])
 assert host.wait(timeout=28)==0;assert client.wait(timeout=10)==0
 reports={name:json.loads((base/f'work/raw-{name}.json').read_text()) for name in ['host','client']}
 for name,r in reports.items():
  assert r['local_id']>0 and r['metrics']['snapshots']>100,r
  assert r['room']==code,r
  assert len(r['players'])==2,r
  assert r['metrics']['shots']>20,r
  assert 'SCRIPT ERROR' not in (base/f'work/raw-lobby-{name}.log').read_text()
 (root/'docs/native-lobby-test-evidence.json').write_text(json.dumps(reports,indent=2))
 print('NATIVE SOCKET.IO TEST PASSED: two Godot lobby clients create/join/ready/start dedicated ENet, lobby reconnect keeps gameplay')
finally:
 for p in processes:
  if p.poll() is None:p.terminate()
 for f in logs:f.close()
