# Tao cac bien the mau cua bo do ve ca nguoi tu sheet bo lam goc (plb_navy_*): chi doi mau pixel xanh (quan ao),
# giu nguyen da/kiem. Dong thoi sua 2 frame huong dong bi ve quay lung (idle f3, walk f0) bang frame huong tay lat ngang.
# Dung: powershell -File tools\make_recolors.ps1
$root = Split-Path $PSScriptRoot -Parent
$fashion = Join-Path $root "character\hd\fashion"
$srcDir = Join-Path $root "backup\old_skins\fashion"
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @"
using System; using System.Drawing; using System.Drawing.Imaging;
public static class Recolor {
  static void ToHsv(double r,double g,double b,out double h,out double s,out double v){
    double mx=Math.Max(r,Math.Max(g,b)), mn=Math.Min(r,Math.Min(g,b)), d=mx-mn; v=mx; s=mx<=0?0:d/mx;
    if(d<=0){h=0;return;}
    if(mx==r) h=60*(((g-b)/d)%6); else if(mx==g) h=60*((b-r)/d+2); else h=60*((r-g)/d+4);
    if(h<0) h+=360;
  }
  static void FromHsv(double h,double s,double v,out double r,out double g,out double b){
    double c=v*s, x=c*(1-Math.Abs((h/60)%2-1)), m=v-c; double rr=0,gg=0,bb=0;
    if(h<60){rr=c;gg=x;} else if(h<120){rr=x;gg=c;} else if(h<180){gg=c;bb=x;} else if(h<240){gg=x;bb=c;} else if(h<300){rr=x;bb=c;} else {rr=c;bb=x;}
    r=rr+m; g=gg+m; b=bb+m;
  }
  // hue<0: giu mau goc. fixRow/fixCol: o can thay bang o (row 6, cung cot) lat ngang.
  public static void Run(string src,string dst,double hue,double sMul,double vMul,double vAdd,int fixCol){
    Bitmap bmp=new Bitmap(src); Bitmap o=new Bitmap(bmp.Width,bmp.Height,PixelFormat.Format32bppArgb);
    Rectangle rc=new Rectangle(0,0,bmp.Width,bmp.Height);
    BitmapData bd=bmp.LockBits(rc,ImageLockMode.ReadOnly,PixelFormat.Format32bppArgb);
    int n=bd.Stride*bmp.Height; byte[] px=new byte[n]; System.Runtime.InteropServices.Marshal.Copy(bd.Scan0,px,0,n); bmp.UnlockBits(bd);
    int st=bd.Stride;
    if(fixCol>=0){
      for(int y=0;y<64;y++) for(int x=0;x<64;x++){
        int s=((6*64+y)*st)+(fixCol*64+(63-x))*4; int d=((2*64+y)*st)+(fixCol*64+x)*4;
        for(int k=0;k<4;k++) px[d+k]=px[s+k];
      }
    }
    if(hue>=0){
      for(int i=0;i<n;i+=4){
        if(px[i+3]==0) continue;
        double h,s,v; ToHsv(px[i+2]/255.0,px[i+1]/255.0,px[i]/255.0,out h,out s,out v);
        if(h>=170 && h<=270 && s>0.12){
          double r,g,b; s=Math.Min(1,s*sMul); v=Math.Min(1,v*vMul+vAdd);
          FromHsv(hue,s,v,out r,out g,out b);
          px[i+2]=(byte)Math.Round(r*255); px[i+1]=(byte)Math.Round(g*255); px[i]=(byte)Math.Round(b*255);
        }
      }
    }
    BitmapData od=o.LockBits(rc,ImageLockMode.WriteOnly,PixelFormat.Format32bppArgb);
    System.Runtime.InteropServices.Marshal.Copy(px,0,od.Scan0,n); o.UnlockBits(od);
    o.Save(dst,ImageFormat.Png); o.Dispose(); bmp.Dispose();
  }
}
"@

# style, hue, sMul, vMul, vAdd
$variants = @(
  @("lam",     -1,  1.0, 1.0, 0.0),
  @("do",       355, 1.0, 1.0, 0.0),
  @("luc",      130, 0.9, 1.0, 0.0),
  @("vang",     42,  1.0, 1.15, 0.05),
  @("tim",      275, 0.9, 1.0, 0.0),
  @("trang",    210, 0.12, 1.25, 0.35),
  @("xam",      210, 0.08, 1.0, 0.1),
  @("thanh",    178, 0.9, 1.05, 0.0),
  @("bachvan",  195, 0.30, 1.2, 0.30),
  @("tudien",   262, 1.2, 0.6, 0.0),
  @("langvuong", 8, 1.15, 0.75, 0.0),
  @("linhmach", 203, 1.5, 1.2, 0.06)
)
foreach ($v in $variants) {
  foreach ($a in "idle","walk","run","slash") {
    $src = if ($a -eq "slash") { Join-Path $fashion "plb_navy_slash.png" } else { Join-Path $srcDir "plb_navy_$a.png" }
    $fix = -1; if ($a -eq "idle") { $fix = 3 } elseif ($a -eq "walk") { $fix = 0 }
    [Recolor]::Run($src, (Join-Path $fashion "clothes_$($v[0])_$a.png"), [double]$v[1], [double]$v[2], [double]$v[3], [double]$v[4], $fix)
  }
  Write-Host "ok $($v[0])"
}
