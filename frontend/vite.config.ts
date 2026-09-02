import react from "@vitejs/plugin-react";
import { defineConfig } from "vite";

// Single unified web app. Live surfaces (employers + console) need this
// origin in the API's JOBIFY_CORS_ALLOW_ORIGINS. See frontend/README.md.
// (The applicant `web` surface was removed in 2026-07 — the Flutter app in
// app/ is the applicant client.)
export default defineConfig({
  plugins: [react()],
  server: { port: 5173 },
});
