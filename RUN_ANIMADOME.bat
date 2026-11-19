@echo off
rem ANIMADOME : lance le serveur local (fenetre reduite) puis ouvre la page dans le navigateur par defaut.
rem Pour arreter le serveur, fermer la fenetre "ANIMADOME serveur" de la barre des taches.
cd /d "%~dp0dome-preview"
start "ANIMADOME serveur" /min powershell -ExecutionPolicy Bypass -File "%~dp0dome-preview\serve.ps1" -Port 8765
timeout /t 3 /nobreak >nul
start "" http://localhost:8765/show.html
