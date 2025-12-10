#!/bin/bash

# ============================================
# 전체 종료 및 정리 스크립트
# ============================================

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  모든 서비스 종료 중...${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Tegola 종료
echo -e "${BLUE}[1/3] Tegola 종료...${NC}"
docker compose -f docker-compose.tegola.yml down -v 2>/dev/null || true

# PostGIS 종료
echo -e "${BLUE}[2/3] PostGIS 종료...${NC}"
docker compose -f docker-compose.db.yml down -v 2>/dev/null || true

# 네트워크 삭제
echo -e "${BLUE}[3/3] Docker 네트워크 정리...${NC}"
docker network rm tegola_network 2>/dev/null || true

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  ✅ 모든 서비스 종료 및 정리 완료${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "  다시 시작하려면: ${GREEN}./start.sh${NC}"
echo ""

