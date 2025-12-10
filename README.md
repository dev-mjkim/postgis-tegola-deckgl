# GeoJSON → PostGIS → Tegola → DeckGL 3D 빌딩 시각화

GeoJSON 빌딩 데이터를 3D로 시각화하는 파이프라인입니다.

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   GeoJSON   │────▶│   PostGIS   │────▶│   Tegola    │────▶│   DeckGL    │
│   (데이터)    │     │    (DB)     │     │ (벡터타일)    │     │  (3D 렌더링)  │
└─────────────┘     └─────────────┘     └─────────────┘     └─────────────┘
```

---

## 📋 사전 요구사항

- **Docker & Docker Compose** - 이것만 있으면 됩니다! 🐳

---

## 📁 GeoJSON 데이터 준비

`geojson/` 폴더에 **`buildings.geojson`** 파일을 넣어주세요.

```
geojson/
└── buildings.geojson   ← 이 파일명으로 저장!
```

### 필수 조건

| 항목      | 값                             |
| --------- | ------------------------------ |
| 파일명    | **`buildings.geojson`** (고정) |
| 좌표계    | **EPSG:3857** (Web Mercator)   |
| Geometry  | MultiPolygon 또는 Polygon      |
| 높이 속성 | `height` (미터 단위)           |

### 예시 GeoJSON 구조

```json
{
  "type": "FeatureCollection",
  "features": [
    {
      "type": "Feature",
      "geometry": {
        "type": "MultiPolygon",
        "coordinates": [...]
      },
      "properties": {
        "height": 45.5
      }
    }
  ]
}
```

> ⚠️ **주의**: `properties`에 `height` 필드가 없으면 DeckGL에서 기본값(30m)으로 표시됩니다.

---

## ⚡ 빠른 시작 (원클릭 실행)

GeoJSON 파일을 `geojson/` 폴더에 넣고 스크립트만 실행하면 끝!

### Linux / macOS

```bash
./start.sh
```

### Windows

```cmd
start.bat
```

> 스크립트가 자동으로: DB 실행 → 데이터 임포트 → Tegola 실행 → DeckGL 실행까지 모두 처리합니다!
>
> 완료되면 http://localhost:4000 에서 3D 빌딩을 볼 수 있습니다.
>
> 💡 `deckgl/src/Map.tsx` 파일을 수정하면 자동으로 반영됩니다 (핫리로드)

### 종료 및 전체 삭제

```bash
# Linux / macOS
./stop.sh

# Windows
stop.bat
```

---

## 🚀 수동 실행 방법 (단계별)

### Step 1. PostGIS 데이터베이스 실행

```bash
docker compose -f docker-compose.db.yml up -d --build
```

DB가 완전히 뜰 때까지 약 10초 정도 기다려주세요.

```bash
# DB 상태 확인 (healthy가 되어야 함)
docker ps
```

#### Database 내부에 접근하기 (선택사항)

DB 내부에서 직접 SQL을 실행하고 싶다면:

```bash
# 컨테이너 내부 psql 접속 (한 줄로)
docker exec -it tegola_postgis psql -U gisuser -d gis
```

### Step 2. GeoJSON 데이터를 DB에 넣기

```bash
# 기존 테이블 삭제 (있으면)
docker exec tegola_postgis psql -U gisuser -d gis -c "DROP TABLE IF EXISTS buildings;"

# 컨테이너 내부에서 ogr2ogr 실행
docker exec tegola_postgis ogr2ogr \
  -f "PostgreSQL" \
  PG:"host=localhost port=5432 user=gisuser dbname=gis password=gispw" \
  /geojson/buildings.geojson \
  -nln buildings \
  -a_srs EPSG:3857 \
  -nlt MULTIPOLYGON \
  -lco GEOMETRY_NAME=geom \
  -skipfailures
```

> 📌 데이터가 잘 들어갔는지 확인해보세요:

```bash
# 컨테이너 내부 psql 접속 (한 줄로)
docker exec -it tegola_postgis psql -U gisuser -d gis
```

```sql
-- 테이블 목록 확인
\dt

-- 데이터 개수 확인
SELECT COUNT(*) FROM buildings;

-- 나가기
\q
```

### Step 3. Tegola 벡터타일 서버 실행

```bash
docker compose -f docker-compose.tegola.yml up -d
```

#### Tegola Web Console로 데이터 미리보기

Tegola는 내장 웹 콘솔을 제공합니다. 브라우저에서 접속해서 데이터가 잘 들어갔는지 확인할 수 있습니다:

```
http://localhost:28080
```

**⚠️ 지도가 엉뚱한 곳을 보여준다면?**

`tegola/tegola.toml` 파일에서 `center` 값을 데이터의 중심 좌표로 수정하세요:

```toml
[[maps]]
name = "seoul_buildings"
center = [ 경도, 위도, 줌레벨 ]  # 예: [127.0, 37.5, 12.0] (서울)
```

| 파라미터 | 설명           | 예시  |
| -------- | -------------- | ----- |
| 경도     | Longitude (X)  | 127.0 |
| 위도     | Latitude (Y)   | 37.5  |
| 줌레벨   | 초기 줌 (0~20) | 12.0  |

> 💡 **Tip**: 데이터의 중심 좌표를 모르겠다면 DB에서 조회:
>
> ```bash
> docker exec -it tegola_postgis psql -U gisuser -d gis -c \
>   "SELECT ST_X(ST_Centroid(ST_Transform(ST_SetSRID(ST_Extent(geom), 3857), 4326))), \
>           ST_Y(ST_Centroid(ST_Transform(ST_SetSRID(ST_Extent(geom), 3857), 4326))) \
>    FROM buildings;"
> ```

수정 후 Tegola 재시작:

```bash
docker compose -f docker-compose.tegola.yml restart
```

### Step 4. DeckGL 프론트엔드 실행

```bash
cd deckgl
npm install
npm run dev
```

브라우저에서 http://localhost:4000 접속!

> 💡 데이터 위치에 맞게 `deckgl/src/Map.tsx`의 `center` 좌표를 수정하세요.

---

## 🔧 커스터마이징

### 다른 속성으로 높이 표현하기

`deckgl/src/Map.tsx`에서 `getElevation` 수정:

```tsx
getElevation: (f) => f.properties?.height ?? 30,
// 또는 다른 속성 사용
getElevation: (f) => f.properties?.h_max ?? f.properties?.height ?? 30,
```

### Tegola SQL 쿼리 수정

`tegola/tegola.toml`에서 SELECT 할 컬럼 수정:

```toml
sql = "SELECT ST_AsMVTGeom(geom, !BBOX!) AS geom, ogc_fid, height FROM buildings WHERE geom && !BBOX!"
```

---

## 🛑 종료 방법

```bash
# DeckGL 종료
# 터미널에서 Ctrl+C

# Tegola 종료
docker compose -f docker-compose.tegola.yml down

# PostGIS 종료
docker compose -f docker-compose.db.yml down
```

### 🗑️ 전체 삭제 (처음부터 다시 시작하고 싶을 때)

```bash
# 모든 컨테이너 종료 + 볼륨(DB 데이터) + 네트워크 삭제
docker compose -f docker-compose.tegola.yml down -v
docker compose -f docker-compose.db.yml down -v

# 생성된 Docker 네트워크 삭제
docker network rm tegola_network 2>/dev/null || true

# 빌드된 이미지까지 삭제 (선택사항)
docker rmi tegola_deckgl-postgis 2>/dev/null || true
```

> ⚠️ 위 명령어 실행 후 Step 1부터 다시 시작하면 됩니다.

---

## 📡 포트 정보

| 서비스  | 포트  | 용도                    |
| ------- | ----- | ----------------------- |
| PostGIS | 25432 | PostgreSQL 데이터베이스 |
| Tegola  | 28080 | 벡터타일 서버           |
| DeckGL  | 4000  | 프론트엔드 (Vite)       |

---

### Map.tsx 를 수정하고나서
```
docker restart deckgl_frontend
```
 
실행해서 브라우저 새로고침하세연.

### DB 내부에서 데이터 수정하기

#### 1. DB 접근

```
docker exec -it tegola_postgis psql -U gisuser -d gis
```

#### 2. 원하는 데이터 변경하기

예시)

```
UPDATE 테이블이름
SET height = 180
WHERE id = 1;
```
