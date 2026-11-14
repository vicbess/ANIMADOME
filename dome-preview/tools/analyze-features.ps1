param([string]$raw, [string]$out)
Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.Text;
using System.Globalization;
public static class An {
  const int SR = 22050, N = 4096, HOP = 2205; // 0.1 s
  static void FFT(double[] re, double[] im) {
    int n = re.Length;
    for (int i=1,j=0;i<n;i++){ int bit=n>>1; for(;(j&bit)!=0;bit>>=1) j^=bit; j^=bit; if(i<j){double t=re[i];re[i]=re[j];re[j]=t;t=im[i];im[i]=im[j];im[j]=t;} }
    for (int len=2;len<=n;len<<=1){ double ang=-2*Math.PI/len; double wr=Math.Cos(ang), wi=Math.Sin(ang);
      for (int i=0;i<n;i+=len){ double cr=1,ci=0; for(int j=0;j<len/2;j++){
        int a=i+j,b=i+j+len/2; double xr=re[b]*cr-im[b]*ci, xi=re[b]*ci+im[b]*cr;
        re[b]=re[a]-xr; im[b]=im[a]-xi; re[a]+=xr; im[a]+=xi; double nr=cr*wr-ci*wi; ci=cr*wi+ci*wr; cr=nr; } } }
  }
  public static string Run(string path) {
    byte[] bytes = File.ReadAllBytes(path);
    int total = bytes.Length/2; float[] x = new float[total];
    for (int i=0;i<total;i++) x[i] = BitConverter.ToInt16(bytes, i*2)/32768f;
    int frames = (total - N)/HOP;
    double[] win = new double[N]; for (int i=0;i<N;i++) win[i]=0.5-0.5*Math.Cos(2*Math.PI*i/(N-1));
    // bandes : sub 20-80, bass 80-250, lowmid 250-800, mid 800-3000, high 3000-10000
    double[] edges = {20,80,250,800,3000,10000};
    int nb = edges.Length-1;
    double[] re=new double[N], im=new double[N], prev=new double[N/2];
    var sb = new StringBuilder();
    var rms = new double[frames]; var bands = new double[frames][]; var flux=new double[frames]; var cent=new double[frames];
    for (int f=0; f<frames; f++) {
      double s=0; for (int i=0;i<N;i++){ double v=x[f*HOP+i]; s+=v*v; re[i]=v*win[i]; im[i]=0; }
      rms[f]=Math.Sqrt(s/N);
      FFT(re,im);
      bands[f]=new double[nb]; double fl=0, cn=0, cd=0;
      for (int k=1;k<N/2;k++) { double m=Math.Sqrt(re[k]*re[k]+im[k]*im[k]); double fr=k*(double)SR/N;
        for (int b=0;b<nb;b++) if (fr>=edges[b] && fr<edges[b+1]) bands[f][b]+=m*m;
        double d=m-prev[k]; if (d>0 && fr<8000) fl+=d; prev[k]=m; cn+=fr*m; cd+=m; }
      flux[f]=fl; cent[f]= cd>0? cn/cd : 0;
    }
    var ci = CultureInfo.InvariantCulture;
    sb.Append("{\"hop\":0.1,\"frames\":"+frames+",\"bands\":[\"sub\",\"bass\",\"lowmid\",\"mid\",\"high\"],");
    sb.Append("\"rmsDb\":["); for(int f=0;f<frames;f++) sb.Append((f>0?",":"")+(20*Math.Log10(rms[f]+1e-6)).ToString("F1",ci)); sb.Append("],");
    for (int b=0;b<nb;b++){ sb.Append("\"b"+b+"\":["); for(int f=0;f<frames;f++) sb.Append((f>0?",":"")+(10*Math.Log10(bands[f][b]+1e-3)).ToString("F1",ci)); sb.Append("],"); }
    sb.Append("\"flux\":["); for(int f=0;f<frames;f++) sb.Append((f>0?",":"")+flux[f].ToString("F2",ci)); sb.Append("],");
    sb.Append("\"centroid\":["); for(int f=0;f<frames;f++) sb.Append((f>0?",":"")+cent[f].ToString("F0",ci)); sb.Append("]}");
    return sb.ToString();
  }
}
'@
$j = [An]::Run($raw)
[System.IO.File]::WriteAllText($out, $j, (New-Object System.Text.UTF8Encoding($false)))
"ok " + (Get-Item $out).Length
