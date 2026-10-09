# Dọn sprite: chỉ giữ cụm pixel liền lớn nhất (loại mảnh vụn của sprite hàng xóm), rồi cắt sát viền.
# Dùng: powershell -File tools\clean_sprites.ps1 -Names tree_b,tree_big [-Bridge 3]
param([string[]]$Names,
      [int]$Bridge = 3,                     # khoảng hở (px) vẫn coi là cùng một vật
      [string]$Dir = "$PSScriptRoot\..\assets\props",
      [string]$DropBlue = "")               # tên sprite cần loại nền nước xanh (vd: lily)
$src = @'
using System; using System.Drawing; using System.Drawing.Imaging; using System.Collections.Generic;
public static class Cleaner {
 public static string Run(string path, int bridge, bool dropBlue) {
  Bitmap bmp; using (var tmp = new Bitmap(path)) bmp = new Bitmap(tmp);
  int W=bmp.Width,H=bmp.Height;
  var bd=bmp.LockBits(new Rectangle(0,0,W,H),ImageLockMode.ReadWrite,PixelFormat.Format32bppArgb);
  byte[] px=new byte[bd.Stride*H]; System.Runtime.InteropServices.Marshal.Copy(bd.Scan0,px,0,px.Length); int st=bd.Stride;
  bool[] solid=new bool[W*H];
  for(int y=0;y<H;y++)for(int x=0;x<W;x++){ int i=y*st+x*4; byte b=px[i],g=px[i+1],r=px[i+2],a=px[i+3];
    bool s=a>40; if(s&&dropBlue&&b>g+25) s=false; solid[y*W+x]=s; }
  int[] lab=new int[W*H]; var sizes=new List<int>(); var stack=new Stack<int>();
  for(int i=0;i<W*H;i++){ if(!solid[i]||lab[i]!=0) continue; int id=sizes.Count+1; int n=0; stack.Push(i); lab[i]=id;
   while(stack.Count>0){int p=stack.Pop(); n++; int x=p%W,y=p/W;
    for(int dy=-bridge;dy<=bridge;dy++)for(int dx=-bridge;dx<=bridge;dx++){int nx=x+dx,ny=y+dy; if(nx<0||ny<0||nx>=W||ny>=H)continue; int q=ny*W+nx; if(solid[q]&&lab[q]==0){lab[q]=id;stack.Push(q);}}}
   sizes.Add(n);}
  if(sizes.Count==0){bmp.UnlockBits(bd); bmp.Dispose(); return "empty";}
  int best=1; for(int k=0;k<sizes.Count;k++) if(sizes[k]>sizes[best-1]) best=k+1;
  int minx=W,miny=H,maxx=-1,maxy=-1;
  for(int y=0;y<H;y++)for(int x=0;x<W;x++){ if(lab[y*W+x]==best){ if(x<minx)minx=x; if(y<miny)miny=y; if(x>maxx)maxx=x; if(y>maxy)maxy=y; } }
  bmp.UnlockBits(bd);
  int w=maxx-minx+1,h=maxy-miny+1; var o=new Bitmap(w,h,PixelFormat.Format32bppArgb);
  for(int y=0;y<h;y++)for(int x=0;x<w;x++){ int sx=minx+x,sy=miny+y; int i=sy*st+sx*4;
    if(lab[sy*W+sx]==best) o.SetPixel(x,y,Color.FromArgb(px[i+3],px[i+2],px[i+1],px[i])); }
  bmp.Dispose(); o.Save(path+".tmp",ImageFormat.Png); o.Dispose();
  System.IO.File.Delete(path); System.IO.File.Move(path+".tmp",path);
  return W+"x"+H+" -> "+w+"x"+h+" ("+sizes.Count+" cum)"; }
}
'@
Add-Type -AssemblyName System.Drawing
Add-Type -TypeDefinition $src -ReferencedAssemblies System.Drawing
foreach ($n in ($Names -split ',')) {
  $p = Join-Path ([IO.Path]::GetFullPath($Dir)) "$n.png"
  Write-Host $n ([Cleaner]::Run($p, $Bridge, ($n -eq $DropBlue)))
}
