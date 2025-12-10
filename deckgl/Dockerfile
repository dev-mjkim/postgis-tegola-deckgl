# DeckGL 프론트엔드 Docker 이미지
FROM node:20-alpine

WORKDIR /app

# 패키지 파일 복사 및 설치
COPY package*.json ./
RUN npm install

# 소스 코드 복사
COPY . .

# Vite 개발 서버 포트
EXPOSE 4000

# 개발 서버 실행 (--host로 외부 접속 허용)
CMD ["npm", "run", "dev", "--", "--host", "0.0.0.0"]

