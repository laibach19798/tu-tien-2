# Nhập sheet thân nhân vật do AI vẽ thành sheet 64x64 chuẩn của game.
#  - sheet chính: raw_idle.png, raw_walk.png, raw_run.png (3 hàng: trước / sau / ngang)
#  - từng hàng có thể vẽ riêng: raw_<walk|run>_<front|back|side>.png (1 hàng) thay cho hàng đó
#  - animation ra chiêu (cần có kiếm): raw_<slash|slash_heavy|thrust|cast|ultimate>_<front|back|side>.png
#    (1 hàng mỗi hướng, số khung tự nhận). Pixel kiếm được ghi riêng ra <tên>_weapon.png để trang phục không đè lên kiếm.
#  Thu nhỏ bằng lấy trung bình vùng, tỉ lệ theo cỡ đầu của hàng idle cùng hướng, mốc chân (32,56).
# Dùng: powershell -File tools\import_body.ps1 [-TargetH 48]
param([string]$Dir = "$PSScriptRoot\..\character\sheets_new", [int]$TargetH = 48)
$src = @'
using System; using System.Drawing; using System.Drawing.Imaging; using System.Collections.Generic; using System.IO; using System.Linq;

public class Box { public int x0,y0,x1,y1; public int hcx; public int ay=-1; public int headWs; public int W{get{return x1-x0+1;}} public int H{get{return y1-y0+1;}} public int headW; }

public class Sheet {
  public int W,H; public byte[] px; public bool[] bg;
  public Sheet(string path){
    var b=new Bitmap(path); W=b.Width; H=b.Height; px=new byte[W*H*4];
    var bd=b.LockBits(new Rectangle(0,0,W,H),ImageLockMode.ReadOnly,PixelFormat.Format32bppArgb);
    var raw=new byte[bd.Stride*H]; System.Runtime.InteropServices.Marshal.Copy(bd.Scan0,raw,0,raw.Length);
    for(int y=0;y<H;y++)for(int x=0;x<W;x++){ int i=y*bd.Stride+x*4,o=(y*W+x)*4; px[o]=raw[i+2]; px[o+1]=raw[i+1]; px[o+2]=raw[i]; px[o+3]=raw[i+3]; }
    b.UnlockBits(bd); b.Dispose();
    bg=new bool[W*H]; var st=new Stack<int>();
    Func<int,bool> white=i=>{ int o=i*4; return px[o+3]<30 || (px[o]>=226&&px[o+1]>=226&&px[o+2]>=226); };
    for(int x=0;x<W;x++){ Push(st,x,0); Push(st,x,H-1); } for(int y=0;y<H;y++){ Push(st,0,y); Push(st,W-1,y); }
    while(st.Count>0){ int p=st.Pop(); if(bg[p]||!white(p)) continue; bg[p]=true; int x=p%W,y=p/W;
      if(x>0)st.Push(p-1); if(x<W-1)st.Push(p+1); if(y>0)st.Push(p-W); if(y<H-1)st.Push(p+W); }
    // remove tiny specks (area < 400 px) before detecting rows/columns
    var lab=new int[W*H]; int id=0;
    for(int i0=0;i0<W*H;i0++){ if(bg[i0]||lab[i0]!=0) continue; id++; var comp=new List<int>(); st.Push(i0); lab[i0]=id;
      while(st.Count>0){ int p=st.Pop(); comp.Add(p); int x=p%W,y=p/W;
        for(int dy=-1;dy<=1;dy++)for(int dx=-1;dx<=1;dx++){ int nx=x+dx,ny=y+dy; if(nx<0||ny<0||nx>=W||ny>=H) continue; int q=ny*W+nx; if(!bg[q]&&lab[q]==0){ lab[q]=id; st.Push(q);} } }
      if(comp.Count<400) foreach(int p in comp) bg[p]=true; }
  }
  void Push(Stack<int> st,int x,int y){ st.Push(y*W+x); }
  public bool Op(int x,int y){ return x>=0&&y>=0&&x<W&&y<H&&!bg[y*W+x]; }

  // weapon pixels: pale blue-white blade or gold guard (the character body is skin / underwear / dark outline)
  public static bool IsWeapon(int r,int g,int b){
    int lum=(r*30+g*59+b*11)/100; bool blade=lum>140&&(r-b)<25; bool gold=b<90&&r>170&&g>110&&(r-g)<90; return blade||gold; }
  bool WeaponAt(int x,int y){ int o=(y*W+x)*4; return IsWeapon(px[o],px[o+1],px[o+2]); }
  // skin / underwear pixels only (no dark outline, no blade): used to measure the head so a sword outline cannot widen it
  bool SkinAt(int x,int y){ int o=(y*W+x)*4; int r=px[o],g=px[o+1],b=px[o+2]; int lum=(r*30+g*59+b*11)/100; return r>g+10&&r>b+15&&lum>95&&!IsWeapon(r,g,b); }

  static List<int[]> Runs(int[] cnt,int minGap,int minCount){
    var runs=new List<int[]>(); int start=-1,last=-1;
    for(int i=0;i<cnt.Length;i++){ if(cnt[i]>=minCount){ if(start<0){start=i;} else if(i-last>minGap){ runs.Add(new[]{start,last}); start=i; } last=i; } }
    if(start>=0) runs.Add(new[]{start,last}); return runs; }

  // n<=0: accept any number of frames. weapon: head and feet anchors use body pixels only (ignore the sword)
  public List<List<Box>> Frames(int n,out string err,int expectBands=3,bool weapon=false){
    err=""; var rows=new List<List<Box>>();
    var rc=new int[H]; for(int y=0;y<H;y++)for(int x=0;x<W;x++) if(Op(x,y)) rc[y]++;
    var bands=Runs(rc,3,2);
    if(bands.Count!=expectBands){ err="rows="+bands.Count+" (need "+expectBands+"): "+string.Join("; ",bands.Select(r=>r[0]+"-"+r[1]).ToArray()); return rows; }
    foreach(var bnd in bands){
      var cc=new int[W]; for(int x=0;x<W;x++)for(int y=bnd[0];y<=bnd[1];y++) if(Op(x,y)) cc[x]++;
      var cols=Runs(cc,8,1);
      if(n>0&&cols.Count!=n){ err="row "+rows.Count+": frames="+cols.Count+" (need "+n+")"; return rows; }
      var list=new List<Box>();
      foreach(var c in cols){ var bx=new Box(); bx.x0=c[0]; bx.x1=c[1]; bx.y0=H; bx.y1=-1;
        for(int y=bnd[0];y<=bnd[1];y++)for(int x=c[0];x<=c[1];x++) if(Op(x,y)){ if(y<bx.y0)bx.y0=y; if(y>bx.y1)bx.y1=y; }
        int hy=bx.y0+(int)(bx.H*0.30); int hmin=W,hmax=-1;
        for(int y=bx.y0;y<=hy;y++)for(int x=c[0];x<=c[1];x++) if(Op(x,y)&&!(weapon&&WeaponAt(x,y))){ if(x<hmin)hmin=x; if(x>hmax)hmax=x; }
        // skin-only measurements
        int sy0=H,sy1=-1; for(int y=bx.y0;y<=bx.y1;y++)for(int x=c[0];x<=c[1];x++) if(Op(x,y)&&SkinAt(x,y)){ if(y<sy0)sy0=y; if(y>sy1)sy1=y; }
        if(sy1<0){ sy0=bx.y0; sy1=bx.y1; }
        int shh=sy1-sy0+1; int hyS=sy0+(int)(shh*0.35); int smin=W,smax=-1;
        for(int y=sy0;y<=hyS;y++)for(int x=c[0];x<=c[1];x++) if(Op(x,y)&&SkinAt(x,y)){ if(x<smin)smin=x; if(x>smax)smax=x; }
        if(smax<0){ smin=hmin; smax=hmax; }
        bx.headWs=smax-smin+1;        if(weapon){ bx.hcx=(smin+smax)/2; bx.headW=bx.headWs; bx.ay=sy1+1; }          // skin bottom + 1 = the outline row under the feet
        else { bx.hcx=(hmin+hmax)/2; bx.headW=hmax-hmin+1; bx.ay=bx.y1; }
        list.Add(bx); }
      rows.Add(list);
    }
    return rows; }

  // Draw one frame: area average of the source for each 64x64 destination pixel. yBottomDest = row of the anchor bottom (feet).
  public Color[] Render(Box b,double s,double yBottomDest){
    var o=new Color[64*64]; double inv=1.0/s; int ay=b.ay>=0?b.ay:b.y1;
    for(int dy=0;dy<64;dy++)for(int dx=0;dx<64;dx++){
      double cx=(dx+0.5-32.0)*inv+b.hcx, cy=(dy+0.5-yBottomDest)*inv+ay;
      int x0=(int)Math.Floor(cx-inv/2), x1=(int)Math.Ceiling(cx+inv/2), y0=(int)Math.Floor(cy-inv/2), y1=(int)Math.Ceiling(cy+inv/2);
      int tot=0,opq=0; long r=0,g=0,bl=0;
      for(int y=y0;y<y1;y++)for(int x=x0;x<x1;x++){ tot++; if(x>=b.x0&&x<=b.x1&&y>=b.y0&&y<=b.y1&&Op(x,y)){ opq++; int p=(y*W+x)*4; r+=px[p]; g+=px[p+1]; bl+=px[p+2]; } }
      if(tot>0&&opq*2>=tot) o[dy*64+dx]=Color.FromArgb(255,(int)(r/opq),(int)(g/opq),(int)(bl/opq)); else o[dy*64+dx]=Color.FromArgb(0,0,0,0);
    }
    return o; }
}

public static class Importer {
  static double Median(List<double> v){ v.Sort(); return v[v.Count/2]; }
  static readonly string[] Views={"front","back","side"};
  public static readonly string[] Extras={"slash","slash_heavy","thrust","cast","ultimate"};

  public static string Run(string dir,int targetH){
    var log=new System.Text.StringBuilder();
    string[] names={"idle","walk","run"}; int[] ns={4,6,8};
    var wTarget=new double[3]; var wTargetS=new double[3];                                 // target head width per direction (front/back/side), from the idle sheet
    for(int a=0;a<3;a++){
      var sh=new Sheet(Path.Combine(dir,"raw_"+names[a]+".png")); string err;
      var rows=sh.Frames(ns[a],out err); if(err!=""){ return "ERROR "+names[a]+": "+err; }
      var ov=new Sheet[3]; var ovRows=new List<Box>[3];
      for(int rv=0;rv<3&&a>0;rv++){ string op=Path.Combine(dir,"raw_"+names[a]+"_"+Views[rv]+".png");
        if(!File.Exists(op)) continue; var os=new Sheet(op); string e2; var rr=os.Frames(ns[a],out e2,1);
        if(e2!="") return "ERROR "+names[a]+"_"+Views[rv]+": "+e2; ov[rv]=os; ovRows[rv]=rr[0]; log.AppendLine(names[a]+": own row "+Views[rv]); }
      double sIdle=-1; if(a==0){ sIdle=targetH/Median(rows[0].Select(b=>(double)b.H).ToList()); }
      var outB=new Bitmap(ns[a]*64,192,PixelFormat.Format32bppArgb);
      for(int r=0;r<3;r++){
        bool useOv=(ov[r]!=null); var src2=useOv?ov[r]:sh; var rowBoxes=useOv?ovRows[r]:rows[r];
        double mW=Median(rowBoxes.Select(b=>(double)b.headW).ToList());
        double s; if(a==0){ s=sIdle; wTarget[r]=mW*s; wTargetS[r]=Median(rowBoxes.Select(b=>(double)b.headWs).ToList())*s; } else s=wTarget[r]/mW;
        log.AppendLine(names[a]+" row"+r+": head~"+mW+", scale="+s.ToString("0.000"));
        var bots=rowBoxes.Select(b=>(double)b.y1).ToList(); double med=Median(new List<double>(bots));
        int n=ns[a];
        for(int i=0;i<n;i++){ var b=rowBoxes[i]; double yb=56.0; if(a==2) yb+=(b.y1-med)*s;       // only running keeps the bobbing
          var px=src2.Render(b,s,yb); for(int y=0;y<64;y++)for(int x=0;x<64;x++) outB.SetPixel(i*64+x,r*64+y,px[y*64+x]); }
      }
      outB.Save(Path.Combine(dir,names[a]+".png"),ImageFormat.Png); outB.Dispose();
    }
    // action animations (with a sword); one raw file per direction, frame count detected automatically
    foreach(var nm in Extras){
      var rowsD=new Sheet[3]; var boxes=new List<Box>[3]; int nf=0;
      for(int rv=0;rv<3;rv++){ string op=Path.Combine(dir,"raw_"+nm+"_"+Views[rv]+".png"); if(!File.Exists(op)) continue;
        var os=new Sheet(op); string e2; var rr=os.Frames(0,out e2,1,true); if(e2!="") return "ERROR "+nm+"_"+Views[rv]+": "+e2;
        if(nf==0) nf=rr[0].Count; else if(nf!=rr[0].Count) return "ERROR "+nm+": directions have different frame counts ("+nf+" vs "+rr[0].Count+")";
        rowsD[rv]=os; boxes[rv]=rr[0]; }
      if(nf==0) continue;
      var outB=new Bitmap(nf*64,192,PixelFormat.Format32bppArgb); var wB=new Bitmap(nf*64,192,PixelFormat.Format32bppArgb);
      for(int r=0;r<3;r++){ if(rowsD[r]==null) continue;
        double mW=Median(boxes[r].Select(b=>(double)b.headWs).ToList()); double s=wTargetS[r]/mW;
        var bots=boxes[r].Select(b=>(double)b.ay).ToList(); double med=Median(new List<double>(bots));
        log.AppendLine(nm+" "+Views[r]+": "+nf+" frames, head~"+mW+", scale="+s.ToString("0.000"));
        for(int i=0;i<nf;i++){ var b=boxes[r][i]; double yb=56.0+(b.ay-med)*s;
          var px=rowsD[r].Render(b,s,yb);
          for(int y=0;y<64;y++)for(int x=0;x<64;x++){ var c=px[y*64+x]; outB.SetPixel(i*64+x,r*64+y,c);
            if(c.A>0&&Sheet.IsWeapon(c.R,c.G,c.B)) wB.SetPixel(i*64+x,r*64+y,Color.FromArgb(255,255,255,255)); } }
      }
      // drop tiny weapon-colored blobs (eye whites): keep weapon components of >= 12 px per frame
      for(int r=0;r<3;r++)for(int i=0;i<nf;i++){ var seen=new bool[64*64]; for(int sy=0;sy<64;sy++)for(int sx=0;sx<64;sx++){ if(seen[sy*64+sx]||wB.GetPixel(i*64+sx,r*64+sy).A==0) continue; var comp=new List<int>(); var stk=new Stack<int>(); stk.Push(sy*64+sx); seen[sy*64+sx]=true;
          while(stk.Count>0){ int p=stk.Pop(); comp.Add(p); int px0=p%64,py0=p/64; for(int dy=-1;dy<=1;dy++)for(int dx=-1;dx<=1;dx++){ int nx=px0+dx,ny=py0+dy; if(nx<0||ny<0||nx>=64||ny>=64) continue; int q=ny*64+nx; if(!seen[q]&&wB.GetPixel(i*64+nx,r*64+ny).A>0){ seen[q]=true; stk.Push(q);} } }
          if(comp.Count<12) foreach(int q in comp) wB.SetPixel(i*64+q%64,r*64+q/64,Color.FromArgb(0,0,0,0)); } }
      outB.Save(Path.Combine(dir,nm+".png"),ImageFormat.Png); wB.Save(Path.Combine(dir,nm+"_weapon.png"),ImageFormat.Png); outB.Dispose(); wB.Dispose();
    }
    return log.ToString(); }
}
'@
Add-Type -AssemblyName System.Drawing
Add-Type -TypeDefinition $src -ReferencedAssemblies System.Drawing,System.Core
Write-Host ([Importer]::Run((Resolve-Path $Dir).Path, $TargetH))
