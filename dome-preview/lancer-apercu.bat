@echo off
rem Lance le serveur local puis ouvre la page dans le navigateur par defaut.
start "" http://localhost:8765/show.html
powershell -ExecutionPolicy Bypass -File "%~dp0serve.ps1"
