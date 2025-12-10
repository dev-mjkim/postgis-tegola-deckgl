@echo off
chcp 65001 > nul
setlocal enabledelayedexpansion

REM ============================================
REM GeoJSON → PostGIS → Tegola → DeckGL 자동 실행 스크립트
REM ============================================

echo ========================================
echo   GeoJSON → PostGIS → Tegola → DeckGL
echo ========================================
echo.

REM GeoJSON 파일 확인
set "GEOJSON_FILE=geojson\buildings.geojson"

if not exist "%GEOJSON_FILE%" (
    echo [오류] geojson\buildings.geojson 파일이 없습니다.
    echo        geojson\ 폴더에 buildings.geojson 파일을 넣어주세요.
    exit /b 1
)

echo [OK] GeoJSON 파일 확인: %GEOJSON_FILE%
echo.

REM Step 1: PostGIS 실행
echo [Step 1/5] PostGIS 데이터베이스 시작...
docker compose -f docker-compose.db.yml up -d --build
if %errorlevel% neq 0 (
    echo [오류] Docker Compose 실행 실패
    exit /b 1
)

REM Step 2: DB가 healthy 될 때까지 대기
echo [Step 2/5] 데이터베이스 준비 대기 중...
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

REM Step 3: GeoJSON 데이터 넣기 (컨테이너 내부에서 실행)
echo [Step 3/5] GeoJSON 데이터를 DB에 넣는 중...

REM 기존 테이블 삭제 (있으면)
docker exec tegola_postgis psql -U gisuser -d gis -c "DROP TABLE IF EXISTS buildings;" > nul 2>&1

REM 컨테이너 내부에서 ogr2ogr 실행 (geojson 폴더가 /geojson으로 마운트됨)
docker exec tegola_postgis ogr2ogr ^
    -f "PostgreSQL" ^
    PG:"host=localhost port=5432 user=gisuser dbname=gis password=gispw" ^
    /geojson/buildings.geojson ^
    -nln buildings ^
    -a_srs EPSG:3857 ^
    -nlt MULTIPOLYGON ^
    -lco GEOMETRY_NAME=geom ^
    -skipfailures

if %errorlevel% neq 0 (
    echo [오류] 데이터 임포트 실패
    exit /b 1
)

REM 데이터 개수 확인
for /f "tokens=*" %%i in ('docker exec tegola_postgis psql -U gisuser -d gis -t -c "SELECT COUNT(*) FROM buildings;"') do set COUNT=%%i
echo    [OK] %COUNT% 개의 건물 데이터 임포트 완료
echo.

REM Step 4: Tegola 실행
echo [Step 4/5] Tegola 벡터타일 서버 시작...
docker compose -f docker-compose.tegola.yml up -d

timeout /t 2 /nobreak > nul
echo    [OK] Tegola 서버 시작 완료
echo.

REM Step 5: DeckGL 프론트엔드 실행
echo [Step 5/5] DeckGL 프론트엔드 시작...
docker compose -f docker-compose.deckgl.yml up -d --build

REM DeckGL 준비 대기
echo    대기 중...
timeout /t 10 /nobreak > nul
echo    [OK] DeckGL 프론트엔드 시작 완료
echo.

REM 완료 메시지
echo ========================================
echo   [완료] 모든 서비스 시작 완료!
echo ========================================
echo.
echo   Tegola 미리보기: http://localhost:28080
echo   DeckGL 3D 뷰어:  http://localhost:4000
echo.
echo   deckgl\src\Map.tsx 파일을 수정하면 자동으로 반영됩니다.
echo.
echo   종료하려면: stop.bat
echo.

endlocal
