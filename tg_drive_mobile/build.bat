@echo off
for /f "tokens=1,2 delims==" %%a in (.env) do set %%a=%%b
flutter build apk --dart-define=API_ID=%API_ID% --dart-define=API_HASH=%API_HASH%
