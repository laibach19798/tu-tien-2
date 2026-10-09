# Chuẩn bị sheet do AI vẽ có nền ca-rô giả và/hoặc xếp lưới nhiều hàng thành MỘT hàng sạch nền trong suốt.
#  - bỏ nền: loang từ mép ảnh qua các pixel xám trung tính (viền tối của nhân vật chặn không cho loang vào trong)
#  - mỗi nhân vật là một khung (thứ tự đọc: hàng trên trước, trái sang phải)
#  - khung bị dính nhau (kiếm khung này chui ra sau thân khung kia) được tách: phần kiếm dính được trả về khung đầu
# Dùng: powershell -File tools\prep_grid.ps1 -In raw.png -Out raw_slash_side.png -Frames 8
param([Parameter(Mandatory)][string]$In, [Parameter(Mandatory)][string]$Out, [int]$Frames = 0)
$src = @'
using System; using System.Drawing; using System.Drawing.Imaging; using System.Collections.Generic; using System.Linq; using System.Text;
public static class Prep {
  static bool Warm(Color c){ bool gold=c.B<80&&c.R>170&&c.G>100; return !gold && c.R>c.G+12 && c.R>c.B+20 && (c.R*30+c.G*59+c.B*11)/100>120; }   // (chu thich)
  public static string Run(string inPath,string outPath,int expect){
    var b=new Bitmap(inPath); int W=b.Width,H=b.Height; var bg=new bool[W*H]; var px=new Color[W*H];
    for(int y=0;y<H;y++)for(int x=0;x<W;x++) px[y*W+x]=b.GetPixel(x,y);
    Func<Color,bool> neutral=c=> c.A<20 || (Math.Abs(c.R-c.G)<10 && Math.Abs(c.G-c.B)<10 && (c.R*30+c.G*59+c.B*11)/100>=165);
    var st=new Stack<int>();
    for(int x=0;x<W;x++){ st.Push(x); st.Push((H-1)*W+x);} for(int y=0;y<H;y++){ st.Push(y*W); st.Push(y*W+W-1);}
    while(st.Count>0){ int p=st.Pop(); if(bg[p]||!neutral(px[p])) continue; bg[p]=true; int x=p%W,y=p/W;
      if(x>0)st.Push(p-1); if(x<W-1)st.Push(p+1); if(y>0)st.Push(p-W); if(y<H-1)st.Push(p+W); }
    // (chu thich)
    var lab=new int[W*H]; var comps=new List<int[]>(); // {id,area,x0,y0,x1,y1}
    for(int i=0;i<W*H;i++){ if(bg[i]||lab[i]!=0) continue; int id=comps.Count+1,area=0,x0=W,y0=H,x1=0,y1=0; st.Push(i); lab[i]=id;
      while(st.Count>0){ int p=st.Pop(); area++; int x=p%W,y=p/W; if(x<x0)x0=x; if(x>x1)x1=x; if(y<y0)y0=y; if(y>y1)y1=y;
        for(int dy=-1;dy<=1;dy++)for(int dx=-1;dx<=1;dx++){ int nx=x+dx,ny=y+dy; if(nx<0||ny<0||nx>=W||ny>=H)continue; int q=ny*W+nx; if(!bg[q]&&lab[q]==0){lab[q]=id;st.Push(q);} } }
      comps.Add(new int[]{id,area,x0,y0,x1,y1}); }
    var big=comps.Where(c=>c[1]>2500).ToList(); if(big.Count==0) return "LOI: khong tim thay nhan vat";
    // (chu thich)
    foreach(var c in comps) if(c[1]<=2500) for(int i=0;i<W*H;i++) if(lab[i]==c[0]) bg[i]=true;
    // frame owner map
    var own=new int[W*H]; for(int i=0;i<W*H;i++) own[i]=-1;
    var sortedRows=new List<List<int[]>>();
    foreach(var c in big.OrderBy(c=>(c[3]+c[5])/2)){ var row=sortedRows.FirstOrDefault(r=>Math.Abs((r[0][3]+r[0][5])/2-(c[3]+c[5])/2)<80); if(row==null){ row=new List<int[]>(); sortedRows.Add(row);} row.Add(c); }
    var frames=new List<int[]>(); var log=new StringBuilder(); double medW=big.Select(c=>(double)(c[4]-c[2]+1)).OrderBy(v=>v).ElementAt(big.Count/2);
    foreach(var row in sortedRows){ foreach(var c in row.OrderBy(c=>c[2])){ int w=c[4]-c[2]+1;
        if(w>medW*1.45){ // (chu thich)
          var dens=new int[W]; for(int y=c[3];y<=c[5];y++)for(int x=c[2];x<=c[4];x++) if(lab[y*W+x]==c[0]&&Warm(px[y*W+x])) dens[x]++;
          // (chu thich)
          int a=c[2]; while(a<=c[4]&&dens[a]<3) a++; int e=a; while(e<=c[4]&&dens[e]>=1) e++; // (chu thich)
          int gapStart=e; int gapEnd=gapStart; while(gapEnd<=c[4]&&dens[gapEnd]<3) gapEnd++;
          int cut=(gapStart+gapEnd)/2; log.AppendLine("tach khung dinh tai x="+cut+" (gap "+gapStart+".."+gapEnd+")");
          // (chu thich)
          int ya=H,yb=-1; for(int y=c[3];y<=c[5];y++) if(lab[y*W+cut-1]==c[0]) { if(y<ya)ya=y; if(y>yb)yb=y; }
          int f1=frames.Count, f2=f1+1;
          // (chu thich)
          int x4=c[4]; for(int pass=0;pass<2;pass++){ int y0s=(pass==0)?ya-30:yb+1, y1s=(pass==0)?ya-1:yb+30;
            for(int y=y0s;y<=y1s;y++) for(int x=cut+60;x<=c[4];x++){ if(y>=0&&y<H&&lab[y*W+x]==c[0]&&Warm(px[y*W+x])){ if(x<x4) x4=x; break; } } }
          log.AppendLine("mep trai khung 2 x="+x4+", kiem khung 1 o hang "+ya+".."+yb);
          for(int y=c[3];y<=c[5];y++)for(int x=c[2];x<=c[4];x++){ int i=y*W+x; if(lab[i]!=c[0]) continue;
            bool band=(y>=ya&&y<=yb);
            if(x<cut) own[i]=f1;
            else if(band&&x<x4-2) own[i]=f1;                                     // (chu thich)
            else if(band&&x<x4+26&&!Warm(px[i])&&(px[i].R*30+px[i].G*59+px[i].B*11)/100>150) own[i]=-1;
            else if(band&&x<x4+14&&!Warm(px[i])) own[i]=-1;   // (chu thich)
            else own[i]=f2; }          frames.Add(new int[]{c[0],c[2],c[3],c[4],c[5]}); frames.Add(new int[]{c[0],c[2],c[3],c[4],c[5]});
        } else { int f=frames.Count; for(int y=c[3];y<=c[5];y++)for(int x=c[2];x<=c[4];x++) if(lab[y*W+x]==c[0]) own[y*W+x]=f; frames.Add(new int[]{c[0],c[2],c[3],c[4],c[5]}); }
    } }
    // don cac manh roi nho (dom vien thua) trong tung khung
    { var seen=new bool[W*H]; var stk=new Stack<int>();
      for(int i=0;i<W*H;i++){ int f0=own[i]; if(f0<0||seen[i]) continue; var comp=new List<int>(); stk.Push(i); seen[i]=true;
        while(stk.Count>0){ int p=stk.Pop(); comp.Add(p); int x=p%W,y=p/W;
          for(int dy=-1;dy<=1;dy++)for(int dx=-1;dx<=1;dx++){ int nx=x+dx,ny=y+dy; if(nx<0||ny<0||nx>=W||ny>=H) continue; int q=ny*W+nx; if(!seen[q]&&own[q]==f0){ seen[q]=true; stk.Push(q);} } }
        if(comp.Count<150) foreach(int q in comp) own[q]=-1; } }
    int n=frames.Count; log.AppendLine("so khung="+n); if(expect>0&&n!=expect) log.AppendLine("CANH BAO: mong "+expect+" khung nhung tim thay "+n);
    // (chu thich)
    var bb=new int[n][]; for(int f=0;f<n;f++) bb[f]=new int[]{W,H,-1,-1};
    for(int y=0;y<H;y++)for(int x=0;x<W;x++){ int f=own[y*W+x]; if(f<0) continue; if(x<bb[f][0])bb[f][0]=x; if(y<bb[f][1])bb[f][1]=y; if(x>bb[f][2])bb[f][2]=x; if(y>bb[f][3])bb[f][3]=y; }
    int cellW=0,cellH=0; for(int f=0;f<n;f++){ cellW=Math.Max(cellW,bb[f][2]-bb[f][0]+1); cellH=Math.Max(cellH,bb[f][3]-bb[f][1]+1); }
    cellW+=24; var o=new Bitmap(cellW*n,cellH+20,PixelFormat.Format32bppArgb);
    for(int f=0;f<n;f++){ int ox=f*cellW+12; int oy=cellH+10-(bb[f][3]-bb[f][1]+1);   // (chu thich)
      for(int y=bb[f][1];y<=bb[f][3];y++)for(int x=bb[f][0];x<=bb[f][2];x++){ if(own[y*W+x]!=f) continue; var c=px[y*W+x]; o.SetPixel(ox+x-bb[f][0],oy+y-bb[f][1],Color.FromArgb(255,c.R,c.G,c.B)); } }
    o.Save(outPath,ImageFormat.Png); return log.ToString(); }
}
'@
Add-Type -AssemblyName System.Drawing
Add-Type -TypeDefinition $src -ReferencedAssemblies System.Drawing,System.Core
Write-Host ([Prep]::Run((Resolve-Path $In).Path, [IO.Path]::GetFullPath($Out), $Frames))
