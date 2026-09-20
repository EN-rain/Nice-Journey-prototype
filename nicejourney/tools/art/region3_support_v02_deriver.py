#!/usr/bin/env python3
"""Deterministic Region3 support atlas derivation.

Extracts grid sources into pixel-art outputs. Transparent support cells use
alpha-thresholded connected components assigned by component centroid, which
keeps objects that slightly cross nominal grid boundaries (notably the town
well roof) intact.
"""
from __future__ import annotations
import argparse, hashlib, json
from pathlib import Path
from collections import deque
from PIL import Image
import numpy as np

ALPHA_THRESHOLD = 24

def sha256(path: Path) -> str:
    h=hashlib.sha256()
    with path.open('rb') as f:
        for b in iter(lambda:f.read(1024*1024), b''): h.update(b)
    return h.hexdigest()

def clean(im: Image.Image) -> Image.Image:
    a=np.array(im.convert('RGBA'),dtype=np.uint8)
    a[:,:,3][a[:,:,3] < ALPHA_THRESHOLD] = 0
    return Image.fromarray(a,'RGBA')

def components(im: Image.Image):
    a=np.array(im.getchannel('A'))
    mask=a>0; h,w=mask.shape; seen=np.zeros_like(mask,bool); out=[]
    for y,x in zip(*np.where(mask & ~seen)):
        if seen[y,x]: continue
        q=[(int(y),int(x))]; seen[y,x]=1; pts=[]
        while q:
            yy,xx=q.pop(); pts.append((yy,xx))
            for dy in (-1,0,1):
                for dx in (-1,0,1):
                    if not (dy or dx): continue
                    ny,nx=yy+dy,xx+dx
                    if 0<=ny<h and 0<=nx<w and mask[ny,nx] and not seen[ny,nx]:
                        seen[ny,nx]=1; q.append((ny,nx))
        # Ignore isolated antialias/background specks after alpha cleanup.
        if len(pts)>=16:
            ys=[p[0] for p in pts]; xs=[p[1] for p in pts]
            out.append({'bbox':[min(xs),min(ys),max(xs)+1,max(ys)+1], 'centroid':[sum(xs)/len(xs),sum(ys)/len(ys)], 'pixels':len(pts), '_points':pts})
    return out

def fit_nearest(im: Image.Image, size: int) -> Image.Image:
    im=im.convert('RGBA'); bbox=im.getbbox()
    if not bbox: return Image.new('RGBA',(size,size))
    im=im.crop(bbox); scale=min((size-4)/im.width,(size-4)/im.height)
    nw=max(1,round(im.width*scale)); nh=max(1,round(im.height*scale))
    im=im.resize((nw,nh),Image.Resampling.NEAREST)
    out=Image.new('RGBA',(size,size)); out.paste(im,((size-nw)//2,(size-nh)//2))
    return out

def derive(src:Path,out:Path,cols:int,rows:int,kind:str,size:int,atlas_name:str):
    im=clean(Image.open(src)); w,h=im.size
    out.mkdir(parents=True,exist_ok=True)
    comps=components(im) if kind=='support' else []
    records=[]; cells=[]
    for idx in range(cols*rows):
        col,row=idx%cols,idx//cols
        # Ground source has broad transparent gutters/background glow; use the
        # authored square swatch rectangles exactly rather than nominal grid
        # thirds. Props retain equal 4x4 nominal cells so the well roof can be
        # selected by its centroid while its bbox crosses the row boundary.
        if w == 1536 and h == 1024 and cols == 4 and rows == 2:
            rects = [(64,148,375,454),(430,148,741,454),(795,148,1106,454),(1162,148,1473,454),
                     (64,570,375,880),(430,570,741,880),(795,570,1106,880),(1162,570,1473,880)]
            x0,y0,x1,y1 = rects[idx]
        elif w == 1536 and h == 1024 and cols == 3 and rows == 2:
            rects = [(64,148,475,454),(560,148,971,454),(1052,148,1463,454),
                     (64,570,475,880),(560,570,971,880),(1052,570,1463,880)]
            x0,y0,x1,y1 = rects[idx]
        else:
            x0=round(col*w/cols); x1=round((col+1)*w/cols)
            y0=round(row*h/rows); y1=round((row+1)*h/rows)
        if kind=='material': crop=im.crop((x0,y0,x1,y1)).resize((size,size),Image.Resampling.NEAREST); selected=[]
        else:
            selected=[c for c in comps if x0 <= c['centroid'][0] < x1 and y0 <= c['centroid'][1] < y1]
            if selected:
                bx0=min(c['bbox'][0] for c in selected); by0=min(c['bbox'][1] for c in selected); bx1=max(c['bbox'][2] for c in selected); by1=max(c['bbox'][3] for c in selected)
                # Keep only selected connected components. A bbox crop alone
                # would retain neighboring halos/specks from the source cell.
                a=np.array(im,dtype=np.uint8)
                keep=np.zeros(a.shape[:2],dtype=bool)
                for c in selected:
                    for yy,xx in c['_points']: keep[yy,xx]=True
                a[:,:,3][~keep]=0
                crop=Image.fromarray(a,'RGBA').crop((bx0,by0,bx1,by1))
            else: bx0=by0=bx1=by1=0; crop=Image.new('RGBA',(1,1))
            crop=fit_nearest(crop,size)
        name=f'{atlas_name}_{idx:02d}.png'; path=out/name; crop.save(path)
        cells.append(crop)
        selected_public=[{k:v for k,v in c.items() if k != '_points'} for c in selected]
        records.append({'index':idx,'row':row,'col':col,'nominal_rect':[x0,y0,x1,y1], 'selected_components':selected_public, 'bbox':[bx0,by0,bx1,by1] if kind=='support' else [x0,y0,x1,y1], 'output':name, 'sha256':sha256(path)})
    atlas=Image.new('RGBA',(cols*size,rows*size))
    for i,c in enumerate(cells): atlas.paste(c,((i%cols)*size,(i//cols)*size))
    atlas_path=out/f'{atlas_name}.png'; atlas.save(atlas_path)
    manifest={'schema':'region3-support-derivation/v02','source':str(src),'source_sha256':sha256(src),'source_size':[w,h],'alpha_threshold':ALPHA_THRESHOLD,'kind':kind,'grid':[cols,rows],'output_cell_size':size,'atlas':atlas_path.name,'atlas_sha256':sha256(atlas_path),'cells':records}
    (out/f'{atlas_name}.manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    return manifest

def main():
    p=argparse.ArgumentParser(); p.add_argument('source',type=Path); p.add_argument('output',type=Path); p.add_argument('--cols',type=int,required=True); p.add_argument('--rows',type=int,required=True); p.add_argument('--kind',choices=['support','material'],required=True); p.add_argument('--size',type=int,required=True); p.add_argument('--name',required=True)
    a=p.parse_args(); print(json.dumps(derive(a.source,a.output,a.cols,a.rows,a.kind,a.size,a.name),indent=2))
if __name__=='__main__': main()
