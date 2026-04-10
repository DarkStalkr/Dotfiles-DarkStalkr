pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property string city: ""
    property string loc: ""
    property var cc: null
    property list<var> forecast: []
    property list<var> hourlyForecast: []
    property int _requestGen: 0
    property int _retryCount: 0
    property int _maxRetries: 3
    property bool _isFetching: false

    readonly property string icon: cc ? Icons.getWeatherIcon(String(cc.weatherCode)) : "cloud_alert"
    readonly property string description: cc?.weatherDesc ?? qsTr("No weather")
    readonly property string temp: cc ? cc.tempC + "°C" : "--°C"
    readonly property string feelsLike: cc ? cc.feelsLikeC + "°C" : "--°C"
    readonly property int humidity: cc?.humidity ?? 0
    readonly property real windSpeed: cc?.windSpeed ?? 0
    readonly property string sunrise: cc ? Qt.formatDateTime(new Date(cc.sunrise), "hh:mm A") : "--:--"
    readonly property string sunset: cc ? Qt.formatDateTime(new Date(cc.sunset), "hh:mm A") : "--:--"

    FileView {
        id: cacheFile
        path: Quickshell.cachePath("weather.json")
        onLoaded: root.reload()

        JsonAdapter {
            id: cache
            property var cc: null
            property list<var> forecast: []
            property string city: ""
            property string loc: ""
            property real timestamp: 0
        }
    }

    function reload(): void {
        // 1. Load from cache immediately if available
        if (cache.cc) {
            console.log("Weather: Loading from cache...");
            cc = cache.cc;
            forecast = cache.forecast;
            city = cache.city;
            loc = cache.loc;
        }

        // 2. Decide if we need to update from network
        const now = Date.now();
        const age = now - cache.timestamp;
        
        if (cache.timestamp === 0 || age > 1800000) {
            console.log("Weather: Cache expired or missing (age: " + Math.round(age / 60000) + " mins). Fetching from network...");
            const gen = ++root._requestGen;
            _retryCount = 0;
            fetchLocation(gen);
        } else {
            console.log("Weather: Cache is fresh (age: " + Math.round(age / 60000) + " mins).");
        }
    }

    function fetchLocation(gen): void {
        Requests.get("https://ipinfo.io/json", function(text) {
            if (gen !== root._requestGen) return;
            try {
                var response = JSON.parse(text);
                console.log("Weather: ipinfo.io response:", JSON.stringify(response, null, 2));
                if (response.loc) {
                    loc = response.loc;
                    city = response.city ?? "";
                    fetchWeatherData(gen);
                } else {
                    console.error("Weather: ipinfo.io did not return location data.");
                    useCacheFallback();
                }
            } catch (e) {
                console.error("Weather reload error (ipinfo.io): " + e + "\\nResponse text: " + text);
                useCacheFallback();
            }
        }, function(errorText) {
            console.error("Weather: ipinfo.io request failed: " + errorText);
            useCacheFallback();
        });
    }

    function useCacheFallback(): void {
        if (cache.cc) {
            console.log("Weather: Falling back to old cached data");
            cc = cache.cc;
            forecast = cache.forecast;
            city = cache.city;
            loc = cache.loc;
        }
    }

    function fetchWeatherData(gen): void {
        if (!loc) {
            console.warn("Weather: No location (loc) available to fetch weather data.");
            useCacheFallback();
            return;
        }
        var coords = loc.split(",");
        var url = "https://api.open-meteo.com/v1/forecast?latitude=" + coords[0] + "&longitude=" + coords[1] + "&current=temperature_2m,relative_humidity_2m,apparent_temperature,is_day,weather_code,wind_speed_10m&daily=weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset&timezone=auto";
        console.log("Weather: Fetching weather data from:", url);

        Requests.get(url, function(text) {
            if (gen !== root._requestGen) return;
            try {
                var json = JSON.parse(text);
                // console.log("Weather: open-meteo.com response:", JSON.stringify(json, null, 2));
                if (!json.current || !json.daily) {
                    throw new Error("Missing current or daily data");
                }

                cc = {
                    weatherCode: json.current.weather_code,
                    weatherDesc: getWeatherCondition(json.current.weather_code),
                    tempC: Math.round(json.current.temperature_2m),
                    feelsLikeC: Math.round(json.current.apparent_temperature),
                    humidity: json.current.relative_humidity_2m,
                    windSpeed: json.current.wind_speed_10m,
                    isDay: json.current.is_day,
                    sunrise: json.daily.sunrise[0],
                    sunset: json.daily.sunset[0]
                };

                var forecastList = [];
                for (var i = 0; i < json.daily.time.length; i++) {
                    forecastList.push({
                        date: json.daily.time[i],
                        maxTempC: Math.round(json.daily.temperature_2m_max[i]),
                        minTempC: Math.round(json.daily.temperature_2m_min[i]),
                        weatherCode: json.daily.weather_code[i],
                        icon: Icons.getWeatherIcon(String(json.daily.weather_code[i]))
                    });
                }
                forecast = forecastList;

                // Update cache
                cache.cc = cc;
                cache.forecast = forecastList;
                cache.city = city;
                cache.loc = loc;
                cache.timestamp = Date.now();
                cacheFile.writeAdapter();

            } catch (e) {
                console.error("Fetch weather data error (open-meteo.com): " + e);
                handleFetchError(gen);
            }
        }, function(errorText) {
            console.error("Weather: open-meteo.com request failed: " + errorText);
            handleFetchError(gen);
        });
    }

    function handleFetchError(gen): void {
        if (_retryCount < _maxRetries) {
            _retryCount++;
            console.log("Weather: Retrying fetch (" + _retryCount + "/" + _maxRetries + ")...");
            // Exponential backoff
            retryTimer.interval = Math.pow(2, _retryCount) * 1000;
            retryTimer.gen = gen;
            retryTimer.start();
        } else {
            console.log("Weather: Max retries reached, trying fallback provider...");
            fetchFallbackWeatherData(gen);
        }
    }

    function fetchFallbackWeatherData(gen): void {
        // wttr.in fallback
        var url = "https://wttr.in/" + encodeURIComponent(city || "Mexico City") + "?format=j1";
        console.log("Weather: Fetching fallback data from:", url);

        Requests.get(url, function(text) {
            if (gen !== root._requestGen) return;
            try {
                var json = JSON.parse(text);
                var current = json.current_condition[0];
                var weather = json.weather[0];
                var astronomy = weather.astronomy[0];

                var now = new Date();
                var todayStr = now.toISOString().split("T")[0];

                function parseAstronomyTime(timeStr) {
                    var parts = timeStr.match(/(\d+):(\d+)\s+(AM|PM)/);
                    if (!parts) return todayStr + "T06:00"; // Fallback
                    var hours = parseInt(parts[1]);
                    var minutes = parseInt(parts[2]);
                    var ampm = parts[3];
                    if (ampm === "PM" && hours < 12) hours += 12;
                    if (ampm === "AM" && hours === 12) hours = 0;
                    var hStr = hours < 10 ? "0" + hours : "" + hours;
                    var mStr = minutes < 10 ? "0" + minutes : "" + minutes;
                    return todayStr + "T" + hStr + ":" + mStr;
                }

                var sunriseStr = parseAstronomyTime(astronomy.sunrise);
                var sunsetStr = parseAstronomyTime(astronomy.sunset);
                var sunriseDate = new Date(sunriseStr);
                var sunsetDate = new Date(sunsetStr);

                cc = {
                    weatherCode: mapWwoToWmo(current.weatherCode),
                    weatherDesc: current.weatherDesc[0].value,
                    tempC: parseInt(current.temp_C),
                    feelsLikeC: parseInt(current.FeelsLikeC),
                    humidity: parseInt(current.humidity),
                    windSpeed: parseInt(current.windspeedKmph),
                    isDay: (now >= sunriseDate && now <= sunsetDate) ? 1 : 0,
                    sunrise: sunriseStr,
                    sunset: sunsetStr
                };

                var forecastList = [];
                for (var i = 0; i < json.weather.length; i++) {
                    var day = json.weather[i];
                    forecastList.push({
                        date: day.date,
                        maxTempC: parseInt(day.maxtempC),
                        minTempC: parseInt(day.mintempC),
                        weatherCode: mapWwoToWmo(day.hourly[4].weatherCode), // mid-day
                        icon: Icons.getWeatherIcon(String(mapWwoToWmo(day.hourly[4].weatherCode)))
                    });
                }
                forecast = forecastList;
                
                // Update cache
                cache.cc = cc;
                cache.forecast = forecastList;
                cache.city = city;
                cache.loc = loc;
                cache.timestamp = Date.now();
                cacheFile.writeAdapter();

            } catch (e) {
                console.error("Fetch fallback weather data error (wttr.in): " + e);
                useCacheFallback();
            }
        }, function(errorText) {
            console.error("Weather: wttr.in request failed: " + errorText);
            useCacheFallback();
        });
    }

    // Rough mapping from WWO codes to WMO codes
    function mapWwoToWmo(wwoCode) {
        var mapping = {
            "113": 0,  // Clear/Sunny
            "116": 2,  // Partly Cloudy
            "119": 3,  // Cloudy
            "122": 3,  // Overcast
            "143": 45, // Mist
            "176": 61, // Patchy rain nearby
            "179": 71, // Patchy snow nearby
            "182": 61, // Patchy sleet nearby
            "185": 61, // Patchy freezing drizzle nearby
            "200": 95, // Thundery outbreaks in nearby
            "227": 71, // Blowing snow
            "230": 75, // Blizzard
            "248": 45, // Fog
            "260": 48, // Freezing fog
            "263": 51, // Patchy light drizzle
            "266": 51, // Light drizzle
            "281": 56, // Freezing drizzle
            "284": 57, // Heavy freezing drizzle
            "293": 61, // Patchy light rain
            "296": 61, // Light rain
            "299": 63, // Moderate rain at times
            "302": 63, // Moderate rain
            "305": 65, // Heavy rain at times
            "308": 65, // Heavy rain
            "311": 66, // Light freezing rain
            "314": 67, // Moderate or heavy freezing rain
            "317": 61, // Light sleet
            "320": 61, // Moderate or heavy sleet
            "323": 71, // Patchy light snow
            "326": 71, // Light snow
            "329": 73, // Patchy moderate snow
            "332": 73, // Moderate snow
            "335": 75, // Patchy heavy snow
            "338": 75, // Heavy snow
            "350": 77, // Ice pellets
            "353": 80, // Light rain shower
            "356": 81, // Moderate or heavy rain shower
            "359": 82, // Torrential rain shower
            "362": 80, // Light sleet showers
            "365": 81, // Moderate or heavy sleet showers
            "368": 85, // Light snow showers
            "371": 86, // Moderate or heavy snow showers
            "374": 77, // Light showers of ice pellets
            "377": 77, // Moderate or heavy showers of ice pellets
            "386": 95, // Patchy light rain in thunder
            "389": 99, // Moderate or heavy rain in thunder
            "392": 95, // Patchy light snow in thunder
            "395": 99  // Moderate or heavy snow in thunder
        };
        return mapping[String(wwoCode)] || 0;
    }

    Timer {
        id: retryTimer
        property int gen: 0
        onTriggered: fetchWeatherData(gen)
    }

    function getWeatherCondition(code) {
        var conditions = {
            "0": "Clear sky", "1": "Mainly clear", "2": "Partly cloudy", "3": "Overcast",
            "45": "Fog", "48": "Depositing rime fog", "51": "Light drizzle",
            "53": "Moderate drizzle", "55": "Dense drizzle", "56": "Light freezing drizzle",
            "57": "Dense freezing drizzle", "61": "Slight rain", "63": "Moderate rain",
            "65": "Heavy rain", "66": "Light freezing rain", "67": "Heavy freezing rain",
            "71": "Slight snow fall", "73": "Moderate snow fall", "75": "Heavy snow fall",
            "77": "Snow grains", "80": "Slight rain showers", "81": "Moderate rain showers",
            "82": "Violent rain showers", "85": "Slight snow showers", "86": "Heavy snow showers",
            "95": "Thunderstorm", "96": "Thunderstorm with slight hail", "99": "Thunderstorm with heavy hail"
        };
        var condition = conditions[String(code)];
        if (condition === undefined) {
            console.warn("Weather: Unknown weather code encountered: " + code);
            return "Unknown";
        }
        return condition;
    }

    Component.onCompleted: {
        cacheFile.reload();
    }

    Timer {
        interval: 1800000 // 30 mins
        running: true
        repeat: true
        onTriggered: reload()
    }
}
