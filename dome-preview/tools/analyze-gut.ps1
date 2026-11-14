# Détecte la « progression » d'un son guttural / glitché (bande 150-1500 Hz, hors grosse caisse) : flux spectral relatif, 50 images/s.
# Sert à faire avancer les coulées de lave par à-coups EN SUIVANT CE SON (et pas le beat).
param([Parameter(Mandatory)][string]$raw, [Parameter(Mandatory)][string]$out)
Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.Text;
using System.Globalization;
public static class Gut {
  const int SR = 22050, N = 1024, HOP = 256;
  static void FFT(double[] re, double[] im) {
    int n = re.Length;
    for (int i=1,j=0;i<n;i++){ int bit=n>>1; for(;(j&bit)!=0;bit>>=1) j^=bit; j^=bit; if(i<j){double t=re[i];re[i]=re[j];re[j]=t;t=im[i];im[i]=im[j];im[j]=t;} }
    for (int len=2;len<=n;len<<=1){ double ang=-2*Math.PI/len; double wr=Math.Cos(ang), wi=Math.Sin(ang);
      for (int i=0;i<n;i+=len){ double cr=1,ci=0; for(int j=0;j<len/2;j++){
        int a=i+j,b=i+j+len/2; double xr=re[b]*cr-im[b]*ci, xi=re[b]*ci+im[b]*cr;
        re[b]=re[a]-xr; im[b]=im[a]-xi; re[a]+=xr; im[a]+=xi; double nr=cr*wr-ci*wi; ci=cr*wi+ci*wr; cr=nr; } } }
  }
  public static string Run(string path) {
    byte[] bytes = File.ReadAllBytes(path); int total = bytes.Length/2; float[] x = new float[total];
    for (int i=0;i<total;i++) x[i] = BitConverter.ToInt16(bytes, i*2)/32768f;
    int F = (total - N)/HOP; double hopSec = (double)HOP/SR;
    double[] win = new double[N]; for (int i=0;i<N;i++) win[i]=0.5-0.5*Math.Cos(2*Math.PI*i/(N-1));
    double[] re=new double[N], im=new double[N], prev=new double[N/2], flux=new double[F];
    int k0=(int)(150.0*N/SR), k1=(int)(1500.0*N/SR);
    for (int f=0; f<F; f++) {
      for (int i=0;i<N;i++){ re[i]=x[f*HOP+i]*win[i]; im[i]=0; }
      FFT(re,im); double fl=0;
      for (int k=k0;k<=k1;k++){ double m=Math.Sqrt(re[k]*re[k]+im[k]*im[k]); double d=m-prev[k]; if (d>0) fl+=d; prev[k]=m; }
      flux[f]=fl;
    }
    // moyenne glissante ~2 s pour obtenir un flux RELATIF (sursauts par rapport au niveau local)
    double[] cum=new double[F+1]; for(int i=0;i<F;i++) cum[i+1]=cum[i]+flux[i];
    int W=(int)(1.0/hopSec); int nb=(int)(total/(double)SR*50)+2; int[] v=new int[nb];
    for (int f=0; f<F; f++) { int a=Math.Max(0,f-W), b=Math.Min(F,f+W); double mean=(cum[b]-cum[a])/(b-a); double r=flux[f]/(mean+1e-3); if (r>9.9) r=9.9;
      int bin=(int)(f*hopSec*50); if (bin<nb) v[bin]=Math.Max(v[bin],(int)Math.Round(r*10)); }
    var sb=new StringBuilder(); sb.Append("window.GUT={fps:50,v:[");
    for (int i=0;i<nb;i++){ if(i>0) sb.Append(','); sb.Append(v[i].ToString(CultureInfo.InvariantCulture)); }
    sb.Append("]};"); return sb.ToString();
  }
}
'@
$j = [Gut]::Run($raw)
[System.IO.File]::WriteAllText($out, $j, (New-Object System.Text.UTF8Encoding($false)))
"ok " + (Get-Item $out).Length
