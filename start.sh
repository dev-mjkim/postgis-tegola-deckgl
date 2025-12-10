#!/bin/bash

# ============================================
# GeoJSON → PostGIS → Tegola → DeckGL 자동 실행 스크립트
# ============================================

set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  GeoJSON → PostGIS → Tegola → DeckGL${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# GeoJSON 파일 확인
GEOJSON_FILE="./geojson/buildings.geojson"

if [ ! -f "$GEOJSON_FILE" ]; then
    echo -e "${RED}❌ 오류: geojson/buildings.geojson 파일이 없습니다.${NC}"
    echo -e "${YELLOW}   geojson/ 폴더에 buildings.geojson 파일을 넣어주세요.${NC}"
    exit 1
fi

echo -e "${GREEN}✓ GeoJSON 파일 확인: ${GEOJSON_FILE}${NC}"
echo ""

# Step 1: PostGIS 실행
echo -e "${BLUE}[Step 1/5] PostGIS 데이터베이스 시작...${NC}"
docker compose -f docker-compose.db.yml up -d --build

# Step 2: DB가 healthy 될 때까지 대기
echo -e "${BLUE}[Step 2/5] 데이터베이스 준비 대기 중...${NC}"
echo -n "   "
until docker exec tegola_postgis pg_isready -U gisuser -d gis > /dev/null 2>&1; do
    echo -n "."
    sleep 1
done
echo ""
echo -e "${GREEN}   ✓ 데이터베이스 준비 완료${NC}"
echo ""

# 추가 대기 (PostGIS 확장 로드)
sleep 3

# Step 3: GeoJSON 데이터 넣기 (컨테이너 내부에서 실행)
echo -e "${BLUE}[Step 3/5] GeoJSON 데이터를 DB에 넣는 중...${NC}"

# 기존 테이블 삭제 (있으면)
docker exec tegola_postgis psql -U gisuser -d gis -c "DROP TABLE IF EXISTS buildings;" > /dev/null 2>&1 || true

# 컨테이너 내부에서 ogr2ogr 실행 (geojson 폴더가 /geojson으로 마운트됨)
docker exec tegola_postgis ogr2ogr \
    -f "PostgreSQL" \
    PG:"host=localhost port=5432 user=gisuser dbname=gis password=gispw" \
    /geojson/buildings.geojson \
    -nln buildings \
    -a_srs EPSG:3857 \
    -nlt MULTIPOLYGON \
    -lco GEOMETRY_NAME=geom \
    -skipfailures

# 데이터 개수 확인
COUNT=$(docker exec tegola_postgis psql -U gisuser -d gis -t -c "SELECT COUNT(*) FROM buildings;" | tr -d ' ')
echo -e "${GREEN}   ✓ ${COUNT}개의 건물 데이터 임포트 완료${NC}"
echo ""

# Step 4: Tegola 실행
echo -e "${BLUE}[Step 4/5] Tegola 벡터타일 서버 시작...${NC}"
docker compose -f docker-compose.tegola.yml up -d

sleep 2
echo -e "${GREEN}   ✓ Tegola 서버 시작 완료${NC}"
echo ""

# Step 5: DeckGL 프론트엔드 실행
echo -e "${BLUE}[Step 5/5] DeckGL 프론트엔드 시작...${NC}"
docker compose -f docker-compose.deckgl.yml up -d --build

# DeckGL 준비 대기
echo -n "   "
until curl -s http://localhost:4000 > /dev/null 2>&1; do
    echo -n "."
    sleep 1
done
echo ""
echo -e "${GREEN}   ✓ DeckGL 프론트엔드 시작 완료${NC}"
echo ""

# 완료 메시지
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  ✅ 모든 서비스 시작 완료!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "  📊 Tegola 미리보기: ${YELLOW}http://localhost:28080${NC}"
echo -e "  🌐 DeckGL 3D 뷰어:  ${YELLOW}http://localhost:4000${NC}"
echo ""
echo -e "  💡 ${BLUE}deckgl/src/Map.tsx${NC} 파일을 수정하면 자동으로 반영됩니다."
echo ""
echo -e "  🛑 종료하려면: ${YELLOW}./stop.sh${NC}"
echo ""
