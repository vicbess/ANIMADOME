# Serveur local de prévisualisation (gère les "Range" pour l'audio) + surveillance du descriptif.
# À chaque enregistrement de descriptif-pyrobeats.txt, descriptif.json est régénéré (la page se met à jour seule).
# Lancer :  powershell -ExecutionPolicy Bypass -File serve.ps1      puis ouvrir http://localhost:8765/show.html
param([int]$Port = 8765)
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.Net;
using System.Threading;
using System.Text;
using System.Text.RegularExpressions;
using System.Collections.Generic;
public static class Srv {
  public static void Start(string root, int port) {
    var l = new HttpListener(); l.Prefixes.Add("http://localhost:" + port + "/"); l.Start();
    Console.WriteLine("Serveur sur http://localhost:" + port + "/  (racine : " + root + ")");
    var th = new Thread(() => { while (true) { var c = l.GetContext(); ThreadPool.QueueUserWorkItem(_ => Handle(c, root)); } });
    th.IsBackground = true; th.Start();
  }
  static readonly object Lock = new object();
  static string MixFile(string root, string dir, string name) {
    dir = (dir ?? "").Replace("/", "\\").Trim(); if (dir == "" || dir == ".") dir = "";
    string full = Path.GetFullPath(Path.Combine(Path.Combine(root, dir), Path.GetFileName(name ?? "")));
    if (!full.StartsWith(root)) throw new Exception("chemin refusé");
    return full;
  }
  static string SavePhase(string body, string root, string dir, string txt) {
    // corps : "<début en s>\n<kind: tech|desc|son>\n<texte>"
    string[] parts = body.Replace("\r", "").Split(new char[] { '\n' }, 3);
    if (parts.Length < 3) return "bad request";
    int startSec; if (!int.TryParse(parts[0].Trim(), out startSec)) return "bad start";
    string kind = parts[1].Trim(); string text = parts[2];
    if (kind != "tech" && kind != "desc" && kind != "son") return "bad kind";
    lock (Lock) {
      string tn = Path.GetFileName(txt ?? ""); if (!tn.StartsWith("descriptif-") || !tn.EndsWith(".txt")) return "fichier refusé";
      string path = MixFile(root, dir, tn);
      var lines = new List<string>(File.ReadAllLines(path, Encoding.UTF8));
      var hdr = new Regex(@"^\[(\d{1,2}):(\d{2})\s*=>");
      int h = -1;
      for (int i = 0; i < lines.Count; i++) { var m = hdr.Match(lines[i]); if (m.Success && int.Parse(m.Groups[1].Value) * 60 + int.Parse(m.Groups[2].Value) == startSec) { h = i; break; } }
      if (h < 0) return "phase introuvable";
      int e = h + 1;
      while (e < lines.Count && !hdr.IsMatch(lines[e]) && !Regex.IsMatch(lines[e], @"^=+\s*$") && !lines[e].StartsWith("Questions") && !lines[e].StartsWith("**CHAPITRE") && !Regex.IsMatch(lines[e], @"PARTIR D.ICI")) e++;
      // classe chaque ligne : sub / event / blank / tech / son / desc
      var keep = new List<string>(); var kinds = new List<string>(); int firstOfKind = -1; bool inEvent = false;
      for (int i = h + 1; i < e; i++) {
        string l = lines[i]; string k;
        if (l.Trim() == "") { inEvent = false; k = "blank"; }
        else if (Regex.IsMatch(l, @"^\s+-\s+\[")) k = "sub";
        else if (Regex.IsMatch(l, @"^\*\d{1,2}:\d{2}")) { inEvent = true; k = "event"; }
        else if (inEvent) k = "event";
        else if (Regex.IsMatch(l, @"^\*\*.+\*\*\s*$")) k = "tech";
        else if (Regex.IsMatch(l, @"^_.+_\s*$") || Regex.IsMatch(l, @"^\(Son")) k = "son";
        else k = "desc";
        if (k == kind) { if (firstOfKind < 0) firstOfKind = keep.Count; continue; }   // lignes de ce type : remplacées
        keep.Add(l); kinds.Add(k);
      }
      int insertAt;
      if (firstOfKind >= 0) insertAt = firstOfKind;
      else {
        // ordre : tech, desc, son -> après la dernière ligne d'un type précédent
        string[] order = { "desc", "tech", "son" }; int rank = Array.IndexOf(order, kind); insertAt = 0;
        for (int i = 0; i < keep.Count; i++) { int r = Array.IndexOf(order, kinds[i]); if (r >= 0 && r < rank) insertAt = i + 1; }
      }
      var add = new List<string>();
      foreach (var ln in text.Split('\n')) {
        var t = ln.Trim(); if (t.Length == 0) continue;
        if (kind == "tech") { t = Regex.Replace(t, @"^\*\*|\*\*$", "").Trim(); add.Add("**" + t + "**"); }
        else if (kind == "son") { t = Regex.Replace(t, @"^_|_$", "").Trim(); add.Add("_" + t + "_"); }
        else add.Add(t);
      }
      keep.InsertRange(insertAt, add);
      var outLines = new List<string>(lines.GetRange(0, h + 1)); outLines.AddRange(keep); outLines.AddRange(lines.GetRange(e, lines.Count - e));
      File.Copy(path, Path.ChangeExtension(path, ".bak.txt"), true);
      File.WriteAllLines(path, outLines, new UTF8Encoding(false));
    }
    return "ok";
  }
  static string MixDir(string root, string dir) {
    dir = (dir ?? "").Replace("/", "\\").Trim(); if (dir == "" || dir == ".") dir = "";
    string full = Path.GetFullPath(Path.Combine(root, dir)); if (!full.StartsWith(root)) throw new Exception("chemin refusé"); return full;
  }
  // Clean My Prompt : rapport d'une phase (clean/phase-<début en s>.json)
  static string SaveClean(string body, string root, string dir, string phase) {
    body = body.Replace("\r", "").Trim(); if (body.Length == 0 || body.Length > 20000 || !body.StartsWith("{")) return "bad request";
    if (!Regex.IsMatch(phase ?? "", @"^\d{1,6}$")) return "bad phase";
    lock (Lock) { string d = Path.Combine(MixDir(root, dir), "clean"); Directory.CreateDirectory(d); File.WriteAllText(Path.Combine(d, "phase-" + phase + ".json"), body, new UTF8Encoding(false)); }
    return "ok";
  }
  // Clean My Prompt : restaure le descriptif, fxmap.js et events-timing.json depuis clean/backups/<id>/
  static string UndoClean(string root, string dir, string id, string txt) {
    if (!Regex.IsMatch(id ?? "", @"^[A-Za-z0-9_\-]{3,60}$")) return "bad id";
    lock (Lock) {
      string md = MixDir(root, dir), bk = Path.Combine(md, "clean", "backups", id); if (!Directory.Exists(bk)) return "sauvegarde introuvable";
      string tn = Path.GetFileName(txt ?? ""); int n = 0;
      foreach (string name in new string[] { tn, "fxmap.js", "events-timing.json" }) {
        if (name == "") continue; if (name == tn && (!tn.StartsWith("descriptif-") || !tn.EndsWith(".txt"))) continue;
        string src = Path.Combine(bk, name); if (File.Exists(src)) { File.Copy(src, Path.Combine(md, name), true); n++; }
      }
      return n > 0 ? "ok" : "rien à restaurer";
    }
  }
  static string SaveEvt(string body, string root, string dir) {
    body = body.Replace("\r", "").Replace("\n", " ").Trim();
    if (body.Length == 0 || body.Length > 4000 || !body.StartsWith("{")) return "bad request";
    lock (Lock) { File.WriteAllText(MixFile(root, dir, "events-timing.json"), body, new UTF8Encoding(false)); }
    return "ok";
  }
  static string AppendPrompt(string body, string root, string dir) {
    body = body.Replace("\r", "").Replace("\n", " ").Trim();
    if (body.Length == 0 || body.Length > 8000 || !body.StartsWith("{")) return "bad request";
    lock (Lock) { File.AppendAllText(MixFile(root, dir, "prompts.jsonl"), body + "\n", new UTF8Encoding(false)); }
    return "ok";
  }  static string Mime(string p) {
    switch (Path.GetExtension(p).ToLower()) {
      case ".html": return "text/html; charset=utf-8"; case ".js": return "text/javascript; charset=utf-8";
      case ".json": return "application/json; charset=utf-8"; case ".css": return "text/css";
      case ".mp3": return "audio/mpeg"; case ".txt": return "text/plain; charset=utf-8";
      case ".png": return "image/png"; case ".webm": return "video/webm"; case ".mp4": return "video/mp4";
      default: return "application/octet-stream"; }
  }
  static void Handle(HttpListenerContext c, string root) {
    try {
      if (c.Request.HttpMethod == "POST" && (c.Request.Url.AbsolutePath == "/api/phase-text" || c.Request.Url.AbsolutePath == "/api/prompt" || c.Request.Url.AbsolutePath == "/api/event-time" || c.Request.Url.AbsolutePath == "/api/clean-report" || c.Request.Url.AbsolutePath == "/api/clean-undo")) {
        string body; using (var sr = new StreamReader(c.Request.InputStream, Encoding.UTF8)) body = sr.ReadToEnd();
        string res; try { string qd = c.Request.QueryString["dir"], qt = c.Request.QueryString["txt"];
        res = c.Request.Url.AbsolutePath == "/api/prompt" ? AppendPrompt(body, root, qd) : c.Request.Url.AbsolutePath == "/api/event-time" ? SaveEvt(body, root, qd) : c.Request.Url.AbsolutePath == "/api/clean-report" ? SaveClean(body, root, qd, c.Request.QueryString["phase"]) : c.Request.Url.AbsolutePath == "/api/clean-undo" ? UndoClean(root, qd, c.Request.QueryString["id"], qt) : SavePhase(body, root, qd, qt); } catch (Exception ex) { res = "erreur: " + ex.Message; }
        byte[] rb = Encoding.UTF8.GetBytes(res); c.Response.ContentType = "text/plain; charset=utf-8"; c.Response.ContentLength64 = rb.Length;
        c.Response.OutputStream.Write(rb, 0, rb.Length); c.Response.Close(); return;
      }
      string rel = Uri.UnescapeDataString(c.Request.Url.AbsolutePath).TrimStart('/'); if (rel == "") rel = "show.html";
      string full = Path.GetFullPath(Path.Combine(root, rel));
      if (!full.StartsWith(root) || !File.Exists(full)) { c.Response.StatusCode = 404; c.Response.Close(); return; }
      using (var fs = new FileStream(full, FileMode.Open, FileAccess.Read, FileShare.ReadWrite)) {
        long len = fs.Length, start = 0, end = len - 1; string range = c.Request.Headers["Range"];
        c.Response.ContentType = Mime(full); c.Response.AddHeader("Accept-Ranges", "bytes");
        c.Response.AddHeader("Cache-Control", "no-cache");
        if (!string.IsNullOrEmpty(range) && range.StartsWith("bytes=")) {
          var p = range.Substring(6).Split('-'); if (p[0] != "") start = long.Parse(p[0]); if (p.Length > 1 && p[1] != "") end = long.Parse(p[1]);
          if (end >= len) end = len - 1; c.Response.StatusCode = 206;
          c.Response.AddHeader("Content-Range", "bytes " + start + "-" + end + "/" + len);
        }
        long n = end - start + 1; c.Response.ContentLength64 = n; fs.Seek(start, SeekOrigin.Begin);
        byte[] buf = new byte[65536]; long left = n;
        while (left > 0) { int r = fs.Read(buf, 0, (int)Math.Min(buf.Length, left)); if (r <= 0) break; c.Response.OutputStream.Write(buf, 0, r); left -= r; }
      }
      c.Response.Close();
    } catch { try { c.Response.Abort(); } catch { } }
  }
}
'@
# Registre des mix : généré à partir de mixes\<nom>\mix.json (un dossier de mix = un projet ; mixes\ est son propre dépôt Git)
function Write-Mixes {
  $list = @()
  Get-ChildItem (Join-Path $root 'mixes') -Directory -ErrorAction SilentlyContinue | Sort-Object Name | ForEach-Object {
    $mj = Join-Path $_.FullName 'mix.json'
    if (Test-Path $mj) { try { $o = [System.IO.File]::ReadAllText($mj, [System.Text.Encoding]::UTF8) | ConvertFrom-Json; $list += [ordered]@{ slug = $o.slug; title = $o.title; dir = ('mixes/' + $_.Name); audio = $o.audio; descriptif = $o.descriptif } } catch {} } }
  $js = 'window.MIXES=' + (ConvertTo-Json -InputObject @($list) -Depth 4) + ';'
  $mp = Join-Path $root 'mixes.js'
  if (-not (Test-Path $mp) -or [System.IO.File]::ReadAllText($mp) -ne $js) { [System.IO.File]::WriteAllText($mp, $js, (New-Object System.Text.UTF8Encoding($false))) }
}
Write-Mixes
[Srv]::Start($root, $Port)
function Get-Mixes { $t = [System.IO.File]::ReadAllText((Join-Path $root 'mixes.js'), [System.Text.Encoding]::UTF8); $m = [regex]::Match($t, '(\[.*\])', 'Singleline'); return ($m.Value | ConvertFrom-Json) }
$parser = Join-Path $root 'parse-descriptif.ps1'
$last = @{}
while ($true) {
  try {
    Write-Mixes
    foreach ($mx in (Get-Mixes)) {
      $dir = if ($mx.dir -eq '.') { $root } else { Join-Path $root ($mx.dir -replace '/', '\') }
      if (-not (Test-Path (Join-Path $dir 'prompts.jsonl')) -and (Test-Path $dir)) { New-Item (Join-Path $dir 'prompts.jsonl') -ItemType File | Out-Null }
      if (-not (Test-Path (Join-Path $dir 'prompts-done.json')) -and (Test-Path $dir)) { [System.IO.File]::WriteAllText((Join-Path $dir 'prompts-done.json'), '{}') }
      $txt = Join-Path $dir $mx.descriptif
      if (-not (Test-Path $txt)) { continue }
      $m = (Get-Item $txt).LastWriteTimeUtc
      if ($last[$mx.slug] -ne $m) { Start-Sleep -Milliseconds 300; & $parser -In $txt -Out (Join-Path $dir 'descriptif.json') | Out-Host; $last[$mx.slug] = $m }
    }
  } catch { Write-Host "Parse : $($_.Exception.Message)" }
  Start-Sleep -Seconds 1
}