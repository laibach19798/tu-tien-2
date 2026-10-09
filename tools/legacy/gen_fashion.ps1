# Sinh các lớp trang phục (tóc, áo, giày) từ hình bóng của từng khung hình thân nhân vật,
# nên khớp tuyệt đối với animation. Ảnh xuất ra là thang xám; màu được tô bằng modulate trong game.
# Dùng: powershell -File tools\gen_fashion.ps1
param([string]$Body = "$PSScriptRoot\..\character\sheets",
      [string]$Out = "$PSScriptRoot\..\character")
$src = @'
using System; using System.Drawing; using System.Drawing.Imaging; using System.Collections.Generic; using System.IO;

public class Cv {                                  // một lớp 32x32: shade >= 0 là có pixel
  public float[,] s = new float[32,32];
  public Cv(){ for(int y=0;y<32;y++)for(int x=0;x<32;x++) s[x,y]=-1f; }
  public bool Has(int x,int y){ return x>=0&&y>=0&&x<32&&y<32&&s[x,y]>=0f; }
  public void Set(int x,int y,float v){ if(x>=0&&y>=0&&x<32&&y<32) s[x,y]=v; }
  public void Outline(float v){
    var b=new List<int[]>();
    for(int y=0;y<32;y++)for(int x=0;x<32;x++) if(Has(x,y)){
      if(!Has(x-1,y)||!Has(x+1,y)||!Has(x,y-1)||!Has(x,y+1)) b.Add(new int[]{x,y}); }
    foreach(var p in b) s[p[0],p[1]]=Math.Min(s[p[0],p[1]],v);
  }
}

public class Fr {                                  // thông tin hình bóng của một khung
  public bool[,] A=new bool[32,32]; public int top=99,bottom=-1,hmin=99,hmax=-1,cx; public int view;
  public bool a(int x,int y){ return x>=0&&y>=0&&x<32&&y<32&&A[x,y]; }
  public int RowMin(int y){ for(int x=0;x<32;x++) if(A[x,y]) return x; return -1; }
  public int RowMax(int y){ for(int x=31;x>=0;x--) if(A[x,y]) return x; return -1; }
  public void Analyze(){
    for(int y=0;y<32;y++)for(int x=0;x<32;x++) if(A[x,y]){ if(y<top)top=y; if(y>bottom)bottom=y; }
    for(int y=top;y<=top+10&&y<32;y++){ int a0=RowMin(y),a1=RowMax(y); if(a0>=0){ if(a0<hmin)hmin=a0; if(a1>hmax)hmax=a1; } }
    cx=(hmin+hmax)/2; }
}

public static class Gen {
  static float Clamp(float v){ return v<0?0:(v>1?1:v); }

  // ---------------------------------------------------------------- ÁO
  public static Cv Clothes(Fr f,string style){
    var c=new Cv(); int t=f.top; bool robe=style!="tunic"; bool wide=style=="wide";
    for(int y=t+11;y<=t+18;y++) for(int x=0;x<32;x++) if(f.A[x,y]) c.Set(x,y,y>=t+16?0.80f:0.88f);
    if(robe){
      int last=Math.Min(t+21,f.bottom-2); int pmin=-1,pmax=-1;
      for(int y=t+19;y<=last;y++){
        int a0=f.RowMin(y),a1=f.RowMax(y); if(a0<0){a0=pmin;a1=pmax;} if(a0<0) continue; pmin=a0;pmax=a1;
        int flare=(y==last)?2:1; if(f.view==2) flare=(y==last)?2:1;
        for(int x=a0-flare;x<=a1+flare;x++) c.Set(x,y,(x%3==0)?0.72f:0.82f);
      }
    }
    if(wide){
      int maxExt=(f.view==2)?2:3;
      for(int y=t+13;y<=t+19;y++){
        int a0=f.RowMin(y),a1=f.RowMax(y); if(a0<0) continue;
        int ext=Math.Min(maxExt,(y-(t+13))/2+1);
        if(f.view==2){ for(int k=1;k<=ext;k++){ c.Set(a0-k+1,y,0.78f); c.Set(a1+k-1,y,0.78f);} }
        else { for(int k=1;k<=ext;k++){ c.Set(a0-k,y,0.78f); c.Set(a1+k,y,0.78f);} }
      }
    }
    c.Outline(0.34f);
    if(robe){                                       // đai lưng
      int y=t+17; for(int x=0;x<32;x++) if(c.Has(x,y)&&c.s[x,y]>0.4f) c.s[x,y]=0.52f;
      if(f.view==0){ c.Set(f.cx+1,t+18,0.45f); c.Set(f.cx+1,t+19,0.40f); }
      if(f.view==0){                                // cổ áo chéo
        int[,] v={{-2,12},{-1,13},{0,14},{1,13},{2,12}};
        for(int i=0;i<5;i++) if(c.Has(f.cx+v[i,0],t+v[i,1])) c.s[f.cx+v[i,0],t+v[i,1]]=1.0f; }
    } else if(f.view==0){                           // cổ tròn áo ngắn
      for(int x=f.cx-1;x<=f.cx+1;x++) if(c.Has(x,t+11)) c.s[x,t+11]=0.98f; }
    return c; }

  // ---------------------------------------------------------------- GIÀY
  public static Cv Shoes(Fr f,string style){
    var c=new Cv(); int win=f.bottom-4; int h=(style=="boot")?4:2;
    var seen=new bool[32,32];
    for(int y=win;y<=f.bottom;y++)for(int x=0;x<32;x++) if(f.A[x,y]&&!seen[x,y]){
      var st=new Stack<int[]>(); var pts=new List<int[]>(); st.Push(new int[]{x,y}); seen[x,y]=true; int maxy=y;
      while(st.Count>0){ var p=st.Pop(); pts.Add(p); if(p[1]>maxy)maxy=p[1];
        for(int dy=-1;dy<=1;dy++)for(int dx=-1;dx<=1;dx++){ int nx=p[0]+dx,ny=p[1]+dy;
          if(nx<0||ny<win||nx>=32||ny>f.bottom||seen[nx,ny]||!f.A[nx,ny]) continue; seen[nx,ny]=true; st.Push(new int[]{nx,ny}); } }
      foreach(var p in pts) if(p[1]>=maxy-h) c.Set(p[0],p[1],p[1]==maxy?0.50f:(p[1]==maxy-h&&h==4?1.0f:0.86f));
    }
    c.Outline(0.30f); return c; }

  // ---------------------------------------------------------------- TÓC
  static void Cap(Cv c,Fr f){
    int t=f.top;
    if(f.view==1){                                   // sau gáy: phủ kín đầu
      for(int y=t;y<=t+9;y++){ int a0=f.RowMin(y),a1=f.RowMax(y); if(a0<0) continue;
        int e=(y>=t+1&&y<=t+8)?1:0; for(int x=a0-e;x<=a1+e;x++) c.Set(x,y,(y==t+1&&x%4==1)?0.98f:0.80f); }
      return; }
    for(int y=t;y<=t+3;y++){ int a0=f.RowMin(y),a1=f.RowMax(y); if(a0<0) continue;
      int e=(y>=t+1)?1:0;
      for(int x=a0-((f.view==2)?e:e);x<=a1+((f.view==2)?0:e);x++) c.Set(x,y,(y==t+1&&x%4==1)?0.98f:0.80f); }
    if(f.view==0){
      int a0=f.RowMin(t+4),a1=f.RowMax(t+4);                              // mái
      for(int x=a0+1;x<=a1-1;x++) if((x-a0)%2==0&&(x<a0+3||x>a1-3||(x-a0)%4==0)) c.Set(x,t+4,0.74f);
      for(int y=t+4;y<=t+7;y++){ int b0=f.RowMin(y),b1=f.RowMax(y); if(b0<0) continue;  // tóc mai
        c.Set(b0+1,y,0.78f); c.Set(b1-1,y,0.78f); c.Set(b0,y,0.78f); c.Set(b1,y,0.78f); }
    } else {                                                              // nhìn ngang: nửa sau đầu
      for(int y=t+4;y<=t+9;y++){ int a0=f.RowMin(y),a1=f.RowMax(y); if(a0<0) continue;
        int mid=a0+(a1-a0)/2; for(int x=a0-1;x<=mid;x++) c.Set(x,y,0.76f); }
      int q0=f.RowMin(t+4),q1=f.RowMax(t+4); if(q0>=0) for(int x=q1-3;x<=q1-1;x+=2) c.Set(x,t+4,0.74f);
    }
  }
  static void Knot(Cv c,Fr f){
    int kx=(f.view==2)?f.cx-1:f.cx, ky=f.top-2;
    for(int dy=-2;dy<=1;dy++)for(int dx=-2;dx<=2;dx++){
      double v=(dx/2.6)*(dx/2.6)+(dy/2.0)*(dy/2.0); if(v<=1.0) c.Set(kx+dx,ky+dy,dy<=-1?0.95f:0.80f); }
  }

  public static void Hair(Fr f,string style,out Cv front,out Cv back){
    front=new Cv(); back=new Cv(); int t=f.top;
    Cap(front,f);
    if(style=="topknot") Knot(front,f);
    if(style=="long"){
      if(f.view==0){
        for(int y=t+2;y<=t+16;y++){ int x0=f.hmin-1,x1=f.hmax+1; if(y>=t+11){x0=f.hmin;x1=f.hmax;}
          for(int x=x0;x<=x1;x++) back.Set(x,y,(x%3==0)?0.66f:0.78f); }
        for(int y=t+9;y<=t+14;y++){ front.Set(f.hmin+1,y,0.74f); front.Set(f.hmin+2,y,0.80f); front.Set(f.hmax-2,y,0.80f); front.Set(f.hmax-1,y,0.74f); }
      } else if(f.view==1){
        for(int y=t+10;y<=t+17;y++){ int w=(y<=t+13)?3:((y<=t+16)?2:1);
          for(int x=f.cx-w;x<=f.cx+w;x++) front.Set(x,y,(x%2==0)?0.66f:0.80f); }
      } else {
        for(int y=t+3;y<=t+16;y++){ int x0=f.hmin-2,x1=f.hmin+((y>t+13)?2:4);
          for(int x=x0;x<=x1;x++) back.Set(x,y,(x%3==0)?0.66f:0.78f); }
      }
    }
    if(style=="ponytail"){
      if(f.view==1){
        for(int y=t+2;y<=t+14;y++){ int w=(y<=t+10)?1:0; for(int x=f.cx-w;x<=f.cx+w;x++) front.Set(x,y,(x==f.cx)?0.70f:0.82f); }
        for(int x=f.cx-2;x<=f.cx+2;x++) front.Set(x,t+3,0.42f);
      } else if(f.view==2){
        int[,] o={{-1,3},{-2,4},{-2,5},{-3,6},{-3,7},{-3,8},{-3,9},{-2,10},{-2,11},{-1,12}};
        for(int i=0;i<10;i++){ back.Set(f.hmin+o[i,0],t+o[i,1],0.80f); back.Set(f.hmin+o[i,0]+1,t+o[i,1],0.72f); }
        back.Set(f.hmin,t+3,0.42f); back.Set(f.hmin,t+4,0.42f);
      }
    }
    front.Outline(0.32f); back.Outline(0.32f);
  }

  // ---------------------------------------------------------------- SHEET
  static Fr[,] Load(string path,int n){
    var bmp=new Bitmap(path); var fr=new Fr[3,n];
    for(int r=0;r<3;r++)for(int i=0;i<n;i++){ var f=new Fr(); f.view=r;
      for(int y=0;y<32;y++)for(int x=0;x<32;x++) f.A[x,y]=bmp.GetPixel(i*32+x,r*32+y).A>40;
      f.Analyze(); fr[r,i]=f; }
    bmp.Dispose(); return fr; }

  static void Save(Cv[,] cs,int n,string path){
    var o=new Bitmap(n*32,96,PixelFormat.Format32bppArgb);
    for(int r=0;r<3;r++)for(int i=0;i<n;i++)for(int y=0;y<32;y++)for(int x=0;x<32;x++){ float v=cs[r,i].s[x,y];
      if(v>=0f){ int g=(int)(Clamp(v)*255f); o.SetPixel(i*32+x,r*32+y,Color.FromArgb(255,g,g,g)); } }
    o.Save(path,ImageFormat.Png); o.Dispose(); }

  public static void Run(string bodyDir,string outDir){
    Directory.CreateDirectory(outDir);
    string[] anims={"idle","walk","run"}; int[] ns={4,6,8};
    for(int a=0;a<3;a++){
      var fr=Load(Path.Combine(bodyDir,anims[a]+".png"),ns[a]); int n=ns[a];
      foreach(var st in new[]{"tunic","robe","wide"}){ var cs=new Cv[3,n];
        for(int r=0;r<3;r++)for(int i=0;i<n;i++) cs[r,i]=Clothes(fr[r,i],st);
        Save(cs,n,Path.Combine(outDir,"clothes_"+st+"_"+anims[a]+".png")); }
      foreach(var st in new[]{"cloth","boot"}){ var cs=new Cv[3,n];
        for(int r=0;r<3;r++)for(int i=0;i<n;i++) cs[r,i]=Shoes(fr[r,i],st);
        Save(cs,n,Path.Combine(outDir,"shoes_"+st+"_"+anims[a]+".png")); }
      foreach(var st in new[]{"topknot","long","ponytail"}){ var cf=new Cv[3,n]; var cb=new Cv[3,n];
        for(int r=0;r<3;r++)for(int i=0;i<n;i++){ Cv a1,b1; Hair(fr[r,i],st,out a1,out b1); cf[r,i]=a1; cb[r,i]=b1; }
        Save(cf,n,Path.Combine(outDir,"hairf_"+st+"_"+anims[a]+".png"));
        Save(cb,n,Path.Combine(outDir,"hairb_"+st+"_"+anims[a]+".png")); }
    }
  }
}
'@
Add-Type -AssemblyName System.Drawing
Add-Type -TypeDefinition $src -ReferencedAssemblies System.Drawing
$bodyDir = (Resolve-Path $Body).Path
$outRoot = [IO.Path]::GetFullPath($Out)
$fashion = Join-Path $outRoot "fashion"
[Gen]::Run($bodyDir, $fashion)

# Tạo SpriteFrames (.tres) cho từng bộ: sao chép base_frames.tres rồi đổi đường dẫn 3 sheet.
$base = Get-Content (Join-Path $outRoot "base_frames.tres") -Raw
$framesDir = Join-Path $fashion "frames"
New-Item -ItemType Directory -Force $framesDir | Out-Null
Get-ChildItem $fashion -Filter "*_idle.png" | ForEach-Object {
  $prefix = $_.Name -replace '_idle\.png$', ''
  $t = $base
  foreach ($a in 'idle','walk','run') {
    $t = $t.Replace("res://character/sheets/$a.png", "res://character/fashion/${prefix}_$a.png")
  }
  [IO.File]::WriteAllText((Join-Path $framesDir "$prefix.tres"), $t, (New-Object Text.UTF8Encoding($false)))
}
Write-Host "Da tao" (Get-ChildItem $fashion -Filter *.png).Count "sheet va" (Get-ChildItem $framesDir).Count "file frames"
