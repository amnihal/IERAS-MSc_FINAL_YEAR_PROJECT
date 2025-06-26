import json
from channels.generic.websocket import AsyncWebsocketConsumer

class NormalVehicleConsumer(AsyncWebsocketConsumer):
    async def connect(self):
        await self.channel_layer.group_add("normal_vehicle_group", self.channel_name)
        await self.accept()
        print("✅ Normal vehicle connected to WebSocket")

    async def disconnect(self, close_code):
        await self.channel_layer.group_discard("normal_vehicle_group", self.channel_name)
        print("❌ Normal vehicle disconnected from WebSocket")

    async def receive(self, text_data):
        # If you want ambulance to send location etc.
        pass


    async def ambulance_location(self, event):
        ambulance_id = event["ambulance_id"]
        latitude = event["latitude"]
        longitude = event["longitude"]
        to_lat = event["to_lat"]
        to_long = event["to_long"]

        data = {
            "ambulance_id": ambulance_id,
            "latitude": latitude,
            "longitude": longitude,
            "to_lat": to_lat,
            "to_long": to_long,
        }
        await self.send(text_data=json.dumps(data))
        print(f"📤 Sent location to normal vehicle: {data}")
