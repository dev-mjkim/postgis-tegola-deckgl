@echo off
chcp 65001 > nul

REM ============================================
REM 전체 종료 및 정리 스크립트
REM ============================================

echo ========================================
echo   모든 서비스 종료 중...
echo ========================================
echo.

REM Tegola 종료
echo [1/3] Tegola 종료...
docker compose -f docker-compose.tegola.yml down -v 2> nul

REM PostGIS 종료
echo [2/3] PostGIS 종료...
docker compose -f docker-compose.db.yml down -v 2> nul

REM 네트워크 삭제
echo [3/3] Docker 네트워크 정리...
docker network rm tegola_network 2> nul

echo.
echo ========================================
echo   [완료] 모든 서비스 종료 및 정리 완료
echo ========================================
echo.
echo   다시 시작하려면: start.bat
echo.

