import requests

def get_eta_minutes(from_lat, from_long, to_lat, to_long):
    try:
        url = f"http://router.project-osrm.org/route/v1/driving/{from_long},{from_lat};{to_long},{to_lat}?overview=false"
        response = requests.get(url)
        data = response.json()
        if data.get("routes"):
            duration_seconds = data["routes"][0]["duration"]
            return round(duration_seconds / 60)
    except:
        pass
    return None
