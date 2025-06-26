from django.urls import path
from . import consumers

websocket_urlpatterns = [
    path("ws/ambulance/alert/", consumers.NormalVehicleConsumer.as_asgi()),
]