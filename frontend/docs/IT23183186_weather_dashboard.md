# Environment weather dashboard

The Environment bottom-navigation destination now uses the supplied reference component structure with the shared Frontend_skill palette and Inter typography. Saved apiary/hive selection and snapshot history remain available.

Components:
- Current outdoor weather and observation time, with a real location map beside it on wide screens and below it on phones.
- Daily forecast cards and a selectable hourly temperature/feels-like, precipitation, humidity, or wind chart/list.
- Nine weather cards: temperature, feels-like, cloud cover, precipitation, wind, humidity, UV, air quality category, and visibility. Optional fields remain unavailable when omitted by the provider. Small temperature sparklines are explicitly labeled as forecast trends.
- Month selection and a calendar populated only from loaded observations and forecasts; tapping a date explains its data or missing coverage.
- Rain/no-recorded-rain observation summary for the selected month and historical high/low temperature, precipitation, humidity, and wind charts.

The forecast endpoint requests three days. The historical endpoint supports the previous seven days. This does not provide a complete monthly calendar, a twelve-month climate series, thirty-day predictions, or storm radar. Blank calendar dates are intentional. The Air Quality card displays WeatherAPI's US EPA category 1-6, not a fabricated 0-500 AQI score.

## Actual map

The reusable ApiaryWeatherMap renders on-demand OpenStreetMap tiles at the location returned by WeatherAPI, with saved numeric apiary coordinates as fallback. It supports drag-to-pan, zoom buttons, recentering, a weather-label toggle, and retry. The marker is tied to actual coordinates; no illustrative map or synthetic storm overlay is used. Attribution remains visible. A network/backend failure displays unavailable tiles and retry controls.

`GET /api/v1/environment/map/tiles/{z}/{x}/{y}.png` validates tile coordinates, identifies the app to the provider, and caches tiles for seven days in the operating system temporary directory (`HiveSenseResearchMapTiles`). It downloads only tiles visible in the viewport; there is no offline/bulk download feature. Cache responses are also provided to the client. No new runtime dependency or map API key is required.

Restart FastAPI and hot-restart Flutter after updating. Weather still needs WEATHERAPI_KEY in backend/.env. Forecast/history access depends on the configured provider account; failures keep current conditions and saved hive features usable. Map tiles require network access from the backend. Inter font weights 400-800 are bundled with their OFL license so text rendering does not depend on a runtime font download.

## Verification

Backend tests exercise forecast forwarding, omitted metrics, tile validation/caching, and existing assessment/history behavior. Widget tests cover 320px and 1120px layouts, calendar gaps, chart/list selection, hive location changes, and the existing snapshot/history flow. A live tile request returned a valid PNG through the new caching service. Test weather values are fixtures, not real apiary observations.

Provider references: [WeatherAPI forecast fields](https://www.weatherapi.com/docs/forecast-api/), [OpenStreetMap tile policy](https://operations.osmfoundation.org/policies/tiles/), [Inter source and license](https://github.com/google/fonts/tree/main/ofl/inter).
