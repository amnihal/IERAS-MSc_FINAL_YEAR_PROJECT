# serializers.py
from rest_framework import serializers
from .models import EmergencyRequest

class EmergencyRequestSerializer(serializers.ModelSerializer):
    user_name = serializers.CharField(source='user.name')
    driver_contact = serializers.CharField(source='ambulance.driver.contact', default='', read_only=True)
    class Meta:
        model = EmergencyRequest
        fields = '__all__'
