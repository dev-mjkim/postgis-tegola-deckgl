import { MVTLayer } from "@deck.gl/geo-layers";
import { MapboxOverlay } from "@deck.gl/mapbox";
import maplibregl from "maplibre-gl";
import "maplibre-gl/dist/maplibre-gl.css";
import { useEffect, useRef } from "react";

// Tegola 서버 URL (환경변수 또는 기본값)
const TEGOLA_URL = import.meta.env.VITE_TEGOLA_URL || "http://localhost:28080";

export default function Map() {
  const mapContainerRef = useRef<HTMLDivElement>(null);
  const mapRef = useRef<maplibregl.Map | null>(null);

  useEffect(() => {
    if (mapContainerRef.current && !mapRef.current) {
      const map = new maplibregl.Map({
        container: mapContainerRef.current,
        style: {
          version: 8,
          sources: {
            osm: {
              type: "raster",
              tiles: [
                "https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}",
              ],
              tileSize: 256,
              maxzoom: 19,
            },
          },
          layers: [{ id: "osm", type: "raster", source: "osm" }],
        },
        center: [127.0, 37.5], // 서울 중심 (데이터에 맞게 수정)
        zoom: 13,
        pitch: 60,
        bearing: 0,
      });

      mapRef.current = map;

      const overlay = new MapboxOverlay({
        interleaved: true,
        layers: [
          new MVTLayer({
            id: "buildings-layer",
            data: `${TEGOLA_URL}/maps/seoul_buildings/{z}/{x}/{y}.pbf`,
            minZoom: 10,
            maxZoom: 20,
            getElevation: (f) =>
              f.properties?.height ??
              f.properties?.h_top5_avg ??
              f.properties?.h_mean ??
              30,
            getFillColor: [255, 105, 180, 220],
            getLineColor: [80, 80, 80],
            extruded: true,
            pickable: true,
            autoHighlight: true,
            highlightColor: [255, 255, 0],
          }),
        ],
      });

      map.addControl(overlay);
    }

    return () => {
      mapRef.current?.remove();
      mapRef.current = null;
    };
  }, []);

  return (
    <div
      ref={mapContainerRef}
      style={{ position: "absolute", width: "100%", height: "100%" }}
    />
  );
}
