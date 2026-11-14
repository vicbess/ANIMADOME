@echo off
rem Lance le serveur local puis ouvre la prévisualisation dans le navigateur par défaut.
start "" http://localhost:8765/show.html
powershell -ExecutionPolicy Bypass -File "%~dp0serve.ps1"
