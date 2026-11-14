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
  // ---------- Versions de l'outil (publish / update) : opérations Git sur le dépôt de l'outil (dossier parent de dome-preview) ----------
  static string GitExe() {
    foreach (var p in new string[] { @"C:\Program Files\Git\cmd\git.exe", @"C:\Program Files (x86)\Git\cmd\git.exe", Environment.GetEnvironmentVariable("LOCALAPPDATA") + @"\Programs\Git\cmd\git.exe" }) if (File.Exists(p)) return p;
    return "git";
  }
  static string RepoRoot(string root) { return Path.GetFullPath(Path.Combine(root, "..")); }
  static string Git(string repo, string args, out int code) {
    var psi = new System.Diagnostics.ProcessStartInfo(GitExe(), args);
    psi.WorkingDirectory = repo; psi.UseShellExecute = false; psi.CreateNoWindow = true; psi.RedirectStandardOutput = true; psi.RedirectStandardError = true;
    psi.StandardOutputEncoding = Encoding.UTF8; psi.StandardErrorEncoding = Encoding.UTF8;
    psi.EnvironmentVariables["GIT_TERMINAL_PROMPT"] = "0"; psi.EnvironmentVariables["GIT_SSH_COMMAND"] = "ssh -o BatchMode=yes";
    using (var p = System.Diagnostics.Process.Start(psi)) {
      var er = p.StandardError.ReadToEndAsync(); string o = p.StandardOutput.ReadToEnd(); p.WaitForExit(180000); code = p.ExitCode; return (o + er.Result).Trim();
    }
  }
  static string OfficialRemote(string repo) {   // seul le dépôt officiel de l'outil est accepté (jamais une adresse venue de la page)
    int c; string rem = Git(repo, "remote get-url origin", out c);
    if (c != 0 || !Regex.IsMatch(rem, @"vicbess/ANIMADOME(\.git)?$")) return null; return rem;
  }
  static string Json(string s) { return "\"" + (s ?? "").Replace("\\", "\\\\").Replace("\"", "\\\"").Replace("\r", "").Replace("\n", "\\n").Replace("\t", " ") + "\""; }
  static string Versions(string root) {
    lock (Lock) {
      string repo = RepoRoot(root); int c; string rem = OfficialRemote(repo); if (rem == null) return "{\"error\":\"dépôt distant inattendu\"}";
      string branch = Git(repo, "rev-parse --abbrev-ref HEAD", out c);
      string fetch = Git(repo, "fetch origin --tags --force --quiet", out c); string warn = c != 0 ? fetch : "";
      string cur = Git(repo, "describe --tags --exact-match HEAD", out c); if (c != 0) cur = "";
      string dirty = Git(repo, "status --porcelain", out c);
      string list = Git(repo, "for-each-ref --sort=-creatordate \"--format=%(refname:short)|%(creatordate:short)|%(contents:subject)\" \"refs/tags/v*\"", out c);
      var sb = new StringBuilder("[");
      foreach (var ln in list.Split(new char[] { '\n' }, StringSplitOptions.RemoveEmptyEntries)) {
        var f = ln.Trim().Split(new char[] { '|' }, 3); if (f.Length < 3 || !Regex.IsMatch(f[0], @"^v\d+\.\d+\.\d+$")) continue;
        if (sb.Length > 1) sb.Append(","); sb.Append("{\"v\":" + Json(f[0]) + ",\"date\":" + Json(f[1]) + ",\"note\":" + Json(f[2]) + "}");
      }
      sb.Append("]");
      return "{\"branch\":" + Json(branch) + ",\"current\":" + Json(cur) + ",\"dirty\":" + (dirty.Length > 0 ? "true" : "false") + ",\"warn\":" + Json(warn) + ",\"versions\":" + sb + "}";
    }
  }
  static string Publish(string body, string root) {
    string[] parts = body.Replace("\r", "").Split(new char[] { '\n' }, 2);
    string ver = parts[0].Trim(), notes = parts.Length > 1 ? parts[1].Trim() : "";
    if (!Regex.IsMatch(ver, @"^\d{1,3}\.\d{1,3}\.\d{1,3}$")) return "KO version invalide (attendu : 1.0.0)";
    if (notes.Length > 4000) return "KO notes trop longues";
    lock (Lock) {
      string repo = RepoRoot(root); int c; var log = new StringBuilder();
      if (OfficialRemote(repo) == null) return "KO dépôt distant inattendu";
      string br = Git(repo, "rev-parse --abbrev-ref HEAD", out c); if (c != 0 || br == "HEAD") return "KO HEAD détaché : revenir sur une branche avant de publier";
      string ex = Git(repo, "ls-remote --tags origin refs/tags/v" + ver, out c); if (c != 0) return "KO connexion à GitHub impossible :\n" + ex; if (ex.Length > 0) return "KO la version v" + ver + " existe déjà sur GitHub";
      Git(repo, "tag -d v" + ver, out c);   // étiquette locale restée d'un essai précédent
      string date = DateTime.Now.ToString("yyyy-MM-dd");
      File.WriteAllText(Path.Combine(root, "version.json"), "{\"version\":\"" + ver + "\",\"date\":\"" + date + "\"}\n", new UTF8Encoding(false));
      string cl = Path.Combine(repo, "CHANGELOG.md"); string old = File.Exists(cl) ? File.ReadAllText(cl, Encoding.UTF8) : "# Changelog\n\n";
      string entry = "## v" + ver + " — " + date + "\n\n" + (notes == "" ? "(pas de notes)" : notes) + "\n\n";
      int ix = old.IndexOf("\n## "); string nw = ix >= 0 ? old.Substring(0, ix + 1) + entry + old.Substring(ix + 1) : old.TrimEnd() + "\n\n" + entry;
      File.WriteAllText(cl, nw, new UTF8Encoding(false));
      string msg = Path.Combine(Path.GetTempPath(), "animadome-msg-" + Guid.NewGuid().ToString("N") + ".txt");
      File.WriteAllText(msg, "Version " + ver + "\n\n" + notes + "\n", new UTF8Encoding(false));
      try {
        Func<string, bool> step = (a) => { string o = Git(repo, a, out c); log.AppendLine("> git " + (a.Length > 70 ? a.Substring(0, 70) + "…" : a)); if (o.Length > 0) log.AppendLine(o); return c == 0; };
        if (!step("add -A")) return "KO\n" + log;
        string st = Git(repo, "status --porcelain", out c);
        if (st.Length > 0 && !step("commit -F \"" + msg + "\"")) return "KO\n" + log;
        if (!step("push origin HEAD")) return "KO\n" + log;
        if (!step("tag -a v" + ver + " -F \"" + msg + "\"")) return "KO\n" + log;
        if (!step("push origin v" + ver)) return "KO\n" + log;
        log.AppendLine("Version v" + ver + " publiée (branche " + br + ").");
        return "OK\n" + log;
      } finally { try { File.Delete(msg); } catch { } }
    }
  }
  static string Update(string body, string root) {
    string ver = body.Trim().TrimStart('v', 'V');
    if (!Regex.IsMatch(ver, @"^\d{1,3}\.\d{1,3}\.\d{1,3}$")) return "KO version invalide";
    lock (Lock) {
      string repo = RepoRoot(root); int c; var log = new StringBuilder();
      if (OfficialRemote(repo) == null) return "KO dépôt distant inattendu";
      string st = Git(repo, "status --porcelain", out c);
      if (st.Length > 0) return "KO des modifications locales de l'outil ne sont pas publiées : publie-les ou annule-les avant de changer de version.\n" + st;
      string f = Git(repo, "fetch origin --tags --force --quiet", out c); if (c != 0) return "KO connexion à GitHub impossible :\n" + f;
      Git(repo, "rev-parse -q --verify refs/tags/v" + ver, out c); if (c != 0) return "KO version v" + ver + " introuvable";
      string o = Git(repo, "switch --detach v" + ver, out c); log.AppendLine(o);
      if (c != 0) return "KO\n" + log;
      log.AppendLine("Version v" + ver + " installée. Relance le serveur (ferme sa fenêtre puis lancer-apercu.bat) et recharge la page.");
      return "OK\n" + log;
    }
  }
  static void Handle(HttpListenerContext c, string root) {
    try {
      string ap = c.Request.Url.AbsolutePath;
      if (ap == "/api/versions" || ap == "/api/publish" || ap == "/api/update") {
        // opérations Git : en-tête personnalisé exigé (une page web tierce ne peut pas l'envoyer sans autorisation du navigateur)
        string rs;
        if (c.Request.Headers["X-Animadome"] != "1") rs = "KO requête refusée";
        else {
          string bd = ""; if (c.Request.HttpMethod == "POST") using (var sr0 = new StreamReader(c.Request.InputStream, Encoding.UTF8)) bd = sr0.ReadToEnd();
          try { rs = ap == "/api/versions" ? Versions(root) : ap == "/api/publish" ? Publish(bd, root) : Update(bd, root); } catch (Exception ex0) { rs = "KO erreur : " + ex0.Message; }
        }
        byte[] rb0 = Encoding.UTF8.GetBytes(rs); c.Response.ContentType = (ap == "/api/versions" ? "application/json" : "text/plain") + "; charset=utf-8"; c.Response.ContentLength64 = rb0.Length;
        c.Response.OutputStream.Write(rb0, 0, rb0.Length); c.Response.Close(); return;
      }
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