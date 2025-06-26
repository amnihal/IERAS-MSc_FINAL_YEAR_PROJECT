from django.urls import path
from . import consumers

websocket_urlpatterns = [
    path("ws/ambulance/", consumers.AmbulanceConsumer.as_asgi()),
    
]
