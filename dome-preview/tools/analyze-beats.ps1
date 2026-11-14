param([string]$raw, [string]$out)
Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.Text;
using System.Collections.Generic;
using System.Globalization;
public static class Bt {
  const int SR = 22050, N = 1024, HOP = 512;
  static void FFT(double[] re, double[] im) {
    int n = re.Length;
    for (int i=1,j=0;i<n;i++){ int bit=n>>1; for(;(j&bit)!=0;bit>>=1) j^=bit; j^=bit; if(i<j){double t=re[i];re[i]=re[j];re[j]=t;t=im[i];im[i]=im[j];im[j]=t;} }
    for (int len=2;len<=n;len<<=1){ double ang=-2*Math.PI/len; double wr=Math.Cos(ang), wi=Math.Sin(ang);
      for (int i=0;i<n;i+=len){ double cr=1,ci=0; for(int j=0;j<len/2;j++){
        int a=i+j,b=i+j+len/2; double xr=re[b]*cr-im[b]*ci, xi=re[b]*ci+im[b]*cr;
        re[b]=re[a]-xr; im[b]=im[a]-xi; re[a]+=xr; im[a]+=xi; double nr=cr*wr-ci*wi; ci=cr*wi+ci*wr; cr=nr; } } }
  }
  static List<double[]> Pick(double[] o, double hopSec, double minGap, double k) {
    int F = o.Length; var res = new List<double[]>(); int W = (int)(1.0/hopSec);
    double lastT = -10;
    for (int f=4; f<F-4; f++) {
      bool mx = true; for (int i=-4;i<=4;i++) if (o[f+i] > o[f]) { mx=false; break; }
      if (!mx) continue;
      double m=0, s=0; int c=0; for (int i=Math.Max(0,f-W); i<Math.Min(F,f+W); i++){ m+=o[i]; c++; } m/=c;
      for (int i=Math.Max(0,f-W); i<Math.Min(F,f+W); i++) s+=(o[i]-m)*(o[i]-m); s=Math.Sqrt(s/c);
      double thr = m + k*s; if (o[f] < thr) continue;
      double t = f*hopSec; if (t - lastT < minGap) { if (res.Count>0 && o[f] > res[res.Count-1][1]) { res[res.Count-1][0]=t; res[res.Count-1][1]=o[f]; lastT=t; } continue; }
      res.Add(new double[]{ t, o[f], (o[f]-m)/(s+1e-9) }); lastT = t;
    }
    return res;
  }
  public static string Run(string path) {
    byte[] bytes = File.ReadAllBytes(path); int total = bytes.Length/2; float[] x = new float[total];
    for (int i=0;i<total;i++) x[i] = BitConverter.ToInt16(bytes, i*2)/32768f;
    int F = (total - N)/HOP; double hopSec = (double)HOP/SR;
    double[] win = new double[N]; for (int i=0;i<N;i++) win[i]=0.5-0.5*Math.Cos(2*Math.PI*i/(N-1));
    double[] re=new double[N], im=new double[N];
    double[] bass=new double[F], high=new double[F];
    for (int f=0; f<F; f++) {
      for (int i=0;i<N;i++){ re[i]=x[f*HOP+i]*win[i]; im[i]=0; }
      FFT(re,im); double eb=0, eh=0;
      for (int k=1;k<N/2;k++){ double fr=k*(double)SR/N; double m2=re[k]*re[k]+im[k]*im[k];
        if (fr>=30 && fr<150) eb+=m2; else if (fr>=2500 && fr<9000) eh+=m2; }
      bass[f]=10*Math.Log10(eb+1e-3); high[f]=10*Math.Log10(eh+1e-3);
    }
    double[] ob=new double[F], oh=new double[F];
    for (int f=3; f<F; f++) { double mb=(bass[f-1]+bass[f-2]+bass[f-3])/3, mh=(high[f-1]+high[f-2]+high[f-3])/3; ob[f]=Math.Max(0,bass[f]-mb); oh[f]=Math.Max(0,high[f]-mh); }
    var kicks = Pick(ob, hopSec, 0.16, 1.0); var hits = Pick(oh, hopSec, 0.09, 1.3);
    var ci = CultureInfo.InvariantCulture; var sb = new StringBuilder();
    sb.Append("window.BEATS={kick:[");
    for (int i=0;i<kicks.Count;i++) sb.Append((i>0?",":"")+kicks[i][0].ToString("F2",ci));
    sb.Append("],kickS:["); for (int i=0;i<kicks.Count;i++) sb.Append((i>0?",":"")+Math.Min(9,Math.Max(1,(int)Math.Round(kicks[i][2]))));
    sb.Append("],hit:["); for (int i=0;i<hits.Count;i++) sb.Append((i>0?",":"")+hits[i][0].ToString("F2",ci));
    sb.Append("],hitS:["); for (int i=0;i<hits.Count;i++) sb.Append((i>0?",":"")+Math.Min(9,Math.Max(1,(int)Math.Round(hits[i][2]))));
    sb.Append("]};");
    Console.WriteLine("kicks=" + kicks.Count + " hits=" + hits.Count);
    return sb.ToString();
  }
}
'@
$j = [Bt]::Run($raw)
[System.IO.File]::WriteAllText($out, $j, (New-Object System.Text.UTF8Encoding($false)))
"ok " + (Get-Item $out).Length
