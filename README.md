# ⛅ WeatherAPI.com — Developer Reference

> **Real-time weather, forecasts, astronomy, marine data, and more — delivered via a clean RESTful API.**

[![Version](https://img.shields.io/badge/version-1.0.2-blue?style=flat-square)](https://www.weatherapi.com)
[![Format](https://img.shields.io/badge/format-JSON%20%7C%20XML-green?style=flat-square)](https://www.weatherapi.com/docs/)
[![Auth](https://img.shields.io/badge/auth-API%20Key-orange?style=flat-square)](https://www.weatherapi.com/signup.aspx)
[![Base URL](https://img.shields.io/badge/base%20URL-api.weatherapi.com%2Fv1-lightgrey?style=flat-square)](https://api.weatherapi.com/v1)

---

## 📋 Table of Contents

- [Overview](#overview)
- [Getting Started](#getting-started)
- [Authentication](#authentication)
- [Base URL](#base-url)
- [Endpoints](#endpoints)
  - [Realtime Weather](#-realtime-weather)
  - [Forecast](#-forecast)
  - [History](#-history)
  - [Future Weather](#-future-weather)
  - [Marine Weather](#-marine-weather)
  - [Astronomy](#-astronomy)
  - [Search / Autocomplete](#-search--autocomplete)
  - [IP Lookup](#-ip-lookup)
  - [Time Zone](#-time-zone)
- [Request Parameters](#request-parameters)
- [Response Objects](#response-objects)
- [Error Handling](#error-handling)
- [SDKs & Tools](#sdks--tools)

---

## Overview

WeatherAPI.com provides global weather and geo data through a simple, well-documented REST API. Whether you're building a mobile app, a dashboard, or an IoT device, you can access:

| Data Type | Description |
|---|---|
| 🌤 Real-time Weather | Up-to-the-minute current conditions |
| 📅 14-Day Forecast | Daily and hourly interval forecasts |
| 📖 Historical Weather | Back to January 1, 2010 |
| 🌊 Marine & Tide Data | Swell height, wave period, direction |
| 🔭 Future Weather | Up to 365 days ahead (3-hourly) |
| 🌙 Astronomy | Sunrise, sunset, moon phase & illumination |
| 🌍 Geo & Time Zone | Location info and timezone lookup |
| 🔍 Search / Autocomplete | City/location search |
| 💨 Air Quality | CO, NO₂, O₃, SO₂, PM2.5, PM10, EPA & DEFRA indices |
| 🚨 Weather Alerts | Active alerts and advisories |

---

## Getting Started

1. **Sign up** at [weatherapi.com/signup.aspx](https://www.weatherapi.com/signup.aspx)
2. **Retrieve your API key** from your [account dashboard](https://www.weatherapi.com/login.aspx)
3. **Make your first request:**

```bash
curl "https://api.weatherapi.com/v1/current.json?key=YOUR_API_KEY&q=London"
```

Try it interactively using the [API Explorer](https://www.weatherapi.com/api-explorer.aspx).

---

## Authentication

All requests require an API key passed as a query parameter:

```
key=YOUR_API_KEY
```

**Example:**
```
https://api.weatherapi.com/v1/current.json?key=YOUR_API_KEY&q=Paris
```

> ⚠️ If your key is compromised, regenerate it immediately from your account dashboard.

---

## Base URL

```
https://api.weatherapi.com/v1
```

All endpoints are HTTPS only. Responses are available in **JSON** and **XML**.

---

## Endpoints

### ☀️ Realtime Weather

```
GET /current.json
```

Returns current weather conditions for any location.

**Parameters:**

| Parameter | Type | Required | Description |
|---|---|---|---|
| `key` | string | ✅ | Your API key |
| `q` | string | ✅ | Location query (see [Location Query formats](#location-query-q)) |
| `lang` | string | ❌ | Language code for `condition.text` |

**Example Request:**
```bash
curl "https://api.weatherapi.com/v1/current.json?key=YOUR_KEY&q=New+York&lang=en"
```

**Example Response:**
```json
{
  "location": {
    "name": "New York",
    "region": "New York",
    "country": "United States of America",
    "lat": 40.71,
    "lon": -74.01,
    "tz_id": "America/New_York",
    "localtime": "2022-07-22 16:49"
  },
  "current": {
    "temp_c": 34.4,
    "temp_f": 93.9,
    "condition": {
      "text": "Partly cloudy",
      "icon": "//cdn.weatherapi.com/weather/64x64/day/116.png",
      "code": 1003
    },
    "wind_kph": 25.9,
    "humidity": 31,
    "feelslike_c": 37,
    "uv": 8
  }
}
```

---

### 📅 Forecast

```
GET /forecast.json
```

Returns weather forecast for up to **14 days**, including hourly data, astronomy, air quality, and alerts.

**Parameters:**

| Parameter | Type | Required | Description |
|---|---|---|---|
| `key` | string | ✅ | Your API key |
| `q` | string | ✅ | Location query |
| `days` | integer (1–14) | ✅ | Number of forecast days |
| `dt` | date (yyyy-MM-dd) | ❌ | Specific date within forecast range |
| `unixdt` | integer | ❌ | Unix timestamp (use `dt` OR `unixdt`, not both) |
| `hour` | integer (0–23) | ❌ | Return only a specific hour's data |
| `lang` | string | ❌ | Language code |
| `alerts` | string (`yes`/`no`) | ❌ | Include weather alerts |
| `aqi` | string (`yes`/`no`) | ❌ | Include air quality data |
| `tp` | integer | ❌ | Enterprise only: `15` for 15-min intervals |

**Example Request:**
```bash
curl "https://api.weatherapi.com/v1/forecast.json?key=YOUR_KEY&q=London&days=3&aqi=yes&alerts=yes"
```

---

### 📖 History

```
GET /history.json
```

Returns historical weather data back to **January 1, 2010**.

**Parameters:**

| Parameter | Type | Required | Description |
|---|---|---|---|
| `key` | string | ✅ | Your API key |
| `q` | string | ✅ | Location query |
| `dt` | date (yyyy-MM-dd) | ✅ | Start date (on or after 2010-01-01) |
| `end_dt` | date (yyyy-MM-dd) | ❌ | End date (max 30-day range from `dt`) |
| `unixdt` | integer | ❌ | Unix timestamp (use instead of `dt`) |
| `unixend_dt` | integer | ❌ | Unix end timestamp |
| `hour` | integer (0–23) | ❌ | Specific hour only |
| `lang` | string | ❌ | Language code |

**Example Request:**
```bash
curl "https://api.weatherapi.com/v1/history.json?key=YOUR_KEY&q=Tokyo&dt=2023-01-15&end_dt=2023-01-20"
```

---

### 🔮 Future Weather

```
GET /future.json
```

Returns weather in **3-hourly intervals** for a date between **14 and 365 days** from today.

**Parameters:**

| Parameter | Type | Required | Description |
|---|---|---|---|
| `key` | string | ✅ | Your API key |
| `q` | string | ✅ | Location query |
| `dt` | date (yyyy-MM-dd) | ❌ | Target future date (14–300 days from today) |
| `lang` | string | ❌ | Language code |

**Example Request:**
```bash
curl "https://api.weatherapi.com/v1/future.json?key=YOUR_KEY&q=Sydney&dt=2024-03-01"
```

---

### 🌊 Marine Weather

```
GET /marine.json
```

Returns marine and sailing forecasts plus tide data for up to **7 days**. Requires a sea/ocean coordinate.

**Parameters:**

| Parameter | Type | Required | Description |
|---|---|---|---|
| `key` | string | ✅ | Your API key |
| `q` | string | ✅ | Latitude/Longitude on a sea or ocean |
| `days` | integer (1–7) | ✅ | Number of forecast days |
| `dt` | date (yyyy-MM-dd) | ❌ | Specific date within range |
| `unixdt` | integer | ❌ | Unix timestamp alternative |
| `hour` | integer (0–23) | ❌ | Specific hour only |
| `lang` | string | ❌ | Language code |

**Marine-specific response fields:**

| Field | Type | Description |
|---|---|---|
| `sig_ht_mt` | number | Significant wave height (metres) |
| `swell_ht_mt` | number | Swell height (metres) |
| `swell_ht_ft` | number | Swell height (feet) |
| `swell_dir` | number | Swell direction (degrees) |
| `swell_dir_16_point` | number | 16-point compass swell direction |
| `swell_period_secs` | number | Swell period (seconds) |

**Example Request:**
```bash
curl "https://api.weatherapi.com/v1/marine.json?key=YOUR_KEY&q=51.5,-0.1&days=3"
```

---

### 🌙 Astronomy

```
GET /astronomy.json
```

Returns sunrise, sunset, moonrise, moonset, moon phase, and moon illumination for a specific date.

**Parameters:**

| Parameter | Type | Required | Description |
|---|---|---|---|
| `key` | string | ✅ | Your API key |
| `q` | string | ✅ | Location query |
| `dt` | date (yyyy-MM-dd) | ✅ | Date (on or after 2015-01-01) |

**Example Response:**
```json
{
  "astronomy": {
    "astro": {
      "sunrise": "05:10 AM",
      "sunset": "09:03 PM",
      "moonrise": "12:29 AM",
      "moonset": "04:01 PM",
      "moon_phase": "Third Quarter",
      "moon_illumination": "42"
    }
  }
}
```

---

### 🔍 Search / Autocomplete

```
GET /search.json
```

Returns an array of matching cities and towns for use in search/autocomplete features.

**Parameters:**

| Parameter | Type | Required | Description |
|---|---|---|---|
| `key` | string | ✅ | Your API key |
| `q` | string | ✅ | Search string (partial city name, postcode, etc.) |

**Example Response:**
```json
[
  {
    "id": 2796590,
    "name": "Holborn",
    "region": "Camden Greater London",
    "country": "United Kingdom",
    "lat": 51.52,
    "lon": -0.12,
    "url": "holborn-camden-greater-london-united-kingdom"
  }
]
```

---

### 🌐 IP Lookup

```
GET /ip.json
```

Returns geographic and timezone information for a given IP address.

**Parameters:**

| Parameter | Type | Required | Description |
|---|---|---|---|
| `key` | string | ✅ | Your API key |
| `q` | string | ✅ | IP address (IPv4 or IPv6) |

---

### 🕐 Time Zone

```
GET /timezone.json
```

Returns timezone and location data for any supported location query.

**Parameters:**

| Parameter | Type | Required | Description |
|---|---|---|---|
| `key` | string | ✅ | Your API key |
| `q` | string | ✅ | Location query |

---

## Request Parameters

### Location Query (`q`)

The `q` parameter accepts multiple formats:

| Format | Example |
|---|---|
| City name | `q=Paris` |
| US Zip Code | `q=10001` |
| UK Postcode | `q=SW1A+1AA` |
| Canada Postal Code | `q=M5H+2N2` |
| Latitude/Longitude | `q=48.8566,2.3522` |
| IP Address | `q=100.0.0.1` |

### Language Codes (`lang`)

Pass a language code to receive `condition.text` in your desired language. Full list available in the [WeatherAPI docs](https://www.weatherapi.com/docs/#intro-request).

---

## Response Objects

### `location`

| Field | Type | Description |
|---|---|---|
| `name` | string | City name |
| `region` | string | Region or state |
| `country` | string | Country |
| `lat` | number | Latitude |
| `lon` | number | Longitude |
| `tz_id` | string | Timezone identifier |
| `localtime_epoch` | integer | Local time as Unix timestamp |
| `localtime` | string | Local time (yyyy-MM-dd HH:mm) |

### `current`

| Field | Type | Description |
|---|---|---|
| `temp_c` / `temp_f` | number | Temperature in °C / °F |
| `feelslike_c` / `feelslike_f` | number | Feels-like temperature |
| `condition` | object | `text`, `icon`, `code` |
| `wind_kph` / `wind_mph` | number | Wind speed |
| `wind_dir` | string | Wind direction (e.g. `S`, `NW`) |
| `humidity` | number | Relative humidity (%) |
| `cloud` | number | Cloud cover (%) |
| `precip_mm` / `precip_in` | number | Precipitation |
| `vis_km` / `vis_miles` | number | Visibility |
| `uv` | integer | UV index |
| `gust_kph` / `gust_mph` | number | Wind gust speed |
| `air_quality` | object | CO, NO₂, O₃, SO₂, PM2.5, PM10, EPA index, DEFRA index |

### `forecast.forecastday[]`

| Field | Type | Description |
|---|---|---|
| `date` | string | Forecast date |
| `day` | object | Daily summary (max/min/avg temp, rain/snow chance, UV, etc.) |
| `astro` | object | Sunrise, sunset, moonrise, moonset, moon phase |
| `hour[]` | array | 24 hourly objects with full weather detail |

### `alerts.alert[]`

| Field | Description |
|---|---|
| `headline` | Alert issuing authority |
| `event` | Alert type (e.g. Heat Advisory) |
| `severity` | Severity level |
| `effective` | Start datetime (ISO 8601) |
| `expires` | Expiry datetime (ISO 8601) |
| `desc` | Full alert description |
| `instruction` | Recommended action |

---

## Error Handling

All errors return a standard error object with a `code` and `message`.

### HTTP Status Codes

| Status | Meaning |
|---|---|
| `200 OK` | Success |
| `400 Bad Request` | Invalid or missing parameters |
| `401 Unauthorized` | API key missing or invalid |
| `403 Forbidden` | Quota exceeded, key disabled, or access restricted |

### Error Codes

| Code | HTTP | Description |
|---|---|---|
| `1002` | 401 | API key not provided |
| `1003` | 400 | Parameter `q` not provided |
| `1005` | 400 | API request URL is invalid |
| `1006` | 400 | No location found for `q` |
| `2006` | 401 | API key is invalid |
| `2007` | 403 | Monthly quota exceeded |
| `2008` | 403 | API key has been disabled |
| `2009` | 403 | No access to this resource (check your plan) |
| `9000` | 400 | Invalid JSON body in bulk request |
| `9001` | 400 | Bulk request exceeds 50 location limit |
| `9999` | 400 | Internal application error |

**Example Error Response:**
```json
{
  "error": {
    "code": 1006,
    "message": "No location found matching parameter 'q'"
  }
}
```

---

## SDKs & Tools

| Resource | Link |
|---|---|
| 📦 Official SDKs (GitHub) | [github.com/weatherapicom](https://github.com/weatherapicom/) |
| 🧪 Interactive API Explorer | [weatherapi.com/api-explorer.aspx](https://www.weatherapi.com/api-explorer.aspx) |
| 📄 Full Documentation | [weatherapi.com/docs](https://www.weatherapi.com/docs/) |
| 💬 Contact & Support | [weatherapi.com/contact.aspx](https://www.weatherapi.com/contact.aspx) |
| 🔑 Sign Up | [weatherapi.com/signup.aspx](https://www.weatherapi.com/signup.aspx) |

---

<p align="center">
  Built with ❤️ using <a href="https://www.weatherapi.com">WeatherAPI.com</a>
</p>
