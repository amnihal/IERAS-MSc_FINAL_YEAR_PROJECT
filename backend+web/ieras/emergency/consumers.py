import json
from channels.generic.websocket import AsyncWebsocketConsumer

class AmbulanceConsumer(AsyncWebsocketConsumer):
    async def connect(self):
        # Join the general ambulance group
        await self.channel_layer.group_add("ambulance_broadcast", self.channel_name)
        await self.accept()

    async def disconnect(self, close_code):
        await self.channel_layer.group_discard("ambulance_broadcast", self.channel_name)

    async def receive(self, text_data):
        # If you want ambulance to send location etc.
        pass

    async def send_emergency(self, event):
        await self.send(text_data=json.dumps(event["data"]))
