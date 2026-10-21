# AI-Based Smart Beehive Mobile Platform

AI-Based Smart Beehive Mobile Platform for Colony Health Monitoring and Relocation Support.

## Research Components

1. AI-Based Colony Health Monitoring
2. Wild Beehive Detection and Relocation Support
3. Bee Acoustic Analysis
4. Environmental Impact Analysis

## Bee Acoustic Analysis (frontend)

Code lives in `frontend/lib/{screens,services,models,widgets,utils}/IT23139930_*.dart`, with tests in `frontend/test/{screens,services,models,support}/IT23139930_*.dart`. See `frontend/docs/IT23139930_acoustic_integration.md`.

The acoustic model (training code, test clips, README) lives in `backend/models/IT23139930_Model/acoustic`. The backend loads `models/queen_baseline.onnx` from there by default (override with `ACOUSTIC_MODEL_PATH`).
