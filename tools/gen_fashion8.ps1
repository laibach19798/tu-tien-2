# Sinh lop trang phuc (toc / ao / giay) cho nhan vat 8 huong tu hinh bong cua tung khung, tu dong cho moi animation.
#  - Doc character\hd\sheets\<anim>.png (hang = 8 huong: south, south-east, east, north-east, north, north-west, west, south-west)
#  - Moc hinh hoc cua moi khung: dinh dau, co (hang hep nhat duoi dau), hong, tam dau, MAT (khoi toi nho nam trong dau) -> biet nhan vat nhin huong nao
#  - Anh xuat ra la thang xam; mau to bang modulate trong game. Ghi character\hd\fashion\*.png va character\hd\frames\*.tres
# Dung: powershell -File tools\gen_fashion8.ps1
param([string]$Sheets = "$PSScriptRoot\..\character\hd\sheets",
      [string]$Out = "$PSScriptRoot\..\character\hd")
$src = @'
using System; using System.Drawing; using System.Drawing.Imaging; using System.Collections.Generic; using System.IO;

public class Cv {
  public const int N=64; public float[,] s=new float[N,N];
  public Cv(){ for(int y=0;y<N;y++)for(int x=0;x<N;x++) s[x,y]=-1f; }
  public bool Has(int x,int y){ return x>=0&&y>=0&&x<N&&y<N&&s[x,y]>=0f; }
  public void Set(int x,int y,float v){ if(x>=0&&y>=0&&x<N&&y<N) s[x,y]=v; }
  public void SetIf(int x,int y,float v){ if(Has(x,y)) s[x,y]=v; }
  public void Outline(float v){ var b=new List<int[]>();
    for(int y=0;y<N;y++)for(int x=0;x<N;x++) if(Has(x,y)&&(!Has(x-1,y)||!Has(x+1,y)||!Has(x,y-1)||!Has(x,y+1))) b.Add(new int[]{x,y});
    foreach(var p in b) s[p[0],p[1]]=Math.Min(s[p[0],p[1]],v); }
}

public class Fr {
  public bool[,] A=new bool[64,64]; public bool[,] Dark=new bool[64,64];
  public bool empty; public int dir; public int T=99,B=-1,H,neck,hip,cx,cxBody,eyeY,eyeX0,eyeX1,face; // face: 0 front, 1 right, 2 left, 3 none (back)
  public bool[,] foot,shin;
  public int RowMin(int y){ for(int x=0;x<64;x++) if(A[x,y]) return x; return -1; }
  public int RowMax(int y){ for(int x=63;x>=0;x--) if(A[x,y]) return x; return -1; }
  public int RowCount(int y){ int c=0; for(int x=0;x<64;x++) if(A[x,y]) c++; return c; }
  public bool a(int x,int y){ return x>=0&&y>=0&&x<64&&y<64&&A[x,y]; }
  public void Analyze(){
    for(int y=0;y<64;y++)for(int x=0;x<64;x++) if(A[x,y]){ if(y<T)T=y; if(y>B)B=y; }
    if(B<0){ empty=true; return; }
    H=B-T+1;
    // head center from the narrow top rows
    int mn=99,mx=-1; for(int y=T+2;y<=T+4;y++){ int a0=RowMin(y),a1=RowMax(y); if(a0>=0){ if(a0<mn)mn=a0; if(a1>mx)mx=a1; } } cx=(mn+mx)/2;
    // neck = narrowest row below the head
    int best=99,by=T+21; for(int y=T+16;y<=T+26&&y<64;y++){ int c=RowCount(y); if(c>0&&c<best){ best=c; by=y; } } neck=by;
    hip=neck+(int)Math.Round(0.30*H);
    int r0=neck+9; int m0=RowMin(r0),m1=RowMax(r0); cxBody=(m0>=0)?(m0+m1)/2:cx;
    // dark pixels and eyes: small dark blobs inside the head that do not touch the outline
    var seen=new bool[64,64]; var eyes=new List<int[]>();
    for(int y=T+6;y<=neck-2;y++)for(int x=0;x<64;x++){ if(!Dark[x,y]||seen[x,y]) continue;
      var comp=new List<int[]>(); var st=new Stack<int[]>(); st.Push(new int[]{x,y}); seen[x,y]=true; bool touch=false;
      while(st.Count>0){ var p=st.Pop(); comp.Add(p);
        for(int dy=-1;dy<=1;dy++)for(int dx=-1;dx<=1;dx++){ int nx=p[0]+dx,ny=p[1]+dy; if(nx<0||ny<0||nx>=64||ny>=64){ touch=true; continue; }
          if(!A[nx,ny]){ touch=true; continue; } if(Dark[nx,ny]&&!seen[nx,ny]){ seen[nx,ny]=true; st.Push(new int[]{nx,ny}); } } }
      if(!touch&&comp.Count<=10){ double sx=0,sy=0; foreach(var p in comp){ sx+=p[0]; sy+=p[1]; } eyes.Add(new int[]{(int)Math.Round(sx/comp.Count),(int)Math.Round(sy/comp.Count)}); } }
    bool seen2=eyes.Count>0;
    if(!seen2){ eyeY=T+(int)Math.Round(0.72*(neck-T)); eyeX0=cx; eyeX1=cx; }
    else { int x0=99,x1=-1; double sy=0; foreach(var e in eyes){ if(e[0]<x0)x0=e[0]; if(e[0]>x1)x1=e[0]; sy+=e[1]; } eyeX0=x0; eyeX1=x1; eyeY=(int)Math.Round(sy/eyes.Count); }
    // facing is known from the row (direction); eyes only give the height of the face
    switch(dir){
      case 0: face=seen2?0:3; break;                 // south: facing the camera
      case 1: case 2: face=1; break;                 // south-east, east: facing right
      case 6: case 7: face=2; break;                 // west, south-west: facing left
      default: face=3; break;                        // north family: we see the back of the head
    }
    if(face==1&&(!seen2||eyeX0<=cx)){ eyeX0=cx+8; eyeX1=cx+8; }
    if(face==2&&(!seen2||eyeX1>=cx)){ eyeX0=cx-8; eyeX1=cx-8; }
    if(face==0&&eyeX1-eyeX0<6){ eyeX0=cx-5; eyeX1=cx+5; }
  }  // head pixel: inside an ellipse around the head, between the top and the neck
  public bool Head(int x,int y){ if(!a(x,y)||y<T||y>=neck) return false; double hc=T+(neck-T)/2.0; double dx=(x-cx)/14.5, dy=(y-hc)/((neck-T)/2.0+1.5); return dx*dx+dy*dy<=1.0; }
}

public static class Gen {
  static float Cl(float v){ return v<0?0:(v>1?1:v); }

  // ------------------------------------------------------------ CLOTHES
  public static Cv Clothes(Fr f,string style){
    var c=new Cv(); if(f.empty) return c; bool robe=style!="tunic", wide=style=="wide";
    int tw=(f.dir==2||f.dir==6)?99:(f.dir==0||f.dir==4?8:9);
    int sleeveEnd=robe?f.hip-3:f.neck+7;
    for(int y=f.neck+1;y<=f.hip;y++)for(int x=0;x<64;x++) if(f.A[x,y]){
      bool arm=Math.Abs(x-f.cxBody)>tw; if(arm&&y>sleeveEnd) continue;
      c.Set(x,y,y>=f.neck+8?0.80f:0.88f); }
    if(robe){
      int last=Math.Min(f.hip+7,f.B-5); int pmin=-1,pmax=-1;
      for(int y=f.hip+1;y<=last;y++){ int a0=f.RowMin(y),a1=f.RowMax(y); if(a0<0){a0=pmin;a1=pmax;} if(a0<0) continue; pmin=a0;pmax=a1;
        int flare=1+(y-f.hip-1)/3;
        a0=Math.Max(a0,f.cxBody-9); a1=Math.Min(a1,f.cxBody+9);
        for(int x=a0-flare;x<=a1+flare;x++) c.Set(x,y,((x-f.cxBody)%5==0)?0.70f:(y==last?0.62f:0.80f)); }
    }
    if(wide&&f.dir!=2&&f.dir!=6){
      int y0=f.neck+3,y1=f.neck+15;
      for(int y=y0;y<=y1;y++){ int a0=f.RowMin(y),a1=f.RowMax(y); if(a0<0) continue; int ext=Math.Min(6,2+(y-y0)/3);
        for(int k=1;k<=ext;k++){ c.Set(a0-k,y,0.76f); c.Set(a1+k,y,0.76f); } }
    }
    c.Outline(0.34f);
    if(robe){
      for(int y=f.hip-3;y<=f.hip-2;y++) for(int x=0;x<64;x++) if(c.Has(x,y)&&c.s[x,y]>0.4f&&Math.Abs(x-f.cxBody)<=tw+1) c.s[x,y]=0.52f;
      if(f.face==0){ for(int y=f.hip-4;y<=f.hip-1;y++) for(int x=f.cxBody+3;x<=f.cxBody+5;x++) c.SetIf(x,y,0.42f); }
      if(f.face!=3){ int vx=f.face==0?f.cxBody:f.cxBody+(f.face==1?2:-2);
        for(int i=0;i<=5;i++){ c.SetIf(vx-5+i,f.neck+1+i,1.0f); c.SetIf(vx+5-i,f.neck+1+i,1.0f); } }
    } else if(f.face!=3){ for(int x=f.cxBody-3;x<=f.cxBody+3;x++){ c.SetIf(x,f.neck+1,0.98f); c.SetIf(x,f.neck+2,0.94f); } }
    if(f.face==3){ for(int y=f.neck+3;y<=f.hip-4;y++) c.SetIf(f.cxBody,y,0.66f); }
    return c; }

  // ------------------------------------------------------------ SHOES (two lowest "plateaus" of the bottom contour)
  static void FootMasks(Fr f){
    int y0=f.B-12; var yl=new int[64]; for(int x=0;x<64;x++){ yl[x]=-1; for(int y=f.B;y>=y0;y--) if(f.A[x,y]){ yl[x]=y; break; } }
    var used=new bool[64]; f.foot=new bool[64,64]; f.shin=new bool[64,64];
    for(int pass=0;pass<2;pass++){
      int bx=-1,bp=-1; for(int x=0;x<64;x++) if(!used[x]&&yl[x]>bp&&yl[x]>=y0+4){ bp=yl[x]; bx=x; }
      if(bx<0) break;
      int a=bx,b=bx; while(a-1>=0&&!used[a-1]&&yl[a-1]>=bp-1) a--; while(b+1<64&&!used[b+1]&&yl[b+1]>=bp-1) b++;
      for(int x=Math.Max(0,a-1);x<=Math.Min(63,b+1);x++) for(int y=bp-3;y<=bp;y++) if(f.A[x,y]) f.foot[x,y]=true;
      for(int x=Math.Max(0,a-2);x<=Math.Min(63,b+2);x++) for(int y=bp-6;y<=bp;y++) if(f.A[x,y]) f.shin[x,y]=true;
      for(int x=Math.Max(0,a-2);x<=Math.Min(63,b+2);x++) used[x]=true; }
  }
  public static Cv Shoes(Fr f,string style){
    var c=new Cv(); if(f.empty) return c; if(f.foot==null) FootMasks(f); bool boot=style=="boot";
    for(int y=0;y<64;y++)for(int x=0;x<64;x++) if(f.A[x,y]&&(f.foot[x,y]||(boot&&f.shin[x,y]))) c.Set(x,y,0.86f);
    for(int y=0;y<64;y++)for(int x=0;x<64;x++) if(c.Has(x,y)){ if(!c.Has(x,y+1)) c.s[x,y]=0.50f; else if(boot&&!c.Has(x,y-1)) c.s[x,y]=1.0f; }
    c.Outline(0.30f); return c; }

  // ------------------------------------------------------------ HAIR
  static float HairShade(Fr f,int x,int y,int T){ if(y==T+2&&x%6<2) return 0.98f; if(y>T+3&&(x-f.cx)%6==0) return 0.68f; return 0.80f; }

  public static void Hair(Fr f,string style,out Cv front,out Cv back){
    front=new Cv(); back=new Cv(); if(f.empty) return;
    int T=f.T; int brow=f.eyeY-6; int sideEnd=f.eyeY+3;
    int fx0=-99,fx1=99; if(f.face==0){ fx0=f.eyeX0-6; fx1=f.eyeX1+6; } else if(f.face==1){ fx0=f.eyeX0-7; fx1=99; } else if(f.face==2){ fx0=-99; fx1=f.eyeX1+7; }
    int bottom=(f.face==3)?f.neck-3:sideEnd;
    for(int y=T;y<=bottom;y++)for(int x=0;x<64;x++){ if(!f.Head(x,y)) continue;
      bool inFace=f.face!=3&&y>=brow&&x>=fx0&&x<=fx1; if(inFace) continue;
      front.Set(x,y,HairShade(f,x,y,T)); }
    if(f.face!=3){ // fringe teeth along the brow line
      for(int x=Math.Max(fx0,f.cx-14);x<=Math.Min(fx1,f.cx+14);x++) if(f.Head(x,brow)&&((x/3)%2==0)){ front.Set(x,brow,0.74f); if(f.Head(x,brow+1)&&((x/3)%4==0)) front.Set(x,brow+1,0.72f); } }
    int sgn=(f.face==1)?-1:((f.face==2)?1:0);          // direction of the BACK of the head (+1 = right)
    if(style=="topknot"){
      int kx=f.cx+sgn*3, ky=T-1;
      for(int dy=-5;dy<=3;dy++)for(int dx=-5;dx<=5;dx++){ double v=(dx/5.0)*(dx/5.0)+(dy/4.0)*(dy/4.0); if(v<=1.0) front.Set(kx+dx,ky+dy,(dy<0&&dx<1)?0.98f:0.80f); }
      for(int x=kx-3;x<=kx+3;x++){ front.SetIf(x,T+1,0.45f); front.SetIf(x,T+2,0.45f); }
    }
    if(style=="ponytail"){
      if(f.face==3){ for(int y=T+6;y<=f.neck+8;y++){ int w=(y<=f.neck-2)?2:(y<=f.neck+4?2:1); for(int x=f.cx-w;x<=f.cx+w;x++) front.Set(x,y,(x==f.cx)?0.70f:0.82f); }
        for(int x=f.cx-3;x<=f.cx+3;x++){ front.Set(x,T+8,0.42f); front.Set(x,T+9,0.42f); } }
      else if(f.face==0){ for(int y=f.eyeY-4;y<=f.eyeY+8;y++){ back.Set(f.cx+13,y,0.80f); back.Set(f.cx+14,y,0.72f); back.Set(f.cx+15,y,0.72f); } }
      else { int ex=f.cx+sgn*10;
        for(int i=0;i<18;i++){ int y=T+8+i; int off=2+Math.Min(i,4)-(i>12?(i-12)/2:0); int x=ex+sgn*off;
          for(int dx=0;dx<4;dx++) back.Set(x-sgn*dx,y,(dx<2)?0.80f:0.70f); }
        for(int y=T+8;y<=T+10;y++) for(int k=0;k<=2;k++) back.Set(ex+sgn*(3+k),y,0.42f); }
    }    if(style=="long"){
      if(f.face==3){ for(int y=f.neck-2;y<=f.neck+14;y++){ int w=Math.Max(3,9-(y-(f.neck-2))*6/16); for(int x=f.cx-w;x<=f.cx+w;x++) front.Set(x,y,(Math.Abs(x-f.cx)%3==0)?0.66f:0.80f); } }
      else if(f.face==0){
        for(int y=f.eyeY-4;y<=f.neck+10;y++){ int ext=(y<=f.neck)?14:12; for(int x=f.cx-ext;x<=f.cx+ext;x++) back.Set(x,y,(x%4==0)?0.66f:0.78f); }
        for(int y=f.neck-2;y<=f.neck+8;y++){ for(int k=0;k<3;k++){ front.Set(f.cx-10+k,y,0.78f); front.Set(f.cx+10-k,y,0.78f); } } }
      else { int ex=(sgn>0)?f.cx+8:f.cx-8;
        for(int y=T+8;y<=f.neck+12;y++){ int w=Math.Max(2,7-(y-(T+8))/4); for(int k=0;k<w;k++){ int xx=ex+sgn*k; back.Set(xx,y,(k%3==0)?0.66f:0.78f); } } }
    }
    front.Outline(0.32f); back.Outline(0.32f);
  }

  // ------------------------------------------------------------ SHEETS
  static Fr[,] Load(string path,int n){
    var bmp=new Bitmap(path); var fr=new Fr[8,n];
    for(int r=0;r<8;r++)for(int i=0;i<n;i++){ var f=new Fr(); f.dir=r;
      for(int y=0;y<64;y++)for(int x=0;x<64;x++){ var p=bmp.GetPixel(i*64+x,r*64+y); f.A[x,y]=p.A>40; f.Dark[x,y]=p.A>40&&(p.R*30+p.G*59+p.B*11)/100<80; }
      f.Analyze(); fr[r,i]=f; }
    bmp.Dispose(); return fr; }
  static void Save(Cv[,] cs,int n,string path){
    var o=new Bitmap(n*64,8*64,PixelFormat.Format32bppArgb);
    for(int r=0;r<8;r++)for(int i=0;i<n;i++)for(int y=0;y<64;y++)for(int x=0;x<64;x++){ float v=cs[r,i].s[x,y];
      if(v>=0f){ int g=(int)(Cl(v)*255f); o.SetPixel(i*64+x,r*64+y,Color.FromArgb(255,g,g,g)); } }
    o.Save(path,ImageFormat.Png); o.Dispose(); }
  public static List<string> Run(string sheetDir,string outDir){
    Directory.CreateDirectory(outDir); var names=new List<string>();
    foreach(var an in new[]{"idle","walk","run","jump"}){ string sp=Path.Combine(sheetDir,an+".png"); if(!File.Exists(sp)) continue;
      int n; using(var b=new Bitmap(sp)) n=b.Width/64; var fr=Load(sp,n); names.Add(an+":"+n);
      foreach(var st in new[]{"tunic","robe","wide"}){ var cs=new Cv[8,n]; for(int r=0;r<8;r++)for(int i=0;i<n;i++) cs[r,i]=Clothes(fr[r,i],st); Save(cs,n,Path.Combine(outDir,"clothes_"+st+"_"+an+".png")); }
      foreach(var st in new[]{"cloth","boot"}){ var cs=new Cv[8,n]; for(int r=0;r<8;r++)for(int i=0;i<n;i++) cs[r,i]=Shoes(fr[r,i],st); Save(cs,n,Path.Combine(outDir,"shoes_"+st+"_"+an+".png")); }
      foreach(var st in new[]{"topknot","long","ponytail"}){ var cf=new Cv[8,n]; var cb=new Cv[8,n];
        for(int r=0;r<8;r++)for(int i=0;i<n;i++){ Cv a1,b1; Hair(fr[r,i],st,out a1,out b1); cf[r,i]=a1; cb[r,i]=b1; }
        Save(cf,n,Path.Combine(outDir,"hairf_"+st+"_"+an+".png")); Save(cb,n,Path.Combine(outDir,"hairb_"+st+"_"+an+".png")); }
    }
    return names; }
}
'@
Add-Type -AssemblyName System.Drawing
Add-Type -TypeDefinition $src -ReferencedAssemblies System.Drawing
$sheets = (Resolve-Path $Sheets).Path
$out = [IO.Path]::GetFullPath($Out)
$fashion = Join-Path $out "fashion"
$anims = [Gen]::Run($sheets, $fashion)
Write-Host ("Da sinh anh trang phuc cho: " + ($anims -join ", "))

# SpriteFrames cho tung lop (cung ten animation va so khung voi than)
$dirs = @("south","south-east","east","north-east","north","north-west","west","south-west")
$fps = @{ idle = 4; walk = 10; run = 14; jump = 12 }
$loop = @{ idle = "true"; walk = "true"; run = "true"; jump = "false" }
$info = @(); foreach ($a in $anims) { $p = $a.Split(':'); $info += @{ name = $p[0]; n = [int]$p[1] } }
function Build-Frames([string]$prefix) {
  $ext = New-Object Collections.Generic.List[string]; $sub = New-Object Collections.Generic.List[string]; $an = New-Object Collections.Generic.List[string]
  $ai = 0; $k = 0
  foreach ($a in $info) {
    $ai++
    $ext.Add("[ext_resource type=`"Texture2D`" path=`"res://character/hd/fashion/${prefix}_$($a.name).png`" id=`"$ai`"]")
    for ($r = 0; $r -lt 8; $r++) {
      $fr = New-Object Collections.Generic.List[string]
      for ($i = 0; $i -lt $a.n; $i++) {
        $k++
        $sub.Add("[sub_resource type=`"AtlasTexture`" id=`"Atlas_$k`"]`natlas = ExtResource(`"$ai`")`nregion = Rect2($($i * 64), $($r * 64), 64, 64)`n")
        $fr.Add("{`"duration`": 1.0, `"texture`": SubResource(`"Atlas_$k`")}")
      }
      $an.Add("{`"frames`": [" + ($fr -join ", ") + "], `"loop`": $($loop[$a.name]), `"name`": &`"$($a.name)_$($dirs[$r])`", `"speed`": $($fps[$a.name]).0}")
    }
  }
  $steps = $ext.Count + $sub.Count + 1
  return "[gd_resource type=`"SpriteFrames`" load_steps=$steps format=3]`n`n" + ($ext -join "`n") + "`n`n" + ($sub -join "`n") + "`n[resource]`nanimations = [" + ($an -join ",`n") + "]`n"
}
$framesDir = Join-Path $out "frames"
New-Item -ItemType Directory -Force $framesDir | Out-Null
$utf8 = New-Object Text.UTF8Encoding($false)
$prefixes = Get-ChildItem $fashion -Filter "*_idle.png" | ForEach-Object { $_.Name -replace '_idle\.png$', '' }
foreach ($pf in $prefixes) { [IO.File]::WriteAllText((Join-Path $framesDir "$pf.tres"), (Build-Frames $pf), $utf8) }
Write-Host ("Da tao {0} file frames" -f @($prefixes).Count)
