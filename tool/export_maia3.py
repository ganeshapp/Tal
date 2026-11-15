#!/usr/bin/env python3
"""Export pinned official Maia-3 weights without quantization; verify parity.
Run with .venv-maia/bin/python tool/export_maia3.py.
Model source: UofTCSSLab/Maia3-23M @ 51a0145a8178046f7de23119160b136672deeb2b.
Code source: CSSLab/maia3 @ 1e13597c42d4858b7cfd7cfdae01e297263364b2.
"""
import sys, json, hashlib, time, copy
from pathlib import Path
from collections import deque
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'third_party/maia3'))
import torch, numpy as np, onnx, onnxruntime as ort, chess
from maia3.uci import parse_args
from maia3.models import MAIA3Model
from maia3.dataset import tokenize_board,get_historical_tokens
from maia3.utils import get_all_possible_moves,mirror_move

torch.set_num_threads(2)
cfg=parse_args(['--model','23m','--checkpoint-path',str(ROOT/'build/maia3-23m.pt'),'--device','cpu','--no-use-amp'])
model=MAIA3Model(cfg)
weights=torch.load(cfg.checkpoint_path,map_location='cpu',weights_only=True)
weights=weights.get('model_state_dict',weights)
model.load_state_dict({k.replace('smolgen','gab'):v for k,v in weights.items()},strict=True)
model.eval()
class Policy(torch.nn.Module):
    def __init__(self,model):super().__init__();self.model=model
    def forward(self,tokens,self_elo,opponent_elo):return self.model(tokens,self_elo,opponent_elo)[0]
policy=Policy(model).eval()
# Express RMSNorm in primitive ONNX operators; preserve epsilon and FP32 weights.
class ExportRMSNorm(torch.nn.Module):
    def __init__(self, norm):
        super().__init__(); self.weight=norm.weight; self.eps=norm.eps if norm.eps is not None else torch.finfo(torch.float32).eps
    def forward(self,x): return x * torch.rsqrt(torch.mean(x*x,dim=-1,keepdim=True)+self.eps) * self.weight
export_policy=copy.deepcopy(policy)
def portable_norms(module):
    for name,child in list(module.named_children()):
        if isinstance(child,torch.nn.RMSNorm): setattr(module,name,ExportRMSNorm(child))
        else: portable_norms(child)
portable_norms(export_policy)
torch.backends.mha.set_fastpath_enabled(False)
output=ROOT/'assets/weights/maia3-23m.onnx'
if not output.exists():
    torch.onnx.export(export_policy,(torch.zeros(1,64,97),torch.tensor([1500.]),torch.tensor([1500.])),str(output),
        input_names=['tokens','self_elo','opponent_elo'],output_names=['policy'],opset_version=17,dynamo=False)
onnx.checker.check_model(str(output))
options=ort.SessionOptions();options.intra_op_num_threads=2
session=ort.InferenceSession(str(output),options,providers=['CPUExecutionProvider'])
vocab=get_all_possible_moves();index={m:i for i,m in enumerate(vocab)}
scenarios=[(chess.STARTING_FEN,[]),(chess.STARTING_FEN,['e2e4','c7c5','g1f3','d7d6','d2d4','c5d4','f3d4']),
 ('4k3/P7/8/8/8/8/7p/4K3 w - - 0 1',[]),('4k3/P7/8/8/8/8/7p/4K3 b - - 0 1',[]),
 (chess.STARTING_FEN,['e2e4','e7e5','g1f3','b8c6','f1c4','g8f6','d2d3','f8c5','e1g1','d7d6','c2c3','e8g8'])]
fixtures=[];max_error=0;times=[]
for fen,moves in scenarios:
  board=chess.Board(fen);history=deque([tokenize_board(board)],maxlen=8)
  for move in moves:board.push_uci(move);history.append(tokenize_board(board))
  tokens=get_historical_tokens(history,cfg,0,0,0,0).unsqueeze(0)
  for elo in [600,1500,1900,2000,2600]:
    self_elo=torch.tensor([float(elo)]);other=torch.tensor([float(elo)])
    with torch.no_grad():expected=policy(tokens,self_elo,other).numpy()[0]
    started=time.perf_counter()
    actual=session.run(None,{'tokens':tokens.numpy(),'self_elo':self_elo.numpy(),'opponent_elo':other.numpy()})[0][0]
    times.append((time.perf_counter()-started)*1000)
    max_error=max(max_error,float(np.max(np.abs(expected-actual))))
    np.testing.assert_allclose(actual,expected,rtol=2e-4,atol=2e-4)
    legal=[m.uci() for m in board.legal_moves]
    indices=[index[m if board.turn else mirror_move(m)] for m in legal]
    top=legal[int(np.argmax(actual[indices]))]
    assert top==legal[int(np.argmax(expected[indices]))]
    fixtures.append({'startFen':fen,'moves':moves,'rating':elo,'top':top,'logits':{m:float(actual[idx]) for m,idx in zip(legal,indices)}})
(ROOT/'assets/data/maia3_validation.json').write_text(json.dumps(fixtures,separators=(',',':')))
report={'code_revision':'1e13597c42d4858b7cfd7cfdae01e297263364b2','model_revision':'51a0145a8178046f7de23119160b136672deeb2b','model_url':'https://huggingface.co/UofTCSSLab/Maia3-23M','bytes':output.stat().st_size,'sha256':hashlib.sha256(output.read_bytes()).hexdigest(),'checkpoint_sha256':hashlib.sha256(Path(cfg.checkpoint_path).read_bytes()).hexdigest(),'parity_cases':len(fixtures),'max_absolute_logit_error':max_error,'inference_ms_mean':sum(times)/len(times),'precision':'float32','opset':17}
(ROOT/'assets/data/maia3_manifest.json').write_text(json.dumps(report,indent=2))
print(json.dumps(report,indent=2))
