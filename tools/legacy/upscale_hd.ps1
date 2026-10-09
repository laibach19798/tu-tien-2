# Tạo bản "HD" 64x64 từ sheet 32x32: làm mịn đường chéo (EPX/Scale2x), thêm ánh sáng
# (sáng mép trên-trái, tối mép dưới-phải) và gradient sáng trên - tối dưới để hợp nét vẽ của tileset.
# Dùng: powershell -File tools\upscale_hd.ps1 -InDir <thư mục sheet> -OutDir <thư mục xuất>
param([Parameter(Mandatory)][string]$InDir, [Parameter(Mandatory)][string]$OutDir)
$src = @'
using System; using System.Drawing; using System.Drawing.Imaging; using System.IO;
public static class Hd {
  static int[] Read(Bitmap b){ int W=b.Width,H=b.Height; var a=new int[W*H];
    for(int y=0;y<H;y++)for(int x=0;x<W;x++){ var c=b.GetPixel(x,y); a[y*W+x]= c.A<40 ? 0 : (255<<24)|(c.R<<16)|(c.G<<8)|c.B; } return a; }
  static int G(int[] a,int W,int H,int x,int y){ if(x<0||y<0||x>=W||y>=H) return 0; return a[y*W+x]; }
  static int Lum(int c){ return (((c>>16)&255)*30 + ((c>>8)&255)*59 + (c&255)*11)/100; }
  static int Mix(int c,float t){ // t>0 sáng hơn, t<0 tối hơn
    int r=(c>>16)&255,g=(c>>8)&255,b=c&255;
    if(t>=0){ r+=(int)((255-r)*t); g+=(int)((255-g)*t); b+=(int)((255-b)*t); }
    else { r=(int)(r*(1+t)); g=(int)(g*(1+t)); b=(int)(b*(1+t)); }
    return (255<<24)|(r<<16)|(g<<8)|b; }
  public static void Run(string inPath,string outPath){
    var bmp=new Bitmap(inPath); int W=bmp.Width,H=bmp.Height; var p=Read(bmp); bmp.Dispose();
    int W2=W*2,H2=H*2; var o=new int[W2*H2];
    for(int y=0;y<H;y++)for(int x=0;x<W;x++){                       // EPX
      int P=p[y*W+x],A=G(p,W,H,x,y-1),B=G(p,W,H,x+1,y),C=G(p,W,H,x-1,y),D=G(p,W,H,x,y+1);
      int p1=P,p2=P,p3=P,p4=P;
      if(C==A&&C!=D&&A!=B) p1=A; if(A==B&&A!=C&&B!=D) p2=B; if(D==C&&D!=B&&C!=A) p3=C; if(B==D&&B!=A&&D!=C) p4=D;
      o[(2*y)*W2+2*x]=p1; o[(2*y)*W2+2*x+1]=p2; o[(2*y+1)*W2+2*x]=p3; o[(2*y+1)*W2+2*x+1]=p4; }
    var r=new int[W2*H2]; Array.Copy(o,r,o.Length);
    // mỗi khung 64x64: gradient + ánh sáng
    for(int fy=0;fy<H2/64;fy++)for(int fx=0;fx<W2/64;fx++){
      int x0=fx*64,y0=fy*64,top=64,bot=-1;
      for(int y=0;y<64;y++)for(int x=0;x<64;x++) if(o[(y0+y)*W2+x0+x]!=0){ if(y<top)top=y; if(y>bot)bot=y; }
      if(bot<0) continue;
      for(int y=0;y<64;y++)for(int x=0;x<64;x++){
        int gx=x0+x,gy=y0+y; int c=o[gy*W2+gx]; if(c==0) continue;
        if(Lum(c)<85) continue;                                         // giữ nét viền
        float t=0.05f-0.12f*(y-top)/(float)Math.Max(1,bot-top);        // sáng trên, tối dưới
        bool tl=(G(o,W2,H2,gx-1,gy-1)==0)||(G(o,W2,H2,gx-2,gy-2)==0)||(G(o,W2,H2,gx-1,gy)==0&&G(o,W2,H2,gx,gy-1)==0);
        bool br=(G(o,W2,H2,gx+1,gy+1)==0)||(G(o,W2,H2,gx+2,gy+2)==0)||(G(o,W2,H2,gx+1,gy)==0&&G(o,W2,H2,gx,gy+1)==0);
        if(tl&&!br) t+=0.16f; else if(br&&!tl) t-=0.14f;
        r[gy*W2+gx]=Mix(c,t); }
    }
    var ob=new Bitmap(W2,H2,PixelFormat.Format32bppArgb);
    for(int y=0;y<H2;y++)for(int x=0;x<W2;x++){ int c=r[y*W2+x]; ob.SetPixel(x,y, c==0?Color.FromArgb(0,0,0,0):Color.FromArgb(255,(c>>16)&255,(c>>8)&255,c&255)); }
    ob.Save(outPath,ImageFormat.Png); ob.Dispose(); }
}
'@
Add-Type -AssemblyName System.Drawing
Add-Type -TypeDefinition $src -ReferencedAssemblies System.Drawing
$in = (Resolve-Path $InDir).Path
$out = [IO.Path]::GetFullPath($OutDir)
New-Item -ItemType Directory -Force $out | Out-Null
Get-ChildItem $in -Filter *.png | ForEach-Object { [Hd]::Run($_.FullName, (Join-Path $out $_.Name)) }
Write-Host "Xong:" (Get-ChildItem $out -Filter *.png).Count "file ->" $out
