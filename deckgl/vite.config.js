import react from "@vitejs/plugin-react";
import { defineConfig } from "vite";

// https://vitejs.dev/config/
export default defineConfig({
  plugins: [react()],
  optimizeDeps: {
    include: ["mapbox-gl"],
  },
  define: {
    "process.env": {},
  },
  server: {
    port: 4000,
    open: true,
    proxy: {
      "/tiles": {
        target: "http://localhost:8080",
        changeOrigin: true,
      },
    },
  },
});
