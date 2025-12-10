# PostGIS Docker 이미지
# PostgreSQL 16 + PostGIS 3.4 + GDAL
FROM postgis/postgis:16-3.4

# GDAL 설치 (ogr2ogr 포함)
RUN apt-get update && apt-get install -y \
    gdal-bin \
    && rm -rf /var/lib/apt/lists/*

# 환경변수 설정
ENV POSTGRES_USER=gisuser
ENV POSTGRES_PASSWORD=gispw
ENV POSTGRES_DB=gis

# 초기화 스크립트 복사 (컨테이너 시작 시 자동 실행)
COPY ./init-db.sql /docker-entrypoint-initdb.d/

# PostgreSQL 기본 포트
EXPOSE 5432
