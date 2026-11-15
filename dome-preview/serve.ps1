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
      try {   // contrôle léger : show.html doit être la page générée à partir du template actuel
        string tpl = File.ReadAllText(Path.Combine(root, "show.template.html"), Encoding.UTF8), geo = File.ReadAllText(Path.Combine(root, "dome-geometry.json"), Encoding.UTF8), pg = File.ReadAllText(Path.Combine(root, "show.html"), Encoding.UTF8);
        if (tpl.Replace("\r\n", "\n").Replace("/*DOME_JSON*/", geo.Replace("\r\n", "\n")) != pg.Replace("\r\n", "\n")) return "KO show.html n'est pas à jour par rapport à show.template.html : lance dome-preview\\build.ps1 puis recommence.";
      } catch (Exception ex1) { return "KO contrôle de la page impossible : " + ex1.Message; }
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
      string oldHead = Git(repo, "rev-parse HEAD", out c);
      string o = Git(repo, "switch --detach v" + ver, out c); log.AppendLine(o);
      if (c != 0) return "KO\n" + log;
      bool okFiles = File.Exists(Path.Combine(root, "serve.ps1")) && File.Exists(Path.Combine(root, "version.json")) && File.Exists(Path.Combine(root, "show.html")) && File.ReadAllText(Path.Combine(root, "show.html"), Encoding.UTF8).Contains("<!doctype html>");
      if (!okFiles && oldHead.Length >= 7) { Git(repo, "switch --detach " + oldHead, out c); return "KO la version v" + ver + " est incomplète : l'ancienne version a été rétablie."; }
      log.AppendLine("Version v" + ver + " installée. Relance le serveur (ferme sa fenêtre puis lancer-apercu.bat) et recharge la page.");
      return "OK\n" + log;
    }
  }
  // ---------- Publication des phases d'un mix : fichier mixes/<mix>/publish/<utilisateur>_phases.json, commit + push dans le dépôt des mix ----------
  static string PublishPhases(string body, string root, string mix) {
    if (!Regex.IsMatch(mix ?? "", @"^[A-Za-z0-9_-]{1,40}$")) return "KO mix invalide";
    string[] parts = body.Split(new char[] { '\n' }, 2); string user = parts[0].Trim(), json = parts.Length > 1 ? parts[1] : "";
    if (!Regex.IsMatch(user, @"^[A-Za-z0-9_-]{2,30}$")) return "KO nom d'utilisateur invalide (2 à 30 caractères : lettres, chiffres, - et _)";
    if (json.Length < 2 || json.Length > 6000000 || !json.TrimStart().StartsWith("{")) return "KO données invalides";
    lock (Lock) {
      string mixes = Path.Combine(root, "mixes"), mdir = Path.Combine(mixes, mix); int c; var log = new StringBuilder();
      if (!Directory.Exists(mdir)) return "KO mix introuvable";
      if (!Directory.Exists(Path.Combine(mixes, ".git"))) return "KO le dossier mixes n'est pas un dépôt Git";
      string rem = Git(mixes, "remote get-url origin", out c); if (c != 0 || !Regex.IsMatch(rem, @"vicbess/MIX_Animadome(\.git)?$")) return "KO dépôt des mix inattendu : " + rem;
      string dir = Path.Combine(mdir, "publish"); Directory.CreateDirectory(dir);
      string rel = mix + "/publish/" + user + "_phases.json";
      File.WriteAllText(Path.Combine(dir, user + "_phases.json"), json.Replace("\r", "") + "\n", new UTF8Encoding(false));
      Func<string, bool> step = (a) => { string o = Git(mixes, a, out c); log.AppendLine("> git " + (a.Length > 80 ? a.Substring(0, 80) + "…" : a)); if (o.Length > 0) log.AppendLine(o); return c == 0; };
      string ctxRel = mix + "/CONTEXT.md"; bool hasCtx = File.Exists(Path.Combine(mdir, "CONTEXT.md")); string paths = "\"" + rel + "\"" + (hasCtx ? " \"" + ctxRel + "\"" : "");   // le contexte du mix est publié avec les phases
      if (!step("add " + paths)) return "KO\n" + log;
      string st = Git(mixes, "status --porcelain -- " + paths, out c);
      if (st.Length == 0) { log.AppendLine("Aucune modification depuis la dernière publication : rien à envoyer."); return "OK\n" + log; }
      if (!step("commit -m \"Phases " + mix + " (" + user + ")\" -- " + paths)) return "KO\n" + log;
      if (!step("pull --rebase --autostash origin main")) return "KO\n" + log;
      if (!step("push origin HEAD")) return "KO\n" + log;
      log.AppendLine("Phases publiées : " + rel);
      return "OK\n" + log;
    }
  }
  static string WhoAmI(string root) { int c; string n = Git(RepoRoot(root), "config user.name", out c); return c == 0 ? n : ""; }
  // ---------- Récupération d'une phase : liste des publications (avec pull optionnel) et enregistrement de fichiers de mix autorisés ----------
  static string PublishList(string root, string mix, string pull) {
    if (!Regex.IsMatch(mix ?? "", @"^[A-Za-z0-9_-]{1,40}$")) return "{\"error\":\"mix invalide\"}";
    lock (Lock) {
      string mixes = Path.Combine(root, "mixes"), dir = Path.Combine(mixes, mix, "publish"); int c; string log = "";
      if (pull == "1") {
        string rem = Git(mixes, "remote get-url origin", out c); if (c != 0 || !Regex.IsMatch(rem, @"vicbess/MIX_Animadome(\.git)?$")) return "{\"error\":\"dépôt des mix inattendu\"}";
        log = Git(mixes, "pull --rebase --autostash origin main", out c); if (c != 0) return "{\"error\":\"git pull impossible\",\"log\":" + Json(log) + "}";
      }
      var sb = new StringBuilder("[");
      if (Directory.Exists(dir)) { var fs = Directory.GetFiles(dir, "*_phases.json"); Array.Sort(fs); foreach (var f in fs) { if (sb.Length > 1) sb.Append(","); sb.Append(Json(Path.GetFileName(f))); } }
      sb.Append("]"); return "{\"files\":" + sb + ",\"log\":" + Json(log) + "}";
    }
  }
  static string SaveMixFile(string body, string root, string mix, string name, string backup) {
    if (!Regex.IsMatch(mix ?? "", @"^[A-Za-z0-9_-]{1,40}$")) return "KO mix invalide";
    name = Path.GetFileName(name ?? ""); bool okName = name == "fxmap.js" || name == "events-timing.json" || Regex.IsMatch(name, @"^descriptif-[A-Za-z0-9_-]+\.txt$");
    if (!okName) return "KO fichier refusé";
    if (!Regex.IsMatch(backup ?? "", @"^[A-Za-z0-9_-]{3,60}$")) return "KO identifiant de sauvegarde invalide";
    if (body == null || body.Length < 2 || body.Length > 3000000) return "KO contenu invalide";
    if (name == "events-timing.json" && !body.TrimStart().StartsWith("{")) return "KO contenu invalide";
    if (name == "fxmap.js" && !body.Contains("window.FXMAP")) return "KO contenu invalide";
    lock (Lock) {
      string md = Path.GetFullPath(Path.Combine(root, "mixes", mix)); if (!md.StartsWith(root) || !Directory.Exists(md)) return "KO mix introuvable";
      string target = Path.Combine(md, name), bk = Path.Combine(md, "clean", "backups", backup); Directory.CreateDirectory(bk);
      if (File.Exists(target) && !File.Exists(Path.Combine(bk, name))) File.Copy(target, Path.Combine(bk, name), false);
      File.WriteAllText(target, body, new UTF8Encoding(false)); return "OK";
    }
  }
  // ---------- Publications des autres, lues sur GitHub SANS toucher au dossier de travail : ls-remote (très léger) puis, seulement s'il y a du neuf, fetch + lecture en mémoire ----------
  static string _rSha = "", _rMix = "", _rJson = "";
  static string CtxJson(string mixes, string mix) {   // état de CONTEXT.md : version sur GitHub, version publiée localement (HEAD) et fichier actuel
    int c; string rp = mix + "/CONTEXT.md";
    string rr = Git(mixes, "rev-parse -q --verify \"origin/main:" + rp + "\"", out c); if (c != 0) rr = "";
    string hh = Git(mixes, "rev-parse -q --verify \"HEAD:" + rp + "\"", out c); if (c != 0) hh = "";
    string lp = Path.Combine(mixes, mix, "CONTEXT.md"), ll = ""; if (File.Exists(lp)) { ll = Git(mixes, "hash-object \"" + lp + "\"", out c); if (c != 0) ll = ""; }
    return "{\"remote\":" + Json(rr) + ",\"head\":" + Json(hh) + ",\"local\":" + Json(ll) + "}";
  }
  static string PublishRemote(string root, string mix, string known, bool force) {
    if (!Regex.IsMatch(mix ?? "", @"^[A-Za-z0-9_-]{1,40}$")) return "{\"error\":\"mix invalide\"}";
    lock (Lock) {
      string mixes = Path.Combine(root, "mixes"); int c;
      string rem = Git(mixes, "remote get-url origin", out c); if (c != 0 || !Regex.IsMatch(rem, @"vicbess/MIX_Animadome(\.git)?$")) return "{\"error\":\"dépôt des mix inattendu\"}";
      string ls = Git(mixes, "ls-remote origin refs/heads/main", out c); if (c != 0 || ls.Length < 40) return "{\"error\":\"GitHub injoignable\"}";
      string sha = ls.Substring(0, 40);
      if (!force && sha == (known ?? "")) return "{\"sha\":\"" + sha + "\",\"same\":true,\"ctx\":" + CtxJson(mixes, mix) + "}";
      if (sha != _rSha || mix != _rMix || force) {
        string f = Git(mixes, "fetch origin main --quiet", out c); if (c != 0) return "{\"error\":\"fetch impossible\",\"log\":" + Json(f) + "}";
        string names = Git(mixes, "ls-tree -r --name-only origin/main -- \"" + mix + "/publish/\"", out c);
        var sb = new StringBuilder("{\"sha\":\"" + sha + "\",\"files\":{"); bool first = true;
        foreach (var n in names.Split(new char[] { '\n' }, StringSplitOptions.RemoveEmptyEntries)) {
          string nm = n.Trim(); if (!Regex.IsMatch(nm, @"^" + Regex.Escape(mix) + @"/publish/[A-Za-z0-9_-]+_phases\.json$")) continue;
          string txt = Git(mixes, "show \"origin/main:" + nm + "\"", out c); if (c != 0 || !txt.TrimStart().StartsWith("{")) continue;
          if (!first) sb.Append(","); first = false; sb.Append(Json(Path.GetFileName(nm)) + ":" + Json(txt));
        }
        sb.Append("}}"); _rSha = sha; _rMix = mix; _rJson = sb.ToString();
      }
      return _rJson.Substring(0, _rJson.Length - 1) + ",\"ctx\":" + CtxJson(mixes, mix) + "}";
    }
  }
  // ---------- Fusion du CONTEXT.md d'un mix lors de la mise à jour d'une phase (fusion à 3 voies ; jamais d'écrasement silencieux) ----------
  static string Norm(string s) { return (s ?? "").Replace("\r\n", "\n").Trim(); }
  static string MergeContext(string root, string mix) {
    if (!Regex.IsMatch(mix ?? "", @"^[A-Za-z0-9_-]{1,40}$")) return "KO mix invalide";
    lock (Lock) {
      string mixes = Path.Combine(root, "mixes"); int c; string rem = Git(mixes, "remote get-url origin", out c);
      if (c != 0 || !Regex.IsMatch(rem, @"vicbess/MIX_Animadome(\.git)?$")) return "KO dépôt des mix inattendu";
      string rp = mix + "/CONTEXT.md", lp = Path.Combine(mixes, mix, "CONTEXT.md");
      string theirs = Git(mixes, "show \"origin/main:" + rp + "\"", out c); if (c != 0) return "OK pas de contexte publié par d'autres";
      if (!File.Exists(lp)) { File.WriteAllText(lp, theirs + "\n", new UTF8Encoding(false)); return "OK contexte récupéré"; }
      string ours = File.ReadAllText(lp, Encoding.UTF8), bv = ""; string mb = Git(mixes, "merge-base HEAD origin/main", out c);
      if (c == 0 && mb.Length >= 7) { string b = Git(mixes, "show \"" + mb + ":" + rp + "\"", out c); if (c == 0) bv = b; }
      if (Norm(ours) == Norm(theirs)) return "OK contexte déjà à jour";
      if (Norm(ours) == Norm(bv)) { File.WriteAllText(lp, theirs + "\n", new UTF8Encoding(false)); return "OK contexte mis à jour"; }
      if (Norm(theirs) == Norm(bv)) return "OK ton contexte est plus récent que celui des autres";
      string tmp = Path.Combine(Path.GetTempPath(), "animadome-ctx-" + Guid.NewGuid().ToString("N")); Directory.CreateDirectory(tmp);
      try {
        File.WriteAllText(Path.Combine(tmp, "ours.md"), Norm(ours) + "\n", new UTF8Encoding(false)); File.WriteAllText(Path.Combine(tmp, "base.md"), Norm(bv) + "\n", new UTF8Encoding(false)); File.WriteAllText(Path.Combine(tmp, "theirs.md"), Norm(theirs) + "\n", new UTF8Encoding(false));
        string merged = Git(mixes, "merge-file -p \"" + Path.Combine(tmp, "ours.md") + "\" \"" + Path.Combine(tmp, "base.md") + "\" \"" + Path.Combine(tmp, "theirs.md") + "\"", out c);
        if (c == 0) { File.WriteAllText(lp, merged + "\n", new UTF8Encoding(false)); return "OK contexte fusionné avec celui des autres"; }
        File.WriteAllText(Path.Combine(mixes, mix, "CONTEXT.theirs.md"), theirs + "\n", new UTF8Encoding(false));
        return "CONFLIT : ton CONTEXT.md et celui des autres ont changé aux mêmes endroits. Le tien est conservé ; leur version est enregistrée dans CONTEXT.theirs.md : fusionne-les à la main.";
      } finally { try { Directory.Delete(tmp, true); } catch { } }
    }
  }
  // ---------- Fichiers audio d'un mix : envoi (local), contrôle des outils d'analyse, lancement et suivi de l'analyse ----------
  static System.Diagnostics.Process _an = null; static string _anMix = "";
  static readonly object AnLock = new object();
  static string MixAudioRel(string md) {
    string mj = Path.Combine(md, "mix.json"); if (!File.Exists(mj)) return null;
    var m = Regex.Match(File.ReadAllText(mj, Encoding.UTF8), "\"audio\"\\s*:\\s*\"([^\"]+)\""); return m.Success ? m.Groups[1].Value : null;
  }
  static string UploadFile(HttpListenerContext c, string root, string mix, string kind, string name, bool reset) {
    if (!Regex.IsMatch(mix ?? "", @"^[A-Za-z0-9_-]{1,40}$")) return "KO mix invalide";
    if (kind != "audio" && kind != "track") return "KO type de fichier invalide";
    name = Path.GetFileName(name ?? ""); string ext = Path.GetExtension(name).ToLower();
    if (Array.IndexOf(new string[] { ".mp3", ".wav", ".flac", ".m4a", ".ogg", ".aif", ".aiff" }, ext) < 0) return "KO format audio non pris en charge";
    if (!Regex.IsMatch(name, @"^[\p{L}\p{N} ._()\[\]+&'\-]{1,120}$")) return "KO nom de fichier non pris en charge (lettres, chiffres, espaces et . _ - ( ) )";
    string md = Path.GetFullPath(Path.Combine(root, "mixes", mix)); if (!md.StartsWith(root) || !Directory.Exists(md)) return "KO mix introuvable";
    string target;
    if (kind == "audio") { string rel = MixAudioRel(md); if (rel == null || rel.Contains("..")) return "KO mix.json sans fichier audio déclaré"; target = Path.GetFullPath(Path.Combine(md, rel.Replace("/", "\\"))); }
    else target = Path.GetFullPath(Path.Combine(md, "tracks", name));
    if (!target.StartsWith(md)) return "KO chemin refusé";
    if (kind == "track" && reset) { string td = Path.GetDirectoryName(target); if (Directory.Exists(td)) foreach (var old in Directory.GetFiles(td)) { try { File.Delete(old); } catch { } } }   // nouveau lot de pistes : on repart d'un dossier vide
    Directory.CreateDirectory(Path.GetDirectoryName(target)); string part = target + ".part"; long total = 0, limit = 6L * 1024 * 1024 * 1024;
    try {
      using (var fs = new FileStream(part, FileMode.Create, FileAccess.Write)) { byte[] buf = new byte[262144]; int n; var s = c.Request.InputStream; while ((n = s.Read(buf, 0, buf.Length)) > 0) { total += n; if (total > limit) throw new Exception("fichier trop volumineux (6 Go max)"); fs.Write(buf, 0, n); } }
      if (total == 0) { File.Delete(part); return "KO fichier vide"; }
      if (File.Exists(target)) File.Delete(target); File.Move(part, target);
    } catch (Exception ex) { try { File.Delete(part); } catch { } return "KO envoi interrompu : " + ex.Message; }
    return "OK " + (kind == "audio" ? "audio" : "piste") + " enregistré(e) (" + (total / 1048576) + " Mo)";
  }
  static string RunPs(string root, string script, string args, int timeoutMs) {
    var psi = new System.Diagnostics.ProcessStartInfo("powershell.exe", "-NoProfile -ExecutionPolicy Bypass -File \"" + Path.Combine(root, "tools", script) + "\" " + args);
    psi.UseShellExecute = false; psi.CreateNoWindow = true; psi.RedirectStandardOutput = true; psi.StandardOutputEncoding = Encoding.UTF8; psi.WorkingDirectory = root;
    using (var p = System.Diagnostics.Process.Start(psi)) { string o = p.StandardOutput.ReadToEnd(); p.WaitForExit(timeoutMs); return o.Trim(); }
  }
  static string AnalysisCheck(string root, bool needStems) { lock (AnLock) { return RunPs(root, "check-analysis.ps1", needStems ? "-NeedStems" : "", 60000); } }
  static string AnalysisStart(string root, string mix, bool tracks) {
    if (!Regex.IsMatch(mix ?? "", @"^[A-Za-z0-9_-]{1,40}$")) return "KO mix invalide";
    lock (AnLock) {
      if (_an != null && !_an.HasExited) return "KO une analyse est déjà en cours";
      string md = Path.GetFullPath(Path.Combine(root, "mixes", mix)); if (!md.StartsWith(root) || !Directory.Exists(md)) return "KO mix introuvable";
      if (tracks && !(Directory.Exists(Path.Combine(md, "tracks")) && Directory.GetFiles(Path.Combine(md, "tracks")).Length > 0)) return "KO aucune piste envoyée";
      string log = Path.Combine(md, "analysis.log"); File.WriteAllText(log, "", new UTF8Encoding(false));
      var psi = new System.Diagnostics.ProcessStartInfo("powershell.exe", "-NoProfile -ExecutionPolicy Bypass -File \"" + Path.Combine(root, "tools", "run-analysis.ps1") + "\" -MixDir \"" + md + "\"" + (tracks ? " -Tracks" : ""));
      psi.UseShellExecute = false; psi.CreateNoWindow = true; psi.RedirectStandardOutput = true; psi.RedirectStandardError = true; psi.StandardOutputEncoding = Encoding.UTF8; psi.StandardErrorEncoding = Encoding.UTF8; psi.WorkingDirectory = root;
      var p = new System.Diagnostics.Process(); p.StartInfo = psi; object ll = new object();
      System.Diagnostics.DataReceivedEventHandler h = (s, ev) => { if (ev.Data != null) lock (ll) { try { File.AppendAllText(log, ev.Data + "\n", new UTF8Encoding(false)); } catch { } } };
      p.OutputDataReceived += h; p.ErrorDataReceived += h; p.Start(); p.BeginOutputReadLine(); p.BeginErrorReadLine(); _an = p; _anMix = mix;
      return "OK analyse lancée";
    }
  }
  static string AnalysisStatus(string root, string mix) {
    if (!Regex.IsMatch(mix ?? "", @"^[A-Za-z0-9_-]{1,40}$")) return "{\"error\":\"mix invalide\"}";
    lock (AnLock) {
      string log = Path.Combine(root, "mixes", mix, "analysis.log"); string[] lines = File.Exists(log) ? File.ReadAllLines(log, Encoding.UTF8) : new string[0];
      int from = Math.Max(0, lines.Length - 40); var sb = new StringBuilder(); for (int i = from; i < lines.Length; i++) sb.AppendLine(lines[i]);
      bool running = _an != null && !_an.HasExited && _anMix == mix; int code = (_an != null && _an.HasExited && _anMix == mix) ? _an.ExitCode : -1;
      return "{\"running\":" + (running ? "true" : "false") + ",\"exit\":" + code + ",\"log\":" + Json(sb.ToString()) + "}";
    }
  }
  static void Handle(HttpListenerContext c, string root) {
    try {
      string ap = c.Request.Url.AbsolutePath;
      if (ap == "/api/upload") {
        string up = c.Request.Headers["X-Animadome"] != "1" || c.Request.HttpMethod != "POST" ? "KO requête refusée" : UploadFile(c, root, c.Request.QueryString["mix"], c.Request.QueryString["kind"], c.Request.QueryString["name"], c.Request.QueryString["reset"] == "1");
        byte[] ub = Encoding.UTF8.GetBytes(up); c.Response.ContentType = "text/plain; charset=utf-8"; c.Response.ContentLength64 = ub.Length; c.Response.OutputStream.Write(ub, 0, ub.Length); c.Response.Close(); return;
      }
      if (ap == "/api/versions" || ap == "/api/publish" || ap == "/api/update" || ap == "/api/whoami" || ap == "/api/publish-phases" || ap == "/api/publish-list" || ap == "/api/save-mixfile" || ap == "/api/publish-remote" || ap == "/api/merge-context" || ap == "/api/analysis-check" || ap == "/api/analysis-start" || ap == "/api/analysis-status") {
        // opérations Git : en-tête personnalisé exigé (une page web tierce ne peut pas l'envoyer sans autorisation du navigateur)
        string rs;
        if (c.Request.Headers["X-Animadome"] != "1") rs = "KO requête refusée";
        else {
          string bd = ""; if (c.Request.HttpMethod == "POST") using (var sr0 = new StreamReader(c.Request.InputStream, Encoding.UTF8)) bd = sr0.ReadToEnd();
          try { rs = ap == "/api/versions" ? Versions(root) : ap == "/api/publish" ? Publish(bd, root) : ap == "/api/whoami" ? WhoAmI(root) : ap == "/api/publish-phases" ? PublishPhases(bd, root, c.Request.QueryString["mix"]) : ap == "/api/publish-list" ? PublishList(root, c.Request.QueryString["mix"], c.Request.QueryString["pull"]) : ap == "/api/publish-remote" ? PublishRemote(root, c.Request.QueryString["mix"], c.Request.QueryString["known"], c.Request.QueryString["force"] == "1") : ap == "/api/analysis-check" ? AnalysisCheck(root, c.Request.QueryString["stems"] == "1") : ap == "/api/analysis-start" ? AnalysisStart(root, c.Request.QueryString["mix"], c.Request.QueryString["tracks"] == "1") : ap == "/api/analysis-status" ? AnalysisStatus(root, c.Request.QueryString["mix"]) : ap == "/api/merge-context" ? MergeContext(root, c.Request.QueryString["mix"]) : ap == "/api/save-mixfile" ? SaveMixFile(bd, root, c.Request.QueryString["mix"], c.Request.QueryString["name"], c.Request.QueryString["backup"]) : Update(bd, root); } catch (Exception ex0) { rs = "KO erreur : " + ex0.Message; }
        }
        byte[] rb0 = Encoding.UTF8.GetBytes(rs); c.Response.ContentType = ((ap == "/api/versions" || ap == "/api/analysis-check" || ap == "/api/analysis-status") ? "application/json" : "text/plain") + "; charset=utf-8"; c.Response.ContentLength64 = rb0.Length;
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
      if (full.StartsWith(root) && !File.Exists(full) && Regex.IsMatch(c.Request.Url.AbsolutePath, @"/(clean/phase-\d+\.json|layers\.js)$")) { byte[] nb = Encoding.UTF8.GetBytes("null"); c.Response.ContentType = c.Request.Url.AbsolutePath.EndsWith(".js") ? "text/javascript" : "application/json"; c.Response.ContentLength64 = nb.Length; c.Response.OutputStream.Write(nb, 0, nb.Length); c.Response.Close(); return; }   // pas encore de rapport de nettoyage : réponse vide plutôt qu'une erreur 404 dans la console
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