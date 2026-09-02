import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import "./shared/styles/tokens.css";
import "./shared/styles/base.css";
import "./shared/styles/components.css";
import "./shared/styles/candidate-card.css";
import { ThemeProvider } from "./shared/theme/ThemeProvider";
import { App } from "./App";

createRoot(document.getElementById("root")!).render(
  <StrictMode>
    <ThemeProvider>
      <App />
    </ThemeProvider>
  </StrictMode>,
);
