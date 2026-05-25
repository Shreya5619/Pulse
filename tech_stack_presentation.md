# Tech Stack Presentation

Below is an interactive deck summarizing the technology stack powering this project.

````carousel
# Tech Stack Overview
### Pulse & LifeCanvas Ecosystem

A state-of-the-art personal cognitive companion and life mapping engine.

* **Frontend**: Cross-platform mobile architecture built for visual excellence.
* **Backend**: High-performance API orchestration server.
* **Intelligence**: Secure edge-and-cloud hybrid AI processing.

> [!NOTE]
> Swipe or click next to explore each component layer.
<!-- slide -->
# Mobile Frontend (Client)
### Cross-Platform Visual Engine

Built with **Flutter** and **Dart** for a smooth, high-fidelity experience.

* **Core Framework**: Flutter 3.x / Dart 3.x
* **State Management**: Provider architecture (`AppState`)
* **Design & Typography**: Google Fonts (`Outfit`, `JetBrains Mono`)
* **Icons**: Lucide Icons package
* **Visuals & Physics**: Custom paint orbital models, force-directed graph physics, custom gesture trackers (scaling, panning, dragging)
* **Local Persistence**: SharedPreferences (`LifeCanvasDiary`)
<!-- slide -->
# Backend Orchestration (Server)
### API Gateway & Intelligence Pipeline

Built using **Node.js** and **TypeScript** for safety and speed.

* **Runtime**: Node.js
* **Language**: TypeScript
* **Server Framework**: Express.js
* **End-points**:
  * `/config` — Serves configuration keys securely to client apps
  * `/lifecanvas` — Logic routes for handling diary log analysis and memory reduction
<!-- slide -->
# AI & Cognitive Engine
### Groq Llama 3 Inference

High-speed LLM processing utilizing advanced edge/cloud security models.

* **Provider**: Groq Cloud API
* **Models**: Llama-3-8b, Llama-3-70b
* **Core Functions**:
  * Emotion classification & log ingestion
  * Phantom future events prediction
  * Graph Map-Reduce cluster pruning and summary generation
* **Security**: Key resolution system fetching tokens dynamically from backend configuration instead of hardcoded client-side keys
````
