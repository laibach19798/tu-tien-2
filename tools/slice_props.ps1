# Cắt tileset.png thành các vật thể riêng theo vùng pixel liền nhau.
# Dùng: powershell -File tools\slice_props.ps1 [-Merge 0]
param([int]$Merge = 0,
      [string]$Image = "$PSScriptRoot\..\assets\tileset.png",
      [string]$Out = "$PSScriptRoot\..\assets\_raw2")
$src = @'
using System; using System.Drawing; using System.Drawing.Imaging; using System.Collections.Generic; using System.IO; using System.Text;
public static class Slicer {
 public static string Run(string path, string outDir, int merge) {
  var bmp=new Bitmap(path); int W=bmp.Width,H=bmp.Height;
  var bd=bmp.LockBits(new Rectangle(0,0,W,H),ImageLockMode.ReadOnly,PixelFormat.Format32bppArgb);
  byte[] px=new byte[bd.Stride*H]; System.Runtime.InteropServices.Marshal.Copy(bd.Scan0,px,0,px.Length); int st=bd.Stride; bmp.UnlockBits(bd);
  bool[] solid=new bool[W*H]; for(int y=0;y<H;y++)for(int x=0;x<W;x++) solid[y*W+x]=px[y*st+x*4+3]>40;
  bool[] d=new bool[W*H];
  for(int y=0;y<H;y++)for(int x=0;x<W;x++) if(solid[y*W+x]){ for(int dy=-merge;dy<=merge;dy++)for(int dx=-merge;dx<=merge;dx++){int nx=x+dx,ny=y+dy; if(nx>=0&&ny>=0&&nx<W&&ny<H) d[ny*W+nx]=true;} }
  int[] lab=new int[W*H]; var boxes=new List<int[]>(); var stack=new Stack<int>();
  for(int i=0;i<W*H;i++){ if(!d[i]||lab[i]!=0) continue; int id=boxes.Count+1; int[] b={W,H,0,0,0}; stack.Push(i); lab[i]=id;
   while(stack.Count>0){int p=stack.Pop(); int x=p%W,y=p/W; if(solid[p]){ if(x<b[0])b[0]=x; if(y<b[1])b[1]=y; if(x>b[2])b[2]=x; if(y>b[3])b[3]=y; b[4]++; }
    for(int dy=-1;dy<=1;dy++)for(int dx=-1;dx<=1;dx++){int nx=x+dx,ny=y+dy; if(nx<0||ny<0||nx>=W||ny>=H)continue; int q=ny*W+nx; if(d[q]&&lab[q]==0){lab[q]=id;stack.Push(q);}}}
   boxes.Add(b);}
  Directory.CreateDirectory(outDir); var sb=new StringBuilder(); int n=0;
  var list=new List<int[]>(); foreach(var b in boxes) if(b[4]>=30) list.Add(b);
  list.Sort((a,c)=>{int ra=a[1]/60, rc=c[1]/60; return ra!=rc? a[1].CompareTo(c[1]) : a[0].CompareTo(c[0]);});
  foreach(var b in list){ int w=b[2]-b[0]+1,h=b[3]-b[1]+1; var o=new Bitmap(w,h,PixelFormat.Format32bppArgb);
   for(int y=0;y<h;y++)for(int x=0;x<w;x++){ int sx=b[0]+x,sy=b[1]+y; int i=sy*st+sx*4; o.SetPixel(x,y,Color.FromArgb(px[i+3],px[i+2],px[i+1],px[i])); }
   string name="s"+(n++).ToString("D3"); o.Save(Path.Combine(outDir,name+".png"),ImageFormat.Png); o.Dispose();
   sb.AppendLine(name+","+b[0]+","+b[1]+","+w+","+h); }
  return sb.ToString(); }
}
'@
Add-Type -AssemblyName System.Drawing
Add-Type -TypeDefinition $src -ReferencedAssemblies System.Drawing
$r = [Slicer]::Run((Resolve-Path $Image).Path, [IO.Path]::GetFullPath($Out), $Merge)
$r | Set-Content (Join-Path ([IO.Path]::GetFullPath($Out)) "index.csv")
Write-Host (($r -split "`n" | ? { $_ }).Count) "sprites"
