@echo off
chcp 65001 > nul
setlocal enabledelayedexpansion

REM ============================================
REM GeoJSON → PostGIS → Tegola 자동 실행 스크립트
REM ============================================

echo ========================================
echo   GeoJSON → PostGIS → Tegola 시작
echo ========================================
echo.

REM GeoJSON 파일 찾기
set "GEOJSON_FILE="
for %%f in (geojson\*.geojson geojson\*.json) do (
    if exist "%%f" (
        set "GEOJSON_FILE=%%f"
        goto :found
    )
)

:notfound
echo [오류] geojson\ 폴더에 GeoJSON 파일이 없습니다.
echo        geojson\ 폴더에 .geojson 또는 .json 파일을 넣어주세요.
exit /b 1

:found
echo [OK] GeoJSON 파일 발견: %GEOJSON_FILE%
echo.

REM Step 1: PostGIS 실행
echo [Step 1/4] PostGIS 데이터베이스 시작...
docker compose -f docker-compose.db.yml up -d --build
if %errorlevel% neq 0 (
    echo [오류] Docker Compose 실행 실패
    exit /b 1
)

REM Step 2: DB가 healthy 될 때까지 대기
echo [Step 2/4] 데이터베이스 준비 대기 중...
:waitloop
docker exec tegola_postgis pg_isready -U gisuser -d gis > nul 2>&1
if %errorlevel% neq 0 (
    echo|set /p="."
    timeout /t 1 /nobreak > nul
    goto :waitloop
)
echo.
echo    [OK] 데이터베이스 준비 완료
echo.

REM 추가 대기 (PostGIS 확장 로드)
timeout /t 3 /nobreak > nul

REM Step 3: GeoJSON 데이터 넣기
echo [Step 3/4] GeoJSON 데이터를 DB에 넣는 중...

REM 기존 테이블 삭제 (있으면)
docker exec tegola_postgis psql -U gisuser -d gis -c "DROP TABLE IF EXISTS buildings;" > nul 2>&1

REM ogr2ogr로 데이터 임포트
ogr2ogr ^
    -f "PostgreSQL" ^
    PG:"host=localhost port=25432 user=gisuser dbname=gis password=gispw" ^
    "%GEOJSON_FILE%" ^
    -nln buildings ^
    -a_srs EPSG:3857 ^
    -nlt MULTIPOLYGON ^
    -lco GEOMETRY_NAME=geom ^
    -skipfailures

if %errorlevel% neq 0 (
    echo [오류] ogr2ogr 실행 실패. GDAL이 설치되어 있는지 확인하세요.
    exit /b 1
)

REM 데이터 개수 확인
for /f "tokens=*" %%i in ('docker exec tegola_postgis psql -U gisuser -d gis -t -c "SELECT COUNT(*) FROM buildings;"') do set COUNT=%%i
echo    [OK] %COUNT% 개의 건물 데이터 임포트 완료
echo.

REM Step 4: Tegola 실행
echo [Step 4/4] Tegola 벡터타일 서버 시작...
docker compose -f docker-compose.tegola.yml up -d

timeout /t 2 /nobreak > nul
echo    [OK] Tegola 서버 시작 완료
echo.

REM 완료 메시지
echo ========================================
echo   [완료] 모든 서비스 시작 완료!
echo ========================================
echo.
echo   Tegola 미리보기: http://localhost:28080
echo.
echo   DeckGL 프론트엔드 실행:
echo      cd deckgl ^&^& npm install ^&^& npm run dev
echo.
echo   브라우저에서: http://localhost:4000
echo.

endlocal

