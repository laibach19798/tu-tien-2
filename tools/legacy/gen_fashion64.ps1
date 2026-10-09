# Sinh các lớp trang phục (tóc, áo, giày) trực tiếp ở 64x64 từ hình bóng thân nhân vật mới.
# Mọi mốc (đầu, vai, hông, chân) tính theo tỉ lệ chiều cao thân nên khớp từng khung hình animation.
# Ảnh xuất ra là thang xám; màu tô bằng modulate trong game.
# Dùng: powershell -File tools\gen_fashion64.ps1   (đọc character\hd\sheets, ghi character\hd\fashion)
param([string]$Body = "$PSScriptRoot\..\character\hd\sheets",
      [string]$Out = "$PSScriptRoot\..\character\hd\fashion")
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
  public bool[,] A=new bool[64,64]; public bool empty; public bool[,] foot,shin; public int view,T=99,B=-1,H,hr,headEnd,ts,te,ls,hmin,hmax,cx; public double u;
  public bool a(int x,int y){ return x>=0&&y>=0&&x<64&&y<64&&A[x,y]; }
  public int RowMin(int y){ for(int x=0;x<64;x++) if(A[x,y]) return x; return -1; }
  public int RowMax(int y){ for(int x=63;x>=0;x--) if(A[x,y]) return x; return -1; }
  public int U(double v){ return (int)Math.Round(v*u); }
  public void Analyze(){
    for(int y=0;y<64;y++)for(int x=0;x<64;x++) if(A[x,y]){ if(y<T)T=y; if(y>B)B=y; }
    if(B<0){ empty=true; return; }
    H=B-T+1; u=H/24.0; hr=(int)Math.Round(0.52*H); headEnd=T+hr-1; ts=T+hr; te=ts+(int)Math.Round(0.27*H)-1; ls=te+1;
    hmin=99;hmax=-1; for(int y=T+U(1.5);y<=T+U(6);y++){ int a0=RowMin(y),a1=RowMax(y); if(a0>=0){ if(a0<hmin)hmin=a0; if(a1>hmax)hmax=a1; } }
    // robust head center from the top rows: a raised arm or a long sword can widen the silhouette next to the head
    double sx=0; int scn=0; for(int y=T;y<=T+3;y++) for(int x=0;x<64;x++) if(A[x,y]){ sx+=x; scn++; }
    int cxTop=scn>0?(int)Math.Round(sx/scn):(hmin+hmax)/2;
    if(hmax-hmin+1>27||Math.Abs(cxTop-(hmin+hmax)/2)>3){ hmin=cxTop-12; hmax=cxTop+12; }
    cx=(hmin+hmax)/2; }
  // head bounds on row y limited to an ellipse around the head center (ignores arms and weapons next to the head)
  public int HL(int y){ int m=RowMin(y); if(m<0) return -1; double k=(y-(T+12.5))/13.0; double hw=13.0*Math.Sqrt(Math.Max(0.0,1.0-k*k)); return Math.Max(m,(int)Math.Floor(cx-hw-1)); }
  public int HR(int y){ int m=RowMax(y); if(m<0) return -1; double k=(y-(T+12.5))/13.0; double hw=13.0*Math.Sqrt(Math.Max(0.0,1.0-k*k)); return Math.Min(m,(int)Math.Ceiling(cx+hw+1)); }
}

public static class Gen {
  public static string Dbg="";
  static float Cl(float v){ return v<0?0:(v>1?1:v); }

  // ---------------------------------------------------------------- ÁO
  public static Cv Clothes(Fr f,string style){
    if(f.empty) return new Cv();
    var c=new Cv(); bool robe=style!="tunic", wide=style=="wide"; int th=(int)Math.Round(0.4*(f.hmax-f.hmin+1));
    for(int y=f.ts+1;y<=f.te;y++){
      int shortSleeveEnd=f.ts+f.U(3);
      for(int x=0;x<64;x++) if(f.A[x,y]){
        bool arm=f.view!=2&&Math.Abs(x-f.cx)>th;
        if(arm){ if(!robe&&y>shortSleeveEnd) continue; if(robe&&y>f.te-f.U(2)) continue; }
        c.Set(x,y,y>=f.ts+f.U(4)?0.80f:0.88f); }
    }
    if(robe){
      int last=Math.Min(f.ls+f.U(3)-1,f.B-f.U(2)); int pmin=-1,pmax=-1;
      for(int y=f.ls;y<=last;y++){ int a0=f.RowMin(y),a1=f.RowMax(y); if(a0<0){a0=pmin;a1=pmax;} if(a0<0) continue;
        if(f.view==2){ int b0=f.RowMin(f.te),b1=f.RowMax(f.te); a0=Math.Max(a0,b0-2); a1=Math.Min(a1,b1+2); }   // nhìn ngang: vạt áo không chìa theo chân đang dạng
        pmin=a0;pmax=a1;
        int flare=2+(y-f.ls)/3+((y==last)?(f.view==2?1:2):0);
        for(int x=a0-flare;x<=a1+flare;x++) c.Set(x,y,((x-f.cx)%5==0)?0.70f:(y==last?0.62f:0.80f)); }
    }
    if(wide){
      int y0=f.ts+f.U(2),y1=f.ts+f.U(7),maxExt=(f.view==2)?4:7;
      for(int y=y0;y<=y1;y++){ int a0=f.RowMin(y),a1=f.RowMax(y); if(a0<0) continue;
        int ext=Math.Min(maxExt,2+(y-y0)/2);
        if(f.view==2){ for(int k=0;k<ext;k++){ c.Set(a0-k,y,0.76f); c.Set(a1+k,y,0.76f);} }
        else { for(int k=1;k<=ext;k++){ c.Set(a0-k,y,0.76f); c.Set(a1+k,y,0.76f);} } }
    }
    c.Outline(0.34f);
    if(robe){
      for(int y=f.te-3;y<=f.te-2;y++) for(int x=0;x<64;x++) if(c.Has(x,y)&&c.s[x,y]>0.4f&&Math.Abs(x-f.cx)<=th+1) c.s[x,y]=0.52f;   // đai lưng
      if(f.view==0){ for(int y=f.te-4;y<=f.te-1;y++) for(int x=f.cx+3;x<=f.cx+5;x++) c.SetIf(x,y,0.42f);
        for(int y=f.te;y<=f.te+4;y++){ c.Set(f.cx+4,y,0.40f); c.Set(f.cx+5,y,0.40f); } }
      if(f.view==0){ for(int i=0;i<=6;i++){ c.SetIf(f.cx-6+i,f.ts+1+i,1.0f); c.SetIf(f.cx-5+i,f.ts+1+i,1.0f); c.SetIf(f.cx+6-i,f.ts+1+i,1.0f); c.SetIf(f.cx+5-i,f.ts+1+i,1.0f); } }
    } else if(f.view==0){ for(int x=f.cx-4;x<=f.cx+4;x++){ c.SetIf(x,f.ts+1,0.98f); c.SetIf(x,f.ts+2,0.95f); } }
    if(f.view==1){ for(int y=f.ts+3;y<=f.te-4;y++) c.SetIf(f.cx,y,0.66f); }
    return c; }

  // Tìm bàn chân bằng đường viền đáy của hai chân: lấy tối đa hai "mặt phẳng" thấp nhất, tách rời nhau.
  // Mặt phẳng thấp nhất thường là chân chống đất; mặt phẳng thứ hai là chân kia (kể cả khi đang nhấc lên).
  static void FootMasks(Fr f){
    int y0=f.B-12; var yl=new int[64]; for(int x=0;x<64;x++){ yl[x]=-1; for(int y=f.B;y>=y0;y--) if(f.A[x,y]){ yl[x]=y; break; } }
    var used=new bool[64]; f.foot=new bool[64,64]; f.shin=new bool[64,64];
    for(int pass=0;pass<2;pass++){
      int bx=-1,bp=-1; for(int x=0;x<64;x++) if(!used[x]&&yl[x]>bp&&yl[x]>=y0+4){ bp=yl[x]; bx=x; }
      if(bx<0) break;
      int a=bx,b=bx; while(a-1>=0&&!used[a-1]&&yl[a-1]>=bp-1) a--; while(b+1<64&&!used[b+1]&&yl[b+1]>=bp-1) b++;
      Gen.Dbg+="view"+f.view+" B="+f.B+" plateau"+pass+" x["+a+".."+b+"] y="+bp+"\n";
      for(int x=Math.Max(0,a-1);x<=Math.Min(63,b+1);x++) for(int y=bp-3;y<=bp;y++) if(f.A[x,y]) f.foot[x,y]=true;
      for(int x=Math.Max(0,a-2);x<=Math.Min(63,b+2);x++) for(int y=bp-6;y<=bp;y++) if(f.A[x,y]) f.shin[x,y]=true;
      for(int x=Math.Max(0,a-2);x<=Math.Min(63,b+2);x++) used[x]=true;
    }
  }
  // ---------------------------------------------------------------- GIÀY
  public static Cv Shoes(Fr f,string style){
    if(f.empty) return new Cv();
    var c=new Cv(); int win=f.B-8; int h=(style=="boot")?5:3; var seen=new bool[64,64];
    if(f.foot!=null){                                                           // có mặt nạ bàn chân: phủ đúng từng bàn chân, kể cả chân đang nhấc
      bool boot=style=="boot";
      for(int y=0;y<64;y++)for(int x=0;x<64;x++) if(f.A[x,y]&&(f.foot[x,y]||(boot&&f.shin[x,y]))) c.Set(x,y,0.86f);
      for(int y=0;y<64;y++)for(int x=0;x<64;x++) if(c.Has(x,y)){ if(!c.Has(x,y+1)) c.s[x,y]=0.50f; else if(boot&&!c.Has(x,y-1)) c.s[x,y]=1.0f; }
      c.Outline(0.30f); return c; }
    for(int y=win;y<=f.B;y++)for(int x=0;x<64;x++) if(f.A[x,y]&&!seen[x,y]){
      var st=new Stack<int[]>(); var pts=new List<int[]>(); st.Push(new int[]{x,y}); seen[x,y]=true; int maxy=y;
      while(st.Count>0){ var p=st.Pop(); pts.Add(p); if(p[1]>maxy)maxy=p[1];
        for(int dy=-1;dy<=1;dy++)for(int dx=-1;dx<=1;dx++){ int nx=p[0]+dx,ny=p[1]+dy;
          if(nx<0||ny<win||nx>=64||ny>f.B||seen[nx,ny]||!f.A[nx,ny]) continue; seen[nx,ny]=true; st.Push(new int[]{nx,ny}); } }
      foreach(var p in pts) if(p[1]>=maxy-h){ float v=0.86f; if(p[1]==maxy) v=0.46f; else if(p[1]==maxy-1) v=0.70f; else if(style=="boot"&&p[1]<=maxy-h+1) v=1.0f; c.Set(p[0],p[1],v); }
    }
    c.Outline(0.30f); return c; }

  // ---------------------------------------------------------------- TÓC
  static void Cap(Cv c,Fr f){
    int T=f.T; int capEnd=T+f.U(4); int end=f.headEnd-f.U(1.5);
    Func<int,float> sh=y=> (y==T+1)?0.98f:0.80f;
    if(f.view==1){                                                       // phía sau: phủ kín đầu
      for(int y=T;y<=end;y++){ int a0=f.HL(y),a1=f.HR(y); if(a0<0) continue;
        if(y>=T+f.U(7)){ a0=f.hmin; a1=f.hmax; }
        int e=(y>T&&y<=capEnd)?2:((y>capEnd)?1:0);
        for(int x=a0-e;x<=a1+e;x++) c.Set(x,y,(y==T+1&&x%6<2)?0.98f:(((x-f.cx)%6==0&&y>T+2)?0.66f:0.80f)); }
      return; }
    for(int y=T;y<=capEnd;y++){ int a0=f.HL(y),a1=f.HR(y); if(a0<0) continue;
      int e=(y==T)?0:((y<=T+2)?1:2); int eb=e; int ef=(f.view==2)?0:e;
      for(int x=a0-eb;x<=a1+ef;x++) c.Set(x,y,(y==T+1&&x%6<2)?0.98f:(((x-f.cx)%6==0&&y>T+2)?0.68f:0.80f)); }
    if(f.view==0){
      for(int y=capEnd+1;y<=capEnd+2;y++){ int a0=f.hmin,a1=f.hmax;                       // mái
        for(int x=a0+1;x<=a1-1;x++){ int k=(x-a0+((y==capEnd+1)?0:3))/3; if(k%2==0) c.Set(x,y,0.74f); } }
      for(int y=capEnd+1;y<=T+f.U(8);y++){ for(int k=1;k<=3;k++){ c.Set(f.hmin+k,y,0.78f); c.Set(f.hmax-k,y,0.78f); } }   // tóc mai
      for(int y=capEnd+1;y<=capEnd+2;y++){ c.Set(f.cx,y,-1f); c.Set(f.cx-1,y,-1f); }                                   // rẽ ngôi
    } else {
      for(int y=capEnd+1;y<=end;y++){ int a0=f.HL(y),a1=f.HR(y); if(a0<0) continue; if(y>=T+f.U(7)) a0=f.hmin;
        int mid=a0+(int)((a1-a0)*0.48); for(int x=a0-2;x<=mid;x++) c.Set(x,y,(((x-f.cx)%6==0)?0.68f:0.78f)); }
      int q1=f.HR(capEnd+1); if(q1>=0) for(int x=q1-8;x<=q1-1;x++) if((x/3)%2==0) c.Set(x,capEnd+1,0.74f);
    }
  }
  static void Knot(Cv c,Fr f){
    int kx=(f.view==2)?f.cx-3:f.cx, ky=f.T-f.U(1), rx=f.U(2.8), ry=f.U(2.2);
    for(int dy=-ry;dy<=ry;dy++)for(int dx=-rx;dx<=rx;dx++){ double v=(dx/(double)rx)*(dx/(double)rx)+(dy/(double)ry)*(dy/(double)ry);
      if(v<=1.0) c.Set(kx+dx,ky+dy,(dy<0&&dx<1)?0.98f:0.80f); }
    for(int x=kx-3;x<=kx+3;x++){ c.SetIf(x,f.T+1,0.45f); c.SetIf(x,f.T+2,0.45f); }       // dây buộc
  }

  public static void Hair(Fr f,string style,out Cv front,out Cv back){
    front=new Cv(); back=new Cv(); if(f.empty) return; int T=f.T;
    Cap(front,f);
    if(style=="topknot") Knot(front,f);
    if(style=="long"){
      if(f.view==0){       // lớp sau: vòm tóc ôm hai bên đầu rồi thu nhỏ dần xuống vai
        int yEnd=f.ts+f.U(4);
        for(int y=T+3;y<=yEnd;y++){ int shrink=(y<=T+f.U(7))?0:(y-(T+f.U(7)))/2; int ext=Math.Max(0,3-shrink/2);
          int x0=f.hmin-ext+Math.Max(0,shrink-6),x1=f.hmax+ext-Math.Max(0,shrink-6);
          for(int x=x0;x<=x1;x++) back.Set(x,y,(x%4==0)?0.66f:0.78f); }
        for(int y=T+f.U(7);y<=f.ts+f.U(3);y++){ int t=(y-(T+f.U(7)))/6; for(int k=3;k<=4;k++){ front.Set(f.hmin+k-t,y,(k%2==0)?0.74f:0.80f); front.Set(f.hmax-k+t,y,(k%2==0)?0.74f:0.80f); } }
      } else if(f.view==1){ // phía sau: suối tóc rủ xuống lưng, thon dần
        int y0=f.headEnd-f.U(1), y1=f.ts+f.U(6);
        for(int y=y0;y<=y1;y++){ int w=Math.Max(2,9-(y-y0)*7/Math.Max(1,y1-y0)); if(y>y1-2) w=Math.Max(1,w-1);
          for(int x=f.cx-w;x<=f.cx+w;x++) front.Set(x,y,(Math.Abs(x-f.cx)%3==0)?0.66f:0.80f); }
      } else {              // nhìn ngang: tóc rủ sau gáy, thon dần
        int yEnd=f.ts+f.U(4);
        for(int y=T+f.U(1.5);y<=yEnd;y++){ int taper=Math.Max(0,(y-(T+f.U(5)))/3); int x0=f.hmin-f.U(2)+taper,x1=f.hmin+f.U(1.5)+(y>yEnd-3?-1:0);
          for(int x=x0;x<=x1;x++) back.Set(x,y,(x%3==0)?0.66f:0.78f); }
      }
    }
    if(style=="ponytail"){
      if(f.view==1){
        for(int y=T+f.U(1);y<=f.ts+f.U(6);y++){ int w=(y<=f.ts)?2:1; for(int x=f.cx-w;x<=f.cx+w;x++) front.Set(x,y,(x==f.cx)?0.70f:0.82f); }
        for(int x=f.cx-3;x<=f.cx+3;x++){ front.Set(x,T+f.U(2),0.42f); front.Set(x,T+f.U(2)+1,0.42f); }
      } else if(f.view==2){
        int[,] o={{-1,3},{-2,4},{-2,5},{-3,6},{-3,7},{-3,8},{-3,9},{-2,10},{-2,11},{-1,12}};
        for(int i=0;i<10;i++){ int px=f.hmin+o[i,0]*2, py=T+o[i,1]*2+2; for(int dy=0;dy<2;dy++)for(int dx=0;dx<4;dx++) back.Set(px+dx,py+dy,(dx<2)?0.80f:0.70f); }
        for(int y=T+f.U(2);y<=T+f.U(2)+3;y++){ back.Set(f.hmin,y,0.42f); back.Set(f.hmin+1,y,0.42f); }
      }
    }
    front.Outline(0.32f); back.Outline(0.32f);
  }

  // ---------------------------------------------------------------- SHEET
  static Fr[,] Load(string path,int n){
    var bmp=new Bitmap(path); var fr=new Fr[3,n];
    string mp=path.Replace(".png","_legmask.png"); Bitmap mk=File.Exists(mp)?new Bitmap(mp):null;
    string wp=path.Replace(".png","_weapon.png"); Bitmap wk=File.Exists(wp)?new Bitmap(wp):null;
    for(int r=0;r<3;r++)for(int i=0;i<n;i++){ var f=new Fr(); f.view=r;
      for(int y=0;y<64;y++)for(int x=0;x<64;x++) f.A[x,y]=bmp.GetPixel(i*64+x,r*64+y).A>40&&!(wk!=null&&wk.GetPixel(i*64+x,r*64+y).A>0);
      if(mk!=null&&r==2){ f.foot=new bool[64,64]; f.shin=new bool[64,64]; for(int y=0;y<64;y++)for(int x=0;x<64;x++){ var m=mk.GetPixel(i*64+x,r*64+y); if(m.A>0){ f.foot[x,y]=m.R>128; f.shin[x,y]=m.G>128; } } }
      f.Analyze(); if(!f.empty&&f.foot==null) FootMasks(f); fr[r,i]=f; }
    if(mk!=null) mk.Dispose(); if(wk!=null) wk.Dispose(); bmp.Dispose(); return fr; }
  static void Save(Cv[,] cs,int n,string path){
    var o=new Bitmap(n*64,192,PixelFormat.Format32bppArgb);
    for(int r=0;r<3;r++)for(int i=0;i<n;i++)for(int y=0;y<64;y++)for(int x=0;x<64;x++){ float v=cs[r,i].s[x,y];
      if(v>=0f){ int g=(int)(Cl(v)*255f); o.SetPixel(i*64+x,r*64+y,Color.FromArgb(255,g,g,g)); } }
    o.Save(path,ImageFormat.Png); o.Dispose(); }
  public static void Run(string bodyDir,string outDir){
    Directory.CreateDirectory(outDir);
    var animList=new List<string>{"idle","walk","run"}; var nList=new List<int>{4,6,8};
    foreach(var ex in new[]{"slash","slash_heavy","thrust","cast","ultimate"}){ string ep=Path.Combine(bodyDir,ex+".png"); if(File.Exists(ep)){ using(var eb=new Bitmap(ep)){ animList.Add(ex); nList.Add(eb.Width/64); } } }
    string[] anims=animList.ToArray(); int[] ns=nList.ToArray();
    for(int a=0;a<anims.Length;a++){ var fr=Load(Path.Combine(bodyDir,anims[a]+".png"),ns[a]); int n=ns[a];      foreach(var st in new[]{"tunic","robe","wide"}){ var cs=new Cv[3,n]; for(int r=0;r<3;r++)for(int i=0;i<n;i++) cs[r,i]=Clothes(fr[r,i],st); Save(cs,n,Path.Combine(outDir,"clothes_"+st+"_"+anims[a]+".png")); }
      foreach(var st in new[]{"cloth","boot"}){ var cs=new Cv[3,n]; for(int r=0;r<3;r++)for(int i=0;i<n;i++) cs[r,i]=Shoes(fr[r,i],st); Save(cs,n,Path.Combine(outDir,"shoes_"+st+"_"+anims[a]+".png")); }
      foreach(var st in new[]{"topknot","long","ponytail"}){ var cf=new Cv[3,n]; var cb=new Cv[3,n];
        for(int r=0;r<3;r++)for(int i=0;i<n;i++){ Cv a1,b1; Hair(fr[r,i],st,out a1,out b1); cf[r,i]=a1; cb[r,i]=b1; }
        Save(cf,n,Path.Combine(outDir,"hairf_"+st+"_"+anims[a]+".png")); Save(cb,n,Path.Combine(outDir,"hairb_"+st+"_"+anims[a]+".png")); }
    }
  }
}
'@
Add-Type -AssemblyName System.Drawing
Add-Type -TypeDefinition $src -ReferencedAssemblies System.Drawing
[Gen]::Run((Resolve-Path $Body).Path, [IO.Path]::GetFullPath($Out))
if ($env:FASHION_DEBUG) { [IO.File]::WriteAllText('E:\game 2d\fashion_debug.txt',[Gen]::Dbg) }
Write-Host "Da tao" (Get-ChildItem ([IO.Path]::GetFullPath($Out)) -Filter *.png).Count "sheet"
